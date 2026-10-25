#!/usr/bin/env bats
# bootstrap-first-run against a stand-in Homebrew (BOOTSTRAP_BREW, an absolute path that is never on
# PATH): --help and a stray argument provision nothing, Homebrew bash is installed only when it is
# missing, and the run hands over to Bootstrap --with-initial-setup under that bash; its lines go
# to the session log it inherits. The stand-in bash only logs, so the real Bootstrap never runs.

load ../../helpers

setup() {
	setup_foundation
	cmd=$UNIX_DIR/modules/Bootstrap/bin/bootstrap-first-run
	# The script names Bootstrap by its own folder, symbolic links resolved.
	bootstrap=$(cd "$UNIX_DIR/modules/Bootstrap/bin" && pwd -P)/Bootstrap
	prefix=$BATS_TEST_TMPDIR/homebrew
	mkdir -p "$prefix/bin"
	log=$BATS_TEST_TMPDIR/first-run.log
	# brew --prefix prints the stand-in prefix; brew install bash creates the stand-in bash.
	export BOOTSTRAP_BREW=$BATS_TEST_TMPDIR/stand-in-brew
	cat >"$BOOTSTRAP_BREW" <<SH
#!/bin/sh
echo "brew \$*" >>"$log"
case "\$1" in
	--prefix) printf '%s\n' "$prefix" ;;
	install) printf '#!/bin/sh\necho "bash \$*" >>"$log"\n' >"$prefix/bin/bash"; chmod +x "$prefix/bin/bash" ;;
esac
SH
	chmod +x "$BOOTSTRAP_BREW"
}

# A Homebrew bash that is already installed.
installed_bash() {
	printf '#!/bin/sh\necho "bash $*" >>"%s"\n' "$log" >"$prefix/bin/bash"
	chmod +x "$prefix/bin/bash"
}

@test "--help prints the header and provisions nothing" {
	run sh "$cmd" --help
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == "bootstrap-first-run - "* ]]
	[ ! -e "$log" ]
}

@test "a stray argument is an error and provisions nothing" {
	run sh "$cmd" --bogus
	[ "$status" -eq 1 ]
	[[ $output == *"unknown argument => --bogus"* ]]
	[ ! -e "$log" ]
}

@test "with Homebrew bash present, hands over to Bootstrap --with-initial-setup under it" {
	installed_bash
	run sh "$cmd"
	[ "$status" -eq 0 ]
	! grep -q 'brew install' "$log" || false
	grep -qxF "bash $bootstrap --with-initial-setup" "$log"
}

@test "without Homebrew bash, installs it first, then hands over" {
	run sh "$cmd"
	[ "$status" -eq 0 ]
	[ "$(grep -n 'brew install bash' "$log" | cut -d: -f1)" -lt "$(grep -n '^bash ' "$log" | cut -d: -f1)" ]
	grep -qxF "bash $bootstrap --with-initial-setup" "$log"
}

@test "a failed bash install stops before Bootstrap" {
	printf '#!/bin/sh\necho "brew $*" >>"%s"\ncase "$1" in --prefix) echo "%s" ;; *) exit 1 ;; esac\n' "$log" "$prefix" >"$BOOTSTRAP_BREW"
	run sh "$cmd"
	[ "$status" -eq 1 ]
	! grep -q '^bash ' "$log" || false
}

@test "its lines go to the session log bootstrap.sh opened, when it inherits one" {
	export FOUNDATION_LOG_FILE=$BATS_TEST_TMPDIR/session.log
	: >"$FOUNDATION_LOG_FILE"
	run sh "$cmd"
	[ "$status" -eq 0 ]
	grep -qE '^[0-9:]{8} \[STEP\] Installing Homebrew bash$' "$FOUNDATION_LOG_FILE"
	grep -qF "[STEP] Handing over to Bootstrap --with-initial-setup under $prefix/bin/bash" "$FOUNDATION_LOG_FILE"
	printf '#!/bin/sh\necho "brew $*" >>"%s"\ncase "$1" in --prefix) echo "%s" ;; *) exit 1 ;; esac\n' "$log" "$prefix" >"$BOOTSTRAP_BREW"
	rm "$prefix/bin/bash"
	run sh "$cmd"
	[ "$status" -eq 1 ]
	grep -q '\[ERROR\] brew install bash failed' "$FOUNDATION_LOG_FILE"
}
