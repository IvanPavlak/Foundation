# shellcheck shell=bash
# Loading spinner for long waits - the -Start/-Stop modes of Loading-Spinner. After one blank
# line it draws "FRAME LABEL" on stderr, redrawn in place, until spinner_stop leaves a green
# " ✓ LABEL" there (spinner_stop --discard erases it instead, for an error path). A frame is cut
# to the terminal width, which is read again for every frame: a line that wrapped could not be
# redrawn in place, and a tiling window manager narrows the terminal while a workspace opens.
# Silent when stderr is not a terminal, at the verbose level (debug lines would interleave) or at
# the quiet level (only warnings and errors print), so logs and captured output never contain it.
# The drawing loop ends by itself when the command that started it exits. Styles:
# Unix/config/spinners.conf. Needs lib/config.sh.

SPINNER_PID=''
SPINNER_LABEL=''

# Columns of the terminal on stderr (80 when it cannot be read).
spinner__columns() {
	local size
	size=$(stty size </dev/tty 2>/dev/null) || size=''
	size=${size#* }
	case $size in '' | *[!0-9]* | 0) size=${COLUMNS:-80} ;; esac
	printf '%s' "$size"
}

# A delay in milliseconds as the seconds `sleep` takes: 80 -> 0.080, 1500 -> 1.500.
spinner__seconds() { # MS
	printf '%d.%03d' "$((10#$1 / 1000))" "$((10#$1 % 1000))"
}

# Frames and delay of STYLE (default: the file's `default`), as "DELAY FRAME...". The last line
# of a name wins, so an overlay line replaces the base style of the same name.
spinner_style() { # [STYLE]
	local file style=${1:-} line
	file=$(conf_path spinners.conf 2>/dev/null) || {
		echo '120 - \ | /'
		return 0
	}
	[ -n "$style" ] || style=$(conf_value "$file" default 2>/dev/null) || style=''
	line=$(conf_lines "$file" | awk -v s="$(foundation_lower "$style")" 'tolower($1) == s && $2 ~ /^[0-9]+$/ { $1 = ""; sub(/^ /, ""); found = $0 } END { if (found != "") print found }')
	printf '%s\n' "${line:-120 - \\ | /}"
}

spinner_start() { # LABEL [STYLE]
	spinner_stop --discard
	[ -t 2 ] || return 0
	case ${FOUNDATION_LOG_LEVEL:-normal} in verbose | debug | quiet) return 0 ;; esac
	local label=$1 style parent=$$
	read -r -a style <<<"$(spinner_style "${2:-}")"
	SPINNER_LABEL=$label
	printf '\n' >&2
	(
		delay=${style[0]}
		frames=("${style[@]:1}")
		i=0
		sleep_for=$(spinner__seconds "$delay")
		printf '\033[?25l' >&2
		trap 'printf "\r\033[2K\033[?25h" >&2; exit 0' TERM INT
		while kill -0 "$parent" 2>/dev/null; do
			text="${frames[i % ${#frames[@]}]} $label"
			width=$(($(spinner__columns) - 1))
			[ "${#text}" -le "$width" ] || text=${text:0:width}
			if log_use_color 2; then
				printf '\r\033[2K\033[36m%s\033[0m' "$text" >&2
			else
				printf '\r\033[2K%s' "$text" >&2
			fi
			i=$((i + 1))
			sleep "$sleep_for"
		done
		printf '\r\033[2K\033[?25h' >&2
	) &
	SPINNER_PID=$!
}

# Stops the spinner and leaves " ✓ LABEL" in green on its line; --discard erases the line.
spinner_stop() { # [--discard]
	[ -n "${SPINNER_PID:-}" ] || return 0
	# A killed process reports its end as a failure, which must not abort a caller under set -e.
	kill "$SPINNER_PID" 2>/dev/null || true
	wait "$SPINNER_PID" 2>/dev/null || true
	SPINNER_PID=''
	if [ "${1:-}" != "--discard" ] && [ -n "$SPINNER_LABEL" ]; then
		local text=" ✓ $SPINNER_LABEL" width
		width=$(($(spinner__columns) - 1))
		[ "${#text}" -le "$width" ] || text=${text:0:width}
		if log_use_color 2; then
			printf '\r\033[2K\033[32m%s\033[0m\n' "$text" >&2
		else
			printf '\r\033[2K%s\n' "$text" >&2
		fi
	fi
	SPINNER_LABEL=''
}
