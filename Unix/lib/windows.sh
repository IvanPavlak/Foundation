# shellcheck shell=bash
# Window selection for the Window-module commands (Get-WindowHandle, Move-Windows,
# Center-Windows, Resize-Windows, Reset-Windows): the as_windows rows matching --process /
# --window-title patterns, with the Windows matching rules (wildcard, regex, exact;
# case-insensitive; either pattern), and the Resize-Windows default. Needs lib/config.sh,
# lib/apps.sh and the AeroSpace driver.

# as_windows rows (ID TOKEN BUNDLE PID WORKSPACE NAME TITLE, tab-separated) that match, the
# Get-WindowHandle rules every Window command shares, as on Windows (Move-, Center- and
# Resize-Windows delegate to Get-WindowHandle there). PROCESS matches the apps.conf token (a role
# matches its member apps) or the app name, TITLE a non-empty window title; with both given a
# window matching EITHER is kept, and with neither every window is. WORKSPACE, when given, keeps
# only that AeroSpace workspace.
windows_select() { # PROCESS TITLE [WORKSPACE]
	local process=$1 title=$2 workspace=${3:-} id token bundle pid ws name wtitle hit
	while IFS=$'\t' read -r id token bundle pid ws name wtitle; do
		[ -n "$id" ] || continue
		[ -z "$workspace" ] || [ "$ws" = "$workspace" ] || continue
		if [ -n "$process" ] || [ -n "$title" ]; then
			hit=0
			if [ -n "$process" ] && { app_matches "$process" "$token" || foundation_match_process "$process" "$name"; }; then
				hit=1
			elif [ -n "$title" ] && [ -n "$wtitle" ] && foundation_match_title "$title" "$wtitle"; then
				hit=1
			fi
			[ "$hit" -eq 1 ] || continue
		fi
		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$id" "$token" "$bundle" "$pid" "$ws" "$name" "$wtitle"
	done < <(as_windows)
}

# Centered frame for a WIDTH% x HEIGHT% window in the primary work area: "X Y W H".
windows_centered_frame() { # WIDTH-PERCENT HEIGHT-PERCENT
	local _ wx wy ww wh
	read -r _ _ wx wy ww wh <<<"$(as_primary_monitor)"
	[ -n "$ww" ] || return 1
	awk -v wx="$wx" -v wy="$wy" -v ww="$ww" -v wh="$wh" -v pw="$1" -v ph="$2" 'BEGIN {
		w = int(ww * pw / 100); h = int(wh * ph / 100)
		printf "%d %d %d %d\n", wx + (ww - w) / 2, wy + (wh - h) / 2, w, h }'
}

# Resolve-DisplayAwareProfile: the values of the display-aware row KEY of window.conf
# (`KEY ROW VALUE...`), resolved as on Windows: SmallDisplay when the primary display is at most
# small-display-width points wide (machines.conf, default 3000), then the layout machine type
# (layout_type of lib/layout.sh, which the caller loads: layout-override, then small-display, then
# the machine type; without that lib the machine type), then Default; the last line of a row wins
# (the overlay). Prints VALUE... of the first row that exists and fails when none does.
# DISPLAY-WIDTH is the primary display's width in points (empty when unknown: SmallDisplay is
# skipped). Usage: windows_display_row KEY DISPLAY-WIDTH
windows_display_row() {
	local key=$1 width=$2 file machines limit rows row values type
	file=$(conf_path window.conf) || return 1
	rows=$(conf_lines "$file" | awk -v k="$key" '$1 == k && NF >= 3 { $1 = ""; $2 = tolower($2); sub(/^ /, ""); print }')
	machines=$(conf_path machines.conf) && limit=$(conf_value "$machines" small-display-width 2>/dev/null) || limit=''
	case $limit in '' | *[!0-9]*) limit=3000 ;; esac
	if declare -F layout_type >/dev/null; then type=$(layout_type "$width"); else type=$(foundation_machine_type); fi
	for row in smalldisplay "$(foundation_lower "$type")" default; do
		if [ "$row" = smalldisplay ]; then
			case $width in '' | *[!0-9]*) continue ;; esac
			[ "$width" -le "$limit" ] || continue
		fi
		values=$(printf '%s\n' "$rows" | awk -v r="$row" '$1 == r { $1 = ""; sub(/^ /, ""); v = $0 } END { print v }')
		[ -n "$values" ] || continue
		printf '%s\n' "$values"
		return 0
	done
	return 1
}

# Resolve-ResizeWindowsPercent: the percentage Resize-Windows scales by without --percent, the
# `resize-windows ROW PERCENT` row of window.conf (windows_display_row). A fraction is rounded to
# the nearest whole number (33.5 => 34), as on Windows; a missing row, a value that is not a
# number or one outside 10-500 gives 70. Usage: windows_resize_percent DISPLAY-WIDTH
windows_resize_percent() {
	local value
	value=$(windows_display_row resize-windows "$1") || value=''
	case $value in *.*[!0-9]* | .* | *.) value='' ;; *.*) value=$(awk -v v="$value" 'BEGIN { printf "%d", v + 0.5 }') ;; esac
	if foundation_whole_number "$value" 10 500; then printf '%s' "$((10#$value))"; else printf '70'; fi
}
