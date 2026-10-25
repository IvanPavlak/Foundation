# Shared interactive shell configuration for macOS and Linux.
#
# Sourced from both ~/.zshrc and ~/.bashrc so the two shells behave identically,
# and so a second Unix machine only ever needs the same one-line rc file.
#
# Written in POSIX sh with small, guarded shell-specific branches. Keep it that
# way: this file is read by zsh and bash, and shell-specific syntax in the shared
# path is what broke git-obsidian in the first place.
#
# The lint checks it as bash (the closer of its two readers); each deliberate
# exception carries a directive on its line.
# shellcheck shell=bash

# Set by the rc file that sources this one (Unix/shell/zshrc, bashrc) from its own location.
if [ -z "${DOTFILES_ROOT:-}" ]; then
	printf '\n=> shellrc.sh: DOTFILES_ROOT is not set - source Unix/shell/zshrc or bashrc instead!\n' >&2
	return 1 2>/dev/null || exit 1
fi
export DOTFILES_ROOT

# Shared logging helpers, so an interactive shell reports problems in the same
# voice the scripts do. The fallback matters: the warnings below are what tell
# you the repository is not where this file thinks it is, so they must survive
# log.sh itself being unreachable.
if [ -r "$DOTFILES_ROOT/Unix/lib/log.sh" ]; then
	. "$DOTFILES_ROOT/Unix/lib/log.sh"
else
	log_warning() { printf '\n=> %s\n' "$1"; }
	log_error() { printf '\n=> %s\n' "$1" >&2; }
	log_success() { printf '\n=> %s\n' "$1"; }
	log_title() { printf '\n[%s]\n' "$1"; }
fi

# ---------------------------------------------------------------------------
# PATH: the Foundation modules (Unix/modules/<Module>/bin, and the fork-only
# Unix/modules/Custom/<Module>/bin of the Custom area). Idempotent, so re-sourcing
# never duplicates entries. The shell functions of each module's functions.sh are
# sourced further down, with the interactive configuration.
# ---------------------------------------------------------------------------
# The module folders are listed with find, never a */ pattern: zsh treats a pattern that
# matches nothing as an error ("no matches found"), which would break this file on a checkout
# without Unix/modules (another branch, a partial clone). A here-document keeps the loop in
# this shell under bash too, so the PATH changes stick.
# The Custom modules come first: each module is prepended to PATH and sourced in turn, so the
# engine's come last and an engine command or function wins over a Custom one of the same name.
_foundation_modules() {
	find "$DOTFILES_ROOT/Unix/modules/Custom" -mindepth 1 -maxdepth 1 -type d 2>/dev/null | LC_ALL=C sort
	find "$DOTFILES_ROOT/Unix/modules" -mindepth 1 -maxdepth 1 -type d -not -name Custom 2>/dev/null | LC_ALL=C sort
}
while IFS= read -r _foundation_module; do
	[ -n "$_foundation_module" ] && [ -d "$_foundation_module/bin" ] || continue
	case ":$PATH:" in
		*":$_foundation_module/bin:"*) ;;
		*) PATH="$_foundation_module/bin:$PATH" ;;
	esac
done <<FOUNDATION_MODULES
$(_foundation_modules)
FOUNDATION_MODULES
unset _foundation_module
# ~/.local/bin: where Unix/bootstrap.sh installs chezmoi on a Mac without Homebrew yet. Appended,
# so a Homebrew copy wins once there is one.
case ":$PATH:" in
	*":$HOME/.local/bin:"*) ;;
	*) [ -d "$HOME/.local/bin" ] && PATH="$PATH:$HOME/.local/bin" ;;
esac
# mise's shims folder: node, npm, npx and the other runtimes mise manages (the global version of
# `mise use --global`, a project's own from its mise.toml), without running mise at every start.
# Prepended, so a mise runtime wins over a Homebrew one of the same name.
_foundation_mise_shims="${MISE_DATA_DIR:-${XDG_DATA_HOME:-$HOME/.local/share}/mise}/shims"
case ":$PATH:" in
	*":$_foundation_mise_shims:"*) ;;
	*) [ -d "$_foundation_mise_shims" ] && PATH="$_foundation_mise_shims:$PATH" ;;
esac
unset _foundation_mise_shims
export PATH

# The {MachineType} placeholder analog is Unix/config/machines.conf (foundation_machine_type): a
# host line, then MACHINE_TYPE when exported, then its default line. FOUNDATION_MACHINE_TYPE
# overrides it for one shell.

# ---------------------------------------------------------------------------
# Everything below is interactive-only.
# ---------------------------------------------------------------------------
case $- in
	*i*) ;;
	*) return 0 ;;
esac

# ---------------------------------------------------------------------------
# Startup stages - Test-StartupStage / Complete-StartupStage of the Windows profile, for
# Measure-ShellStartup. Each optional part below runs as `if _foundation_stage NAME; then ...; fi`
# (or `_foundation_stage NAME && ...`) followed by `_foundation_stage_done`. FOUNDATION_STARTUP_SKIP (a
# list, or All) leaves stages out, read as Test-StartupStage reads WINUX_STARTUP_SKIP: names in any
# case, separated by commas, semicolons or spaces; FOUNDATION_STARTUP_TRACE names a file that gets
# NAME<TAB>MS per stage that ran. Stages, in order: LineEditing, Aliases, Prompt, Plugins, Icons,
# Greeting, RepositoryUpdate. What comes before them (PATH, the module functions, the local
# overrides) always runs. Two more names are read by the greeting commands, not here:
# FastfetchImageLogo (Invoke-Fastfetch keeps the text logo) and OnefetchStyle (Invoke-Onefetch
# prints onefetch unstyled), so Measure-ShellStartup can time them apart from the panels.
# ---------------------------------------------------------------------------
# The list once, as `,Name,Name,` in the stage names' own case; no process when it is unset.
_foundation_startup_skip=,
if [ -n "${FOUNDATION_STARTUP_SKIP:-}" ]; then
	_foundation_startup_skip=$(printf '%s\n' "$FOUNDATION_STARTUP_SKIP" | tr ',; \t' '\n\n\n\n' | awk '
		BEGIN {
			n = split("All LineEditing Aliases Prompt Plugins Icons Greeting RepositoryUpdate", k, " ")
			for (i = 1; i <= n; i++) name[tolower(k[i])] = k[i]
			printf ","
		}
		NF { t = tolower($1); printf "%s,", (t in name) ? name[t] : $1 }')
fi
_foundation_now_ms() {
	if [ -n "${ZSH_VERSION:-}" ]; then
		zmodload zsh/datetime 2>/dev/null
		printf '%.0f' "$((EPOCHREALTIME * 1000))"
	elif [ -n "${EPOCHREALTIME:-}" ]; then
		_foundation_us=$(printf '%s' "$EPOCHREALTIME" | tr -d '.,')
		printf '%s' "$((_foundation_us / 1000))"
	else
		printf '%s000' "$(date +%s)"
	fi
}
_foundation_stage() {
	case $_foundation_startup_skip in
		*",$1,"* | *,All,*) return 1 ;;
	esac
	if [ -n "${FOUNDATION_STARTUP_TRACE:-}" ]; then
		_foundation_stage_name=$1
		_foundation_stage_start=$(_foundation_now_ms)
	fi
	return 0
}
_foundation_stage_done() {
	[ -n "${FOUNDATION_STARTUP_TRACE:-}" ] && [ -n "${_foundation_stage_name:-}" ] || return 0
	printf '%s\t%s\n' "$_foundation_stage_name" "$(($(_foundation_now_ms) - _foundation_stage_start))" >>"$FOUNDATION_STARTUP_TRACE"
	_foundation_stage_name=''
}

# ---------------------------------------------------------------------------
# Console experience. Port of the "Enhance Console Experience" block in WinuX's
# Windows/PowerShell/Microsoft.PowerShell_profile.ps1:
#
#   [console]::OutputEncoding = UTF8   ->  LANG / LC_ALL
#   Import-Module PSReadLine           ->  zle, already built into zsh
#   Up/DownArrow HistorySearch*        ->  up/down-line-or-beginning-search
#   Set-PSReadLineOption -EditMode     ->  bindkey -e, plus the navigation keys
#                                          zsh leaves unbound
#   PredictionSource History           ->  zsh-autosuggestions, when installed
#   PredictionViewStyle ListView       ->  zsh-autocomplete, when installed
#   Import-Module Terminal-Icons       ->  eza --icons, when installed
#
# The PowerShell original wraps its PSReadLine calls in try/catch because "a
# cosmetic feature must never break shell startup". Same rule applies here: every
# block below is guarded on the shell and on the tool actually being present.
# ---------------------------------------------------------------------------

if _foundation_stage LineEditing; then
	# The settings of Unix/config/shell.conf (the PSReadLine block of Configuration.psd1) and the
	# prompt theme, read by one helper process; a setting without a line keeps the default below.
	_foundation_history_size=4096
	_foundation_history_file=
	_foundation_edit_mode=emacs
	_foundation_list_lines=10
	_foundation_app_tokens=
	while read -r _foundation_key _foundation_value; do
		case $_foundation_key in
			prompt-theme) _foundation_prompt_theme=$_foundation_value ;;
			app) _foundation_app_tokens="$_foundation_app_tokens$_foundation_value
" ;;
			history-size) _foundation_history_size=$_foundation_value ;;
			history-file) _foundation_history_file=$_foundation_value ;;
			edit-mode) _foundation_edit_mode=$_foundation_value ;;
			list-lines) _foundation_list_lines=$_foundation_value ;;
		esac
	done <<EOF_FOUNDATION_SETTINGS
$(foundation-shell-settings 2>/dev/null)
EOF_FOUNDATION_SETTINGS
	unset _foundation_key _foundation_value

	# The Unix equivalent of forcing the console to UTF-8. macOS starts shells with
	# no LANG at all, which makes some tools fall back to ASCII and mangle exactly the
	# box-drawing characters the fastfetch panel is built from.
	if [ -z "${LANG:-}" ]; then
		export LANG="en_US.UTF-8"
	fi

	if [ -n "${ZSH_VERSION:-}" ]; then
		# zsh defaults to a small history that is NOT shared between shells, which
		# would make the history search below far weaker than PSReadLine's.
		HISTFILE="${_foundation_history_file:-$HOME/.zsh_history}"
		HISTSIZE=$_foundation_history_size
		# shellcheck disable=SC2034 # zsh reads SAVEHIST.
		SAVEHIST=$_foundation_history_size
		setopt APPEND_HISTORY SHARE_HISTORY HIST_IGNORE_ALL_DUPS
		# HIST_IGNORE_ALL_DUPS only dedupes within one shell; SHARE_HISTORY still pulls
		# in the copies other shells wrote. FIND_NO_DUPS makes searches (and the
		# zsh-autocomplete list, which dedupes only under this option) show each command
		# once; SAVE_NO_DUPS and EXPIRE_DUPS_FIRST keep the file itself clean.
		setopt HIST_FIND_NO_DUPS HIST_SAVE_NO_DUPS HIST_EXPIRE_DUPS_FIRST
		setopt HIST_IGNORE_SPACE HIST_REDUCE_BLANKS
		setopt INTERACTIVE_COMMENTS

		# -EditMode Windows is emacs-style line editing; that is bindkey -e in zsh (edit-mode vi:
		# bindkey -v).
		if [ "$_foundation_edit_mode" = vi ]; then bindkey -v; else bindkey -e; fi

		# PredictionViewStyle ListView: the live list of history matches PSReadLine
		# draws under the prompt as you type. zsh-autosuggestions only gives the inline
		# ghost text (InlineView); the list needs zsh-autocomplete. Install it with
		# => brew install zsh-autocomplete. Everything below adapts to its presence.
		#
		# Its README is strict about placement: source it before compinit and before
		# any other plugin, never call compinit yourself when it is loaded, and make
		# key bindings after sourcing it because it installs its own.
		#
		# Docker Desktop's CLI completions go on fpath first, so whichever starts the
		# completion system (the plugin, or compinit below) finds them. Docker Desktop offers
		# to append the same lines, with a compinit of their own, to ~/.zshrc, which is a link
		# into this repository: they are not needed there.
		[ -d "$HOME/.docker/completions" ] && fpath=("$HOME/.docker/completions" "${fpath[@]}")
		_zsh_autocomplete=""
		for _plugin_directory in \
			/opt/homebrew/share \
			/usr/local/share \
			/usr/share/zsh/plugins \
			/usr/share; do
			[ -r "$_plugin_directory/zsh-autocomplete/zsh-autocomplete.plugin.zsh" ] || continue
			_zsh_autocomplete="$_plugin_directory/zsh-autocomplete/zsh-autocomplete.plugin.zsh"
			break
		done
		unset _plugin_directory

		if [ -n "$_zsh_autocomplete" ]; then
			# PredictionSource History: the list shows history matches, not completions.
			# Tab still completes as usual.
			zstyle ':autocomplete:*' default-context history-incremental-search-backward
			# No list on an empty prompt, only once something has been typed.
			zstyle ':autocomplete:*' min-input 1
			# At most list-lines entries (10), like PSReadLine's ListView (the plugin default
			# fills half the screen), in the live list and in the up-arrow history menu alike.
			zstyle ':autocomplete:*' list-lines "$_foundation_list_lines"
			zstyle ':autocomplete:history-search-backward:*' list-lines "$_foundation_list_lines"
			zstyle ':autocomplete:history-incremental-search-backward:*' list-lines "$_foundation_list_lines"
			# shellcheck disable=SC1090 # the plugin's path is found at run time.
			. "$_zsh_autocomplete"
		else
			# -C skips compinit's security audit of the completion dirs, which is the
			# single biggest cost in a zsh startup.
			autoload -Uz compinit && compinit -C
			zstyle ':completion:*' menu select
		fi
		zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'

		# HistorySearchBackward/Forward: filter history by what is already typed,
		# rather than plain previous/next line. With zsh-autocomplete loaded the same
		# keys step through its list instead, which is the ListView behaviour.
		if [ -n "$_zsh_autocomplete" ]; then
			bindkey '^[[A' up-line-or-search
			bindkey '^[[B' down-line-or-select
			bindkey '^[OA' up-line-or-search
			bindkey '^[OB' down-line-or-select
			# Enter on a highlighted entry runs it, as in PSReadLine. The plugin's default
			# only copies the entry to the command line and needs a second Enter.
			bindkey -M menuselect '^M' .accept-line
			bindkey -M menuselect '\r' .accept-line
		else
			autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
			zle -N up-line-or-beginning-search
			zle -N down-line-or-beginning-search
			bindkey '^[[A' up-line-or-beginning-search
			bindkey '^[[B' down-line-or-beginning-search
			bindkey '^[OA' up-line-or-beginning-search
			bindkey '^[OB' down-line-or-beginning-search
		fi
		unset _zsh_autocomplete

		# Keys emacs mode leaves unbound, which Windows users reasonably expect.
		bindkey '^[[H' beginning-of-line
		bindkey '^[[F' end-of-line
		bindkey '^[[3~' delete-char
		bindkey '^[[1;5C' forward-word
		bindkey '^[[1;5D' backward-word
	elif [ -n "${BASH_VERSION:-}" ]; then
		HISTFILE="${_foundation_history_file:-$HOME/.bash_history}"
		HISTSIZE=$_foundation_history_size
		HISTFILESIZE=$_foundation_history_size
		HISTCONTROL=ignoreboth
		shopt -s histappend checkwinsize 2>/dev/null
		[ "$_foundation_edit_mode" = vi ] && set -o vi
		bind '"\e[A": history-search-backward' 2>/dev/null
		bind '"\e[B": history-search-forward' 2>/dev/null
	fi
	unset _foundation_history_size _foundation_history_file _foundation_edit_mode _foundation_list_lines
fi
_foundation_stage_done

# A shell started inside an activated conda environment (the Conda terminal of WezTerm's launch
# menu ends in one) gets conda's shell function back, so `conda activate` keeps working; the
# environment itself came with the process. Every other shell pays nothing.
if [ "${CONDA_SHLVL:-0}" != 0 ] && command -v conda >/dev/null 2>&1; then
	if [ -n "${ZSH_VERSION:-}" ]; then
		eval "$(conda shell.zsh hook 2>/dev/null)"
	elif [ -n "${BASH_VERSION:-}" ]; then
		eval "$(conda shell.bash hook 2>/dev/null)"
	fi
fi

# ---------------------------------------------------------------------------
# Foundation commands. The Unix half is bash executables in Unix/modules/<Module>/bin, named Verb-Noun
# exactly as on Windows (Open-Workspace, Kill-All, Get-WindowHandle ...), so they
# are on PATH above and work from any shell. The short aliases of
# Microsoft.PowerShell_profile.ps1 map onto them here.
# ---------------------------------------------------------------------------
if _foundation_stage Aliases; then
	alias w='Open-Workspace'
	# Open-<App> of every apps.conf token without a command of its own (Open-Slack is
	# Open-Application Slack), as the Windows Open-<App> functions; aliases, so zsh completes them.
	# A here-document, not a for loop: zsh does not split an unquoted variable into words.
	while IFS= read -r _foundation_token; do
		[ -n "$_foundation_token" ] || continue
		# shellcheck disable=SC2139 # expanded on purpose: one alias per token.
		command -v "Open-$_foundation_token" >/dev/null 2>&1 ||
			alias "Open-$_foundation_token=Open-Application $_foundation_token"
	done <<EOF_FOUNDATION_APPS
${_foundation_app_tokens:-}
EOF_FOUNDATION_APPS
	unset _foundation_token _foundation_app_tokens
	alias cw='Close-Workspace'
	alias t='Open-Terminal'
	alias b='Invoke-Browser'
	alias rp='Run-Project'
	alias gb='GitBranch'
	alias gbd='GitBranchDeleteAndPrune'
	alias gsw='GitSwitch'
	alias gp='GitPull'
	alias gmm='GitMergeM'
	alias gs='GitStatus'
	alias gdf='Git-Diff'
	alias efm='EfCoreMigrationWizard'

	# The .NET / npm shorthands the project run commands (config/projects.conf) type
	# into their tabs - the Helper commands, aliased as on Windows.
	alias dnr='DotnetRun'
	alias dnbr='DotnetBuildAndRun'
	alias dnp='DotnetPublish'
	alias nir='NpmInstallAndStart'

	# The shorter ones of New-Alias in Microsoft.PowerShell_profile.ps1.
	alias c='Show-TerminalGreeting'
	alias l='ls -la'
	alias translate='Invoke-GoogleTranslate'

	# Windows command names the Unix half spells differently: Preview-LoadingSpinners is the
	# --preview of Loading-Spinner, Create-CondaEnvironments the Bootstrap step's own command.
	alias Preview-LoadingSpinners='Loading-Spinner --preview'
	alias Create-CondaEnvironments='Install-CondaEnvironments'
fi
_foundation_stage_done

# lazygit and lazydocker default to ~/Library/Application Support on macOS; with
# XDG_CONFIG_HOME they read ~/.config like every other tool here (no-op for the
# XDG-aware ones). See Backlog/MacOS/Research/StowAndConfigPaths.md.
export XDG_CONFIG_HOME="${XDG_CONFIG_HOME:-$HOME/.config}"

# ---------------------------------------------------------------------------
# Oh My Posh prompt. The theme is plain JSON and fully cross-platform; only the
# init line differs per shell. Transient prompt needs no extra call - Oh My Posh
# enables it automatically because the theme declares a `transient_prompt` block.
# ---------------------------------------------------------------------------
#
# Both failure modes report themselves rather than degrading quietly to a plain
# prompt, mirroring Initialize-OhMyPosh.ps1, which prints an install hint when
# the binary is missing. A silently plain prompt is indistinguishable from a
# theme that failed to load, which is exactly the bug you cannot see.
_foundation_stage Prompt && if ! command -v oh-my-posh >/dev/null 2>&1; then
	log_warning "Oh My Posh not found - prompt theming skipped! Install it with => brew install jandedobbeleer/oh-my-posh/oh-my-posh"
else
	# The prompt-theme line of theme.conf for this machine type, as the LineEditing stage read it
	# (the helper runs here only when that stage was skipped); OH_MY_POSH_THEME wins.
	[ -n "${OH_MY_POSH_THEME:-}" ] || OH_MY_POSH_THEME=${_foundation_prompt_theme:-$(foundation-prompt-theme 2>/dev/null)}
	OH_MY_POSH_THEME="${OH_MY_POSH_THEME:-$DOTFILES_ROOT/Oh-My-Posh/WinuX_Test.omp.json}"

	if [ ! -r "$OH_MY_POSH_THEME" ]; then
		log_warning "Oh My Posh theme not readable - prompt theming skipped! Expected => $OH_MY_POSH_THEME"
	elif [ -n "${ZSH_VERSION:-}" ]; then
		eval "$(oh-my-posh init zsh --config "$OH_MY_POSH_THEME")"
	elif [ -n "${BASH_VERSION:-}" ]; then
		# Oh My Posh's generated bash init uses `[[ -v NAME ]]`, which needs bash
		# 4.2 or newer. macOS still ships 3.2.57 - frozen at the last GPLv2
		# release in 2007 - where that line is an outright syntax error and every
		# prompt spews it. Skip cleanly instead, and say why.
		if [ "${BASH_VERSINFO[0]:-0}" -gt 4 ] ||
			{ [ "${BASH_VERSINFO[0]:-0}" -eq 4 ] && [ "${BASH_VERSINFO[1]:-0}" -ge 2 ]; }; then
			eval "$(oh-my-posh init bash --config "$OH_MY_POSH_THEME")"
		else
			log_warning "bash ${BASH_VERSION%%(*} is too old for Oh My Posh (needs 4.2+) - prompt theming skipped! This shell is zsh's fallback only; use zsh, or => brew install bash"
		fi
	fi
fi
_foundation_stage_done
unset _foundation_prompt_theme

# ---------------------------------------------------------------------------
# Optional zsh plugins - the PredictionSource History analog. Sourced only when
# present, so a machine without them still starts cleanly. Homebrew and the usual
# Linux package paths are both probed.
#
# Order is load-bearing: zsh-syntax-highlighting wraps the ZLE widgets and must be
# sourced after everything else that defines or rebinds them.
# ---------------------------------------------------------------------------
_foundation_stage Plugins && if [ -n "${ZSH_VERSION:-}" ]; then
	for _plugin_directory in \
		/opt/homebrew/share \
		/usr/local/share \
		/usr/share/zsh/plugins \
		/usr/share; do
		[ -r "$_plugin_directory/zsh-autosuggestions/zsh-autosuggestions.zsh" ] || continue
		. "$_plugin_directory/zsh-autosuggestions/zsh-autosuggestions.zsh"
		break
	done

	for _plugin_directory in \
		/opt/homebrew/share \
		/usr/local/share \
		/usr/share/zsh/plugins \
		/usr/share; do
		[ -r "$_plugin_directory/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh" ] || continue
		. "$_plugin_directory/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh"
		break
	done

	unset _plugin_directory
fi
_foundation_stage_done

# Module shell functions (Reload-Profile, Cd-Desktop, ...): each module's functions.sh,
# the part of a module that must run in this shell. The loaded module names are kept
# for the Reload-Profile summary at the end of this file.
_foundation_loaded=''
while IFS= read -r _foundation_module; do
	[ -n "$_foundation_module" ] && [ -r "$_foundation_module/module.conf" ] || continue
	if [ -r "$_foundation_module/functions.sh" ] && ! . "$_foundation_module/functions.sh"; then
		log_error "Failed to reload module [${_foundation_module##*/}]"
		continue
	fi
	_foundation_loaded="$_foundation_loaded${_foundation_module##*/}
"
	# PowerShell resolves command names case-insensitively (show-terminalgreeting, reload-profile);
	# zsh and bash do not. A shell function must run in this shell, so each `function` line of the
	# manifest gets a lowercase alias here, derived so a new function cannot be missed.
	while read -r _foundation_kind _foundation_function _; do
		[ "$_foundation_kind" = function ] && [ -n "$_foundation_function" ] || continue
		# shellcheck disable=SC2139 # expanded on purpose: one alias per function.
		alias "$(printf '%s' "$_foundation_function" | tr '[:upper:]' '[:lower:]')=$_foundation_function"
	done <"$_foundation_module/module.conf"
done <<FOUNDATION_MODULES
$(_foundation_modules)
FOUNDATION_MODULES
unset _foundation_module _foundation_kind _foundation_function

# Any other unknown command is retried under its case-insensitive match in the module bins (the
# not-found handler runs in a forked child, which is fine for an executable), then as an alias in
# another case (W, GS, Gs), whose lowercase spelling runs with the same arguments.
_foundation_command_case() {
	_wcc_want=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	find "$DOTFILES_ROOT/Unix/modules" -mindepth 3 -maxdepth 4 -path '*/bin/*' -type f 2>/dev/null |
		awk -F/ -v w="$_wcc_want" 'tolower($NF) == w { print $NF; exit }'
}
_foundation_command_not_found() {
	# Open-<App> for an apps.conf token (one added since this shell started has no alias yet).
	case $1 in
		[Oo][Pp][Ee][Nn]-?*)
			_wcnf_token=${1#*-}
			if command -v Open-Application >/dev/null 2>&1 &&
				Open-Application --list 2>/dev/null | grep -qixF -- "$_wcnf_token"; then
				shift
				Open-Application "$_wcnf_token" "$@"
				return
			fi
			;;
	esac
	_wcnf_name=$(_foundation_command_case "$1")
	if [ -n "$_wcnf_name" ] && [ "$_wcnf_name" != "$1" ]; then
		shift
		"$_wcnf_name" "$@"
		return
	fi
	_wcnf_lower=$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')
	if [ "$_wcnf_lower" != "$1" ] && _wcnf_alias=$(alias "$_wcnf_lower" 2>/dev/null); then
		# bash prints alias w='Open-Workspace', zsh w=Open-Workspace or l='ls -la'.
		_wcnf_alias=${_wcnf_alias#*=}
		_wcnf_alias=${_wcnf_alias#\'}
		_wcnf_alias=${_wcnf_alias%\'}
		shift
		eval "$_wcnf_alias \"\$@\""
		return
	fi
	printf '%s: command not found: %s\n' "${ZSH_NAME:-bash}" "$1" >&2
	return 127
}
if [ -n "${ZSH_VERSION:-}" ]; then
	command_not_found_handler() { _foundation_command_not_found "$@"; }
else
	command_not_found_handle() { _foundation_command_not_found "$@"; }
fi

# Terminal-Icons analog: file-type icons in directory listings, from the same
# Nerd Font the prompt and the fastfetch panel already require.
_foundation_stage Icons && if command -v eza >/dev/null 2>&1; then
	alias ls='eza --icons --group-directories-first'
	alias ll='eza --icons --group-directories-first --long'
	alias la='eza --icons --group-directories-first --long --all'
fi
_foundation_stage_done

# A typed `fastfetch` or `onefetch` looks like the greeting, as the fastfetch and onefetch functions
# of the Windows all-hosts profile (profile.ps1) make it: a bare `fastfetch` is Invoke-Fastfetch (the
# image logo of greeting.conf, no font fit), `onefetch` is Invoke-Onefetch (the onefetch-arguments
# line, or the arguments of the call in its place, restyled), both even when greeting.conf turns that
# step of the greeting off. `fastfetch` with arguments, and either one without the tool or the
# Foundation command, is the tool itself.
# Is the tool installed (_foundation_has_tool FUNCTION TOOL)? Asked in a subshell without this file's function of the same name,
# which `command -v` would find instead.
_foundation_has_tool() {
	(
		unset -f "$1" 2>/dev/null
		command -v "$2" >/dev/null 2>&1
	)
}
fastfetch() {
	if [ $# -eq 0 ] && command -v Invoke-Fastfetch >/dev/null 2>&1 && _foundation_has_tool fastfetch "${FOUNDATION_FASTFETCH:-fastfetch}"; then
		Invoke-Fastfetch --no-resize --always
	else
		command fastfetch "$@"
	fi
}
onefetch() {
	if command -v Invoke-Onefetch >/dev/null 2>&1 && _foundation_has_tool onefetch "${FOUNDATION_ONEFETCH:-onefetch}"; then
		if [ $# -eq 0 ]; then
			Invoke-Onefetch --always
		else
			Invoke-Onefetch --always --arguments "$@"
		fi
	else
		command onefetch "$@"
	fi
}

# ---------------------------------------------------------------------------
# Optional per-machine overrides, never committed.
# ---------------------------------------------------------------------------
[ -r "$HOME/.shellrc.local" ] && . "$HOME/.shellrc.local"

# ---------------------------------------------------------------------------
# System info panel on shell start, matching Microsoft.PowerShell_profile.ps1.
# Drawn through Show-TerminalGreeting --no-resize (Invoke-Clear, Invoke-Fastfetch, then onefetch
# in a repository) rather than bare `fastfetch`: a brand-new terminal window is
# still settling when the rc file runs, and the panel's image logo (Kitty
# graphics, anchored to the cursor) and its text rows end up misaligned unless the screen is cleared and the cursor homed first -
# exactly what `c` does, which is why a manual `c` always looked right.
# --settle additionally waits for the window size to stop changing: a window
# opened from Spotlight is tiled by AeroSpace right after it appears, and a panel
# drawn before that resize reflows and leaves logo fragments behind (new tabs
# never had the problem - their window is already sized). --no-resize skips the
# auto-fit measuring pass, so startup pays for one fastfetch run plus at most a
# second of settling, normally ~100 ms.
# ---------------------------------------------------------------------------
# Gated on Show-TerminalGreeting, not on fastfetch: each step skips itself when its own tool is
# missing, so a Mac with onefetch but no fastfetch still clears and shows the repository panel, as
# the Windows profile does. Bare fastfetch only when the function is missing.
# FOUNDATION_SKIP_STARTUP_PANEL: set by Open-Terminal -SkipStartupPanel for the tabs a
# workspace open spawns. Those windows are moved and resized by the layout pass
# seconds later, which would reflow a panel drawn now; Open-Workspace draws it
# after placement instead (Invoke-DeferredTerminalCommands).
_foundation_stage Greeting && if [ -z "${FOUNDATION_SKIP_STARTUP_PANEL:-}" ]; then
	if command -v Show-TerminalGreeting >/dev/null 2>&1; then
		# FOUNDATION_STARTUP_NO_ONEFETCH: set by Open-ProjectTerminals for tabs whose first greeting
		# leaves onefetch out (greeting.conf onefetch-in-project-terminals off); unset so `c` and the
		# shells started from this one draw it again.
		if [ -n "${FOUNDATION_STARTUP_NO_ONEFETCH:-}" ]; then
			unset FOUNDATION_STARTUP_NO_ONEFETCH
			Show-TerminalGreeting --no-resize --settle --no-onefetch
		else
			Show-TerminalGreeting --no-resize --settle
		fi
	elif command -v fastfetch >/dev/null 2>&1; then
		command fastfetch
	fi
fi
_foundation_stage_done

# ---------------------------------------------------------------------------
# Repository update - the RepositoryUpdate profile stage of Windows. Off unless repositories.conf
# says `startup on`. Invoke-StartupRepositoryUpdate decides everything (schedule, machine type,
# stamp, lock) and records when the next run is due in .next-repository-update (`EPOCH SCHEDULE`);
# this shell only reads that file with a builtin, so a start or a prompt before that moment runs
# no extra process. A new shell runs the command once it is due. With the daily schedule a shell
# that stays open into the next day (a Mac woken from sleep) runs it at its first prompt after the
# day starts, from a precmd / PROMPT_COMMAND hook that keeps the last command's exit status.
# Skipped for one shell with FOUNDATION_STARTUP_SKIP=RepositoryUpdate (or All). The tabs a workspace
# open spawns skip the run at start (another shell runs it, and their windows are still being
# placed) but still get the prompt hook.
# ---------------------------------------------------------------------------
# The gate reads repositories.conf where every command does: FOUNDATION_CONFIG_DIR when set.
_foundation_repositories="${FOUNDATION_CONFIG_DIR:-$DOTFILES_ROOT/Unix/config}/repositories.conf"
_foundation_repository_update_file="${FOUNDATION_LOG_DIR:-$DOTFILES_ROOT/Unix/logs}/.next-repository-update"

# Loads the next due time the command recorded; 0 (due now) when there is none yet.
_foundation_repository_update_read() {
	_foundation_repository_update_next=0
	_foundation_repository_update_schedule=
	[ -r "$_foundation_repository_update_file" ] &&
		read -r _foundation_repository_update_next _foundation_repository_update_schedule <"$_foundation_repository_update_file"
	case $_foundation_repository_update_next in '' | *[!0-9]*) _foundation_repository_update_next=0 ;; esac
}

# Is the next run due? zsh (zsh/datetime) and bash 5 know the time without a process.
_foundation_repository_update_due() {
	[ "${EPOCHSECONDS:-$(date +%s)}" -ge "$_foundation_repository_update_next" ]
}

_foundation_repository_update_run() {
	command -v Invoke-StartupRepositoryUpdate >/dev/null 2>&1 && Invoke-StartupRepositoryUpdate
	_foundation_repository_update_read
}

# The prompt hook. Another shell may have run it already, so the file is read again first.
_foundation_repository_update_prompt() {
	_foundation_repository_update_status=$?
	if [ "$_foundation_repository_update_schedule" = daily ] && _foundation_repository_update_due; then
		_foundation_repository_update_read
		_foundation_repository_update_due && _foundation_repository_update_run
	fi
	return "$_foundation_repository_update_status"
}

case $_foundation_startup_skip in
	*,RepositoryUpdate,* | *,All,*) ;;
	*)
		_foundation_stage RepositoryUpdate
		# A cheap gate before any process: any `startup on` line (an @TYPE one or one in the
		# overlay included) registers the stage; Invoke-StartupRepositoryUpdate then reads the
		# setting properly (overlay, @TYPE, the last line winning) and does nothing when it is off.
		if [ -r "$_foundation_repositories" ] &&
			cat "$_foundation_repositories" "${_foundation_repositories%.conf}.local.conf" 2>/dev/null |
			grep -Eiq '^[[:space:]]*(@[^[:space:]]+[[:space:]]+)?startup[[:space:]]+(on|true|yes|1)[[:space:]]*$'; then
			[ -n "${ZSH_VERSION:-}" ] && zmodload zsh/datetime 2>/dev/null
			_foundation_repository_update_read
			if [ -z "${FOUNDATION_SKIP_STARTUP_PANEL:-}" ] && _foundation_repository_update_due; then
				_foundation_repository_update_run
			fi
			# Registered once, even when this file is sourced again.
			if [ -n "${ZSH_VERSION:-}" ]; then
				case " ${precmd_functions[*]} " in
					*" _foundation_repository_update_prompt "*) ;;
					*) precmd_functions+=(_foundation_repository_update_prompt) ;;
				esac
			elif [ -n "${BASH_VERSION:-}" ]; then
				case "${PROMPT_COMMAND[*]}" in
					*_foundation_repository_update_prompt*) ;;
					*)
						# Oh My Posh may have made PROMPT_COMMAND an array (bash 5.1+); the second
						# branch is the string form, so SC2178/SC2128 do not apply.
						# shellcheck disable=SC2178,SC2128
						case $(declare -p PROMPT_COMMAND 2>/dev/null) in
							'declare -a'*) PROMPT_COMMAND+=(_foundation_repository_update_prompt) ;;
							*) PROMPT_COMMAND="${PROMPT_COMMAND:+$PROMPT_COMMAND; }_foundation_repository_update_prompt" ;;
						esac
						;;
				esac
			fi
		fi
		_foundation_stage_done
		;;
esac
unset _foundation_repositories _foundation_startup_skip

# After Reload-Profile the new shell lists the modules it loaded, as Reload-WinuXModules does
# on Windows. Printed last, because the startup panel clears the screen.
if [ -n "${FOUNDATION_RELOADING:-}" ]; then
	log_title "Reloading Foundation Modules"
	# A read loop, not `for x in $list`: zsh does not word-split unquoted variables.
	printf '%s' "$_foundation_loaded" | while IFS= read -r _foundation_module; do
		printf '  Reloaded module [%s]\n' "$_foundation_module"
	done
	log_success "Shell profile reloaded successfully!"
	unset FOUNDATION_RELOADING _foundation_module
fi
unset _foundation_loaded

return 0
