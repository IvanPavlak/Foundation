# Shared setup for the bats suites: load the library against a throwaway config directory.
# The pure helpers are written to run under bash 3.2 too, so the suites run on a stock macOS.

setup_foundation() {
	# A clean slate: a suite started from a shell or app that inherited Foundation variables (an app
	# started by w) would otherwise log into that session and act as if a workspace open ran.
	local name
	for name in $(env | sed -n 's/^\(FOUNDATION_[A-Za-z0-9_]*\)=.*/\1/p'); do unset "$name"; done
	# A suite started from a WezTerm tab would otherwise act as if it ran in that real pane.
	unset WEZTERM_PANE
	export FOUNDATION_ALLOW_OLD_BASH=1
	# No session logs from the suites.
	export FOUNDATION_LOGGING=off
	# No prompt ever waits for the keyboard: a suite started from a terminal would otherwise block
	# on the first menu that reads /dev/tty (CI has no terminal and fails fast instead).
	export FOUNDATION_TTY="$BATS_TEST_TMPDIR/no-tty"
	export FOUNDATION_STATE_DIR="$BATS_TEST_TMPDIR/state"
	# The library suites sit in tests/, the per-command files in tests/modules/<Module>/: walk up
	# to the folder that holds lib/foundation.sh.
	UNIX_DIR=$BATS_TEST_DIRNAME
	while [ ! -f "$UNIX_DIR/lib/foundation.sh" ] && [ "$UNIX_DIR" != / ]; do UNIX_DIR=$(dirname "$UNIX_DIR"); done
	UNIX_DIR=$(cd "$UNIX_DIR" && pwd)
	# The readers see the generic fixture config, never the personal Unix/config: a test asserts
	# what the fixture says, so editing a workspace or layout cannot break a suite.
	FIXTURE_CONFIG=$UNIX_DIR/tests/fixtures/config
	export FOUNDATION_CONFIG_DIR=$FIXTURE_CONFIG
	# Nor the machine's AeroSpace configuration: no file means AeroSpace's zero gaps.
	export FOUNDATION_AEROSPACE_CONFIG=$BATS_TEST_TMPDIR/no-aerospace.toml
	# shellcheck source=../lib/foundation.sh
	. "$UNIX_DIR/lib/foundation.sh"
	foundation_load config apps layout browser project state
}

# A writable copy of the fixture config, for tests that add to it or run a config writer.
# Exports FOUNDATION_CONFIG_DIR.
copy_fixture_config() {
	export FOUNDATION_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
	rm -rf "$FOUNDATION_CONFIG_DIR"
	cp -R "$FIXTURE_CONFIG" "$FOUNDATION_CONFIG_DIR"
}

# An empty config directory, for tests that write every file they read. Emptied first: it is the
# folder copy_fixture_config fills, so a setup that copied the fixture would otherwise leak into it.
use_empty_config() {
	export FOUNDATION_CONFIG_DIR="$BATS_TEST_TMPDIR/config"
	rm -rf "$FOUNDATION_CONFIG_DIR"
	mkdir -p "$FOUNDATION_CONFIG_DIR/layouts"
}

# A one-off stand-in for an external tool, first on PATH, logging "NAME ARGS" to
# $BATS_TEST_TMPDIR/tool.log before running BODY. Usage: stub_tool NAME 'shell body'
stub_tool() {
	local dir=$BATS_TEST_TMPDIR/tools
	mkdir -p "$dir"
	printf '#!/bin/sh\necho "%s $*" >>"%s/tool.log"\n%s\n' "$1" "$BATS_TEST_TMPDIR" "${2:-exit 0}" >"$dir/$1"
	chmod +x "$dir/$1"
	case ":$PATH:" in *":$dir:"*) ;; *) export PATH="$dir:$PATH" ;; esac
}

# Takes a tool away for a "not installed" case: its stand-in is removed, PATH keeps only the
# stand-ins and the system folders, and FOUNDATION_NO_BREW_PATH stops foundation.sh from adding
# /opt/homebrew/bin and /usr/local/bin back, so the command cannot reach a real install either.
# The guard looks through foundation.sh as the command will: a tool still found fails the test
# before anything runs. Run the command with "${BASH:-bash}", which needs no PATH.
# Usage: hide_tool NAME
hide_tool() {
	rm -f "$BATS_TEST_TMPDIR/tools/$1"
	export PATH="$BATS_TEST_TMPDIR/tools:/usr/bin:/bin:/usr/sbin:/sbin"
	export FOUNDATION_NO_BREW_PATH=1
	local found
	found=$("${BASH:-bash}" -c '. "$1/lib/foundation.sh" || exit 1; command -v "$2" || true' _ "$UNIX_DIR" "$1" 2>/dev/null) || {
		echo "hide_tool guard: foundation.sh did not load" >&2
		return 1
	}
	[ -z "$found" ] || {
		echo "hide_tool guard: $1 still resolves to $found" >&2
		return 1
	}
}

# A stand-in for `defaults` that keeps the global preferences (-g) as files under
# $BATS_TEST_TMPDIR/prefs, one per key: `defaults read -g KEY` prints one (a key written with
# -array as defaults prints an array) and fails when it is missing; `defaults write -g KEY
# [-array | -string] VALUE...` replaces it. Usage: stub_defaults
stub_defaults() {
	local prefs=$BATS_TEST_TMPDIR/prefs
	mkdir -p "$prefs"
	stub_tool defaults 'prefs="'"$prefs"'"
case "$1" in
	read)
		[ -f "$prefs/$3" ] || exit 1
		if [ -f "$prefs/$3.array" ]; then printf "(\n"; sed "s/.*/    \"&\",/" "$prefs/$3"; printf ")\n"; else cat "$prefs/$3"; fi
		;;
	write)
		key=$3
		shift 3
		rm -f "$prefs/$key.array"
		case "$1" in
			-array) : >"$prefs/$key.array"; shift ;;
			-string) shift ;;
		esac
		printf "%s\n" "$@" >"$prefs/$key"
		;;
esac'
}
