# shellcheck shell=bash
# AeroSpace driver - the macOS window and desktop engine. The ONLY file that invokes `aerospace`
# (Linux gets a sibling driver behind the same function names).
#
# Function names keep the Windows primitive they stand in for in their comment, so the mapping
# stays readable: Get-WindowHandle, Move-WindowToVirtualDesktop, Focus-VirtualDesktop, ...
#
# Verified behaviour on AeroSpace 0.21.3-Beta (from the PowerShell port, do not re-learn):
#   - list-windows --workspace does NOT print tree order; order is read with a focus walk.
#   - layout --window-id fails on windows of hidden workspaces: focus the workspace first.
#   - list-windows has no frame tokens; display geometry comes from NSScreen (JXA).
#   - move --boundaries workspace --boundaries-action stop prevents implicit containers.

as_cli() {
	aerospace "$@" </dev/null 2>/dev/null
}

# Test-AeroSpaceAvailable
as_available() {
	command -v aerospace >/dev/null 2>&1 || return 1
	aerospace list-monitors >/dev/null 2>&1
}

# Start-AeroSpace: launch the app if needed and wait until the CLI answers.
as_start() {
	local timeout=${1:-15} waited=0
	as_available && return 0
	if ! command -v aerospace >/dev/null 2>&1; then
		log_error "AeroSpace is not installed. Install it with => brew install --cask nikitabobko/tap/aerospace"
		return 1
	fi
	log_step "Starting AeroSpace..."
	foundation_launch open -a AeroSpace >/dev/null 2>&1
	while [ "$waited" -lt $((timeout * 4)) ]; do
		sleep 0.25
		if as_available; then
			log_success "AeroSpace is running!"
			return 0
		fi
		waited=$((waited + 1))
	done
	log_error "AeroSpace did not answer within ${timeout}s. On a first launch grant it Accessibility (System Settings > Privacy & Security > Accessibility) and rerun."
	return 1
}

# Checks the AeroSpace config without applying it and prints the config file it read; fails when
# the config does not parse or AeroSpace does not answer.
as_config_check() {
	aerospace reload-config --dry-run --no-gui </dev/null >/dev/null 2>&1 || return 1
	aerospace config --config-path </dev/null 2>/dev/null
}

# Get-WindowHandle: every managed window as
#   ID<TAB>TOKEN<TAB>BUNDLE<TAB>PID<TAB>WORKSPACE<TAB>APPNAME<TAB>TITLE
# TOKEN is the apps.conf token of the bundle, or the app name when the bundle is not mapped.
as_windows() {
	as_cli list-windows --all --format '%{window-id}|%{app-bundle-id}|%{app-pid}|%{workspace}|%{app-name}|%{window-title}' |
		awk -F'|' '
			FNR == NR { split($0, f, "\t"); if (f[2] != "") map[tolower(f[2])] = f[1]; next }
			NF >= 6 {
				id = $1; gsub(/ /, "", id)
				bundle = $2; gsub(/ /, "", bundle)
				pid = $3; gsub(/ /, "", pid)
				ws = $4; gsub(/ /, "", ws)
				name = $5
				title = $6
				for (i = 7; i <= NF; i++) title = title "|" $i
				token = (tolower(bundle) in map) ? map[tolower(bundle)] : name
				printf "%s\t%s\t%s\t%s\t%s\t%s\t%s\n", id, token, bundle, pid, ws, name, title
			}' <(apps_list) -
}

# Window ids on a workspace, membership order (not tree order).
as_workspace_windows() {
	as_cli list-windows --workspace "$1" --format '%{window-id}' | tr -d ' '
}

as_focused_window() {
	as_cli list-windows --focused --format '%{window-id}' | tr -d ' ' | head -1
}

as_focused_workspace() {
	as_cli list-workspaces --focused | head -1
}

# Several commands in one CLI call: AeroSpace's eval runs a `;`-separated list in order, a failing
# command not stopping the next, as separate calls would - and each call costs about 17 ms of
# process start, which arranging a desktop pays dozens of times. A trailing sentinel tells a list
# that ran from one that did not (an AeroSpace without eval, a list it cannot parse): then this
# fails and the caller sends the commands one by one, as before. Callers pass only plain tokens
# (as__plain). Prints what the commands print. Usage: as__eval COMMAND...
as__eval_known=''
as__eval() {
	local output expression
	[ "$as__eval_known" != no ] || return 1
	expression=$(printf '%s; ' "$@")
	output=$(as_cli eval -- "${expression}echo -- as-eval-done") || true
	case $output in
		as-eval-done | *$'\n'as-eval-done)
			as__eval_known=yes
			output=${output%as-eval-done}
			printf '%s' "$output"
			;;
		*)
			[ -n "$as__eval_known" ] || as__eval_known=no
			return 1
			;;
	esac
}

# Is eval there? Asked once, in the calling shell, so the batches of its subshells do not each
# find out again. Usage: as_eval_check
as_eval_check() {
	[ -z "$as__eval_known" ] || return 0
	as__eval true >/dev/null || as__eval_known=no
}

# Are all arguments plain tokens (window ids, workspace names) that AeroSpace's shell takes as one
# word each? Usage: as__plain WORD...
as__plain() {
	local word
	for word in "$@"; do
		case $word in '' | *[!A-Za-z0-9._-]*) return 1 ;; esac
	done
}

# as_exit_native_fullscreen for every ID, in one call: prints the ids of the windows that were in
# native full screen (and now are not), in argument order. Usage: as_exit_native_fullscreen_each ID...
as_exit_native_fullscreen_each() {
	local id commands=()
	[ $# -gt 0 ] || return 0
	if as__plain "$@"; then
		for id in "$@"; do commands+=("macos-native-fullscreen --window-id $id --fail-if-noop off && echo -- $id"); done
		as__eval "${commands[@]}" && return 0
	fi
	for id in "$@"; do
		as_exit_native_fullscreen "$id" && printf '%s\n' "$id"
	done
	return 0
}

# Move-WindowToVirtualDesktop for every ID, in one call (the windows of other workspaces a layout
# parks). Usage: as_park_windows WORKSPACE ID...
as_park_windows() {
	local workspace=$1 id commands=()
	shift
	[ $# -gt 0 ] || return 0
	if as__plain "$workspace" "$@"; then
		for id in "$@"; do commands+=("move-node-to-workspace --window-id $id -- $workspace"); done
		as__eval "${commands[@]}" >/dev/null && return 0
	fi
	for id in "$@"; do as_move_window "$id" "$workspace"; done
	return 0
}

# The insertion step of an arrange, in one call: each ID moved to WORKSPACE in argument order
# (appended as the last child, which is how the order is set) and made tiling, then the
# workspace's tree flattened. Usage: as_gather_tiled WORKSPACE ID...
as_gather_tiled() {
	local workspace=$1 id commands=()
	shift
	if as__plain "$workspace" "$@"; then
		for id in "$@"; do
			commands+=("move-node-to-workspace --window-id $id -- $workspace" "layout --window-id $id tiling")
		done
		commands+=("flatten-workspace-tree --workspace $workspace")
		as__eval "${commands[@]}" >/dev/null && return 0
	fi
	for id in "$@"; do
		as_move_window "$id" "$workspace" || true
		as_set_tiling "$id" || true
	done
	as_flatten "$workspace"
}

# Get-DesktopWindowOrder: window ids of a workspace in on-screen left-to-right order, walked
# through focus (see header). Focus ends on the rightmost window. The walk after the first focus
# is one eval when AeroSpace has it: the moves left, then each move right with the focused window
# read after it. A move that fails at the edge leaves the focus where it is, so the moves after it
# fail too and add nothing - the same walk as one call per step, which is the fallback.
as_workspace_order() {
	local workspace=$1 members count i current order=' ' commands=() walked
	members=$(as_workspace_windows "$workspace")
	count=$(printf '%s\n' "$members" | grep -c .)
	if [ "$count" -lt 2 ]; then
		printf '%s\n' "$members" | grep .
		return 0
	fi
	as_cli focus --window-id "$(printf '%s\n' "$members" | head -1)" >/dev/null || {
		printf '%s\n' "$members"
		return 0
	}
	for ((i = 0; i < count; i++)); do commands+=("focus --ignore-floating --boundaries workspace --boundaries-action fail left"); done
	commands+=("echo -- as-walk-start" "list-windows --focused --format %{window-id}" "echo -- as-walk-right")
	for ((i = 0; i < count; i++)); do
		commands+=("focus --ignore-floating --boundaries workspace --boundaries-action fail right && list-windows --focused --format %{window-id}")
	done
	if walked=$(as__eval "${commands[@]}"); then
		# The leftmost window: what the focus read between the two markers printed.
		current=${walked#*as-walk-start}
		current=${current%%as-walk-right*}
		current=$(printf '%s\n' "$current" | tr -d ' ' | grep -m 1 .)
		[ -n "$current" ] || {
			printf '%s\n' "$members"
			return 0
		}
		order=" $current "
		printf '%s\n' "$current"
		# Then each window a move right reached, up to the first already seen.
		while IFS= read -r current; do
			current=${current// /}
			[ -n "$current" ] || continue
			case $order in *" $current "*) break ;; esac
			order="$order$current "
			printf '%s\n' "$current"
		done <<<"${walked#*as-walk-right}"
		local member
		for member in $members; do
			case $order in *" $member "*) ;; *) printf '%s\n' "$member" ;; esac
		done
		return 0
	fi
	for ((i = 0; i < count; i++)); do
		as_cli focus --ignore-floating --boundaries workspace --boundaries-action fail left >/dev/null || break
	done
	current=$(as_focused_window)
	[ -n "$current" ] || {
		printf '%s\n' "$members"
		return 0
	}
	order=" $current "
	printf '%s\n' "$current"
	for ((i = 0; i < count; i++)); do
		as_cli focus --ignore-floating --boundaries workspace --boundaries-action fail right >/dev/null || break
		current=$(as_focused_window)
		[ -n "$current" ] || break
		case $order in *" $current "*) break ;; esac
		order="$order$current "
		printf '%s\n' "$current"
	done
	local member
	for member in $members; do
		case $order in *" $member "*) ;; *) printf '%s\n' "$member" ;; esac
	done
}

# Focus-VirtualDesktop (1-based desktop number == AeroSpace workspace name).
as_focus_workspace() {
	as_cli workspace -- "$1" >/dev/null
}

as_focus_window() {
	as_cli focus --window-id "$1" >/dev/null
}

# Shows the first tab of the browser window ID: focuses it and sends Cmd+1, the first-tab key of
# every browser (Firefox has no tab scripting, so a keystroke it is, as Ctrl+1 on Windows). Needs
# the Accessibility permission for System Events keystrokes; fails without it.
as_select_first_tab() { # ID
	as_focus_window "$1" || return 1
	osascript -e 'tell application "System Events" to keystroke "1" using command down' </dev/null >/dev/null 2>&1
}

# Move-WindowToVirtualDesktop: appended as the last child of the workspace root.
as_move_window() {
	as_cli move-node-to-workspace --window-id "$1" -- "$2" >/dev/null
}

# PostMessage(WM_CLOSE) analog.
as_close_window() {
	as_cli close --window-id "$1" >/dev/null
}

# Take a window out of macOS native full screen (its own Space, outside AeroSpace's tiling).
# Apps such as Claude restore that state from their last session. Succeeds only when the
# window WAS in native full screen, so the caller can wait for the exit animation.
as_exit_native_fullscreen() {
	as_cli macos-native-fullscreen --window-id "$1" --fail-if-noop off >/dev/null
}

# Join a window with its neighbour into a new container (opposite orientation under
# normalization: joining two side-by-side windows stacks them vertically).
as_join_with() {
	as_cli join-with --window-id "$1" "$2" >/dev/null
}

as_set_tiling() {
	as_cli layout --window-id "$1" tiling >/dev/null
}

as_flatten() {
	as_cli flatten-workspace-tree --workspace "$1" >/dev/null
}

as_layout() {
	# Usage: as_layout WINDOW-ID h_tiles|h_accordion|...
	as_cli layout --window-id "$1" "$2" >/dev/null
}

as_balance() {
	as_cli balance-sizes --workspace "$1" >/dev/null
}

as_resize_width() {
	as_cli resize --window-id "$1" width "$2" >/dev/null
}

# A floating window keeps whatever frame it is given (Center-Windows); tiling hands it back.
as_set_floating() {
	as_cli layout --window-id "$1" floating >/dev/null
}

# tiling or floating, as AeroSpace reports the window.
as_window_layout() { # WINDOW-ID
	as_cli list-windows --all --format '%{window-id}|%{window-layout}' | awk -F'|' -v id="$1" '{ gsub(/ /, "", $1); gsub(/ /, "", $2) } $1 == id { print $2; exit }'
}

# Sets the frame of window ID ("X Y WIDTH HEIGHT" in points, top-left origin) through the
# Accessibility API (System Events), which AeroSpace itself does not expose, and prints the frame
# the window then has. AeroSpace's window id is the window server's window number, which the
# Accessibility API does not show, so the window is found by its frame: of the windows of process
# PID, the one whose frame is the id's frame in the window server's list - two "New Tab" windows of
# one browser are told apart that way, and TITLE only breaks a tie. When no window of the process
# has that frame (it moved in between), the window titled TITLE is taken (the first window of the
# process for an empty TITLE), then the app's only window, then its main one. Needs the terminal to
# be allowed in System Settings > Privacy & Security > Accessibility.
as__ax() { # set ID PID TITLE X Y WIDTH HEIGHT
	osascript -l JavaScript - "$@" <<'JXA' 2>&1
ObjC.import("CoreGraphics");
function run(argv) {
	var id = argv[1], pid = +argv[2], title = argv[3];
	var procs = Application("System Events").processes.whose({ unixId: pid });
	if (procs.length === 0) return "missing";
	var windows = procs[0].windows(), w = null, i, p, s, b = null, same = [];
	// kCGWindowListOptionAll (0) and kCGNullWindowID (0): every window, those AeroSpace parks off
	// screen included.
	var list = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0))) || [];
	for (i = 0; i < list.length; i++) {
		if (String(list[i].kCGWindowNumber) === id) { b = list[i].kCGWindowBounds; break; }
	}
	for (i = 0; b && i < windows.length; i++) {
		try {
			p = windows[i].position(); s = windows[i].size();
			if (Math.abs(p[0] - b.X) <= 1 && Math.abs(p[1] - b.Y) <= 1 &&
				Math.abs(s[0] - b.Width) <= 1 && Math.abs(s[1] - b.Height) <= 1) same.push(windows[i]);
		} catch (e) {}
	}
	for (i = 0; !w && i < same.length; i++) {
		if (same[i].name() === title) w = same[i];
	}
	if (!w && same.length > 0) w = same[0];
	for (i = 0; !w && i < windows.length; i++) {
		if (title === "" || windows[i].name() === title) w = windows[i];
	}
	// The title can change between AeroSpace's listing and this call - a terminal retitles its
	// window to the command running in it (Center-Terminal itself). Then the app's only window,
	// or its main one, is the window that was meant.
	if (!w && windows.length === 1) w = windows[0];
	for (i = 0; !w && i < windows.length; i++) {
		try { if (windows[i].attributes.byName("AXMain").value()) w = windows[i]; } catch (e) {}
	}
	if (!w) return "missing";
	w.position = [+argv[4], +argv[5]];
	w.size = [+argv[6], +argv[7]];
	p = w.position(); s = w.size();
	return [p[0], p[1], s[0], s[1]].join(" ");
}
JXA
}

# Frame of window ID, "X Y WIDTH HEIGHT" in points, top-left origin, read from the window server
# by window id (as_window_frames below), so a window of an app with several same-titled windows
# gets its own frame; needs no permission. Fails when the window server lists no such window.
as_window_frame() { # ID
	local frame
	frame=$(as_window_frames "$1") && [ -n "$frame" ] || return 1
	printf '%s\n' "${frame#* }"
}

as_set_window_frame() { # ID PID TITLE X Y WIDTH HEIGHT
	local out
	out=$(as__ax set "$@" </dev/null)
	as__ax_result "$out"
}

as__ax_result() {
	case $1 in
		*"assistive access"* | *"-1719"* | *"-25211"*)
			log_error "The terminal may not control windows - allow it in System Settings > Privacy & Security > Accessibility"
			return 2
			;;
		missing | '') return 1 ;;
		*[!0-9\ .-]*)
			log_debug "[as_set_window_frame] $1"
			return 1
			;;
	esac
	printf '%s\n' "$1"
}

# Frames of several windows in one read (the GetWindowRect reads of
# Confirm-WorkspaceWindowPositions): "ID X Y WIDTH HEIGHT" per window whose frame could be read,
# in points, top-left origin. Read from the window server's window list (CGWindowListCopyWindowInfo)
# by window number, which is AeroSpace's window id, so windows of one app with the same title
# ("New Tab - Google Chrome") each get their own frame. Needs no permission: only window titles
# would need Screen Recording, and none is read.
as_window_frames() { # ID...
	[ $# -gt 0 ] || return 0
	osascript -l JavaScript - frames "$@" <<'JXA' 2>/dev/null | awk 'NF == 5 && $2 $3 $4 $5 ~ /^[-0-9]+$/'
ObjC.import("CoreGraphics");
function run(argv) {
	var want = {}, out = [], i, info, b, id;
	for (i = 1; i < argv.length; i++) want[argv[i]] = true;
	// kCGWindowListOptionAll (0) and kCGNullWindowID (0): every window, those AeroSpace parks
	// off screen included.
	var list = ObjC.deepUnwrap(ObjC.castRefToObject($.CGWindowListCopyWindowInfo(0, 0))) || [];
	for (i = 0; i < list.length; i++) {
		info = list[i];
		id = String(info.kCGWindowNumber);
		b = info.kCGWindowBounds;
		if (!want[id] || !b) continue;
		delete want[id];
		out.push([id, Math.round(b.X), Math.round(b.Y), Math.round(b.Width), Math.round(b.Height)].join(" "));
	}
	return out.join("\n");
}
JXA
}

as_move_left() {
	as_cli move --window-id "$1" --boundaries workspace --boundaries-action stop left >/dev/null
}

# The configuration file AeroSpace reads: FOUNDATION_AEROSPACE_CONFIG when set (the suites point it
# at a file of their own), else ~/.aerospace.toml, else $XDG_CONFIG_HOME/aerospace/aerospace.toml,
# AeroSpace's own order. Prints nothing and fails when there is none.
as_config_file() {
	local file
	for file in ${FOUNDATION_AEROSPACE_CONFIG+"$FOUNDATION_AEROSPACE_CONFIG"} "$HOME/.aerospace.toml" \
		"${XDG_CONFIG_HOME:-$HOME/.config}/aerospace/aerospace.toml"; do
		if [ -r "$file" ]; then
			printf '%s' "$file"
			return 0
		fi
		# An explicit file decides alone, also when it does not exist.
		[ -n "${FOUNDATION_AEROSPACE_CONFIG+x}" ] && return 1
	done
	return 1
}

# The gaps AeroSpace tiles with, the FancyZones spacing of the Unix half, in points:
#   INNER-HORIZONTAL INNER-VERTICAL OUTER-LEFT OUTER-TOP OUTER-RIGHT OUTER-BOTTOM
# Read from the configuration file (`aerospace config --get` does not expose them), whichever TOML
# spelling it uses: dotted keys (gaps.inner.horizontal = 3), [gaps] / [gaps.inner] tables, inline
# tables (inner = { horizontal = 3, vertical = 3 }) and per-monitor lists, of which the
# `monitor.main` value counts (the primary display, the one layouts place on), else the default
# at the end of the list. A gap the file does not set, or no file at all, is AeroSpace's 0.
as_gaps() {
	local file
	file=$(as_config_file) || {
		printf '0 0 0 0 0 0\n'
		return 0
	}
	awk '
		function trim(s) { gsub(/^[ \t]+|[ \t]+$/, "", s); return s }
		function value(v,   m, a, n, i, last) {
			v = trim(v)
			if (v ~ /^[0-9]+(\.[0-9]+)?$/) return v + 0
			if (v !~ /^\[/) return ""
			if (match(v, /monitor\.main[ \t]*=[ \t]*[0-9]+/)) {
				m = substr(v, RSTART, RLENGTH)
				sub(/.*=[ \t]*/, "", m)
				return m + 0
			}
			gsub(/\{[^}]*\}/, "", v)
			n = split(v, a, /[^0-9.]+/)
			for (i = 1; i <= n; i++) if (a[i] != "") last = a[i]
			return last == "" ? "" : last + 0
		}
		function assign(key, v,   n, a, i, eq, x) {
			key = tolower(key)
			if (v ~ /^\{/) {
				v = substr(v, 2)
				sub(/\}[ \t]*$/, "", v)
				n = split(v, a, ",")
				for (i = 1; i <= n; i++) {
					eq = index(a[i], "=")
					if (eq) assign(key "." trim(substr(a[i], 1, eq - 1)), trim(substr(a[i], eq + 1)))
				}
				return
			}
			x = value(v)
			if (x != "") gap[key] = x
		}
		{ sub(/#.*/, ""); line = trim($0) }
		line == "" { next }
		line ~ /^\[/ {
			section = line
			gsub(/^\[+|\]+$/, "", section)
			section = trim(section)
			next
		}
		index(line, "=") {
			eq = index(line, "=")
			key = trim(substr(line, 1, eq - 1))
			if (section != "") key = section "." key
			if (tolower(key) ~ /^gaps(\.|$)/) assign(key, trim(substr(line, eq + 1)))
		}
		END {
			printf "%d %d %d %d %d %d\n", gap["gaps.inner.horizontal"], gap["gaps.inner.vertical"], gap["gaps.outer.left"],
				gap["gaps.outer.top"], gap["gaps.outer.right"], gap["gaps.outer.bottom"]
		}' "$file"
}

# Get-MonitorSpecs, primary display only:
#   WIDTH HEIGHT WORKX WORKY WORKWIDTH WORKHEIGHT   (points, top-left origin)
# Read through AppKit's NSScreen (JXA), which needs no permission. visibleFrame is the area
# AeroSpace tiles into before its outer gaps (as_gaps).
as_primary_monitor() {
	osascript -l JavaScript -e '
ObjC.import("AppKit");
var s = $.NSScreen.screens.objectAtIndex(0);
var f = s.frame, v = s.visibleFrame;
[Math.round(f.size.width), Math.round(f.size.height), Math.round(v.origin.x),
 Math.round(f.size.height - (v.origin.y + v.size.height)), Math.round(v.size.width), Math.round(v.size.height)].join(" ");
' 2>/dev/null
}
