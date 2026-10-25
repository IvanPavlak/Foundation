#!/usr/bin/env bats
# Export-VSCodeProfile against a throwaway home and a stub `code`: copies real profile files into
# the repository, leaves links alone, and merges extensions.txt keeping comments and pins.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	export HOME=$BATS_TEST_TMPDIR/home
	repo=$BATS_TEST_TMPDIR/repo
	user="$HOME/Library/Application Support/Code/User"
	[ "$(uname -s)" = Darwin ] || user="$HOME/.config/Code/User"
	mkdir -p "$repo/Main" "$user"
	printf 'root %s\nprofile Main Default\nprofile Side\n' "$repo" >"$FOUNDATION_CONFIG_DIR/vscode-profiles.conf"
	stub_tool code 'case "$*" in *--list-extensions*) printf "a.keep@1.0.0\nb.new@2.0.0\n" ;; esac'
	cmd=$UNIX_DIR/modules/Application/bin/Export-VSCodeProfile
}

@test "copies real files, skips links and empty snippets, merges extensions.txt" {
	printf '{"live":1}\n' >"$user/keybindings.json"
	printf '{}\n' >"$repo/Main/settings.json"
	ln -s "$repo/Main/settings.json" "$user/settings.json"
	mkdir -p "$user/snippets"
	printf '# why\nz.gone\na.keep@1.0.0  # pinned\nA.KEEP\n' >"$repo/Main/extensions.txt"
	run "${BASH:-bash}" "$cmd" main
	[ "$status" -eq 0 ]
	grep -q live "$repo/Main/keybindings.json"
	[ ! -e "$repo/Main/snippets" ]
	[ "$(cat "$repo/Main/extensions.txt")" = "# why
a.keep@1.0.0  # pinned
b.new" ]
}

@test "keybindings land in keybindings.macos.json when the folder carries one" {
	[ "$(uname -s)" = Darwin ] || skip "macOS only"
	printf '{"live":1}\n' >"$user/keybindings.json"
	printf '[]\n' >"$repo/Main/keybindings.macos.json"
	run "${BASH:-bash}" "$cmd" Main
	[ "$status" -eq 0 ]
	grep -q live "$repo/Main/keybindings.macos.json"
	[ ! -e "$repo/Main/keybindings.json" ]
}

@test "fails for a name outside the catalogue or a profile VS Code does not have" {
	run "${BASH:-bash}" "$cmd" Nope
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" Side
	[ "$status" -eq 1 ]
	[ ! -d "$repo/Side" ]
}

@test "the Windows -Name NAME works like a bare NAME" {
	printf '{"live":1}\n' >"$user/keybindings.json"
	run "${BASH:-bash}" "$cmd" -Name Main
	[ "$status" -eq 0 ]
	grep -q live "$repo/Main/keybindings"*.json
}

@test "a failing extension list leaves extensions.txt byte-identical and fails" {
	stub_tool code 'case "$*" in *--list-extensions*) exit 1 ;; esac'
	printf '# why\na.keep\n' >"$repo/Main/extensions.txt"
	cp "$repo/Main/extensions.txt" "$BATS_TEST_TMPDIR/before.txt"
	run "${BASH:-bash}" "$cmd" Main
	[ "$status" -eq 1 ]
	cmp -s "$repo/Main/extensions.txt" "$BATS_TEST_TMPDIR/before.txt"
}

@test "a profile file linked outside the repository is reported and stays a link" {
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
	printf '{}\n' >"$BATS_TEST_TMPDIR/elsewhere/settings.json"
	ln -s "$BATS_TEST_TMPDIR/elsewhere/settings.json" "$user/settings.json"
	run "${BASH:-bash}" "$cmd" Main
	[ "$status" -eq 0 ]
	[[ $output == *"not to the repository"* ]]
	[ "$(readlink "$user/settings.json")" = "$BATS_TEST_TMPDIR/elsewhere/settings.json" ]
	[ ! -e "$repo/Main/settings.json" ]
}

@test "without an extensions.txt a sorted list is written, with no blank first line" {
	stub_tool code 'case "$*" in *--list-extensions*) printf "z.last@1.0.0\nA.first@2.0.0\nm.mid@3.0.0\n" ;; esac'
	run "${BASH:-bash}" "$cmd" Main
	[ "$status" -eq 0 ]
	[ "$(cat "$repo/Main/extensions.txt")" = "A.first
m.mid
z.last" ]
}
