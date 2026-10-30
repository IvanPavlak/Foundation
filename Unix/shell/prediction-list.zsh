# The prediction list: PSReadLine's ListView (PredictionSource History, PredictionViewStyle ListView)
# for zsh. zsh only: shellrc.sh sources this file in its LineEditing stage, after the key bindings,
# when shell.conf has `prediction-source history` and `prediction-view list`.
#
# From the first character typed, the history lines that contain the typed text (case-insensitive,
# not fuzzy, newest first, each line once) are drawn below the line: a `<n/N>` header, then at
# most 10 rows `> line` with `[History]` on the right, the typed text highlighted. While the list
# shows, Up and Down move in it and the line follows the selected row (Down enters at the first
# row, Up at the last, and past either end the line is the typed text again); otherwise they run
# whatever they were bound to (the prefix search of `key UpArrow HistorySearchBackward`). Enter
# runs the line, Right keeps it, Tab completes and closes the list, and a line recalled by a
# history key opens none.
#
# Synchronous: one pattern match over the in-memory history each time the typed text changes. No
# worker, no per-character fuzzy pattern, so a long line cannot stall it.

autoload -Uz add-zle-hook-widget

typeset -gi _foundation_prediction_rows=10
# The colours, from the color-* lines of shell.conf; without one PSReadLine's defaults:
# ListPredictionColor yellow, ListPredictionSelectedColor 238 (a background), EmphasisColor bright cyan.
typeset -g _foundation_prediction_color_row=${_foundation_prediction_color_row:-yellow}
typeset -g _foundation_prediction_color_selected=${_foundation_prediction_color_selected:-238}
typeset -g _foundation_prediction_color_emphasis=${_foundation_prediction_color_emphasis:-14}
# What starts each row, from prediction-list-marker; PSReadLine's `>` without one.
typeset -g _foundation_prediction_marker=${_foundation_prediction_marker:->}
typeset -ga _foundation_prediction_matches=()
typeset -g _foundation_prediction_typed='' _foundation_prediction_last=''
typeset -gi _foundation_prediction_selected=0

# The history lines containing TYPED, newest first, each once, into _foundation_prediction_matches;
# none for a blank TYPED. Usage: _foundation_prediction_find TYPED
_foundation_prediction_find() {
	emulate -L zsh
	setopt extendedglob
	_foundation_prediction_matches=()
	[[ -n ${1//[[:space:]]/} ]] || return 0
	_foundation_prediction_matches=("${(@u)${(@M)${(@v)history}:#(#i)*${(b)1}*}}")
}

# Draws the list into POSTDISPLAY and its colours into region_highlight (the memo keeps them apart
# from the syntax highlighter's): the rows, the selected row's background and the typed text in
# the three colours above. An empty list draws nothing.
_foundation_prediction_render() {
	emulate -L zsh
	region_highlight=("${(@)region_highlight:#*memo=foundation-prediction*}")
	POSTDISPLAY=''
	local -i count=${#_foundation_prediction_matches} selected=$_foundation_prediction_selected
	((count)) || return 0
	local -i width=$((${COLUMNS:-80} - 1)) first=1 last i base at found from room
	((width < 20)) && width=20
	((selected > _foundation_prediction_rows)) && first=$((selected - _foundation_prediction_rows + 1))
	last=$((first + _foundation_prediction_rows - 1))
	((last > count)) && last=count
	local left="<${${selected:#0}:--}/$count>" right="<History($count)>" tag='[History]' line lower typed=${(L)_foundation_prediction_typed}
	local prefix="$_foundation_prediction_marker "
	local text=$'\n'"${(r:width - ${#right}:)left}$right"
	local -a highlights=()
	base=$((${#PREDISPLAY} + ${#BUFFER}))
	for ((i = first; i <= last; i++)); do
		line=${_foundation_prediction_matches[i]//$'\n'/ }
		room=$((width - ${#prefix} - ${#tag} - 1))
		((${#line} > room)) && line="${line[1,room - 1]}…"
		at=$((base + ${#text} + 1))
		text+=$'\n'"$prefix${(r:room + 1:)line}$tag"
		highlights+=("P$at $((at + width)) fg=$_foundation_prediction_color_row memo=foundation-prediction")
		((i == selected)) && highlights+=("P$at $((at + width)) bg=$_foundation_prediction_color_selected memo=foundation-prediction")
		# Every place the typed text occurs in the row.
		lower=${(L)line}
		from=1
		while ((from <= ${#lower})); do
			found=${lower[from,-1][(ie)$typed]}
			((found > ${#lower} - from + 1)) && break
			found=$((from + found - 1))
			highlights+=("P$((at + ${#prefix} + found - 1)) $((at + ${#prefix} + found - 1 + ${#typed})) fg=$_foundation_prediction_color_emphasis memo=foundation-prediction")
			from=$((found + ${#typed}))
		done
	done
	POSTDISPLAY=$text
	region_highlight+=("${highlights[@]}")
}

_foundation_prediction_clear() {
	_foundation_prediction_matches=()
	_foundation_prediction_selected=0
	_foundation_prediction_render
}

# zle-line-pre-redraw: a new list whenever the typed text changed; none after a completion or a
# history widget, whose result is not typed text.
_foundation_prediction_pre_redraw() {
	[[ $BUFFER == "$_foundation_prediction_last" ]] && return 0
	_foundation_prediction_last=$BUFFER
	case $LASTWIDGET in
		*complete* | *history* | *search* | foundation-prediction-*)
			_foundation_prediction_clear
			return 0
			;;
	esac
	_foundation_prediction_typed=$BUFFER
	_foundation_prediction_selected=0
	_foundation_prediction_find "$BUFFER"
	_foundation_prediction_render
}

_foundation_prediction_line_init() {
	_foundation_prediction_last=''
	_foundation_prediction_typed=''
	_foundation_prediction_matches=()
	_foundation_prediction_selected=0
}

# zle-line-finish: the list goes before the line is run, so it is not left on the screen.
_foundation_prediction_line_finish() {
	_foundation_prediction_clear
	zle -R
}

# Up (-1) or Down (1) in the list while it shows, else WIDGET, the key's own binding.
# Usage: _foundation_prediction_move -1|1 WIDGET
_foundation_prediction_move() {
	local -i count=${#_foundation_prediction_matches} selected=$_foundation_prediction_selected
	if ((!count)); then
		zle "$2"
		return
	fi
	if (($1 < 0)); then
		selected=$((selected == 0 ? count : selected - 1))
	else
		selected=$((selected == count ? 0 : selected + 1))
	fi
	_foundation_prediction_selected=$selected
	if ((selected)); then
		BUFFER=${_foundation_prediction_matches[selected]}
	else
		BUFFER=$_foundation_prediction_typed
	fi
	CURSOR=${#BUFFER}
	_foundation_prediction_last=$BUFFER
	_foundation_prediction_render
}

# The widgets Up and Down had before this file, kept once: a second source must not wrap the
# wrappers. A key with no widget falls back to zsh's own.
if [[ -z ${_foundation_prediction_up:-} ]]; then
	typeset -g _foundation_prediction_up=${${(z)"$(bindkey -- '^[[A')"}[2]}
	typeset -g _foundation_prediction_down=${${(z)"$(bindkey -- '^[[B')"}[2]}
	[[ $_foundation_prediction_up == (|undefined-key) ]] && _foundation_prediction_up=up-line-or-history
	[[ $_foundation_prediction_down == (|undefined-key) ]] && _foundation_prediction_down=down-line-or-history
fi
foundation-prediction-up() { _foundation_prediction_move -1 "$_foundation_prediction_up"; }
foundation-prediction-down() { _foundation_prediction_move 1 "$_foundation_prediction_down"; }
zle -N foundation-prediction-up
zle -N foundation-prediction-down
bindkey '^[[A' foundation-prediction-up
bindkey '^[OA' foundation-prediction-up
bindkey '^[[B' foundation-prediction-down
bindkey '^[OB' foundation-prediction-down

add-zle-hook-widget line-pre-redraw _foundation_prediction_pre_redraw
add-zle-hook-widget line-init _foundation_prediction_line_init
add-zle-hook-widget line-finish _foundation_prediction_line_finish
