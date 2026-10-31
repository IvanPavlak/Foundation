# shellcheck shell=bash
# Workspace layouts: which layout file applies, what it asks for, waiting for the windows and
# tiling them per desktop. Port of Set-WorkspaceWindowLayout, Wait-ForWorkspaceWindows and the
# AeroSpace Set-WindowZoneLayout of the PowerShell slice. Needs lib/drivers/aerospace.sh.

# ---------------------------------------------------------------------------------------------
# Layout selection (Get-WorkspaceLayoutPath)
# ---------------------------------------------------------------------------------------------

# Layout set for this machine: layout-override first, then the small-display rule, else the
# machine type itself (Get-LayoutMachineType). DISPLAY-WIDTH, the primary display's width in
# points, spares a caller that has it a second read. Usage: layout_type [DISPLAY-WIDTH]
layout_type() {
	local machine file line width=${1:-} limit small
	machine=$(foundation_machine_type)
	file=$(conf_path machines.conf) || {
		printf '%s' "$machine"
		return 0
	}
	while IFS= read -r line; do
		set -- $line
		if [ "$1" = "layout-override" ] && foundation_ieq "$2" "$machine" && [ -n "${3:-}" ]; then
			log_debug "[layout_type] override for $machine => $3"
			printf '%s' "$3"
			return 0
		fi
	done < <(conf_lines "$file")
	small=$(conf_value "$file" small-display) || small=''
	if [ -n "$small" ]; then
		limit=$(conf_value "$file" small-display-width) || limit=3000
		[ -n "$width" ] || width=$(as_primary_monitor | awk '{ print $1 }')
		if [ -n "$width" ] && [ "$width" -le "$limit" ]; then
			log_debug "[layout_type] small display (${width} points) => $small layouts"
			printf '%s' "$small"
			return 0
		fi
	fi
	printf '%s' "$machine"
}

# A layout set is a folder, layouts/<Type>/, with one file per workspace,
# <Workspace>_<Type>.conf, holding that workspace's [Workspace] section.

# Folder of a layout set. Usage: layout_dir [TYPE]
layout_dir() {
	local dir=$FOUNDATION_CONFIG_DIR/layouts/${1:-$(layout_type)}
	[ -d "$dir" ] || return 1
	printf '%s' "$dir"
}

# Layout sets that exist, one per line.
layout_types() {
	local dir
	for dir in "$FOUNDATION_CONFIG_DIR"/layouts/*/; do
		[ -d "$dir" ] && basename "$dir"
	done
}

# Layout files of a set, one per line (not the .local overlays). Usage: layout_files [TYPE]
layout_files() {
	local dir file
	dir=$(layout_dir "${1:-}") || return 1
	for file in "$dir"/*.conf; do
		case $file in *.local.conf) continue ;; esac
		[ -f "$file" ] && printf '%s\n' "$file"
	done
}

# Workspace names of a set, from each file's section header. Usage: layout_names [TYPE]
layout_names() {
	local file
	while IFS= read -r file; do
		conf_sections "$file"
	done < <(layout_files "${1:-}")
}

# File of one workspace's layout (case-insensitive). Usage: layout_file WORKSPACE [TYPE]
layout_file() {
	local file
	while IFS= read -r file; do
		conf_section_name "$file" "$1" >/dev/null && {
			printf '%s' "$file"
			return 0
		}
	done < <(layout_files "${2:-}")
	return 1
}

# Entries of a workspace's layout, one per line:
#   W<TAB>DESKTOP<TAB>MONITOR<TAB>ZONE<TAB>APP<TAB>TITLE
#   L<TAB>DESKTOP<TAB>MONITOR<TAB>ZONESET
# A `project A,B` line opens a project variant of the layout (the ProjectOverrides of Windows):
# the lines after it, up to the next `project` line, apply only when one of those projects is
# among PROJECTs. A variant's `layout D SET` changes desktop D's zone set; its window lines
# REPLACE every base window on the same desktop and monitor, and add desktops the base does not
# use. Several selected projects apply in the order given, so on the same desktop the later one
# wins. A variant naming a project projects.conf does not have (checked when lib/project.sh is
# loaded) is skipped - layout_variant_problems says why.
# Usage: layout_entries FILE WORKSPACE [PROJECT...]
layout_entries() {
	local file=$1 workspace=$2 projects known=''
	shift 2
	projects=$(printf '%s\n' "$@" | tr '[:upper:]' '[:lower:]' | tr '\n' ' ')
	if [ $# -gt 0 ] && declare -F project_names >/dev/null; then
		known=" $(project_names | tr '[:upper:]' '[:lower:]' | tr '\n' ' ') "
	fi
	conf_section "$file" "$workspace" | awk -v projects="$projects" -v known="$known" '
		function valid(b,   n, i, t) {
			if (scope[b] == "") return 0
			if (known == "") return 1
			n = split(scope[b], t, ",")
			for (i = 1; i <= n; i++) if (index(known, " " t[i] " ") == 0) return 0
			return 1
		}
		function covers(b, p,   n, i, t) {
			n = split(scope[b], t, ",")
			for (i = 1; i <= n; i++) if (t[i] == p) return 1
			return 0
		}
		function apply(b,   i, k, key, pairs) {
			for (i = 1; i <= nl[b]; i++) {
				key = lm[b, i] SUBSEP ld[b, i]
				if (!(key in zs)) order[++no] = key
				zs[key] = ls[b, i]
			}
			for (i = 1; i <= nw[b]; i++) pairs[wm[b, i] SUBSEP wd[b, i]] = 1
			for (k = 1; k <= nr; k++) if ((rm[k] SUBSEP rd[k]) in pairs) alive[k] = 0
			for (i = 1; i <= nw[b]; i++) {
				nr++; rd[nr] = wd[b, i]; rm[nr] = wm[b, i]; rz[nr] = wz[b, i]; ra[nr] = wa[b, i]; rt[nr] = wt[b, i]; alive[nr] = 1
			}
		}
		BEGIN { OFS = "\t"; b = 0; monitor = "Primary" }
		$1 == "project" { b = ++nb; scope[b] = tolower($2); monitor = "Primary"; next }
		$1 == "monitor" { monitor = $2; next }
		$1 == "layout" { i = ++nl[b]; ld[b, i] = $2; lm[b, i] = monitor; ls[b, i] = $3; next }
		$1 ~ /^[0-9]+$/ && NF >= 3 {
			title = $0
			sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]*/, "", title)
			i = ++nw[b]; wd[b, i] = $1; wm[b, i] = monitor; wz[b, i] = $2; wa[b, i] = $3; wt[b, i] = title
		}
		END {
			for (i = 1; i <= nl[0]; i++) { key = lm[0, i] SUBSEP ld[0, i]; if (!(key in zs)) order[++no] = key; zs[key] = ls[0, i] }
			for (i = 1; i <= nw[0]; i++) { nr++; rd[nr] = wd[0, i]; rm[nr] = wm[0, i]; rz[nr] = wz[0, i]; ra[nr] = wa[0, i]; rt[nr] = wt[0, i]; alive[nr] = 1 }
			np = split(projects, selected, " ")
			for (p = 1; p <= np; p++)
				for (v = 1; v <= nb; v++)
					if (covers(v, selected[p]) && valid(v)) apply(v)
			for (i = 1; i <= no; i++) { split(order[i], parts, SUBSEP); print "L", parts[2], parts[1], zs[order[i]] }
			for (k = 1; k <= nr; k++) if (alive[k]) print "W", rd[k], rm[k], rz[k], ra[k], rt[k]
		}'
}

# The project variants of a workspace's layout, one per line: SCOPE<TAB>DESKTOP.MONITOR... - the
# scope as written (A,B) and the desktops it changes. Usage: layout_variants FILE WORKSPACE
layout_variants() {
	conf_section "$1" "$2" | awk '
		function flush() { if (b) { print scope "\t" substr(touched, 2) } }
		$1 == "project" { flush(); b = 1; scope = $2; touched = ""; split("", seen); monitor = "Primary"; next }
		$1 == "monitor" { monitor = $2; next }
		b && ($1 == "layout" || ($1 ~ /^[0-9]+$/ && NF >= 3)) {
			d = ($1 == "layout") ? $2 : $1
			if (!((d "." monitor) in seen)) { seen[d "." monitor] = 1; touched = touched " " d "." monitor }
		}
		END { flush() }'
}

# Whether a variant scope (A,B, as layout_variants prints it) applies at all: every project it
# names is in projects.conf, the rule layout_entries skips a variant by. Always true when
# lib/project.sh is not loaded, as in layout_entries. Usage: layout_variant_known SCOPE
layout_variant_known() {
	local known name names
	declare -F project_names >/dev/null || return 0
	known=" $(project_names 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr '\n' ' ') "
	IFS=, read -r -a names <<<"$(foundation_lower "$1")"
	[ ${#names[@]} -gt 0 ] || return 1
	for name in "${names[@]}"; do
		[ -n "$name" ] && [[ $known == *" $name "* ]] || return 1
	done
}

# What is wrong with a layout's project variants, one message per line (empty when nothing is): a
# `project` line without a project, or naming one projects.conf does not have.
# Usage: layout_variant_problems FILE WORKSPACE
layout_variant_problems() {
	local known
	known=" $(project_names 2>/dev/null | tr '[:upper:]' '[:lower:]' | tr '\n' ' ') "
	conf_section "$1" "$2" | awk -v known="$known" '
		$1 == "project" {
			if (NF < 2) { print "a project line names no project"; next }
			n = split($2, t, ",")
			for (i = 1; i <= n; i++)
				if (t[i] == "" || index(known, " " tolower(t[i]) " ") == 0)
					print "project variant [" $2 "] names unknown project [" t[i] "] - the variant is skipped"
		}'
}

# What is wrong with a layout's entries (layout_entries lines on stdin), one message per line, empty
# when nothing is (Validate-Layout of Windows): a desktop on an unknown zone set, a desktop with
# windows but no layout line, a zone not in its desktop's zone set, an app that is no apps.conf
# token or role. Test-ConfigurationSchema reports these; Visualize-Layouts skips such a layout.
# Usage: layout_entries FILE WORKSPACE | layout_entry_problems
layout_entry_problems() {
	local kind desktop monitor a b set_name known=' '
	local -A sets=()
	# Tokens and roles, read once: a bundle id is no token here (a layout entry never matches one).
	apps__load &&
		known=" $({
			apps_list | cut -f1
			printf '%s\n' "$APPS__CACHE_LINES" | awk '$1 == "role" { print $2 }'
		} | tr '[:upper:]' '[:lower:]' | tr '\n' ' ') "
	while IFS=$'\t' read -r kind desktop monitor a b _; do
		if [ "$kind" = L ]; then
			zone_set_known "$a" || printf 'desktop %s uses unknown zone set [%s]\n' "$desktop" "$a"
			sets["$monitor.$desktop"]=$a
			continue
		fi
		set_name=${sets["$monitor.$desktop"]:-}
		if [ -z "$set_name" ]; then
			printf 'desktop %s has entries but no layout line\n' "$desktop"
			continue
		fi
		if zone_set_known "$set_name" && ! zone_column "$set_name" "$a" >/dev/null; then
			printf 'zone [%s] is not in zone set [%s] (desktop %s)\n' "$a" "$set_name" "$desktop"
		fi
		[[ $known == *" $(foundation_lower "$b") "* ]] || printf 'unknown app [%s] (not an apps.conf token or role)\n' "$b"
	done
}

# ---------------------------------------------------------------------------------------------
# Zones (config/zones.conf)
# ---------------------------------------------------------------------------------------------

# Prints "COLUMN-INDEX PERCENT ROW" of ZONE in ZONESET (0-based column; ROW is 0 for a
# full-height column or the top half, 1 for the bottom half), fails when unknown.
zone_column() {
	local zoneset=$1 zone=$2
	zones_cache_load || return 1
	zones_cached_lines | awk -v set="$(foundation_lower "$zoneset")" -v zone="$(foundation_lower "$zone")" '
		$1 == "alias" && tolower($2) == set && tolower($3) == zone { zone = tolower($4) }
		{ lines[NR] = $0 }
		END {
			for (n = 1; n <= NR; n++) {
				split(lines[n], f, /[[:space:]]+/)
				if (tolower(f[1]) != set) continue
				col = 0
				for (i = 2; i in f; i++) {
					split(f[i], z, ":")
					rows = split(tolower(z[1]), names, "+")
					for (r = 1; r <= rows; r++) {
						if (names[r] == zone) { print col, z[2], r - 1; found = 1; exit }
					}
					col++
				}
			}
			exit found ? 0 : 1
		}'
}

zone_set_known() {
	zones_cache_load || return 1
	zones_cached_lines | awk -v set="$(foundation_lower "$1")" 'tolower($1) == set { found = 1 } END { exit found ? 0 : 1 }'
}

# Columns of ZONESET as "ZONE:PERCENT" / "TOP+BOTTOM:PERCENT" fields, fails when unknown.
zone_set_columns() {
	zones_cache_load || return 1
	zones_cached_lines | awk -v set="$(foundation_lower "$1")" '
		# No early exit: the writer would get SIGPIPE, which fails the pipe under pipefail.
		!found && tolower($1) == set && $1 != "alias" { $1 = ""; sub(/^ /, ""); print; found = 1 }
		END { exit found ? 0 : 1 }'
}

# Zone set names in file order.
zone_sets() {
	zones_cache_load || return 1
	zones_cached_lines | awk '$1 != "alias" && $1 != "parking-workspace" && $2 ~ /:/ { print $1 }'
}

# Generate-DynamicVisualization analog: draws ZONESET as a box of proportional columns, a
# halved column split into two rows. Cell contents come from stdin as COL<TAB>ROW<TAB>LABEL
# (ROW 0 = full height or top half, 1 = bottom half); with none, each cell shows its zone name.
# Usage: layout_render ZONESET [WIDTH]
layout_render() {
	local columns
	columns=$(zone_set_columns "$1") || return 1
	# Byte semantics everywhere (LC_ALL=C), with dlen counting UTF-8 characters, so a title
	# pattern holding a multibyte character (the em-dash class) keeps the box aligned. Through
	# env, not a bash `LC_ALL=C cmd` prefix: bash 5 re-runs setlocale for the prefix, which
	# crashed the pipeline subshell (SIGSEGV) about one time in ten.
	env LC_ALL=C awk -v spec="$columns" -v width="${2:-64}" -F'\t' '
		function dlen(text,   copy) { copy = text; return length(text) - gsub(/[\200-\277]/, "", copy) }
		function fit(text, w,   pad, left) {
			if (dlen(text) > w) { text = substr(text, 1, w - 1); sub(/[\300-\377][\200-\277]*$/, "", text); text = text "~" }
			pad = w - dlen(text); left = int(pad / 2)
			return rep(" ", left) text rep(" ", pad - left)
		}
		function rep(ch, n,   out) { out = ""; while (n-- > 0) out = out ch; return out }
		{ cell[$1 "," $2] = (($1 "," $2) in cell) ? cell[$1 "," $2] SUBSEP $3 : $3 }
		END {
			n = split(spec, cols, " ")
			inner = width - n - 1; used = 0
			for (c = 1; c <= n; c++) {
				split(cols[c], z, ":"); halved[c] = split(z[1], zn, "+") == 2
				zone[c, 0] = zn[1]; zone[c, 1] = halved[c] ? zn[2] : ""
				w[c] = (c == n) ? inner - used : int(inner * z[2] / 100 + 0.5); used += w[c]
			}
			# Content lines per cell: the zone name, then one line per label.
			for (c = 1; c <= n; c++) for (r = 0; r <= halved[c]; r++) {
				k = (c - 1) "," r; m = 0
				lines[c, r, ++m] = "[" zone[c, r] "]"
				if (k in cell) { cnt = split(cell[k], lab, SUBSEP); for (i = 1; i <= cnt; i++) lines[c, r, ++m] = lab[i] }
				count[c, r] = m
				if (m > half) half = m
			}
			if (half < 2) half = 2
			top = "┌"; bottom = "└"
			for (c = 1; c <= n; c++) { top = top rep("─", w[c]) (c < n ? "┬" : "┐"); bottom = bottom rep("─", w[c]) (c < n ? "┴" : "┘") }
			print top
			total = 2 * half + 1
			for (y = 1; y <= total; y++) {
				mid = (y == half + 1)
				line = mid ? (halved[1] ? "├" : "│") : "│"
				for (c = 1; c <= n; c++) {
					if (halved[c]) {
						if (mid) text = rep("─", w[c])
						else { r = (y > half); i = r ? y - half - 1 : y; text = fit(i <= count[c, r] ? lines[c, r, i] : "", w[c]) }
					} else {
						# A full column centres its lines over the whole height.
						first = int((total - count[c, 0]) / 2) + 1; i = y - first + 1
						text = fit(i >= 1 && i <= count[c, 0] ? lines[c, 0, i] : "", w[c])
					}
					if (c < n) {
						if (mid && halved[c] && halved[c + 1]) sep = "┼"
						else if (mid && halved[c]) sep = "┤"
						else if (mid && halved[c + 1]) sep = "├"
						else sep = "│"
					} else sep = (mid && halved[c]) ? "┤" : "│"
					line = line text sep
				}
				print line
			}
			print bottom
		}'
}

# How long a claimed window's title must hold before layout_wait counts it as ready, in ms
# (browsers retitle while loading): FOUNDATION_STABLE_MS when set, else layout-stable-ms of
# workspaces.conf; a missing or non-numeric line gives 500, the shipped base value.
# Usage: layout_stable_ms
layout_stable_ms() {
	local file value=${FOUNDATION_STABLE_MS:-}
	if [ -z "$value" ]; then
		file=$(conf_path workspaces.conf) && value=$(conf_value "$file" layout-stable-ms 2>/dev/null) || value=''
	fi
	case $value in '' | *[!0-9]*) value=500 ;; esac
	printf '%s' "$value"
}

# How long layout_wait waits for an entry whose app is not running, or whose every match is a window
# it may not take, before giving up on it (ProcessAbsentGraceSeconds of Windows), in seconds:
# layout-absent-grace-seconds of workspaces.conf; a missing or non-numeric line gives 10, the
# shipped base value, and 0 turns the fail-fast off. Usage: layout_absent_grace_seconds
layout_absent_grace_seconds() {
	local file value=''
	file=$(conf_path workspaces.conf) && value=$(conf_value "$file" layout-absent-grace-seconds 2>/dev/null) || value=''
	case $value in '' | *[!0-9]*) value=10 ;; esac
	printf '%s' "$value"
}

# Is an app of the entry pattern APP running? The apps.conf bundle of each app it names (a role's
# members, or the token itself) is asked of LaunchServices; a pattern that names no bundle counts
# as running, since there is nothing to ask. Usage: layout__app_running APP
layout__app_running() {
	local members member bundle asked=0
	members=$(app_role_members "$1") || members=$1
	while IFS= read -r member; do
		bundle=$(app_bundle "$member") || continue
		asked=1
		[ -n "$(app_pids "$bundle")" ] && return 0
	done <<<"$members"
	[ "$asked" -eq 0 ]
}

parking_workspace() {
	local file value
	file=$(conf_path zones.conf) || {
		printf 'P'
		return 0
	}
	value=$(conf_value "$file" parking-workspace) || value=P
	[ "$value" = '""' ] && value=''
	printf '%s' "$value"
}

# Does an entry other than INDEX, of the same app and with a title, match TITLE? Reads the apps
# and titles arrays of layout_wait.
layout__titled_sibling_wants() { # INDEX TITLE
	local j
	for ((j = 0; j < ${#apps[@]}; j++)); do
		[ "$j" -eq "$1" ] && continue
		[ -n "${titles[j]}" ] || continue
		foundation_ieq "${apps[j]}" "${apps[$1]}" || continue
		foundation_match_title "${titles[j]}" "$2" && return 0
	done
	return 1
}

# ---------------------------------------------------------------------------------------------
# Waiting (Wait-ForWorkspaceWindows)
# ---------------------------------------------------------------------------------------------
#
# Each layout entry claims ONE window that satisfies it; a window held by one entry is never
# offered to another, so two "Browser" entries claim two windows. Windows created by this open
# (not in the pre-existing list) are preferred. A claimed window is ready once its title has not
# changed for STABLE seconds (browsers retitle while loading); a pre-existing window is ready at
# once. A window whose title drifts out of its entry's pattern is released and searched again.
# Stable means the title and the window's frame (one window-server read per poll for the windows
# still settling) both held; a frame that cannot be read leaves the title alone to decide.
# An entry's remembered window comes first: layout_pins (ENTRY-INDEX => window id, the windows of
# the last Applied open, state_layout_pins) gives an entry that window when it is still live,
# free and matching; otherwise a candidate on the entry's own desktop (layout_entry_desktop,
# ENTRY-INDEX => desktop) is preferred, so identical windows keep their zones across reruns.
# An entry without a title takes only windows no titled entry of the same app matches; when it is
# the only untitled entry of its app it takes every such window (several result lines for it),
# while untitled duplicates of one app take one window each. The caller may set layout_protected (" ID ID ... ", windows of other workspaces an open must
# leave alone, never claimed), layout_new_only (1: only windows created by this open, the
# alongside rule; pre-existing ones are not adopted) and layout_no_wait (1: a claimed window is
# ready at once, no title has to hold; with TIMEOUT 0 the wait is one poll, the DisableAutoWait of
# Windows).
# Past layout_absent_grace_seconds, an entry that never held a window is given up (it ends without
# a result line) when every window matching it is one it may not take (protected, or pre-existing
# under layout_new_only), or when no window of its app is listed and its app is not running, so a
# missing app costs the grace period, not the whole timeout.
#
# Result lines: ENTRY-INDEX<TAB>WINDOW-ID  (entries that never found a window are absent; a
# catch-all entry has a line per window, its own first)
# Usage: layout_wait TIMEOUT PRE-EXISTING-IDS ENTRY-APP... -- ENTRY-TITLE...
#   entries are passed as two parallel lists separated by --
layout_wait() {
	local timeout=$1 preexisting=" $2 "
	shift 2
	local apps=() titles=() seen_separator=0 argument
	for argument in "$@"; do
		if [ "$seen_separator" -eq 0 ] && [ "$argument" = "--" ]; then
			seen_separator=1
			continue
		fi
		if [ "$seen_separator" -eq 0 ]; then apps+=("$argument"); else titles+=("$argument"); fi
	done
	local count=${#apps[@]} i
	local handle=() last=() lastframe=() since=() ready=() held=()
	for ((i = 0; i < count; i++)); do
		handle[i]=''
		last[i]=''
		lastframe[i]=''
		since[i]=0
		ready[i]=0
		held[i]=0
	done
	local stable_ms grace start
	stable_ms=$(layout_stable_ms)
	grace=$(layout_absent_grace_seconds)
	start=$(foundation_now_ms)
	local deadline=$((start + timeout * 1000))
	log_debug "[layout_wait] waiting for $count workspace window(s)"

	while :; do
		local ids=() tokens=() wtitles=() wdesks=() line id token desk title
		while IFS=$'\t' read -r id token _ _ desk _ title; do
			[ -n "$id" ] || continue
			ids+=("$id")
			tokens+=("$token")
			wdesks+=("$desk")
			wtitles+=("$title")
		done < <(as_windows)
		local now claimed=' ' pending=0 w waiting=()
		now=$(foundation_now_ms)
		for ((i = 0; i < count; i++)); do
			[ -n "${handle[i]}" ] && claimed="$claimed${handle[i]} "
			[ -n "${handle[i]}" ] && [ "${ready[i]}" -eq 0 ] && waiting+=("${handle[i]}")
		done
		# The frames of the claimed windows still settling, in one window-server read: stable means
		# the title AND the frame held (RequireStableDimensions of Windows), so a window still
		# restoring its bounds (VS Code) is not placed mid-resize. A frame that cannot be read
		# leaves the title alone to decide.
		local -A frame_of=()
		if [ ${#waiting[@]} -gt 0 ] && [ "${layout_no_wait:-0}" != 1 ]; then
			while read -r id x y fw fh; do
				[ -n "$id" ] && frame_of[$id]="$x $y $fw $fh"
			done < <(as_window_frames "${waiting[@]}")
		fi

		for ((i = 0; i < count; i++)); do
			[ "${ready[i]}" -eq 1 ] && continue
			if [ -n "${handle[i]}" ]; then
				local found=-1
				for ((w = 0; w < ${#ids[@]}; w++)); do
					[ "${ids[w]}" = "${handle[i]}" ] && {
						found=$w
						break
					}
				done
				if [ "$found" -ge 0 ] && app_matches "${apps[i]}" "${tokens[found]}" && foundation_match_title "${titles[i]}" "${wtitles[found]}"; then
					local frame=${frame_of[${handle[i]}]:-} first_frame=0
					# The first frame seen is recorded without restarting the clock, but it cannot make
					# the window ready yet: a frame read once has not been seen to hold. Without that,
					# a slow pass (more than stable_ms between the claim and the first frame read)
					# declared a window still resizing ready. A second matching read is enough.
					if [ -n "$frame" ] && [ -z "${lastframe[i]}" ]; then
						lastframe[i]=$frame
						first_frame=1
					fi
					if [ "${wtitles[found]}" != "${last[i]}" ] || { [ -n "$frame" ] && [ "$frame" != "${lastframe[i]}" ]; }; then
						last[i]=${wtitles[found]}
						[ -n "$frame" ] && lastframe[i]=$frame
						since[i]=$now
					elif [ "$first_frame" -eq 1 ]; then
						:
					elif [ $((now - since[i])) -ge "$stable_ms" ]; then
						ready[i]=1
						log_debug "[layout_wait] ready: entry $i ${apps[i]} [${titles[i]}] => window ${handle[i]} '${wtitles[found]}'"
					fi
					continue
				fi
				log_debug "[layout_wait] released window ${handle[i]} for entry $i (gone or title changed)"
				claimed=${claimed/ ${handle[i]} / }
				handle[i]=''
				last[i]=''
				lastframe[i]=''
			fi
			# Claim: the window this entry held after the last Applied open (its remembered pin,
			# Get-CurrentLayout and the PinnedMap of Windows) when it is still live, free and
			# matching; else new windows first, then pre-existing ones, each pass preferring a
			# window already on the entry's desktop, so identical windows (33 Browser entries,
			# same-titled VS Code windows) keep their zones and desktops across reruns.
			local pick='' pick_title='' pass prefer pin=${layout_pins[i]:-}
			if [ -n "$pin" ]; then
				for ((w = 0; w < ${#ids[@]}; w++)); do
					[ "${ids[w]}" = "$pin" ] || continue
					case $claimed in *" $pin "*) break ;; esac
					case ${layout_protected:- } in *" $pin "*) break ;; esac
					if [ "${layout_new_only:-0}" = 1 ]; then
						case $preexisting in *" $pin "*) break ;; esac
					fi
					app_matches "${apps[i]}" "${tokens[w]}" || break
					foundation_match_title "${titles[i]}" "${wtitles[w]}" || break
					[ -z "${titles[i]}" ] && layout__titled_sibling_wants "$i" "${wtitles[w]}" && break
					pick=$pin
					pick_title=${wtitles[w]}
					log_debug "[layout_wait] entry $i takes its remembered window $pin"
					break
				done
			fi
			[ -n "$pick" ] || for pass in new old; do
				[ "$pass" = old ] && [ "${layout_new_only:-0}" = 1 ] && break
				for prefer in 1 0; do
					# Without a known desktop there is nothing to prefer.
					[ "$prefer" -eq 1 ] && [ -z "${layout_entry_desktop[i]:-}" ] && continue
					for ((w = 0; w < ${#ids[@]}; w++)); do
						case $claimed in *" ${ids[w]} "*) continue ;; esac
						case ${layout_protected:- } in *" ${ids[w]} "*) continue ;; esac
						case $preexisting in
							*" ${ids[w]} "*) [ "$pass" = "old" ] || continue ;;
							*) [ "$pass" = "new" ] || continue ;;
						esac
						[ "$prefer" -eq 1 ] && [ "${wdesks[w]}" != "${layout_entry_desktop[i]}" ] && continue
						app_matches "${apps[i]}" "${tokens[w]}" || continue
						foundation_match_title "${titles[i]}" "${wtitles[w]}" || continue
						# An entry without a title takes only windows no titled entry of the same app
						# asks for, so it cannot steal a sibling's window that appeared first.
						[ -z "${titles[i]}" ] && layout__titled_sibling_wants "$i" "${wtitles[w]}" && continue
						pick=${ids[w]}
						pick_title=${wtitles[w]}
						break 3
					done
				done
			done
			[ -n "$pick" ] || continue
			handle[i]=$pick
			held[i]=1
			last[i]=$pick_title
			since[i]=$now
			claimed="$claimed$pick "
			# Move-StableWindowEarly: with layout-early-move on, the caller fills
			# layout_early_desktop (entry index => desktop) and the window goes to its desktop the
			# moment it is claimed, while the other apps are still starting; the arrange pass that
			# follows the wait only tiles. Stdout is the claim list, so the move stays silent.
			if [ -n "${layout_early_desktop[i]:-}" ]; then
				as_move_window "$pick" "${layout_early_desktop[i]}" >/dev/null 2>&1 &&
					log_debug "[layout_wait] early move of window $pick to desktop ${layout_early_desktop[i]}"
			fi
			case $preexisting in
				*" $pick "*)
					ready[i]=1
					log_debug "[layout_wait] adopted pre-existing window $pick for entry $i ${apps[i]}"
					;;
				*)
					[ "${layout_no_wait:-0}" = 1 ] && ready[i]=1
					log_debug "[layout_wait] claimed window $pick '$pick_title' for entry $i ${apps[i]}"
					;;
			esac
		done

		# ProcessAbsentGraceSeconds: an entry given up counts as done, without a window.
		if [ "$grace" -gt 0 ] && [ $((now - start)) -ge $((grace * 1000)) ]; then
			local app_listed matching eligible
			for ((i = 0; i < count; i++)); do
				[ "${ready[i]}" -eq 0 ] && [ "${held[i]}" -eq 0 ] || continue
				app_listed=0
				matching=0
				eligible=0
				for ((w = 0; w < ${#ids[@]}; w++)); do
					app_matches "${apps[i]}" "${tokens[w]}" || continue
					app_listed=1
					foundation_match_title "${titles[i]}" "${wtitles[w]}" || continue
					matching=1
					case ${layout_protected:- } in *" ${ids[w]} "*) continue ;; esac
					if [ "${layout_new_only:-0}" = 1 ]; then
						case $preexisting in *" ${ids[w]} "*) continue ;; esac
					fi
					eligible=1
				done
				if [ "$matching" -eq 1 ] && [ "$eligible" -eq 0 ]; then
					log_debug "[layout_wait] giving up on entry $i ${apps[i]} - only windows it may not take match after ${grace}s"
				elif [ "$app_listed" -eq 0 ] && ! layout__app_running "${apps[i]}"; then
					log_debug "[layout_wait] giving up on entry $i ${apps[i]} - not running after ${grace}s"
				else
					continue
				fi
				ready[i]=1
			done
		fi

		for ((i = 0; i < count; i++)); do
			[ "${ready[i]}" -eq 1 ] || pending=$((pending + 1))
		done
		[ "$pending" -eq 0 ] && break
		[ "$(foundation_now_ms)" -ge "$deadline" ] && break
		sleep "${FOUNDATION_POLL_SECONDS:-0.5}"
	done

	# The catch-all of Get-LayoutProcessSiblings: the only untitled entry of an app takes every
	# remaining window of that app, not just the one it waited for (the windows of the last poll;
	# protected, titled siblings' and, under the alongside rule, pre-existing ones excepted).
	local extras=() j catch_all
	for ((i = 0; i < count; i++)); do
		[ -n "${handle[i]}" ] && [ -z "${titles[i]}" ] || continue
		catch_all=1
		for ((j = 0; j < count; j++)); do
			[ "$j" -ne "$i" ] && [ -z "${titles[j]}" ] && foundation_ieq "${apps[j]}" "${apps[i]}" && catch_all=0
		done
		[ "$catch_all" -eq 1 ] || continue
		for ((w = 0; w < ${#ids[@]}; w++)); do
			case $claimed in *" ${ids[w]} "*) continue ;; esac
			case ${layout_protected:- } in *" ${ids[w]} "*) continue ;; esac
			if [ "${layout_new_only:-0}" = 1 ]; then
				case $preexisting in *" ${ids[w]} "*) continue ;; esac
			fi
			app_matches "${apps[i]}" "${tokens[w]}" || continue
			layout__titled_sibling_wants "$i" "${wtitles[w]}" && continue
			extras+=("$i"$'\t'"${ids[w]}")
			claimed="$claimed${ids[w]} "
			log_debug "[layout_wait] entry $i ${apps[i]} (untitled) also takes window ${ids[w]} '${wtitles[w]}'" >&2
		done
	done

	local missing=0
	for ((i = 0; i < count; i++)); do
		if [ -z "${handle[i]}" ]; then
			log_warning "No window found for ${apps[i]}${titles[i]:+ [${titles[i]}]}" >&2
			missing=$((missing + 1))
			continue
		fi
		[ "${ready[i]}" -eq 1 ] || log_warning "Window ${handle[i]} for ${apps[i]} did not settle in time - placing it anyway" >&2
		printf '%s\t%s\n' "$i" "${handle[i]}"
	done
	[ ${#extras[@]} -eq 0 ] || printf '%s\n' "${extras[@]}"
	[ "$missing" -eq 0 ] && log_debug "[layout_wait] all $count workspace window(s) found"
	return 0
}

# ---------------------------------------------------------------------------------------------
# Arranging one desktop (Set-WindowZoneLayout)
# ---------------------------------------------------------------------------------------------
#
# Arguments: WORKSPACE WORK-WIDTH then one "WINDOW-ID:COLUMN:PERCENT[:ROW]" per window
# (ROW 0 = full height or top half, 1 = bottom half).
#   1. focus the workspace (hidden workspaces refuse layout changes)
#   2. park every other window of that workspace on the parking workspace (except the
#      layout_protected windows of other workspaces, which stay where they are)
#   3. move the windows in, left column first and top before bottom (insertion order is the
#      ordering mechanism), force tiling, flatten, horizontal tiles
#   4. read the order back and nudge misplaced windows left
#   5. zones holding several windows become accordions; halved columns: the bottom node joins
#      the top one, which makes a vertical container
#   6. size the columns: equal shares balance, otherwise resize width in points
# Several windows in one zone (of any set, also a top or bottom half) are stacked in an accordion,
# the layout's last entry in front. A zone alone in its column fills it, top or bottom.
layout_arrange_desktop() {
	local workspace=$1 work_width=$2
	shift 2
	local sorted
	# Stable: windows of one zone keep the layout's entry order, which decides the stacking.
	sorted=$(printf '%s\n' "$@" | awk -F: '{ print $0 ":" ($4 == "" ? 0 : $4) }' | sort -s -t: -k2,2n -k5,5n)
	local ids=() cols=() pcts=() rows=()
	while IFS=: read -r spec_id spec_col spec_pct _ spec_row; do
		[ -n "$spec_id" ] || continue
		ids+=("$spec_id")
		cols+=("$spec_col")
		pcts+=("$spec_pct")
		rows+=("${spec_row:-0}")
	done <<<"$sorted"
	local count=${#ids[@]} i ok=0
	[ "$count" -gt 0 ] || return 1

	local distinct stacked=0
	distinct=$(for ((i = 0; i < count; i++)); do printf '%s.%s\n' "${cols[i]}" "${rows[i]}"; done | sort -u | grep -c .)
	[ "$distinct" -eq 1 ] && [ "$count" -gt 1 ] && stacked=1

	# A window in macOS native full screen sits on its own Space and covers the desktop no matter
	# what the tree says; bring it back first and let the exit animation finish.
	local exited=0
	for ((i = 0; i < count; i++)); do
		if as_exit_native_fullscreen "${ids[i]}"; then
			log_debug "[arrange] window ${ids[i]} left macOS native full screen"
			exited=1
		fi
	done
	[ "$exited" -eq 1 ] && sleep 1.5

	as_focus_workspace "$workspace"

	local parking own=' '
	parking=$(parking_workspace)
	for ((i = 0; i < count; i++)); do own="$own${ids[i]} "; done
	if [ -n "$parking" ] && [ "$parking" != "$workspace" ]; then
		local stranger
		for stranger in $(as_workspace_windows "$workspace"); do
			case $own in *" $stranger "*) continue ;; esac
			case ${layout_protected:- } in *" $stranger "*) continue ;; esac
			log_debug "[arrange] parking window $stranger from workspace $workspace on $parking"
			as_move_window "$stranger" "$parking"
		done
	fi

	for ((i = 0; i < count; i++)); do
		as_move_window "${ids[i]}" "$workspace" || true
		as_set_tiling "${ids[i]}" || true
	done
	as_flatten "$workspace"

	if [ "$stacked" -eq 1 ]; then
		as_layout "${ids[0]}" h_accordion || ok=1
		# The last entry ends on top, as the last window placed into a FancyZones zone does.
		as_focus_window "${ids[count - 1]}"
		log_debug "[arrange] stacked $count windows on workspace $workspace (accordion)"
		return $ok
	fi
	as_layout "${ids[0]}" h_tiles || true

	# Order repair: each pass moves the first misplaced window one step left.
	local step max=$((count * count)) current misplaced
	for ((step = 0; step < max; step++)); do
		current=()
		local walked
		for walked in $(as_workspace_order "$workspace"); do
			[[ $own == *" $walked "* ]] && current+=("$walked")
		done
		misplaced=''
		for ((i = 0; i < count && i < ${#current[@]}; i++)); do
			if [ "${current[i]}" != "${ids[i]}" ]; then
				misplaced=${ids[i]}
				break
			fi
		done
		[ -n "$misplaced" ] || break
		log_debug "[arrange] window $misplaced out of order on workspace $workspace - moving it left"
		as_move_left "$misplaced" || {
			ok=1
			break
		}
	done

	# Columns, left to right; in the flat order a column's top (or only) zone comes first, then
	# its bottom zone, each in entry order.
	local start=0 end top=() bottom=() fronts=() k
	while [ "$start" -lt "$count" ]; do
		top=()
		bottom=()
		for ((end = start; end < count && cols[end] == cols[start]; end++)); do
			if [ "${rows[end]}" -eq 1 ]; then bottom+=("${ids[end]}"); else top+=("${ids[end]}"); fi
		done
		# A bottom zone alone fills its column, as a top zone alone does.
		if [ ${#top[@]} -eq 0 ]; then
			top=("${bottom[@]}")
			bottom=()
		fi
		# Set-StackedWindowOrder: a zone holding several windows becomes an accordion, built by
		# joining the second window with the first and moving the rest in from the right.
		if [ ${#top[@]} -gt 1 ]; then
			as_join_with "${top[1]}" left || ok=1
			as_layout "${top[1]}" v_accordion || ok=1
			for ((k = 2; k < ${#top[@]}; k++)); do
				as_move_left "${top[k]}" || ok=1
			done
			fronts+=("${top[${#top[@]} - 1]}")
			log_debug "[arrange] stacked ${#top[@]} windows in column ${cols[start]} (accordion)"
		fi
		# Halved column: the bottom window joins the top node from the right, a vertical container
		# 50/50 by construction. Further bottom windows enter it by a move from the right (with the
		# bottom window focused, they land below it), the first is joined up with it into the bottom
		# accordion, later ones move into that accordion.
		if [ ${#bottom[@]} -gt 0 ]; then
			as_join_with "${bottom[0]}" left || ok=1
			log_debug "[arrange] window ${bottom[0]} stacked under column ${cols[start]}'s top"
			for ((k = 1; k < ${#bottom[@]}; k++)); do
				as_focus_window "${bottom[k - 1]}"
				as_move_left "${bottom[k]}" || ok=1
				if [ "$k" -eq 1 ]; then
					as_join_with "${bottom[1]}" up || ok=1
					as_layout "${bottom[1]}" accordion || ok=1
				fi
			done
			[ ${#bottom[@]} -gt 1 ] && fronts+=("${bottom[${#bottom[@]} - 1]}")
		fi
		start=$end
	done
	# The last entry of a zone ends in front, as the last window snapped into a FancyZones zone.
	for k in "${fronts[@]}"; do
		as_focus_window "$k"
	done

	# One entry per column: its first window and its share.
	local column_ids=() column_pcts=()
	for ((i = 0; i < count; i++)); do
		if [ "$i" -eq 0 ] || [ "${cols[i]}" != "${cols[i - 1]}" ]; then
			column_ids+=("${ids[i]}")
			column_pcts+=("${pcts[i]}")
		fi
	done
	local columns=${#column_ids[@]}
	if [ "$columns" -eq 1 ]; then
		# A single column fills the width; a halved one is already 50/50.
		return $ok
	fi
	local unique
	unique=$(printf '%s\n' "${column_pcts[@]}" | awk '{ printf "%.0f\n", $1 }' | sort -u | grep -c .)
	if [ "$unique" -eq 1 ]; then
		as_balance "$workspace"
		log_debug "[arrange] balanced $columns equal columns on workspace $workspace"
	else
		for ((i = 0; i < columns - 1; i++)); do
			local width
			width=$(awk -v w="$work_width" -v p="${column_pcts[i]}" 'BEGIN { printf "%d", (w * p / 100) + 0.5 }')
			as_resize_width "${column_ids[i]}" "$width" || ok=1
			log_debug "[arrange] column of window ${column_ids[i]} => width $width of $work_width points"
		done
	fi
	return $ok
}

# ---------------------------------------------------------------------------------------------
# Verifying one desktop (Confirm-WorkspaceWindowPositions)
# ---------------------------------------------------------------------------------------------

# The workspace rect AeroSpace tiles into: the primary work area (as_primary_monitor) less the
# outer gaps (as_gaps), followed by the inner gaps, as "X Y WIDTH HEIGHT INNER-H INNER-V".
# Usage: layout_tile_area WORK-X WORK-Y WORK-WIDTH WORK-HEIGHT GAPS...
layout_tile_area() {
	local x=$1 y=$2 width=$3 height=$4 inner_h=$5 inner_v=$6 outer_left=$7 outer_top=$8 outer_right=$9 outer_bottom=${10}
	printf '%s %s %s %s %s %s\n' $((x + outer_left)) $((y + outer_top)) $((width - outer_left - outer_right)) \
		$((height - outer_top - outer_bottom)) "$inner_h" "$inner_v"
}

# The frame each window should have once layout_arrange_desktop has arranged the SPECs, as
# "ID X Y WIDTH HEIGHT" lines (points, top-left origin), on AeroSpace's tiling model: the columns
# that hold windows share the tile area (layout_tile_area) as the arrange sizes them (one column
# fills it, equal shares are balanced, otherwise each column but the last gets its percentage and
# the last the rest); a window is its column less the inner horizontal gap, half of it on each side
# that touches another column (the outer edges carry the outer gaps, already out of the area); a
# column holding both halves splits its height the same way with the inner vertical gap; every
# window of a stacked zone has the zone's frame. Any gaps work, 0 included.
# Usage: layout_expected_frames AREA-X AREA-Y AREA-WIDTH AREA-HEIGHT INNER-H INNER-V SPEC...
layout_expected_frames() {
	local x=$1 y=$2 width=$3 height=$4 gap_h=$5 gap_v=$6
	shift 6
	printf '%s\n' "$@" | awk -F: -v X="$x" -v Y="$y" -v W="$width" -v H="$height" -v GH="$gap_h" -v GV="$gap_v" '
		function r(v) { return int(v + 0.5) }
		NF >= 3 {
			n++; id[n] = $1; col[n] = $2 + 0; row[n] = ($4 == "" ? 0 : $4 + 0)
			if (!(col[n] in pct)) { pct[col[n]] = $3; cols[++nc] = col[n] }
			half[col[n], row[n]] = 1
		}
		END {
			for (i = 2; i <= nc; i++) for (j = i; j > 1 && cols[j - 1] > cols[j]; j--) { t = cols[j]; cols[j] = cols[j - 1]; cols[j - 1] = t }
			for (i = 1; i <= nc; i++) shares[sprintf("%.0f", pct[cols[i]])] = 1
			unique = 0
			for (s in shares) unique++
			left = X; used = 0
			for (i = 1; i <= nc; i++) {
				c = cols[i]
				if (nc == 1) w = W
				else if (unique == 1) w = int(W / nc)
				else if (i < nc) w = int(W * pct[c] / 100 + 0.5)
				else w = W - used
				# The window inside the column node: half the inner gap off each side facing a neighbour.
				wx[c] = left + (i > 1 ? GH / 2 : 0)
				ww[c] = w - (i > 1 ? GH / 2 : 0) - (i < nc ? GH / 2 : 0)
				left += w; used += w
			}
			for (k = 1; k <= n; k++) {
				c = col[k]
				if (half[c, 0] && half[c, 1]) {
					top = (row[k] == 1 ? Y + H / 2 + GV / 2 : Y)
					printf "%s %d %d %d %d\n", id[k], r(wx[c]), int(top), r(ww[c]), int(H / 2 - GV / 2)
				} else printf "%s %d %d %d %d\n", id[k], r(wx[c]), Y, r(ww[c]), H
			}
		}'
}

# Reads the arranged windows back: each must be on DESKTOP and, when its frame can be read (the
# window server's list, by window id), within 50 points of its expected frame on every edge.
# Prints one "ID<TAB>EXPECTED<TAB>ACTUAL" line per window that is not, and fails when there is
# one. A window whose frame cannot be read is checked only for its desktop.
# Usage: layout_verify_desktop DESKTOP AREA-X AREA-Y AREA-WIDTH AREA-HEIGHT INNER-H INNER-V SPEC...
layout_verify_desktop() {
	local desktop=$1 x=$2 y=$3 width=$4 height=$5 gap_h=$6 gap_v=$7
	shift 7
	local ids=() spec id ex ey ew eh ax ay aw ah desktops frames actual on rc=0
	for spec in "$@"; do ids+=("${spec%%:*}"); done
	desktops=$(as_windows | cut -f1,5)
	frames=$(as_window_frames "${ids[@]}") || frames=''
	while read -r id ex ey ew eh; do
		on=$(awk -F'\t' -v id="$id" '$1 == id { print $2; exit }' <<<"$desktops")
		if [ "$on" != "$desktop" ]; then
			printf '%s\tdesktop %s\tdesktop %s\n' "$id" "$desktop" "${on:-none (window gone)}"
			rc=1
			continue
		fi
		actual=$(awk -v id="$id" '$1 == id { print $2, $3, $4, $5; exit }' <<<"$frames")
		[ -n "$actual" ] || continue
		if ! awk -v e="$ex $ey $ew $eh" -v a="$actual" 'BEGIN {
			split(e, E, " "); split(a, A, " ")
			for (i = 1; i <= 4; i++) { d = E[i] - A[i]; if (d < 0) d = -d; if (d > 50) exit 1 }
		}'; then
			read -r ax ay aw ah <<<"$actual"
			printf '%s\t%s,%s %sx%s\t%s,%s %sx%s\n' "$id" "$ex" "$ey" "$ew" "$eh" "$ax" "$ay" "$aw" "$ah"
			rc=1
		fi
	done < <(layout_expected_frames "$x" "$y" "$width" "$height" "$gap_h" "$gap_v" "$@")
	return $rc
}
