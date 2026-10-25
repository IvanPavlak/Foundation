# shellcheck shell=bash
# Terminal tabs on top of the WezTerm driver - the Open-Terminal core shared by Open-Terminal
# (t), Open-ProjectTerminals and Run-Project (rp).

# Opens one tab per spec line read from stdin and prints the new pane ids, one per line.
#   spec line: TITLE<TAB>DIR<TAB>COMMAND   (TITLE and COMMAND may be empty; DIR defaults to $HOME)
# Usage: term_open_tabs TARGET SKIP-PANEL [NO-ONEFETCH]
#   TARGET      same   - join the WezTerm window this shell runs in (new window when outside a
#                        WezTerm pane, see wt_own_pane)
#               new    - a new window for the first tab, the rest join it
#               <id>   - an explicit WezTerm window id
#   SKIP-PANEL  1      - start the shells without the fastfetch panel and queue the panel plus
#                        COMMAND as a deferred command, drawn once the layout placed the window
#                        (Open-Workspace flushes the queue); 0 - run COMMAND right away
#   NO-ONEFETCH 1      - the tabs' first greeting skips the onefetch panel (Open-ProjectTerminals,
#                        greeting.conf onefetch-in-project-terminals off); a later `c` draws it
term_open_tabs() {
	local target=$1 skip_panel=${2:-0} no_onefetch=${3:-0} window='' title dir command pane own=''
	case $target in
		same)
			if wt_running && own=$(wt_own_pane); then
				window=$(wt_pane_window "$own")
			fi
			;;
		new) window='' ;;
		*) window=$target ;;
	esac
	local shell_path=${SHELL:-/bin/zsh}
	local program=()
	if [ "$skip_panel" = "1" ]; then
		program=(/usr/bin/env FOUNDATION_SKIP_STARTUP_PANEL=1 "$shell_path" -l)
	elif [ "$no_onefetch" = "1" ]; then
		# Read once by the startup greeting in Unix/shell/shellrc.sh, which then unsets it.
		program=(/usr/bin/env FOUNDATION_STARTUP_NO_ONEFETCH=1 "$shell_path" -l)
	fi

	local line
	# Split on the tabs by hand: a tab is IFS whitespace to read, so an empty TITLE would vanish
	# and shift DIR and COMMAND one field left.
	while IFS= read -r line; do
		title=${line%%$'\t'*}
		line=${line#"$title"}
		line=${line#$'\t'}
		dir=${line%%$'\t'*}
		command=${line#"$dir"}
		command=${command#$'\t'}
		[ -n "$dir" ] || dir=$HOME
		if ! wt_running; then
			pane=$(wt_start "$dir" "${program[@]}") || return 1
			window=$(wt_pane_window "$pane")
		else
			pane=$(wt_spawn "${window:-new}" "$dir" "${program[@]}")
			if [ -z "$pane" ]; then
				log_error "WezTerm did not open a tab in [$dir]"
				continue
			fi
			[ -n "$window" ] || window=$(wt_pane_window "$pane")
		fi
		[ -n "$title" ] && wt_set_tab_title "$pane" "$title"
		if [ "$skip_panel" = "1" ]; then
			local deferred='Show-TerminalGreeting --no-resize --settle'
			[ "$no_onefetch" = "1" ] && deferred="$deferred --no-onefetch"
			[ -n "$command" ] && deferred="$deferred; $command"
			term_defer "$pane" "$deferred"
		elif [ -n "$command" ]; then
			wt_send_line "$pane" "$command"
		fi
		log_debug "[term_open_tabs] pane $pane in window $window ($dir)${title:+ titled [$title]}"
		printf '%s\n' "$pane"
	done
	# A spawned tab becomes the active one; hand focus back to the tab the command was typed in
	# so the shell you are working in stays in front.
	if [ "$target" = "same" ] && [ -n "$own" ]; then
		wt_activate_pane "$own"
	fi
	return 0
}

# Queue a command for a pane; flushed by term_flush_deferred. Without a run directory (a
# command started on its own) the command is sent immediately.
term_defer() {
	if [ -n "${FOUNDATION_RUN_DIR:-}" ] && [ -d "$FOUNDATION_RUN_DIR" ]; then
		printf '%s\t%s\n' "$1" "$2" >>"$FOUNDATION_RUN_DIR/deferred"
	else
		wt_send_line "$1" "$2"
	fi
}

# Invoke-DeferredTerminalCommands
term_flush_deferred() {
	local file=${FOUNDATION_RUN_DIR:-}/deferred pane command live
	[ -n "${FOUNDATION_RUN_DIR:-}" ] && [ -s "$file" ] || return 0
	live=" $(wt_panes | cut -f3 | tr '\n' ' ') "
	while IFS=$'\t' read -r pane command; do
		case $live in
			*" $pane "*) wt_send_line "$pane" "$command" ;;
			*) log_debug "[term_flush_deferred] pane $pane is gone - skipping [$command]" ;;
		esac
	done <"$file"
	: >"$file"
}

# Named terminal windows - Windows Terminal's `wt -w NAME`, for Open-Terminal --window-id NAME: one
# NAME<TAB>WEZTERM-WINDOW-ID line per name in $FOUNDATION_STATE_DIR/terminal-windows, the last line
# of a name winning.
term__windows_file() {
	printf '%s/terminal-windows' "$FOUNDATION_STATE_DIR"
}

# The WezTerm window id remembered for NAME while that window is still open; fails otherwise (a
# closed window's name opens a new one). Usage: term_named_window NAME
term_named_window() {
	local file id
	file=$(term__windows_file)
	[ -r "$file" ] || return 1
	id=$(awk -F'\t' -v n="$1" '$1 == n { id = $2 } END { print id }' "$file")
	[ -n "$id" ] || return 1
	wt_panes | cut -f1 | grep -qxF -- "$id" || return 1
	printf '%s' "$id"
}

# Remembers WINDOW-ID as the window NAME, replacing an older line of that name.
# Usage: term_remember_window NAME WINDOW-ID
term_remember_window() {
	local file
	file=$(term__windows_file)
	mkdir -p "$FOUNDATION_STATE_DIR" || return 1
	{
		[ -r "$file" ] && awk -F'\t' -v n="$1" '$1 != n' "$file"
		printf '%s\t%s\n' "$1" "$2"
	} >"$file.foundation.$$" && mv "$file.foundation.$$" "$file"
}
