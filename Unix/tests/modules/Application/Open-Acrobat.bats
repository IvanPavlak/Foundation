#!/usr/bin/env bats
# Open-Acrobat against the platform stand-ins and a throwaway pdfs.conf: every PDF of a group
# opens, in Acrobat when Spotlight finds it installed and in the default viewer otherwise, a group
# or recent PDF may be named by its menu number or entry, a missing file or unknown group fails
# without stopping the rest, a bare call opens Acrobat without
# a menu, and the --pdf '' menu (groups, then recently used PDFs) needs a terminal.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	export HOME=$BATS_TEST_TMPDIR/home
	pdfs=$BATS_TEST_TMPDIR/pdfs
	mkdir -p "$pdfs" "$HOME/Documents"
	touch "$pdfs/a.pdf" "$pdfs/b.pdf" "$HOME/Documents/c.pdf"
	cat >"$FOUNDATION_CONFIG_DIR/pdfs.conf" <<EOF2
[Papers]
$pdfs/a.pdf
$pdfs/b.pdf

[Home]
~/Documents/c.pdf

[Broken]
$pdfs/missing.pdf
$pdfs/a.pdf
EOF2
	cmd=$UNIX_DIR/modules/Application/bin/Open-Acrobat
}

# Configures Acrobat in apps.conf; with `installed` Spotlight also finds it.
acrobat() {
	echo 'app Acrobat com.adobe.Reader' >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	[ "${1:-}" != installed ] || echo com.adobe.Reader >>"$STUB_INSTALLED"
}

opened() {
	grep -c '^open ' "$STUB_LOG" || true
}

@test "a group opens every one of its PDFs" {
	run "${BASH:-bash}" "$cmd" Papers
	[ "$status" -eq 0 ]
	stub_called "^open $pdfs/a\.pdf$"
	stub_called "^open $pdfs/b\.pdf$"
	[ "$(opened)" -eq 2 ]
}

@test "groups match case-insensitively, split on commas, and ~ expands to HOME" {
	run "${BASH:-bash}" "$cmd" --pdf papers,HOME
	[ "$status" -eq 0 ]
	stub_called "^open $HOME/Documents/c\.pdf$"
	[ "$(opened)" -eq 3 ]
}

@test "a number names that entry of the menu, as -Pdf 2 does on Windows; a name asks Spotlight nothing" {
	run "${BASH:-bash}" "$cmd" 2
	[ "$status" -eq 0 ]
	stub_called "^open $HOME/Documents/c\.pdf$"
	[ "$(opened)" -eq 1 ]
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Papers
	[ "$status" -eq 0 ]
	! stub_called 'com\.adobe\.pdf' || false
}

@test "a recent PDF given by its menu entry opens, as on Windows" {
	cat >"$STUB_BIN/mdfind" <<SH
#!/bin/sh
case "\$*" in *com.adobe.pdf*) printf '%s\\n' "$pdfs/b.pdf" ;; esac
exit 0
SH
	cat >"$STUB_BIN/mdls" <<SH
#!/bin/sh
echo '2026-10-20 10:00:00 +0000'
SH
	chmod +x "$STUB_BIN/mdfind" "$STUB_BIN/mdls"
	run "${BASH:-bash}" "$cmd" "recent: b.pdf"
	[ "$status" -eq 0 ]
	stub_called "^open $pdfs/b\.pdf$"
	[ "$(opened)" -eq 1 ]
}

@test "an unknown group fails but the other groups still open" {
	run "${BASH:-bash}" "$cmd" NoSuchGroupAnywhere Papers
	[ "$status" -eq 1 ]
	[ "$(opened)" -eq 2 ]
}

@test "a missing PDF fails but the rest of its group still opens" {
	run "${BASH:-bash}" "$cmd" Broken
	[ "$status" -eq 1 ]
	! stub_called 'missing\.pdf' || false
	stub_called "^open $pdfs/a\.pdf$"
}

@test "the menu of --pdf '' opens the chosen group" {
	printf 'home\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" --pdf ''
	[ "$status" -eq 0 ]
	stub_called "^open $HOME/Documents/c\.pdf$"
	[ "$(opened)" -eq 1 ]
}

@test "an empty Enter without Acrobat installed fails and opens nothing" {
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" --pdf ''
	[ "$status" -eq 1 ]
	[ "$(opened)" -eq 0 ]
}

@test "the --pdf '' menu without a terminal opens nothing" {
	run "${BASH:-bash}" "$cmd" --pdf ''
	[ "$status" -eq 1 ]
	[ "$(opened)" -eq 0 ]
}

@test "fails without a pdfs.conf" {
	rm "$FOUNDATION_CONFIG_DIR/pdfs.conf"
	run "${BASH:-bash}" "$cmd" Papers
	[ "$status" -eq 1 ]
	[ "$(opened)" -eq 0 ]
}

@test "an installed Acrobat opens every PDF of the group" {
	acrobat installed
	run "${BASH:-bash}" "$cmd" Papers
	[ "$status" -eq 0 ]
	stub_called "^open -b com\.adobe\.Reader $pdfs/a\.pdf$"
	stub_called "^open -b com\.adobe\.Reader $pdfs/b\.pdf$"
	[ "$(opened)" -eq 2 ]
}

@test "an Acrobat Spotlight does not find leaves the PDFs to the default viewer" {
	acrobat
	run "${BASH:-bash}" "$cmd" Papers
	[ "$status" -eq 0 ]
	stub_called "^mdfind kMDItemCFBundleIdentifier == 'com\.adobe\.Reader'"
	stub_called "^open $pdfs/a\.pdf$"
	! stub_called '^open -b' || false
}

@test "an empty Enter with Acrobat installed opens Acrobat itself" {
	acrobat installed
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" --pdf ''
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.adobe\.Reader$'
	[ "$(opened)" -eq 1 ]
}

@test "a bare call opens Acrobat without a menu, warns when it already runs, fails without it" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"not installed"* ]]
	acrobat installed
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.adobe\.Reader$'
	: >"$STUB_LOG"
	echo com.adobe.Reader >>"$STUB_RUNNING"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Acrobat is already running!"* ]]
	[ "$(opened)" -eq 0 ]
}

@test "the --pdf '' menu lists recently used PDFs, newest first, and opens the chosen one" {
	# Spotlight stand-ins: two PDFs used lately, b.pdf the newest; a third that no longer exists.
	cat >"$STUB_BIN/mdfind" <<SH
#!/bin/sh
echo "mdfind \$*" >>"\$STUB_LOG"
case "\$*" in *com.adobe.pdf*) printf '%s\\n' "$pdfs/a.pdf" "$pdfs/b.pdf" "$pdfs/gone.pdf" ;; esac
exit 0
SH
	cat >"$STUB_BIN/mdls" <<SH
#!/bin/sh
case "\$*" in *a.pdf) echo '2026-10-01 10:00:00 +0000' ;; *b.pdf) echo '2026-10-20 10:00:00 +0000' ;; *) echo '(null)' ;; esac
SH
	chmod +x "$STUB_BIN/mdfind" "$STUB_BIN/mdls"
	printf '4\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" --pdf ''
	[ "$status" -eq 0 ]
	[[ $output == *"Recent: b.pdf"*"Recent: a.pdf"* ]]
	[[ $output != *gone.pdf* ]]
	stub_called "^open $pdfs/b\.pdf$"
	[ "$(opened)" -eq 1 ]
}
