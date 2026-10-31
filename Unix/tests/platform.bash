# Stand-ins for the platform tools the drivers call - aerospace, wezterm, osascript, open,
# lsappinfo, pgrep, pkill, mdfind, ps - so the command suites exercise the real commands without touching a window,
# an app or a terminal tab. Every call is appended to $STUB_LOG. Load after helpers:
#
#   load ../../helpers
#   load ../../platform
#   setup() { setup_foundation; platform_stubs; }
#
# The window list AeroSpace reports is the file $STUB_WINDOWS, one window per line in the
# driver's list-windows format:  ID|BUNDLE|PID|WORKSPACE|APP-NAME|TITLE
# `open -b BUNDLE` adds a window for that bundle (id 900, 901, ...) on the focused workspace, so
# an open "creates" windows the ownership record can see. `aerospace close --window-id N` removes
# window N; a window listed in $BATS_TEST_TMPDIR/stuck refuses `move-node-to-workspace`; with
# $BATS_TEST_TMPDIR/layout-needs-focus, `layout --window-id N` fails unless window N is on the
# focused workspace ($BATS_TEST_TMPDIR/focused, 1 by default), as AeroSpace 0.21 does (ax_stub
# extends it to the frame reads and changes); with $BATS_TEST_TMPDIR/aerospace-down,
# `list-monitors` fails, so AeroSpace never answers and a command that needs it gives up. `eval`
# runs its ;-separated commands one by one (with $BATS_TEST_TMPDIR/no-eval it fails, as on an
# AeroSpace without it). The
# frames the window-list read reports come from $STUB_FRAMES (`ID X Y WIDTH HEIGHT` lines;
# none by default, so only desktops are verified). The browser scripting driver's tabs are
# $STUB_TABS, one `BUNDLE<TAB>WINDOW<TAB>URL<TAB>TITLE` line per tab, read and closed only while
# the bundle is in $STUB_RUNNING; `open` adds a window of tabs (and an AeroSpace window); with
# $BATS_TEST_TMPDIR/automation-refused every call is refused (-1743). Apps listed in
# $STUB_RUNNING (bundle ids, one per line) report the pid 99999999 to lsappinfo: a pid that cannot
# exist, so a force-kill after a quit timeout never hits a real process. `quit app id` removes the
# app from $STUB_RUNNING unless it is listed in $BATS_TEST_TMPDIR/ignores-quit.

platform_stubs() {
	STUB_BIN=$BATS_TEST_TMPDIR/stubs
	export STUB_LOG=$BATS_TEST_TMPDIR/platform.log
	export STUB_WINDOWS=$BATS_TEST_TMPDIR/windows
	export STUB_RUNNING=$BATS_TEST_TMPDIR/running
	export STUB_PANES=$BATS_TEST_TMPDIR/panes.json
	export STUB_INSTALLED=$BATS_TEST_TMPDIR/installed
	export STUB_FRAMES=$BATS_TEST_TMPDIR/frames
	export STUB_TABS=$BATS_TEST_TMPDIR/tabs
	mkdir -p "$STUB_BIN"
	: >"$STUB_LOG"
	: >"$STUB_WINDOWS"
	: >"$STUB_RUNNING"
	: >"$STUB_INSTALLED"
	echo '[]' >"$STUB_PANES"

	cat >"$STUB_BIN/aerospace" <<'SH'
#!/bin/sh
echo "aerospace $*" >>"$STUB_LOG"
arg_after() { printf '%s\n' "$@" | awk -v k="$KEY" 'prev == k { print; exit } { prev = $0 }'; }
case $1 in
	list-monitors)
		[ -f "$BATS_TEST_TMPDIR/aerospace-down" ] && exit 1
		echo "1 | Built-in Retina Display" ;;
	list-workspaces)
		case "$*" in *--focused*) cat "$BATS_TEST_TMPDIR/focused" 2>/dev/null || echo 1 ;; *) seq 1 10 ;; esac ;;
	list-windows)
		case "$*" in
			*--focused*) cat "$BATS_TEST_TMPDIR/focused-window" 2>/dev/null || head -n 1 "$STUB_WINDOWS" | cut -d'|' -f1 ;;
			*--workspace*)
				ws=$(KEY=--workspace arg_after "$@")
				awk -F'|' -v w="$ws" '$4 == w { print $1 }' "$STUB_WINDOWS" ;;
			*window-layout*) awk -F'|' '{ print $1 "|" (($7 != "") ? $7 : "h_tiles") }' "$STUB_WINDOWS" ;;
			*) cut -d'|' -f1-6 "$STUB_WINDOWS" ;;
		esac ;;
	move-node-to-workspace)
		id=$(KEY=--window-id arg_after "$@")
		# A window listed in $BATS_TEST_TMPDIR/stuck refuses to move, as a window AeroSpace cannot
		# manage does.
		grep -qx "$id" "$BATS_TEST_TMPDIR/stuck" 2>/dev/null && exit 1
		ws=$(printf '%s\n' "$@" | tail -n 1)
		awk -F'|' -v OFS='|' -v id="$id" -v ws="$ws" '$1 == id { $4 = ws } { print }' "$STUB_WINDOWS" >"$STUB_WINDOWS.tmp"
		mv "$STUB_WINDOWS.tmp" "$STUB_WINDOWS" ;;
	close)
		id=$(KEY=--window-id arg_after "$@")
		grep -v "^$id|" "$STUB_WINDOWS" >"$STUB_WINDOWS.tmp"
		mv "$STUB_WINDOWS.tmp" "$STUB_WINDOWS" ;;
	focus)
		# Directional focus fails at the edge, as --boundaries-action fail does.
		case "$*" in *--window-id*) KEY=--window-id arg_after "$@" >"$BATS_TEST_TMPDIR/focused-window" ;; *) exit 1 ;; esac ;;
	workspace) printf '%s\n' "$@" | tail -n 1 >"$BATS_TEST_TMPDIR/focused" ;;
	layout)
		# With $BATS_TEST_TMPDIR/layout-needs-focus, `layout --window-id N` fails on a window whose
		# workspace is not the focused one, as AeroSpace 0.21 does (the driver's header).
		if [ -f "$BATS_TEST_TMPDIR/layout-needs-focus" ]; then
			id=$(KEY=--window-id arg_after "$@")
			ws=$(awk -F'|' -v id="$id" '$1 == id { print $4 }' "$STUB_WINDOWS")
			[ "$ws" = "$(cat "$BATS_TEST_TMPDIR/focused" 2>/dev/null || echo 1)" ] || exit 1
		fi ;;
	macos-native-fullscreen) exit 1 ;;
	eval)
		# AeroSpace's eval: each ;-separated command runs as its own call (logged as one), `A && B`
		# runs B only when A succeeded, `echo -- TEXT` prints TEXT; the status is the last one's.
		# $BATS_TEST_TMPDIR/no-eval stands for an AeroSpace without eval.
		[ -f "$BATS_TEST_TMPDIR/no-eval" ] && exit 2
		shift
		[ "$1" = -- ] && shift
		printf '%s\n' "$1" | tr ';' '\n' >"$BATS_TEST_TMPDIR/eval.$$"
		status=0
		while IFS= read -r part; do
			status=0
			rest=$part
			while [ -n "$rest" ]; do
				case $rest in
					*' && '*) cmd=${rest%%' && '*} rest=${rest#*' && '} ;;
					*) cmd=$rest rest='' ;;
				esac
				set -- $cmd
				[ $# -gt 0 ] || continue
				case $1 in
					echo)
						shift
						[ "$1" = -- ] && shift
						echo "$*"
						status=0
						;;
					true) status=0 ;;
					false) status=1 ;;
					*)
						"$0" "$@"
						status=$?
						;;
				esac
				[ "$status" -eq 0 ] || break
			done
		done <"$BATS_TEST_TMPDIR/eval.$$"
		rm -f "$BATS_TEST_TMPDIR/eval.$$"
		exit "$status"
		;;
esac
exit 0
SH

	cat >"$STUB_BIN/wezterm" <<'SH'
#!/bin/sh
echo "wezterm $*" >>"$STUB_LOG"
case "$*" in
	*" list "* | *" list") cat "$STUB_PANES" ;;
	*spawn*) echo 700 ;;
	# kill-pane removes the pane from $STUB_PANES, unless it is listed in
	# $BATS_TEST_TMPDIR/stuck-panes (a tab that refuses to close).
	*kill-pane*)
		pane=$(printf '%s\n' "$@" | tail -n 1)
		grep -qxF -- "$pane" "$BATS_TEST_TMPDIR/stuck-panes" 2>/dev/null && exit 0
		command -v jq >/dev/null 2>&1 || exit 0
		jq --argjson p "$pane" 'map(select(.pane_id != $p))' "$STUB_PANES" >"$STUB_PANES.tmp" && mv "$STUB_PANES.tmp" "$STUB_PANES"
		;;
esac
exit 0
SH

	cat >"$STUB_BIN/osascript" <<'SH'
#!/bin/sh
echo "osascript $*" >>"$STUB_LOG"
# `quit app id "BUNDLE"` (app_quit): the app exits - it leaves $STUB_RUNNING - unless its bundle
# is listed in $BATS_TEST_TMPDIR/ignores-quit (an app holding a save sheet or a dialog).
case "$*" in
	*'quit app id "'*)
		bundle=$(printf '%s' "$*" | sed -n 's/.*quit app id "\([^"]*\)".*/\1/p')
		if ! grep -qxF "$bundle" "$BATS_TEST_TMPDIR/ignores-quit" 2>/dev/null; then
			grep -vxF "$bundle" "$STUB_RUNNING" >"$STUB_RUNNING.tmp"
			mv "$STUB_RUNNING.tmp" "$STUB_RUNNING"
		fi
		exit 0
		;;
esac
# A JXA script read from stdin (`-` before the arguments) must arrive: a call that also redirects
# stdin elsewhere would hand the real osascript an empty script, which it runs silently.
case " $* " in
	*" - frames "* | *" - tabs "* | *" - close "* | *" - open "* | *" - titles "*)
		[ -n "$(cat)" ] || {
			echo "osascript stand-in: no script on stdin" >&2
			exit 1
		}
		;;
esac
# as_primary_monitor: WIDTH HEIGHT WORKX WORKY WORKWIDTH WORKHEIGHT of a 1512 x 982 laptop panel.
# as_window_frames: the frame of each requested window (the window ids after "frames") from
# $STUB_FRAMES, one "ID X Y WIDTH HEIGHT" line per window; a window not listed is unreadable.
case "$*" in
	*NSScreen*) echo "1512 982 0 33 1512 949" ;;
	# app_window_titles: the titles of the bundle's windows in $STUB_WINDOWS (System Events reads
	# them without AeroSpace).
	*" - titles "*)
		while [ $# -gt 0 ] && [ "$1" != titles ]; do shift; done
		awk -F'|' -v b="$2" '$2 == b && $6 != "" { print $6 }' "$STUB_WINDOWS"
		;;
	*" - frames "*)
		while [ $# -gt 0 ] && [ "$1" != frames ]; do shift; done
		shift
		for id in "$@"; do grep "^$id " "$STUB_FRAMES" 2>/dev/null; done
		;;
	*" - tabs "* | *" - close "* | *" - open "*)
		while [ $# -gt 0 ] && [ "$1" != - ]; do shift; done
		mode=$2 bundle=$3
		shift 3
		if [ -f "$BATS_TEST_TMPDIR/automation-refused" ]; then
			echo "execution error: Error: Not authorized to send Apple events to $bundle. (-1743)" >&2
			exit 1
		fi
		touch "$STUB_TABS"
		case $mode in
			open)
				win=$(($(awk -F'\t' -v b="$bundle" '$1 == b && $2 > m { m = $2 } END { print m + 0 }' "$STUB_TABS") + 1))
				for url in "$@"; do printf '%s\t%s\t%s\t%s\n' "$bundle" "$win" "$url" "$url" >>"$STUB_TABS"; done
				n=$((900 + $(grep -c '^9[0-9][0-9]|' "$STUB_WINDOWS")))
				echo "$n|$bundle|99999999|1|$bundle|$1" >>"$STUB_WINDOWS"
				grep -qxF "$bundle" "$STUB_RUNNING" || echo "$bundle" >>"$STUB_RUNNING"
				;;
			tabs)
				grep -qxF "$bundle" "$STUB_RUNNING" || exit 0
				awk -F'\t' -v OFS='\t' -v b="$bundle" '$1 == b { print $2, $3, $4 }' "$STUB_TABS"
				;;
			close)
				grep -qxF "$bundle" "$STUB_RUNNING" || exit 0
				needles=$(printf '%s\n' "$@" | tr '[:upper:]' '[:lower:]')
				# Through the environment: awk -v takes no newline in a value.
				NEEDLES=$needles awk -F'\t' -v b="$bundle" '
					BEGIN { n = split(ENVIRON["NEEDLES"], want, "\n") }
					{
						hay = tolower($3 "\n" $4)
						if ($1 == b) for (i = 1; i <= n; i++) if (want[i] != "" && index(hay, want[i])) { closed++; next }
						print > (FILENAME ".new")
					}
					END { print closed + 0 }' "$STUB_TABS"
				mv "$STUB_TABS.new" "$STUB_TABS" 2>/dev/null || : >"$STUB_TABS"
				;;
		esac
		;;
esac
exit 0
SH

	cat >"$STUB_BIN/open" <<'SH'
#!/bin/sh
echo "open $*" >>"$STUB_LOG"
if [ "$1" = -b ] || { [ "$1" = -g ] && [ "$2" = -b ]; }; then
	[ "$1" = -g ] && shift
	bundle=$2
	n=$((900 + $(grep -c '^9[0-9][0-9]|' "$STUB_WINDOWS")))
	ws=$(cat "$BATS_TEST_TMPDIR/focused" 2>/dev/null || echo 1)
	echo "$n|$bundle|99999999|$ws|$bundle|New window of $bundle" >>"$STUB_WINDOWS"
	grep -qxF "$bundle" "$STUB_RUNNING" || echo "$bundle" >>"$STUB_RUNNING"
fi
exit 0
SH

	cat >"$STUB_BIN/lsappinfo" <<'SH'
#!/bin/sh
echo "lsappinfo $*" >>"$STUB_LOG"
bundle=$(printf '%s\n' "$@" | tail -n 1)
grep -qxF "$bundle" "$STUB_RUNNING" && echo "pid = 99999999"
exit 0
SH

	# pgrep / pkill by exact name: the names listed in $BATS_TEST_TMPDIR/processes are running
	# (windowless processes, not apps); pkill ends one unless it is listed in
	# $BATS_TEST_TMPDIR/ignores-term, and pkill -9 ends it regardless.
	cat >"$STUB_BIN/pgrep" <<'SH'
#!/bin/sh
echo "pgrep $*" >>"$STUB_LOG"
name=$(printf '%s\n' "$@" | tail -n 1)
grep -qxF -- "$name" "$BATS_TEST_TMPDIR/processes" 2>/dev/null && exit 0
exit 1
SH
	cat >"$STUB_BIN/pkill" <<'SH'
#!/bin/sh
echo "pkill $*" >>"$STUB_LOG"
name=$(printf '%s\n' "$@" | tail -n 1)
[ -f "$BATS_TEST_TMPDIR/processes" ] || exit 1
grep -qxF -- "$name" "$BATS_TEST_TMPDIR/processes" || exit 1
case " $* " in
	*" -9 "*) ;;
	*) grep -qxF -- "$name" "$BATS_TEST_TMPDIR/ignores-term" 2>/dev/null && exit 0 ;;
esac
grep -vxF -- "$name" "$BATS_TEST_TMPDIR/processes" >"$BATS_TEST_TMPDIR/processes.tmp"
mv "$BATS_TEST_TMPDIR/processes.tmp" "$BATS_TEST_TMPDIR/processes"
exit 0
SH
	# Spotlight (app_installed): the bundles listed in $STUB_INSTALLED are installed apps.
	cat >"$STUB_BIN/mdfind" <<'SH'
#!/bin/sh
echo "mdfind $*" >>"$STUB_LOG"
bundle=$(printf '%s' "$*" | sed -n "s/.*== '\([^']*\)'.*/\1/p")
grep -qxF "$bundle" "$STUB_INSTALLED" && echo "/Applications/$bundle.app"
exit 0
SH
	# VS Code's CLI (Open-VSCode falls back to the app's own `code` when none is on PATH) and
	# docker (Run-Project). `code -n DIR` opens a Code window titled after the folder. With
	# $BATS_TEST_TMPDIR/compose-fails, `docker compose` fails (a stack that cannot come up).
	cat >"$STUB_BIN/code" <<'SH'
#!/bin/sh
echo "code $*" >>"$STUB_LOG"
dir=$(printf '%s\n' "$@" | tail -n 1)
n=$((900 + $(grep -c '^9[0-9][0-9]|' "$STUB_WINDOWS")))
echo "$n|com.microsoft.VSCode|99999999|1|Code|$(basename "$dir")" >>"$STUB_WINDOWS"
exit 0
SH
	cat >"$STUB_BIN/docker" <<'SH'
#!/bin/sh
echo "docker $*" >>"$STUB_LOG"
[ "$1" = compose ] && [ -f "$BATS_TEST_TMPDIR/compose-fails" ] && exit 1
exit 0
SH
	# ps answers the controlling-terminal question wt_own_pane asks with $STUB_TTY (no terminal,
	# "??", by default); anything else goes to the real ps.
	cat >"$STUB_BIN/ps" <<'SH'
#!/bin/sh
case "$*" in "-o tty= -p "*) echo "${STUB_TTY:-??}" ;; *) exec /bin/ps "$@" ;; esac
SH
	chmod +x "$STUB_BIN"/*
	export PATH="$STUB_BIN:$PATH"
	# No session logs, no spinner, no countdown pauses in the suites.
	export FOUNDATION_LOGGING=off FOUNDATION_STATE_DIR=$BATS_TEST_TMPDIR/state FOUNDATION_VERIFY_SETTLE_SECONDS=0
	mkdir -p "$FOUNDATION_STATE_DIR"
	# The guard of the "never run real commands in tests" rule: every platform tool must resolve
	# to its stand-in before a command runs.
	local tool
	for tool in aerospace wezterm osascript open lsappinfo pgrep pkill mdfind code docker ps; do
		[ "$(command -v "$tool")" = "$STUB_BIN/$tool" ] || {
			echo "stub guard: $tool resolves to $(command -v "$tool")" >&2
			return 1
		}
	done
}

# An osascript stand-in that also answers the Accessibility frame calls of the AeroSpace driver
# (osascript -l JavaScript - set ID PID TITLE X Y WIDTH HEIGHT) by printing the frame it was
# given; $BATS_TEST_TMPDIR/ax-deny makes every such call report the missing Accessibility
# permission, and a title written to $BATS_TEST_TMPDIR/ax-missing is a window System Events cannot
# find. The display and the frame reads by window id ($STUB_FRAMES) answer as in platform_stubs.
# With $BATS_TEST_TMPDIR/layout-needs-focus a window off the focused workspace is where AeroSpace
# parks it: its frame reads as 1511,941 and setting its frame finds no window.
# Usage: ax_stub (after platform_stubs)
ax_stub() {
	cat >"$STUB_BIN/osascript" <<'SH'
#!/bin/sh
echo "osascript $*" >>"$STUB_LOG"
case "$*" in *NSScreen*)
	echo "1512 982 0 33 1512 949"
	exit 0
	;;
esac
[ "$1 $2 $3" = "-l JavaScript -" ] || exit 0
if [ "$4" = frames ]; then
	[ -n "$(cat)" ] || {
		echo "osascript stand-in: no script on stdin" >&2
		exit 1
	}
	shift 4
	focused=$(cat "$BATS_TEST_TMPDIR/focused" 2>/dev/null || echo 1)
	for id in "$@"; do
		if [ -f "$BATS_TEST_TMPDIR/layout-needs-focus" ] && [ "$(awk -F'|' -v id="$id" '$1 == id { print $4 }' "$STUB_WINDOWS")" != "$focused" ]; then
			grep "^$id " "$STUB_FRAMES" 2>/dev/null | awk '{ print $1, 1511, 941, $4, $5 }'
		else
			grep "^$id " "$STUB_FRAMES" 2>/dev/null
		fi
	done
	exit 0
fi
if [ -f "$BATS_TEST_TMPDIR/ax-deny" ]; then
	echo "execution error: osascript is not allowed assistive access. (-1719)"
	exit 1
fi
if [ "$7" = "$(cat "$BATS_TEST_TMPDIR/ax-missing" 2>/dev/null)" ]; then
	echo missing
	exit 0
fi
if [ "$4" = set ] && [ -f "$BATS_TEST_TMPDIR/layout-needs-focus" ] &&
	[ "$(awk -F'|' -v id="$5" '$1 == id { print $4 }' "$STUB_WINDOWS")" != "$(cat "$BATS_TEST_TMPDIR/focused" 2>/dev/null || echo 1)" ]; then
	echo missing
	exit 0
fi
if [ "$4" = set ]; then
	shift 7
	echo "$*"
fi
exit 0
SH
	chmod +x "$STUB_BIN/osascript"
}

# Adds a window to the list AeroSpace reports. Usage: stub_window ID BUNDLE WORKSPACE APP TITLE
stub_window() {
	echo "$1|$2|99999999|$3|$4|$5" >>"$STUB_WINDOWS"
	grep -qxF "$2" "$STUB_RUNNING" || echo "$2" >>"$STUB_RUNNING"
}

# Did a platform call matching the extended regex happen?
stub_called() {
	grep -qE -- "$1" "$STUB_LOG"
}

# A copy of the fixture config whose app binaries are stand-ins: apps.conf names absolute paths
# (/Applications/Firefox.app/...), which no PATH entry can intercept. Each stand-in logs
# "launch TOKEN ARGS" and opens a window for its bundle titled after the first URL argument.
# Exports FOUNDATION_CONFIG_DIR. Usage: stub_config (after platform_stubs)
stub_config() {
	export FOUNDATION_CONFIG_DIR=$BATS_TEST_TMPDIR/config
	rm -rf "$FOUNDATION_CONFIG_DIR"
	cp -R "$FIXTURE_CONFIG" "$FOUNDATION_CONFIG_DIR"
	local token bundle binary tmp
	tmp=$FOUNDATION_CONFIG_DIR/apps.conf.tmp
	while read -r _ token bundle binary; do
		[ -n "$binary" ] || continue
		cat >"$STUB_BIN/launch-$token" <<SH
#!/bin/sh
echo "launch $token \$*" >>"\$STUB_LOG"
title=\$(printf '%s\\n' "\$@" | grep -m1 '://' || echo "$token")
n=\$((900 + \$(grep -c '^9[0-9][0-9]|' "\$STUB_WINDOWS")))
echo "\$n|$bundle|99999999|1|$token|\$title" >>"\$STUB_WINDOWS"
exit 0
SH
		chmod +x "$STUB_BIN/launch-$token"
	done < <(awk '$1 == "app" && NF > 3' "$FOUNDATION_CONFIG_DIR/apps.conf")
	awk -v bin="$STUB_BIN" '$1 == "app" && NF > 3 { print $1, $2, $3, bin "/launch-" $2; next } { print }' "$FOUNDATION_CONFIG_DIR/apps.conf" >"$tmp"
	mv "$tmp" "$FOUNDATION_CONFIG_DIR/apps.conf"
}

# Waits up to 3 s for a platform call matching the regex - for commands that launch in the
# background (nohup ... &) and exit before the stand-in has written its line.
stub_wait_for() {
	local i
	for i in $(seq 1 30); do
		stub_called "$1" && return 0
		sleep 0.1
	done
	return 1
}
