#!/usr/bin/env bats
# Get-RepositoryPath: the repository root and its named parts, from this executable or from any
# folder of another tree (--start-path).

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/Get-RepositoryPath
}

@test "prints the root and each named part, rejects an unknown part" {
	root=$(cd "$UNIX_DIR/.." && pwd -P)
	run "${BASH:-bash}" "$cmd"
	[ "$(cd "$output" && pwd -P)" = "$root" ]
	run "${BASH:-bash}" "$cmd" unix
	[ "$output" = "$root/Unix" ]
	run "${BASH:-bash}" "$cmd" modules
	[ "$output" = "$root/Unix/modules" ]
	run "${BASH:-bash}" "$cmd" docs
	[ "$output" = "$root/docs" ]
	run "${BASH:-bash}" "$cmd" nosuchpart
	[ "$status" -ne 0 ]
}

@test "--start-path walks up from any folder of another tree to its anchor file" {
	other=$(cd "$BATS_TEST_TMPDIR" && pwd -P)/clone
	mkdir -p "$other/Unix/lib" "$other/Unix/modules/Helper/bin" "$other/docs/unix"
	touch "$other/Unix/lib/foundation.sh"
	run "${BASH:-bash}" "$cmd" --start-path "$other/docs/unix"
	[ "$status" -eq 0 ]
	[ "$output" = "$other" ]
	run "${BASH:-bash}" "$cmd" modules -StartPath "$other/Unix/modules/Helper/bin"
	[ "$status" -eq 0 ]
	[ "$output" = "$other/Unix/modules" ]
	run "${BASH:-bash}" "$cmd" config --start-path "$other"
	[ "$output" = "$other/Unix/config" ]
}

@test "--start-path outside any tree, or a folder that does not exist, fails" {
	mkdir -p "$BATS_TEST_TMPDIR/plain"
	run "${BASH:-bash}" "$cmd" --start-path "$BATS_TEST_TMPDIR/plain"
	[ "$status" -ne 0 ]
	[[ $output == *"Could not locate the repository root"* ]]
	run "${BASH:-bash}" "$cmd" --start-path "$BATS_TEST_TMPDIR/nowhere"
	[ "$status" -ne 0 ]
}

@test "windows prints the Windows half where there is one and fails in a clone without it" {
	other=$(cd "$BATS_TEST_TMPDIR" && pwd -P)/clone
	mkdir -p "$other/Unix/lib"
	touch "$other/Unix/lib/foundation.sh"
	run "${BASH:-bash}" "$cmd" windows --start-path "$other"
	[ "$status" -ne 0 ]
	[[ $output == *"No Windows half in this clone"* ]]
	mkdir -p "$other/Windows"
	run "${BASH:-bash}" "$cmd" windows --start-path "$other"
	[ "$status" -eq 0 ]
	[ "$output" = "$other/Windows" ]
}
