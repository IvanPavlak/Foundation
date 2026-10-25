#!/usr/bin/env bats
# Find-Item: finds a file level by level - the start path's subtree, then each parent's - and
# prints only the path.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/Find-Item
}

# Find-Item prints resolved paths (/var is /private/var on macOS), so expectations use pwd -P.
base() { cd "$BATS_TEST_TMPDIR" && pwd -P; }

@test "finds a file below, then above the start path; nothing found fails" {
	mkdir -p "$BATS_TEST_TMPDIR/tree/a/b" "$BATS_TEST_TMPDIR/tree/c"
	touch "$BATS_TEST_TMPDIR/tree/a/b/Deep.cs" "$BATS_TEST_TMPDIR/tree/Top.sln"
	run "${BASH:-bash}" "$cmd" 'deep.cs' --start-path "$BATS_TEST_TMPDIR/tree" --select-first
	[ "$status" -eq 0 ]
	[ "$output" = "$(base)/tree/a/b/Deep.cs" ]
	run "${BASH:-bash}" "$cmd" '*.sln' --start-path "$BATS_TEST_TMPDIR/tree/c" --select-first
	[ "$status" -eq 0 ]
	[ "$output" = "$(base)/tree/Top.sln" ]
	run "${BASH:-bash}" "$cmd" 'nothing-like-this.txt' --start-path "$BATS_TEST_TMPDIR/tree/c" --select-first
	[ "$status" -ne 0 ]
}

@test "--directory finds folders" {
	mkdir -p "$BATS_TEST_TMPDIR/tree/src/Web"
	run "${BASH:-bash}" "$cmd" Web --directory --start-path "$BATS_TEST_TMPDIR/tree" --select-first
	[ "$output" = "$(base)/tree/src/Web" ]
}

@test "a parent's whole subtree is searched, so a sibling project folder is found" {
	mkdir -p "$BATS_TEST_TMPDIR/sol/Api" "$BATS_TEST_TMPDIR/sol/Domain"
	touch "$BATS_TEST_TMPDIR/sol/Domain/Domain.csproj"
	run "${BASH:-bash}" "$cmd" '*.csproj' --start-path "$BATS_TEST_TMPDIR/sol/Api"
	[ "$status" -eq 0 ]
	[ "$output" = "$(base)/sol/Domain/Domain.csproj" ]
}

@test "the nearest level with a match wins without a menu" {
	mkdir -p "$BATS_TEST_TMPDIR/sol/Api/sub"
	touch "$BATS_TEST_TMPDIR/sol/Api/sub/Api.csproj" "$BATS_TEST_TMPDIR/sol/Other.csproj"
	# No --select-first: a match on two levels would otherwise need the menu.
	run "${BASH:-bash}" "$cmd" '*.csproj' --start-path "$BATS_TEST_TMPDIR/sol/Api" </dev/null
	[ "$status" -eq 0 ]
	[ "$output" = "$(base)/sol/Api/sub/Api.csproj" ]
}

@test "--name-filter matches a file's folder or a directory's own name; both finds either" {
	mkdir -p "$BATS_TEST_TMPDIR/sol/Web" "$BATS_TEST_TMPDIR/sol/Domain/Database"
	touch "$BATS_TEST_TMPDIR/sol/Web/Web.csproj" "$BATS_TEST_TMPDIR/sol/Domain/Domain.csproj"
	run "${BASH:-bash}" "$cmd" '*.csproj' --name-filter domain --start-path "$BATS_TEST_TMPDIR/sol"
	[ "$status" -eq 0 ]
	[ "$output" = "$(base)/sol/Domain/Domain.csproj" ]
	run "${BASH:-bash}" "$cmd" '*' --search-target Directory --name-filter base --start-path "$BATS_TEST_TMPDIR/sol"
	[ "$output" = "$(base)/sol/Domain/Database" ]
	run "${BASH:-bash}" "$cmd" 'Web*' --search-target both --start-path "$BATS_TEST_TMPDIR/sol" --select-first
	[ "$output" = "$(base)/sol/Web" ]
	run "${BASH:-bash}" "$cmd" x --search-target neither
	[ "$status" -ne 0 ]
}

@test "--max-downward-depth counts like Get-ChildItem -Depth: 0 still sees the children" {
	mkdir -p "$BATS_TEST_TMPDIR/d/a/b"
	touch "$BATS_TEST_TMPDIR/d/One.txt" "$BATS_TEST_TMPDIR/d/a/b/Two.txt"
	run "${BASH:-bash}" "$cmd" 'one.txt' --start-path "$BATS_TEST_TMPDIR/d" --max-downward-depth 0 --max-upward-depth 1
	[ "$output" = "$(base)/d/One.txt" ]
	run "${BASH:-bash}" "$cmd" 'two.txt' --start-path "$BATS_TEST_TMPDIR/d" --max-downward-depth 0 --max-upward-depth 1
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" 'two.txt' --start-path "$BATS_TEST_TMPDIR/d" --max-downward-depth 2 --max-upward-depth 1
	[ "$output" = "$(base)/d/a/b/Two.txt" ]
}
