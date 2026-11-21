#!/usr/bin/env bats
# Unix/shell/shellrc.sh, the shared interactive rc, and the tracked zshrc that sources it: the PATH
# a source sets up (mise's shims folder once, only when it exists), and the completion setup -
# Docker's completions on fpath before the completion system starts, no second compinit in zshrc,
# and the line-editing settings of shell.conf (in zsh nothing without a line: no key, no history
# option); the startup stages (the skip list, the trace), the StartupTasks stage (its gate and
# prompt hook), the Windows aliases, the Greeting stage and the typed fastfetch and onefetch.
# A non-interactive source stops before the interactive part, so nothing but PATH work runs.

load helpers
# `run -127` (a status check that also silences bats' command-not-found warning) needs bats 1.5.
bats_require_minimum_version 1.5.0

setup() {
	setup_foundation
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	rc=$UNIX_DIR/shell/shellrc.sh
}

# PATH after sourcing the rc twice in a clean, non-interactive bash. Usage: rc_path
rc_path() {
	env -i HOME="$HOME" PATH=/usr/bin:/bin DOTFILES_ROOT="$(dirname "$UNIX_DIR")" "${BASH:-bash}" -c '. "$1"; . "$1"; printf "%s" "$PATH"' _ "$rc"
}

@test "mise's shims folder goes first on PATH, once, and only when it exists" {
	run rc_path
	[ "$status" -eq 0 ]
	[[ ":$output:" != *"/mise/shims:"* ]]
	mkdir -p "$HOME/.local/share/mise/shims"
	run rc_path
	[ "$status" -eq 0 ]
	[[ $output == "$HOME/.local/share/mise/shims:"* ]]
	[ "$(tr ':' '\n' <<<"$output" | grep -c '/mise/shims$')" -eq 1 ]
}

@test "Docker Desktop's per-user ~/.docker/bin goes last on PATH, once, and only when it exists" {
	run rc_path
	[ "$status" -eq 0 ]
	[[ ":$output:" != *"/.docker/bin:"* ]]
	mkdir -p "$HOME/.docker/bin"
	run rc_path
	[ "$status" -eq 0 ]
	[[ $output == *":$HOME/.docker/bin" ]]
	[ "$(tr ':' '\n' <<<"$output" | grep -c '/\.docker/bin$')" -eq 1 ]
	# The tracked login files carry no PATH line of their own: an installer's copy belongs in
	# ~/.shellrc.local.
	! grep -qE '^[^#]*\.docker/bin' "$UNIX_DIR/shell/bash_profile" "$UNIX_DIR/shell/zshrc" || false
}

@test "the tracked zshrc runs no compinit; the shared rc puts Docker's completions on fpath before the completion system" {
	! grep -qE '^[^#]*compinit' "$UNIX_DIR/shell/zshrc" || false
	docker=$(grep -nE '^[^#]*\.docker/completions' "$rc" | head -1 | cut -d: -f1)
	compinit=$(grep -nE '^[^#]*compinit -C' "$rc" | head -1 | cut -d: -f1)
	[ -n "$docker" ] && [ -n "$compinit" ]
	[ "$docker" -lt "$compinit" ]
}

# An interactive bash that sources the rc with every optional stage but Aliases left out, then
# runs SCRIPT. Usage: rc_interactive SCRIPT
rc_interactive() {
	env -i HOME="$HOME" PATH=/usr/bin:/bin TERM=dumb DOTFILES_ROOT="$(dirname "$UNIX_DIR")" FOUNDATION_TTY=/dev/null \
		FOUNDATION_STARTUP_SKIP=LineEditing,Prompt,Plugins,Icons,Greeting,StartupTasks \
		"${BASH:-bash}" -i -c ". \"\$1\" >/dev/null 2>&1; $1" _ "$rc" </dev/null 2>/dev/null
}

@test "every shell function of a manifest gets a lowercase alias, and the Windows-only names resolve" {
	run rc_interactive alias
	[ "$status" -eq 0 ]
	while read -r function; do
		lower=$(printf '%s' "$function" | tr '[:upper:]' '[:lower:]')
		[[ $output == *"alias $lower='$function'"* ]] || {
			echo "no lowercase alias for $function"
			return 1
		}
	done < <(awk '$1 == "function" { print $2 }' "$UNIX_DIR"/modules/*/module.conf)
	[[ $output == *"alias Preview-LoadingSpinners='Loading-Spinner --preview'"* ]]
	[[ $output == *"alias Create-CondaEnvironments='Install-CondaEnvironments'"* ]]
}

@test "an alias typed in another case runs as the alias, with its arguments" {
	mkdir -p "$BATS_TEST_TMPDIR/listed"
	touch "$BATS_TEST_TMPDIR/listed/marker-file"
	run rc_interactive "_foundation_command_not_found L '$BATS_TEST_TMPDIR/listed'"
	[[ $output == *marker-file* ]]
	run -127 rc_interactive "_foundation_command_not_found NoSuchCommandAnywhere"
}

@test "the LineEditing stage applies shell.conf: history size, history file and the vi edit mode" {
	cfg=$BATS_TEST_TMPDIR/config
	mkdir -p "$cfg"
	printf 'history-size 123\nhistory-file ~/my_history\nedit-mode vi\n' >"$cfg/shell.conf"
	# The helper is a Foundation command: it needs the bash 4.4+ this suite runs on, first on PATH as
	# in a real shell (Homebrew's).
	run env -i HOME="$HOME" PATH="$(dirname "$BASH"):/usr/bin:/bin" TERM=dumb DOTFILES_ROOT="$(dirname "$UNIX_DIR")" FOUNDATION_TTY=/dev/null \
		FOUNDATION_CONFIG_DIR="$cfg" FOUNDATION_MACHINE_TYPE=Work \
		FOUNDATION_STARTUP_SKIP=Aliases,Prompt,Plugins,Icons,Greeting,StartupTasks \
		"${BASH:-bash}" -i -c '. "$1" >/dev/null 2>&1; echo "$HISTSIZE $HISTFILESIZE $HISTFILE"; set -o | grep "^vi "' _ "$rc" </dev/null
	[[ $output == *"123 123 $HOME/my_history"* ]]
	[[ $output == *"vi"*"on"* ]]
}

# The zsh keys and history options after an interactive zsh sourced the rc with $cfg as the config.
# Usage: zsh_line_editing
zsh_line_editing() {
	: >"$HOME/.zshrc"
	env -i HOME="$HOME" PATH="$(dirname "$BASH"):/usr/bin:/bin" TERM=dumb DOTFILES_ROOT="$(dirname "$UNIX_DIR")" FOUNDATION_TTY=/dev/null \
		FOUNDATION_CONFIG_DIR="$cfg" FOUNDATION_MACHINE_TYPE=Work \
		FOUNDATION_STARTUP_SKIP=Aliases,Prompt,Plugins,Icons,Greeting,StartupTasks \
		"$(command -v zsh)" -i -c '. "$1" >/dev/null 2>&1; bindkey "^[[A"; bindkey "^[[H"; bindkey "^@"; bindkey "^I"
			[[ -o HIST_FIND_NO_DUPS ]] && echo nodups; [[ -o INC_APPEND_HISTORY ]] && echo incappend; [[ -o HIST_IGNORE_DUPS ]] && echo ignoredups
			[[ -o AUTO_LIST ]] || echo noautolist; zstyle -L ":completion:*" matcher-list; zmodload | grep -x zsh/complist
			print "savehist=$SAVEHIST"; :' _ "$rc" </dev/null
}

@test "zsh: the base ships no line-editing lines, so zsh keeps its own keys and history options" {
	command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
	cfg=$BATS_TEST_TMPDIR/config
	mkdir -p "$cfg"
	cp "$UNIX_DIR/config/shell.conf" "$cfg/"
	run zsh_line_editing
	[[ $output == *'"^[[A" up-line-or-history'* ]]
	[[ $output == *'"^[[H" undefined-key'* ]]
	[[ $output != *nodups* ]]
	[[ $output != *complist* ]]
	[[ $output != *incappend* ]]
	[[ $output != *noautolist* ]]
	[[ $output != *matcher-list* ]]
	[[ $output == *'"^I" expand-or-complete'* ]]
}

@test "zsh: edit-mode windows, key lines, history-no-duplicates, history-save-style and completion-ignore-case are applied" {
	command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
	cfg=$BATS_TEST_TMPDIR/config
	mkdir -p "$cfg"
	printf 'edit-mode windows\nkey UpArrow HistorySearchBackward\nkey Ctrl+Spacebar MenuComplete\nhistory-no-duplicates on\nhistory-save-style incrementally\ncompletion-ignore-case on\n' >"$cfg/shell.conf"
	run zsh_line_editing
	[[ $output == *'"^[[A" history-beginning-search-backward'* ]]
	[[ $output == *'"^I" menu-complete'* ]]
	[[ $output == *noautolist* ]]
	[[ $output == *incappend* ]]
	[[ $output == *ignoredups* ]]
	[[ $output == *"matcher-list 'm:{a-zA-Z}={A-Za-z}'"* ]]
	[[ $output == *'"^[[H" beginning-of-line'* ]]
	[[ $output == *'"^@" menu-select'* ]]
	[[ $output == *nodups* ]]
	[[ $output == *zsh/complist* ]]
}

@test "zsh: history-save-style nothing saves no history; the prediction list takes Up and Down only with source history and view list" {
	command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
	cfg=$BATS_TEST_TMPDIR/config
	mkdir -p "$cfg"
	printf 'history-save-style nothing\nprediction-source history\nprediction-view inline\n' >"$cfg/shell.conf"
	run zsh_line_editing
	[[ $output == *savehist=0* ]]
	[[ $output == *'"^[[A" up-line-or-history'* ]]
	printf 'prediction-source history\nprediction-view list\n' >"$cfg/shell.conf"
	run zsh_line_editing
	[[ $output == *'"^[[A" foundation-prediction-up'* ]]
}

@test "every apps.conf token without a command of its own becomes an Open-<TOKEN> alias" {
	run env -i HOME="$HOME" PATH="$(dirname "$BASH"):/usr/bin:/bin" TERM=dumb DOTFILES_ROOT="$(dirname "$UNIX_DIR")" FOUNDATION_TTY=/dev/null \
		FOUNDATION_CONFIG_DIR="$FIXTURE_CONFIG" FOUNDATION_MACHINE_TYPE=Work \
		FOUNDATION_STARTUP_SKIP=Prompt,Plugins,Icons,Greeting,StartupTasks \
		"${BASH:-bash}" -i -c '. "$1" >/dev/null 2>&1; alias' _ "$rc" </dev/null
	[[ $output == *"alias Open-Slack='Open-Application Slack'"* ]]
	[[ $output == *"alias Open-Steam='Open-Application Steam'"* ]]
	# Open-Obsidian and Open-Docker are commands of their own: no alias shadows them.
	[[ $output != *"alias Open-Obsidian="* ]]
	[[ $output != *"alias Open-Docker="* ]]
}

@test "an Open-<NAME> apps.conf does not know is still command not found" {
	run -127 rc_interactive "_foundation_command_not_found Open-NoSuchAppAnywhere"
}

# The startup-tasks stage (StartupTasks): SHELL -i sources the rc with only that stage left in, the
# config and log folders under the test folder (a startup.conf from 2000 in the config folder) and a
# stand-in Invoke-StartupTasks shell function (it shadows the command) that logs `ran ARGS` and
# records the gate as a run does: the next terminal-open task an hour away, no day boundary (with
# NO_GATE=1 it records nothing, as a run that failed); then runs SCRIPT.
# Usage: rc_hook SHELL SCRIPT   (SKIP_PANEL=1: a tab a workspace open spawns, which skips the run at
# start; TASK_SHELL=1: a shell a startup task runs in)
rc_hook() {
	local cfg=$BATS_TEST_TMPDIR/config logs=$BATS_TEST_TMPDIR/logs
	mkdir -p "$cfg" "$logs"
	if [ ! -e "$cfg/startup.conf" ]; then
		printf '[Task]\ncommand true\ntrigger TerminalOpen\n' >"$cfg/startup.conf"
		touch -t 200001010000 "$cfg/startup.conf"
	fi
	env -i HOME="$HOME" PATH="$(dirname "$BASH"):/usr/bin:/bin" TERM=dumb DOTFILES_ROOT="$(dirname "$UNIX_DIR")" FOUNDATION_TTY=/dev/null \
		FOUNDATION_CONFIG_DIR="$cfg" FOUNDATION_LOG_DIR="${LOG_DIR_ENV-$logs}" FOUNDATION_MACHINE_TYPE=Work RAN_LOG="$logs/ran.log" GATE_FILE="$logs/.startup-terminal-open" \
		FOUNDATION_STARTUP_SKIP=LineEditing,Aliases,Prompt,Plugins,Icons,Greeting ${SKIP_PANEL:+FOUNDATION_SKIP_STARTUP_PANEL=1} \
		${TASK_SHELL:+FOUNDATION_STARTUP_TASK_SHELL=1} ${NO_GATE:+NO_GATE=1} \
		"$1" -i -c 'Invoke-StartupTasks() { echo "ran $*" >>"$RAN_LOG"; [ -n "${NO_GATE:-}" ] || echo "$(($(date +%s) + 3600)) 0" >"$GATE_FILE"; }
. "$1" >/dev/null 2>&1
'"$2" _ "$rc" </dev/null 2>/dev/null
}
# Writes the gate as a run of the tasks does: line 1 `NEXT DAILY`, then one stamp path per line.
# Usage: gate NEXT DAILY [STAMP...]
gate() {
	local next=$1 daily=$2
	shift 2
	mkdir -p "$BATS_TEST_TMPDIR/logs"
	{
		echo "$next $daily"
		[ $# -eq 0 ] || printf '%s\n' "$@"
	} >"$BATS_TEST_TMPDIR/logs/.startup-terminal-open"
}
# How many times the stand-in ran.
runs() {
	if [ -f "$BATS_TEST_TMPDIR/logs/ran.log" ]; then wc -l <"$BATS_TEST_TMPDIR/logs/ran.log" | tr -d ' '; else echo 0; fi
}
# An hour from now.
later() { echo $(($(date +%s) + 3600)); }

@test "bash: the hook is registered once after a second source and keeps the last exit status" {
	gate "$(later)" 0
	run rc_hook "${BASH:-bash}" '. "$1" >/dev/null 2>&1; printf "%s\n" "${PROMPT_COMMAND[*]}"; false; _foundation_startup_prompt; echo "status=$?"'
	[ "$(grep -o _foundation_startup_prompt <<<"$output" | wc -l | tr -d ' ')" -eq 1 ]
	[[ $output == *"status=1"* ]]
	[ "$(runs)" -eq 0 ]
}

@test "zsh: the hook is registered once in precmd_functions and keeps the last exit status" {
	command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
	# An empty zshrc: no new-user setup prompt in a HOME without one.
	: >"$HOME/.zshrc"
	gate "$(later)" 0
	run rc_hook "$(command -v zsh)" '. "$1" >/dev/null 2>&1; print -l -- $precmd_functions; false; _foundation_startup_prompt; echo "status=$?"'
	[ "$(grep -cx _foundation_startup_prompt <<<"$output")" -eq 1 ]
	[[ $output == *"status=1"* ]]
	[ "$(runs)" -eq 0 ]
}

@test "a new shell runs the terminal-open tasks once NEXT has passed; one before that moment runs nothing" {
	gate 1 0
	run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 1 ]
	grep -qx 'ran --trigger TerminalOpen' "$BATS_TEST_TMPDIR/logs/ran.log"
	# The run recorded the next task an hour away: the next shell starts no run.
	run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 1 ]
}

@test "none never runs: no terminal-open task applies to this Mac" {
	gate none 0
	run rc_hook "${BASH:-bash}" ':'
	run rc_hook "${BASH:-bash}" '_foundation_startup_prompt'
	[ "$(runs)" -eq 0 ]
}

@test "without FOUNDATION_LOG_DIR the gate is read from the directory line of logging.conf" {
	logs=$BATS_TEST_TMPDIR/logs
	mkdir -p "$BATS_TEST_TMPDIR/config"
	printf '[Task]\ncommand true\ntrigger TerminalOpen\n' >"$BATS_TEST_TMPDIR/config/startup.conf"
	printf 'directory %s\n' "$logs" >"$BATS_TEST_TMPDIR/config/logging.conf"
	touch -t 200001010000 "$BATS_TEST_TMPDIR/config/startup.conf" "$BATS_TEST_TMPDIR/config/logging.conf"
	gate "$(later)" 0
	LOG_DIR_ENV='' run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 0 ]
}

@test "no gate, a listed stamp that is gone, or a config file newer than the gate makes the tasks due" {
	logs=$BATS_TEST_TMPDIR/logs
	cfg=$BATS_TEST_TMPDIR/config
	# No gate yet.
	run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 1 ]
	# A listed stamp that still exists keeps the gate; once it is gone the tasks are due.
	mkdir -p "$logs" && date >"$logs/.startup-task-Task.stamp"
	gate "$(later)" 0 "$logs/.startup-task-Task.stamp"
	run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 1 ]
	rm "$logs/.startup-task-Task.stamp"
	run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 2 ]
	# startup.conf newer than the gate.
	gate "$(later)" 0
	touch -t 200101010000 "$logs/.startup-terminal-open"
	run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 2 ]
	touch "$cfg/startup.conf"
	touch -t 200101010000 "$logs/.startup-terminal-open"
	run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 3 ]
	# An overlay counts too: machines.local.conf newer than the gate.
	touch -t 200001010000 "$cfg/startup.conf"
	gate "$(later)" 0
	: >"$cfg/machines.local.conf"
	touch -t 203001010000 "$cfg/machines.local.conf"
	run rc_hook "${BASH:-bash}" ':'
	[ "$(runs)" -eq 4 ]
}

@test "a tab a workspace open spawns skips the run at start but still gets the prompt hook" {
	gate 1 0
	SKIP_PANEL=1 run rc_hook "${BASH:-bash}" 'printf "%s\n" "${PROMPT_COMMAND[*]}"'
	[[ $output == *_foundation_startup_prompt* ]]
	[ "$(runs)" -eq 0 ]
}

@test "a shell a startup task runs in runs no task at start and registers no hook" {
	TASK_SHELL=1 run rc_hook "${BASH:-bash}" 'printf "%s\n" "${PROMPT_COMMAND[*]}"; _foundation_startup_prompt'
	[[ $output != *_foundation_startup_prompt* ]]
	[ "$(runs)" -eq 0 ]
}

@test "the prompt runs the tasks only once DAILY has passed, and once per day boundary" {
	gate 1 1
	SKIP_PANEL=1 run rc_hook "${BASH:-bash}" '[ -e "$FOUNDATION_LOG_DIR/ran.log" ] || echo "none at start"; _foundation_startup_prompt; _foundation_startup_prompt'
	[[ $output == *"none at start"* ]]
	[ "$(runs)" -eq 1 ]
	# DAILY still ahead: nothing, even though NEXT has passed.
	gate 1 "$(later)"
	SKIP_PANEL=1 run rc_hook "${BASH:-bash}" '_foundation_startup_prompt'
	[ "$(runs)" -eq 1 ]
	# No once-per-day task (DAILY 0): the prompt never runs the tasks.
	gate 1 0
	SKIP_PANEL=1 run rc_hook "${BASH:-bash}" '_foundation_startup_prompt'
	[ "$(runs)" -eq 1 ]
}

@test "a prompt run that could not record the gate moves the day boundary on: it is not repeated at every prompt" {
	gate 1 1
	SKIP_PANEL=1 NO_GATE=1 run rc_hook "${BASH:-bash}" '_foundation_startup_prompt; _foundation_startup_prompt; _foundation_startup_prompt'
	[ "$(runs)" -eq 1 ]
}

# An interactive bash that sources the rc with FOUNDATION_STARTUP_SKIP=$SKIP (default: every
# optional stage but Greeting), ~/.shellrc.local holding $LOCAL (stand-in shell functions, which win
# over the commands on PATH) and $BATS_TEST_TMPDIR/tools after the system folders on PATH, then
# runs SCRIPT. $SYSTEM_PATH is the PATH before the tools folder: by default the folder of this bash
# (4.4+, which the LineEditing helper needs) first, but that is Homebrew's bin, where the real
# fastfetch and onefetch live, so the typed fastfetch and onefetch cases leave it out.
# Usage: rc_local SCRIPT [NAME=VALUE...]
rc_local() {
	local script=$1
	shift
	printf '%s\n' "${LOCAL:-}" >"$HOME/.shellrc.local"
	mkdir -p "$BATS_TEST_TMPDIR/tools"
	env -i HOME="$HOME" PATH="${SYSTEM_PATH:-$(dirname "$BASH"):/usr/bin:/bin}:$BATS_TEST_TMPDIR/tools" TERM=dumb DOTFILES_ROOT="$(dirname "$UNIX_DIR")" FOUNDATION_TTY=/dev/null \
		FOUNDATION_CONFIG_DIR="$FIXTURE_CONFIG" FOUNDATION_MACHINE_TYPE=Work \
		FOUNDATION_STARTUP_SKIP="${SKIP-LineEditing,Aliases,Prompt,Plugins,Icons,StartupTasks}" "$@" \
		"${BASH:-bash}" -i -c ". \"\$1\" 2>&1; $script" _ "$rc" </dev/null 2>&1
}

@test "FOUNDATION_STARTUP_SKIP is read in any case, split on commas, semicolons and spaces; the trace gets one line per stage run" {
	trace=$BATS_TEST_TMPDIR/trace
	SKIP='prompt; plugins icons,GREETING;startuptasks' run rc_local 'alias w' FOUNDATION_STARTUP_TRACE="$trace"
	[[ $output == *"alias w='Open-Workspace'"* ]]
	[ "$(cut -f1 "$trace" | paste -sd' ' -)" = "LineEditing Aliases" ]
	! cut -f2 "$trace" | grep -qv '^[0-9][0-9]*$' || false
	: >"$trace"
	SKIP=all run rc_local 'alias w' FOUNDATION_STARTUP_TRACE="$trace"
	[[ $output != *"Open-Workspace"* ]]
	[ ! -s "$trace" ]
}

@test "every alias of the Windows profile resolves to its Foundation command" {
	run rc_interactive alias
	[ "$status" -eq 0 ]
	while read -r name target; do
		[[ $output == *"alias $name='$target'"* ]] || {
			echo "alias $name is not $target"
			return 1
		}
	done <<'ALIASES'
w Open-Workspace
cw Close-Workspace
t Open-Terminal
b Invoke-Browser
rp Run-Project
gb GitBranch
gbd GitBranchDeleteAndPrune
gwd GitWorktreeRemoveAndPrune
gsw GitSwitch
gp GitPull
gmm GitMergeM
gs GitStatus
gdf Git-Diff
efm EfCoreMigrationWizard
dnr DotnetRun
dnbr DotnetBuildAndRun
dnp DotnetPublish
nir NpmInstallAndStart
c Show-TerminalGreeting
translate Invoke-GoogleTranslate
ALIASES
	[[ $output == *"alias l='ls -la'"* ]]
}

@test "the Greeting stage draws through Show-TerminalGreeting without fastfetch installed" {
	LOCAL='Show-TerminalGreeting() { echo "greeting $*"; }'
	run rc_local ':'
	[[ $output == *"greeting --no-resize --settle"* ]]
	run rc_local ':' FOUNDATION_STARTUP_NO_ONEFETCH=1
	[[ $output == *"greeting --no-resize --settle --no-onefetch"* ]]
	run rc_local ':' FOUNDATION_SKIP_STARTUP_PANEL=1
	[[ $output != *greeting* ]]
}

@test "a typed fastfetch or onefetch draws what the greeting draws; with arguments fastfetch is the tool" {
	LOCAL='Invoke-Fastfetch() { echo "Invoke-Fastfetch $*"; }
Invoke-Onefetch() { echo "Invoke-Onefetch $*"; }'
	stub_tool fastfetch 'echo "tool fastfetch $*"'
	stub_tool onefetch 'echo "tool onefetch $*"'
	SKIP=All SYSTEM_PATH=/usr/bin:/bin run rc_local 'fastfetch; fastfetch --version; onefetch; onefetch --no-art -d authors'
	[[ $output == *"Invoke-Fastfetch --no-resize --always"* ]]
	[[ $output == *"tool fastfetch --version"* ]]
	[[ $output == *"Invoke-Onefetch --always"$'\n'* ]]
	[[ $output == *"Invoke-Onefetch --always --arguments --no-art -d authors"* ]]
}

@test "without the tool a typed fastfetch or onefetch is command not found" {
	LOCAL='Invoke-Fastfetch() { echo "Invoke-Fastfetch $*"; }
Invoke-Onefetch() { echo "Invoke-Onefetch $*"; }'
	SKIP=All SYSTEM_PATH=/usr/bin:/bin run rc_local 'fastfetch; echo "fastfetch=$?"; onefetch; echo "onefetch=$?"'
	[[ $output == *"fastfetch=127"* ]]
	[[ $output == *"onefetch=127"* ]]
	[[ $output != *Invoke-* ]]
}
