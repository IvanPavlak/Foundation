#!/usr/bin/env bats
# List-AvailableColors: the 16 ANSI colours by name in their own colour, then all 256 swatches.

load ../../helpers

setup() {
	setup_foundation
	cmd=$UNIX_DIR/modules/Helper/bin/List-AvailableColors
}

@test "every ANSI colour is printed in its own SGR code, then the 256 swatches" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *$'\033[31mRed'* ]]
	[[ $output == *$'\033[97mBrightWhite'* ]]
	[ "$(grep -o $'\033\\[48;5;[0-9]*m' <<<"$output" | sort -u | wc -l | tr -d ' ')" -eq 256 ]
}
