#!/usr/bin/env bats
# Add-SymbolicLink against a throwaway chezmoi source tree (FOUNDATION_CHEZMOI_SOURCE): one-line
# templates under chezmoi's naming, an existing private_ folder reused, ~/ dropped, and a missing
# target, a path outside the home folder and an existing template refused.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_CHEZMOI_SOURCE=$BATS_TEST_TMPDIR/home-source
	mkdir -p "$FOUNDATION_CHEZMOI_SOURCE/private_Library"
	cmd=$UNIX_DIR/modules/Configuration/bin/Add-SymbolicLink
}

@test "writes a one-line template under chezmoi's naming" {
	run "${BASH:-bash}" "$cmd" .config/btop/extra.conf Btop/themes
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_CHEZMOI_SOURCE/dot_config/btop/symlink_extra.conf.tmpl")" = "{{ .chezmoi.workingTree }}/Btop/themes" ]
	run "${BASH:-bash}" "$cmd" "~/.toolrc" Git/.gitconfig
	[ "$status" -eq 0 ]
	[ -f "$FOUNDATION_CHEZMOI_SOURCE/symlink_dot_toolrc.tmpl" ]
}

@test "an existing private_ folder is reused" {
	run "${BASH:-bash}" "$cmd" "Library/Application Support/App/settings.json" Git/.gitconfig
	[ "$status" -eq 0 ]
	[ -f "$FOUNDATION_CHEZMOI_SOURCE/private_Library/Application Support/App/symlink_settings.json.tmpl" ]
	[ ! -e "$FOUNDATION_CHEZMOI_SOURCE/Library" ]
}

@test "a missing target, a path outside the home folder and an existing template are refused" {
	run "${BASH:-bash}" "$cmd" .config/x Missing/nowhere
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" ../outside Btop/themes
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" /etc/hosts Btop/themes
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" .config/btop/extra.conf Btop/themes
	[ "$status" -eq 0 ]
	run "${BASH:-bash}" "$cmd" .config/btop/extra.conf Btop/themes
	[ "$status" -ne 0 ]
	[[ $output == *"already has a link template"* ]]
	[ "$(find "$FOUNDATION_CHEZMOI_SOURCE" -type f | wc -l | tr -d ' ')" -eq 1 ]
}

@test "the Windows named form binds by flag in any order; an unknown flag writes nothing" {
	run "${BASH:-bash}" "$cmd" -Name Btop -Target Btop/themes -Path .config/btop/named.conf
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_CHEZMOI_SOURCE/dot_config/btop/symlink_named.conf.tmpl")" = "{{ .chezmoi.workingTree }}/Btop/themes" ]
	run "${BASH:-bash}" "$cmd" .config/btop/other.conf Btop/themes --bogus
	[ "$status" -eq 1 ]
	[ ! -e "$FOUNDATION_CHEZMOI_SOURCE/dot_config/btop/symlink_other.conf.tmpl" ]
}
