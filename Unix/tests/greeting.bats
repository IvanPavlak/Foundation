#!/usr/bin/env bats
# Invoke-Onefetch against a stub onefetch: silent outside a repository, measured height, and the
# Format-OnefetchPanel restyling (true-color palette, separator, re-padded continuation lines, the
# rows it leaves alone, the colour indices it skips).

load helpers

setup() {
	setup_foundation
	bin=$BATS_TEST_TMPDIR/bin
	mkdir -p "$bin" "$BATS_TEST_TMPDIR/repo/.git" "$BATS_TEST_TMPDIR/plain"
	# Two field lines and one continuation line, colored the way onefetch --text-colors 12 9 does.
	cat >"$bin/onefetch" <<'STUB'
#!/bin/sh
e=$(printf '\033')
printf '%s\n' "LOGO   ${e}[94mProject${e}[0m${e}[91m:${e}[0m ${e}[97mDemo${e}[0m"
printf '%s\n' "LOGO   ${e}[94mAuthors${e}[0m${e}[91m:${e}[0m ${e}[97m90% Me${e}[0m"
printf '%s\n' "LOGO           ${e}[97m10% You${e}[0m"
STUB
	chmod +x "$bin/onefetch"
	export PATH="$bin:$PATH"
	cmd=$UNIX_DIR/modules/System/bin/Invoke-Onefetch
}

@test "outside a git repository: nothing drawn, height 0" {
	cd "$BATS_TEST_TMPDIR/plain"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	run "${BASH:-bash}" "$cmd" --measure
	[ "$output" = 0 ]
}

@test "inside a repository: height is the line count" {
	cd "$BATS_TEST_TMPDIR/repo"
	run "${BASH:-bash}" "$cmd" --measure
	[ "$output" = 3 ]
}

@test "restyle: palette, separator, and the continuation line padded by the extra width" {
	cd "$BATS_TEST_TMPDIR/repo"
	run "${BASH:-bash}" "$cmd"
	e=$'\033'
	# The colon, its reset and the following space become the separator, which brings its own spacing.
	[[ ${lines[0]} == *"${e}[38;2;30;144;255mProject${e}[0m${e}[38;2;255;0;0m -> ${e}[0m${e}[97mDemo"* ]]
	[[ ${lines[0]} != *":"* ]]
	# " -> " is two columns wider than ": ", so the continuation value moves right by two.
	plain=$(printf '%s\n' "${lines[2]}" | sed 's/\x1b\[[0-9;]*m//g')
	[ "$plain" = "LOGO             10% You" ]
}

# The guard rows of the restyle: a line above the first field, a blank line, a line with a
# background colour and a line shorter than the value column keep their padding as they are;
# only the continuation line moves. One line comes out per line in.
@test "restyle guard rows: only continuation lines are padded, and the line count is kept" {
	cat >"$bin/onefetch" <<'STUB'
#!/bin/sh
e=$(printf '\033')
printf '%s\n' "HEADER LINE"
printf '%s\n' "LOGO   ${e}[94mProject${e}[0m${e}[91m:${e}[0m ${e}[97mDemo${e}[0m"
printf '%s\n' ""
printf '%s\n' "LOGO           ${e}[41m   ${e}[0m"
printf '%s\n' "LOG"
printf '%s\n' "LOGO           ${e}[97m10% You${e}[0m"
STUB
	cd "$BATS_TEST_TMPDIR/repo"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "${#lines[@]}" -eq 5 ] # bats drops the blank line from lines
	[ "$(printf '%s\n' "$output" | wc -l | tr -d ' ')" -eq 6 ]
	e=$'\033'
	[ "${lines[0]}" = "HEADER LINE" ]
	[ "${lines[2]}" = "LOGO           ${e}[41m   ${e}[0m" ]
	[ "${lines[3]}" = "LOG" ]
	plain=$(printf '%s\n' "${lines[4]}" | sed 's/\x1b\[[0-9;]*m//g')
	[ "$plain" = "LOGO             10% You" ]
}

@test "an onefetch-color index outside 0-15, or one without a replacement, is skipped" {
	copy_fixture_config
	printf '%s\n' 'onefetch-color 16 38;2;1;1;1' 'onefetch-color 15' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	cat >"$bin/onefetch" <<'STUB'
#!/bin/sh
e=$(printf '\033')
printf '%s\n' "LOGO   ${e}[94mProject${e}[0m${e}[91m:${e}[0m ${e}[98mX${e}[0m ${e}[97mY${e}[0m"
STUB
	cd "$BATS_TEST_TMPDIR/repo"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	e=$'\033'
	[[ ${lines[0]} == *"${e}[98mX"* ]]
	[[ ${lines[0]} == *"${e}[97mY"* ]]
	[[ ${lines[0]} == *"${e}[38;2;30;144;255mProject"* ]]
}
