# shellcheck shell=bash
# Line editing (config/shell.conf) and listing colours (the list-color lines of config/theme.conf) -
# the PSReadLine settings of Windows translated for zsh's line editor: the key names of Set-PSReadLineKeyHandler -Key, the function names of -Function, and
# the keys PSReadLine's Windows edit mode binds by itself. foundation-shell-settings hands the
# shell rc the result as finished lines; Test-ConfigurationSchema reports what it cannot read.
#
# Names compare case-insensitively, as PowerShell does. Nothing here touches the shell: the rc
# replays the lines, so a forked shell.conf can be checked without starting one.

# The normalized value of the scalar setting KIND for VALUE; fails when VALUE is not one KIND
# takes. `key` lines are not scalars (see lineediting_bindings).
# Usage: lineediting_setting history-size 32767
lineediting_setting() {
	local kind=$1 value=$2 result=0 nocase=0
	shopt -q nocasematch && nocase=1
	shopt -s nocasematch
	case $kind in
		history-size)
			case $value in '' | *[!0-9]*) result=1 ;; *) [ "$((10#$value))" -gt 0 ] && [ ${#value} -le 9 ] || result=1 ;; esac
			;;
		history-file | prediction-list-marker) [ -n "$value" ] || result=1 ;;
		edit-mode)
			case $value in emacs) value='emacs' ;; vi) value='vi' ;; windows) value='windows' ;; *) result=1 ;; esac
			;;
		history-no-duplicates | completion-ignore-case)
			case $value in on) value=on ;; off) value=off ;; *) result=1 ;; esac
			;;
		history-save-style)
			case $value in incrementally) value=incrementally ;; at-exit) value=at-exit ;; nothing) value=nothing ;; *) result=1 ;; esac
			;;
		color-list-prediction | color-list-prediction-selected | color-emphasis)
			# A colour zsh's highlighting takes: one of the eight names, 0-255, or #RRGGBB.
			case $value in
				black | red | green | yellow | blue | magenta | cyan | white | default) value=$(printf '%s' "$value" | tr '[:upper:]' '[:lower:]') ;;
				[0-9] | [0-9][0-9] | [01][0-9][0-9] | 2[0-4][0-9] | 25[0-5]) ;;
				\#[0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f][0-9a-f]) ;;
				*) result=1 ;;
			esac
			;;
		prediction-source)
			case $value in none) value=none ;; history) value=history ;; *) result=1 ;; esac
			;;
		prediction-view)
			case $value in inline) value=inline ;; list) value=list ;; *) result=1 ;; esac
			;;
		*) result=1 ;;
	esac
	[ $nocase -eq 1 ] || shopt -u nocasematch
	[ $result -eq 0 ] && printf '%s' "$value"
	return $result
}

# The bindkey sequences a terminal sends for the PSReadLine key NAME, one per line (every variant,
# so UpArrow covers the normal and the application cursor mode). A NAME starting with ^ is
# already a sequence and passes as it is. Fails for a name it does not know.
# Usage: lineediting_key_sequences Ctrl+LeftArrow
lineediting_key_sequences() {
	local name=$1 result=0 nocase=0 code='' letter
	case $name in
		^?*)
			printf '%s\n' "$name"
			return 0
			;;
	esac
	shopt -q nocasematch && nocase=1
	shopt -s nocasematch
	# The xterm modifier code of a modified cursor or editing key: Shift 2, Alt 3, Ctrl 5.
	case $name in
		Shift+*Arrow | Shift+Home | Shift+End) code=2 ;;
		Alt+*Arrow) code=3 ;;
		Ctrl+*Arrow | Ctrl+Home | Ctrl+End) code=5 ;;
	esac
	case $name in
		UpArrow) printf '%s\n' '^[[A' '^[OA' ;;
		DownArrow) printf '%s\n' '^[[B' '^[OB' ;;
		RightArrow) printf '%s\n' '^[[C' '^[OC' ;;
		LeftArrow) printf '%s\n' '^[[D' '^[OD' ;;
		Home) printf '%s\n' '^[[H' '^[OH' '^[[1~' ;;
		End) printf '%s\n' '^[[F' '^[OF' '^[[4~' ;;
		Insert) printf '%s\n' '^[[2~' ;;
		Delete) printf '%s\n' '^[[3~' ;;
		PageUp) printf '%s\n' '^[[5~' ;;
		PageDown) printf '%s\n' '^[[6~' ;;
		Tab) printf '%s\n' '^I' ;;
		Shift+Tab) printf '%s\n' '^[[Z' ;;
		Enter) printf '%s\n' '^M' ;;
		Escape) printf '%s\n' '^[' ;;
		Backspace) printf '%s\n' '^?' ;;
		Ctrl+Backspace) printf '%s\n' '^H' ;;
		Ctrl+Spacebar | Ctrl+Space) printf '%s\n' '^@' ;;
		*+UpArrow) [ -n "$code" ] && printf '%s\n' "^[[1;${code}A" || result=1 ;;
		*+DownArrow) [ -n "$code" ] && printf '%s\n' "^[[1;${code}B" || result=1 ;;
		*+RightArrow) [ -n "$code" ] && printf '%s\n' "^[[1;${code}C" || result=1 ;;
		*+LeftArrow) [ -n "$code" ] && printf '%s\n' "^[[1;${code}D" || result=1 ;;
		*+Home) [ -n "$code" ] && printf '%s\n' "^[[1;${code}H" || result=1 ;;
		*+End) [ -n "$code" ] && printf '%s\n' "^[[1;${code}F" || result=1 ;;
		Ctrl+Delete) printf '%s\n' '^[[3;5~' ;;
		F1) printf '%s\n' '^[OP' ;;
		F2) printf '%s\n' '^[OQ' ;;
		F3) printf '%s\n' '^[OR' ;;
		F4) printf '%s\n' '^[OS' ;;
		F5) printf '%s\n' '^[[15~' ;;
		F6) printf '%s\n' '^[[17~' ;;
		F7) printf '%s\n' '^[[18~' ;;
		F8) printf '%s\n' '^[[19~' ;;
		F9) printf '%s\n' '^[[20~' ;;
		F10) printf '%s\n' '^[[21~' ;;
		F11) printf '%s\n' '^[[23~' ;;
		F12) printf '%s\n' '^[[24~' ;;
		Ctrl+[a-z])
			# A control character is the same for either case of the letter; bindkey takes ^R.
			letter=${name#*+}
			printf '^%s\n' "$(printf '%s' "$letter" | tr '[:lower:]' '[:upper:]')"
			;;
		Alt+[a-z])
			# Alt sends ESC before the letter, whose case then matters (Alt+b is not Alt+B).
			printf '^[%s\n' "${name#*+}"
			;;
		*) result=1 ;;
	esac
	[ $nocase -eq 1 ] || shopt -u nocasematch
	return $result
}

# The zle widget for FUNCTION: a PSReadLine function name translated, or a zle widget name (lower
# case, hyphens, as `zle -la` lists them) passed through. Fails for a PSReadLine-style name it does
# not know. MenuComplete opens menu-select, which needs zsh/complist; the rc loads it then.
# Usage: lineediting_widget HistorySearchBackward
lineediting_widget() {
	local function=$1 widget='' nocase=0
	shopt -q nocasematch && nocase=1
	shopt -s nocasematch
	case $function in
		HistorySearchBackward) widget=history-beginning-search-backward ;;
		HistorySearchForward) widget=history-beginning-search-forward ;;
		PreviousHistory) widget=up-line-or-history ;;
		NextHistory) widget=down-line-or-history ;;
		BeginningOfHistory) widget=beginning-of-history ;;
		EndOfHistory) widget=end-of-history ;;
		ReverseSearchHistory) widget=history-incremental-search-backward ;;
		ForwardSearchHistory) widget=history-incremental-search-forward ;;
		Complete) widget=expand-or-complete ;;
		MenuComplete) widget=menu-select ;;
		TabCompleteNext) widget=menu-complete ;;
		TabCompletePrevious) widget=reverse-menu-complete ;;
		PossibleCompletions) widget=list-choices ;;
		AcceptLine) widget=accept-line ;;
		AcceptAndGetNext) widget=accept-line-and-down-history ;;
		BeginningOfLine) widget=beginning-of-line ;;
		EndOfLine) widget=end-of-line ;;
		BackwardChar) widget=backward-char ;;
		ForwardChar) widget=forward-char ;;
		BackwardWord | ShellBackwardWord) widget=backward-word ;;
		ForwardWord | NextWord | ShellForwardWord | ShellNextWord) widget=forward-word ;;
		DeleteChar) widget=delete-char ;;
		BackwardDeleteChar) widget=backward-delete-char ;;
		KillWord | ShellKillWord) widget=kill-word ;;
		BackwardKillWord | ShellBackwardKillWord | UnixWordRubout) widget=backward-kill-word ;;
		KillLine | ForwardDeleteLine) widget=kill-line ;;
		BackwardKillLine | BackwardDeleteLine) widget=backward-kill-line ;;
		RevertLine) widget=kill-whole-line ;;
		Undo) widget=undo ;;
		Redo) widget=redo ;;
		Yank) widget=yank ;;
		ClearScreen) widget=clear-screen ;;
		SelfInsert) widget=self-insert ;;
		TransposeChars) widget=transpose-chars ;;
		CapitalizeWord) widget=capitalize-word ;;
		UpcaseWord) widget=up-case-word ;;
		DowncaseWord) widget=down-case-word ;;
	esac
	[ $nocase -eq 1 ] || shopt -u nocasematch
	if [ -z "$widget" ]; then
		case $function in '' | [!.a-z]* | *[!-.a-z0-9_]*) return 1 ;; esac
		widget=$function
	fi
	printf '%s' "$widget"
}

# The keys PSReadLine's Windows edit mode binds by itself, as `KEY FUNCTION` lines: the layer
# `edit-mode windows` puts under the key lines. The navigation keys and Tab cycling; the rest of
# the mode is documented, not ported (Backlog/MacOS/51_LineEditingParity.md, Scope after the
# capture). The rc also turns off AUTO_LIST and LIST_BEEP in this mode, so Tab shows no list.
lineediting_windows_keys() {
	printf '%s\n' \
		'Tab TabCompleteNext' \
		'Shift+Tab TabCompletePrevious' \
		'Home BeginningOfLine' \
		'End EndOfLine' \
		'Delete DeleteChar' \
		'Ctrl+LeftArrow BackwardWord' \
		'Ctrl+RightArrow ForwardWord'
}

# The effective key bindings as `SEQUENCE WIDGET` lines, from the `KEY FUNCTION` lines on stdin
# (the key lines of shell.conf without their `key` word, in file order) over the Windows-mode
# layer when EDIT_MODE is windows. A later line wins per key sequence; FUNCTION `-` drops the key,
# a layer's binding included, so it keeps the shell's default. A line with an unknown key or
# function is skipped.
# Usage: lineediting_bindings EDIT_MODE <key-lines
lineediting_bindings() {
	local mode=$1 name function widget sequences sequence i found
	local -a keys=() widgets=()
	while read -r name function _; do
		[ -n "$function" ] || continue
		if [ "$function" = - ]; then
			widget=''
		else
			widget=$(lineediting_widget "$function") || continue
		fi
		sequences=$(lineediting_key_sequences "$name") || continue
		while IFS= read -r sequence; do
			found=''
			for i in "${!keys[@]}"; do
				if [ "${keys[i]}" = "$sequence" ]; then
					found=$i
					break
				fi
			done
			if [ -n "$found" ]; then
				widgets[found]=$widget
			else
				keys+=("$sequence")
				widgets+=("$widget")
			fi
		done <<<"$sequences"
	done < <(
		[ "$mode" = windows ] && lineediting_windows_keys
		cat
	)
	for i in "${!keys[@]}"; do
		[ -n "${widgets[i]}" ] && printf '%s %s\n' "${keys[i]}" "${widgets[i]}"
	done
	return 0
}

# What is wrong with the shell.conf lines on stdin (conf_lines output), one message per line:
# an unknown line kind, a value its kind does not take, a key line without a known key or
# function. Prints nothing for a clean file.
# Usage: conf_lines shell.conf | lineediting_problems
lineediting_problems() {
	local kind rest name function extra
	while read -r kind rest; do
		case $(printf '%s' "$kind" | tr '[:upper:]' '[:lower:]') in
			key)
				read -r name function extra <<<"$rest"
				if [ -z "$function" ] || [ -n "$extra" ]; then
					printf 'key [%s] is not KEY FUNCTION\n' "$rest"
					continue
				fi
				lineediting_key_sequences "$name" >/dev/null || printf 'key %s: unknown key name\n' "$name"
				[ "$function" = - ] || lineediting_widget "$function" >/dev/null ||
					printf 'key %s: unknown function %s\n' "$name" "$function"
				;;
			history-size | history-file | edit-mode | history-no-duplicates | history-save-style | completion-ignore-case | prediction-source | prediction-view | prediction-list-marker | color-list-prediction | color-list-prediction-selected | color-emphasis)
				lineediting_setting "$kind" "$rest" >/dev/null || printf '%s: [%s] is not a value it takes\n' "$kind" "$rest"
				;;
			*) printf 'unknown line kind %s\n' "$kind" ;;
		esac
	done
	return 0
}

# The eza colour key of a list-color line: a friendly NAME (case-insensitive) or eza's own
# two-letter key (see `man eza_colors`) as it is. Fails for anything else.
# Usage: lineediting_list_color_key user
lineediting_list_color_key() {
	case $(printf '%s' "$1" | tr '[:upper:]' '[:lower:]') in
		directory) printf di ;;
		file) printf 'fi' ;;
		executable) printf ex ;;
		symlink) printf ln ;;
		symlink-path) printf lp ;;
		user) printf uu ;;
		user-other) printf un ;;
		group) printf gu ;;
		group-other) printf gn ;;
		date) printf da ;;
		size) printf sn ;;
		size-unit) printf sb ;;
		header) printf hd ;;
		punctuation) printf xx ;;
		[a-z][a-z]) printf '%s' "$(printf '%s' "$1" | tr '[:upper:]' '[:lower:]')" ;;
		*) return 1 ;;
	esac
}

# The SGR foreground code of COLOR (a colour lineediting_setting takes: one of the eight names or
# default, 0-255, #RRGGBB), for EZA_COLORS. Fails for anything else.
# Usage: lineediting_sgr '#FFA500'
lineediting_sgr() {
	local color
	color=$(lineediting_setting color-emphasis "$1") || return 1
	case $color in
		black) printf 30 ;;
		red) printf 31 ;;
		green) printf 32 ;;
		yellow) printf 33 ;;
		blue) printf 34 ;;
		magenta) printf 35 ;;
		cyan) printf 36 ;;
		white) printf 37 ;;
		default) printf 39 ;;
		\#*) printf '38;2;%d;%d;%d' "0x${color:1:2}" "0x${color:3:2}" "0x${color:5:2}" ;;
		*) printf '38;5;%s' "$color" ;;
	esac
}

# The EZA_COLORS value of the `KEY COLOR` lines on stdin (the list-color lines of theme.conf
# without their first word), `key=sgr` joined by colons; a later line wins per key, a bad line is
# skipped. Prints nothing without a valid line, so eza keeps its own colours.
# Usage: lineediting_eza_colors <lines
lineediting_eza_colors() {
	local name color key sgr i found
	local -a keys=() codes=()
	while read -r name color _; do
		key=$(lineediting_list_color_key "$name") || continue
		sgr=$(lineediting_sgr "$color") || continue
		found=''
		for i in "${!keys[@]}"; do
			[ "${keys[i]}" = "$key" ] && found=$i
		done
		if [ -n "$found" ]; then
			codes[found]=$sgr
		else
			keys+=("$key")
			codes+=("$sgr")
		fi
	done
	for i in "${!keys[@]}"; do
		[ "$i" -gt 0 ] && printf ':'
		printf '%s=%s' "${keys[i]}" "${codes[i]}"
	done
	return 0
}
