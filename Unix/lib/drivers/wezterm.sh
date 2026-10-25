# shellcheck shell=bash
# WezTerm driver - the orchestrated terminal (Windows Terminal's role). The ONLY file that
# invokes `wezterm`. Research: Backlog/MacOS/Research/WezTermCli.md.
#
#   wt new-tab --title T --suppressApplicationTitle   ->  spawn, then set-tab-title (sticky via
#                                                          the format-tab-title handler in
#                                                          WezTerm/wezterm.lua)
#   tab snapshot (UIA scraping on Windows)            ->  cli list --format json
#   close a tab                                       ->  kill-pane for each of its panes
#
# Every call passes --no-auto-start: without it, `wezterm cli` silently starts a headless mux
# server when no GUI runs and the tabs land somewhere invisible.

wt_bin() {
	local name=${1:-wezterm}
	if command -v "$name" >/dev/null 2>&1; then
		command -v "$name"
		return 0
	fi
	if [ -x "/Applications/WezTerm.app/Contents/MacOS/$name" ]; then
		printf '%s' "/Applications/WezTerm.app/Contents/MacOS/$name"
		return 0
	fi
	return 1
}

wt_cli() {
	local bin
	bin=$(wt_bin) || return 1
	"$bin" cli --no-auto-start "$@" </dev/null 2>/dev/null
}

# Test-WezTermRunning
wt_running() {
	wt_cli list --format json >/dev/null
}

# Get-TerminalTabSnapshot: one line per pane
#   WINDOW<TAB>TAB<TAB>PANE<TAB>ACTIVE(0/1)<TAB>TAB-TITLE<TAB>TITLE<TAB>CWD<TAB>TTY
wt_panes() {
	command -v jq >/dev/null 2>&1 || {
		log_error "jq is required by the WezTerm driver => brew install jq"
		return 1
	}
	wt_cli list --format json | jq -r '.[] | [
		.window_id, .tab_id, .pane_id, (if .is_active then 1 else 0 end),
		(.tab_title // ""), (.title // ""),
		((.cwd // "") | sub("^file://[^/]*"; "")), (.tty_name // "")
	] | map(tostring | gsub("\t"; " ")) | join("\t")'
}

# The pane this process runs in. WEZTERM_PANE alone cannot say: every app started from a WezTerm
# shell (VS Code, the Claude app, anything `open`ed) inherits it, and a command run from there would
# take pane 0 of some other window for its own - killing it, joining its window or sparing it. The
# variable counts only when that pane's tty is this process's controlling terminal (the
# Resolve-HostingTerminalTab of Windows); prints nothing and fails otherwise.
wt_own_pane() {
	local tty
	[ -n "${WEZTERM_PANE:-}" ] || return 1
	tty=$(ps -o tty= -p $$ 2>/dev/null | tr -d ' ')
	case $tty in '' | '?' | '??') return 1 ;; esac
	case $tty in /dev/*) ;; *) tty=/dev/$tty ;; esac
	wt_panes | awk -F'\t' -v p="$WEZTERM_PANE" -v t="$tty" '$3 == p && $8 == t { print $3; found = 1; exit } END { exit !found }'
}

# Window id of a pane.
wt_pane_window() {
	wt_panes | awk -F'\t' -v p="$1" '$3 == p { print $1; exit }'
}

# Tab titles currently open (explicit titles only), one per line.
wt_tab_titles() {
	wt_panes | awk -F'\t' '$5 != "" && !seen[$2]++ { print $5 }'
}

# Start-WezTerm: start the GUI with its first tab in DIR, running PROGRAM... (optional) and
# print the new pane id once the CLI sees it.
wt_start() {
	local dir=$1 gui known waited=0 pane
	shift
	gui=$(wt_bin wezterm) || {
		log_error "WezTerm was not found. Install it with => brew install --cask wezterm"
		return 1
	}
	known=" $(wt_panes 2>/dev/null | cut -f3 | tr '\n' ' ') "
	log_step "Starting WezTerm..." >&2
	if [ $# -gt 0 ]; then
		foundation_launch nohup "$gui" start --cwd "$dir" -- "$@" </dev/null >/dev/null 2>&1 &
	else
		foundation_launch nohup "$gui" start --cwd "$dir" </dev/null >/dev/null 2>&1 &
	fi
	while [ "$waited" -lt 60 ]; do
		sleep 0.25
		for pane in $(wt_panes 2>/dev/null | cut -f3); do
			case $known in *" $pane "*) ;; *)
				printf '%s' "$pane"
				return 0
				;;
			esac
		done
		waited=$((waited + 1))
	done
	log_error "WezTerm did not come up within 15s"
	return 1
}

# Spawn one tab. Usage: wt_spawn WINDOW-ID|new DIR [PROGRAM...]  -> prints the pane id
wt_spawn() {
	local window=$1 dir=$2
	shift 2
	local args=(spawn)
	if [ "$window" = "new" ] || [ -z "$window" ]; then
		args+=(--new-window)
	else
		args+=(--window-id "$window")
	fi
	args+=(--cwd "$dir")
	[ $# -gt 0 ] && args+=(-- "$@")
	wt_cli "${args[@]}" | tr -d ' \r\n'
}

wt_set_tab_title() {
	wt_cli set-tab-title --pane-id "$1" "$2" >/dev/null
}

# Type a command into a pane's shell (the shell stays open afterwards).
wt_send_line() {
	wt_cli send-text --pane-id "$1" --no-paste "$2
" >/dev/null
}

wt_kill_pane() {
	wt_cli kill-pane --pane-id "$1" >/dev/null
}

wt_activate_pane() {
	wt_cli activate-pane --pane-id "$1" >/dev/null
}

# Draws an image into the current terminal (wezterm imgcat) - Show-Image. WIDTH is optional
# (cells, N% or Npx).
wt_imgcat() { # PATH [WIDTH]
	command -v wezterm >/dev/null 2>&1 || return 1
	wezterm imgcat ${2:+--width "$2"} "$1"
}

# Fits the font of the current WezTerm window, one step at a time - the Ctrl+0 / Ctrl+Minus keys
# Invoke-Fastfetch sends on Windows. STEP 0 resets the font to the default (ResetFontSize), any
# other STEP shrinks it once more (DecreaseFontSize), so STEP is the number of steps below the
# default the window is at afterwards. Sent as an OSC 1337 SetUserVar that the user-var-changed
# handler of WezTerm/wezterm.lua answers; the process id after the step makes every value new, so
# a repeated step is never mistaken for an unchanged variable. Written to FOUNDATION_TTY when set (the
# suites), else to the terminal. Fails when there is no terminal to write to.
# Usage: wt_font_step STEP
wt_font_step() {
	local tty=${FOUNDATION_TTY:-/dev/tty} value
	[ -w "$tty" ] || return 1
	value=$(printf '%s %s' "$1" "$$" | base64 | tr -d '\n')
	{ printf '\033]1337;SetUserVar=FONT_STEP=%s\007' "$value" >>"$tty"; } 2>/dev/null
}
