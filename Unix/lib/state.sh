# shellcheck shell=bash
# Workspace ownership state - the OpenWorkspaces.txt tracker of Save-WorkspaceState, so
# Close-Workspace (cw) closes exactly what an open produced and nothing it did not.
#
# File: $FOUNDATION_STATE_DIR/open-workspaces, one owned object per line:
#   WORKSPACE<TAB>window<TAB>WINDOW-ID<TAB>APP-TOKEN<TAB>BUNDLE<TAB>TITLE
#   WORKSPACE<TAB>pane<TAB>PANE-ID<TAB>TAB-TITLE
#   WORKSPACE<TAB>meta<TAB>alongside           (the workspace was opened --alongside)
# WORKSPACE is the record key of one instance: the workspace name for the first, NAME#2, NAME#3,
# ... for each further --alongside open of a workspace already recorded, so a workspace open twice
# (plain, then alongside) keeps two records and either can be closed alone, as on Windows. A plain
# open replaces every instance of its name.
# CurrentLayout analog: $FOUNDATION_STATE_DIR/current-layout holds "WORKSPACE<TAB>LAYOUT-TYPE",
# and $FOUNDATION_STATE_DIR/layout-pins/<WORKSPACE>_<LAYOUT-TYPE> the window each layout entry held
# after its last Applied open ("ENTRY-INDEX<TAB>WINDOW-ID"), the remembered-window pins.
#
# Ownership is the before/after delta of an open, never the configuration: an app that was
# already running when a workspace opened is not that workspace's to close.

state__file() {
	printf '%s/open-workspaces' "$FOUNDATION_STATE_DIR"
}

# Every record key (one per instance), in file order.
state_keys() {
	local file
	file=$(state__file)
	[ -r "$file" ] || return 0
	cut -f1 "$file" | awk '!seen[$0]++'
}

# Every recorded workspace name (the instance suffix dropped), in file order.
state_workspaces() {
	state_keys | awk '{ sub(/#[0-9]+$/, "") } !seen[tolower($0)]++'
}

# The record keys of workspace NAME (case-insensitive), in file order. Usage: state_instances NAME
state_instances() {
	state_keys | awk -v ws="$(foundation_lower "$1")" '{ k = tolower($0); sub(/#[0-9]+$/, "", k) } k == ws'
}

# The key a further instance of NAME records under: NAME when none is recorded, else NAME#N, one
# past the highest. Usage: state_next_key NAME
state_next_key() {
	local keys
	keys=$(state_instances "$1")
	if [ -z "$keys" ]; then
		printf '%s' "$1"
		return 0
	fi
	printf '%s#%s' "$1" "$(printf '%s\n' "$keys" | awk -F'#' 'NF > 1 && $NF + 0 > m { m = $NF + 0 } END { print (m > 1 ? m : 1) + 1 }')"
}

# Entries of one instance (fields 2..), case-insensitive key.
state_entries() {
	local file
	file=$(state__file)
	[ -r "$file" ] || return 0
	awk -F'\t' -v ws="$(foundation_lower "$1")" 'tolower($1) == ws { sub(/^[^\t]*\t/, ""); print }' "$file"
}

# Replace one instance's entries (KEY) with the lines read from stdin (fields 2.. as above).
state_replace() {
	local workspace=$1 file tmp
	file=$(state__file)
	mkdir -p "$FOUNDATION_STATE_DIR" || return 1
	tmp=$(mktemp "$FOUNDATION_STATE_DIR/.open-workspaces.XXXXXX") || return 1
	if [ -r "$file" ]; then
		awk -F'\t' -v ws="$(foundation_lower "$workspace")" 'tolower($1) != ws' "$file" >"$tmp"
	fi
	while IFS= read -r line; do
		[ -n "$line" ] && printf '%s\t%s\n' "$workspace" "$line" >>"$tmp"
	done
	mv "$tmp" "$file"
}

# Drops one instance's record. Usage: state_forget KEY
state_forget() {
	state_replace "$1" </dev/null
}

# Drops every instance of workspace NAME. Usage: state_forget_workspace NAME
state_forget_workspace() {
	local key
	while IFS= read -r key; do
		[ -n "$key" ] && state_forget "$key"
	done < <(state_instances "$1")
}

state_set_current_layout() {
	mkdir -p "$FOUNDATION_STATE_DIR" && printf '%s\t%s\n' "$1" "$2" >"$FOUNDATION_STATE_DIR/current-layout"
}

# Save-CurrentLayout's pins: replaces the pins of WORKSPACE in layout set TYPE with the claim
# lines on stdin ("ENTRY-INDEX<TAB>WINDOW-ID", the first window of each entry kept).
# Usage: state_save_layout_pins WORKSPACE TYPE
state_save_layout_pins() {
	local dir=$FOUNDATION_STATE_DIR/layout-pins
	mkdir -p "$dir" || return 1
	awk -F'\t' 'NF >= 2 && !seen[$1]++ { print $1 "\t" $2 }' >"$dir/$(foundation_lower "$1")_$(foundation_lower "$2")"
}

# Get-CurrentLayout's pins of WORKSPACE in layout set TYPE ("ENTRY-INDEX<TAB>WINDOW-ID" lines;
# nothing when the workspace was never applied there). Usage: state_layout_pins WORKSPACE TYPE
state_layout_pins() {
	local file
	file=$FOUNDATION_STATE_DIR/layout-pins/$(foundation_lower "$1")_$(foundation_lower "$2")
	[ -r "$file" ] && cat "$file"
	return 0
}

# Was instance KEY opened --alongside (its record carries the meta alongside line)?
state_is_alongside() {
	state_entries "$1" | awk -F'\t' '$1 == "meta" && $2 == "alongside" { found = 1 } END { exit !found }'
}

# Resolve-TrackedWorkspaceWindow: the live window each window record of instance KEY refers to,
# one "RECORDED-ID<TAB>LIVE-ID<TAB>HOW" line per record that resolves (HOW: id, bundle, title).
# The ladder, as on Windows: the exact window id; else the same bundle when it has exactly one live
# window (an Electron app recreated its window); else the same bundle and exact title (the app
# restarted). A Terminal role window resolves by id only (its windows share one app and generic
# titles), a live window resolves for one record at most, and a window another instance owns by
# id is never taken. LIVE is the as_windows output, read once by the caller.
# Usage: state_resolve_windows KEY LIVE
state_resolve_windows() {
	local key=$1 live=$2 terminal=' ' foreign=' ' member bundle other
	while IFS= read -r member; do
		[ -n "$member" ] && bundle=$(app_bundle "$member") && terminal+="$bundle "
	done < <(app_role_members Terminal 2>/dev/null)
	while IFS= read -r other; do
		[ -n "$other" ] || continue
		foundation_ieq "$other" "$key" && continue
		foreign+="$(state_entries "$other" | awk -F'\t' '$1 == "window" { print $2 }' | tr '\n' ' ')"
	done < <(state_keys)
	{
		state_entries "$key" | awk -v OFS='\t' '$1 == "window" { print "R", $0 }'
		printf '%s\n' "$live" | awk -v OFS='\t' 'NF { print "L", $0 }'
	} | awk -F'\t' -v terminal="$terminal" -v foreign="$foreign" '
		function free(w) { return !(w in used) && !index(foreign, " " w " ") }
		function ladder(i) { return !(i in out) && rb[i] != "" && !index(terminal, " " rb[i] " ") }
		$1 == "R" { n++; rid[n] = $3; rb[n] = $5; rt[n] = $6; next }
		$1 == "L" { m++; lid[m] = $2; lb[m] = $4; lt[m] = $8; count[$4]++; alive[$2] = 1; next }
		END {
			for (i = 1; i <= n; i++) if (rid[i] in alive) { out[i] = rid[i]; how[i] = "id"; used[rid[i]] = 1 }
			for (i = 1; i <= n; i++) {
				if (!ladder(i) || count[rb[i]] != 1) continue
				for (j = 1; j <= m; j++) if (lb[j] == rb[i]) w = lid[j]
				if (free(w)) { out[i] = w; how[i] = "bundle"; used[w] = 1 }
			}
			for (i = 1; i <= n; i++) {
				if (!ladder(i) || rt[i] == "") continue
				for (j = 1; j <= m; j++)
					if (lb[j] == rb[i] && lt[j] == rt[i] && free(lid[j])) { out[i] = lid[j]; how[i] = "title"; used[lid[j]] = 1; break }
			}
			for (i = 1; i <= n; i++) if (i in out) print rid[i] "\t" out[i] "\t" how[i]
		}'
}

# The live windows instance KEY owns (resolved by state_resolve_windows), one id per line. LIVE
# is the as_windows output (ID first), read once by the caller. Usage: state_live_windows KEY LIVE
state_live_windows() {
	state_resolve_windows "$1" "$2" | cut -f2
}

# The menu label of instance KEY, as Windows labels a workspace open more than once:
# "NAME (plain|alongside, desktop N)", N the lowest desktop holding one of its live windows, or
# "instance N" when none is live. LIVE is the as_windows output.
# Usage: state_instance_label KEY LIVE
state_instance_label() {
	local key=$1 mode=plain where ids
	state_is_alongside "$key" && mode=alongside
	ids=" $(state_live_windows "$key" "$2" | tr '\n' ' ') "
	where=$(printf '%s\n' "$2" | awk -F'\t' -v ids="$ids" '
		NF && index(ids, " " $1 " ") && $5 ~ /^[0-9]+$/ && (min == "" || $5 + 0 < min) { min = $5 + 0 }
		END { if (min != "") print "desktop " min }')
	if [ -z "$where" ]; then
		case $key in *#[0-9]*) where="instance ${key##*#}" ;; *) where="instance 1" ;; esac
	fi
	printf '%s (%s, %s)' "${key%%#*}" "$mode" "$where"
}

# Get-WorkspaceOpenProtection: the live windows an open must leave alone, one per line. A plain
# open (MODE plain) protects the windows of every recorded alongside instance that still has one,
# except the instances of a workspace named in OPENING (being opened now): a plain open of a
# workspace adopts its own alongside instances. An alongside open (MODE alongside) protects those
# of every recorded instance, its own workspace's too: it is a separate instance with windows of
# its own. LIVE is the as_windows output. Usage: state_protected_windows MODE LIVE [OPENING...]
state_protected_windows() {
	local mode=$1 live=$2 key opening skip
	shift 2
	while IFS= read -r key; do
		[ -n "$key" ] || continue
		if [ "$mode" != alongside ]; then
			state_is_alongside "$key" || continue
			skip=0
			for opening in "$@"; do foundation_ieq "$opening" "${key%%#*}" && skip=1; done
			[ "$skip" -eq 0 ] || continue
		fi
		state_live_windows "$key" "$live"
	done < <(state_keys)
}

# The highest desktop (numeric AeroSpace workspace) holding one of the window ids on stdin, 0
# when none does: where an alongside open starts its desktops. LIVE is the as_windows output
# (ID TOKEN BUNDLE PID WORKSPACE ...). Usage: ... | state_desktop_offset LIVE
state_desktop_offset() {
	local ids
	ids=" $(tr '\n' ' ') "
	printf '%s\n' "$1" | awk -F'\t' -v ids="$ids" '
		NF && index(ids, " " $1 " ") && $5 ~ /^[0-9]+$/ && $5 + 0 > max { max = $5 + 0 }
		END { print max + 0 }'
}
