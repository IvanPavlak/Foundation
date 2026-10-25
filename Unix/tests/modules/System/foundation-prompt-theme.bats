#!/usr/bin/env bats
# foundation-prompt-theme: the prompt-theme line of theme.conf for this machine type, {MachineType}
# replaced and variables expanded, the shipped WinuX_Test theme without a line, and no session log.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	cmd=$UNIX_DIR/modules/System/bin/foundation-prompt-theme
	export FOUNDATION_MACHINE_TYPE=Work
}

@test "without theme.conf or a prompt-theme line it prints the shipped WinuX_Test theme" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$output" = "$DOTFILES_ROOT/Oh-My-Posh/WinuX_Test.omp.json" ]
	printf 'theme Work Dark\n' >"$FOUNDATION_CONFIG_DIR/theme.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$output" = "$DOTFILES_ROOT/Oh-My-Posh/WinuX_Test.omp.json" ]
}

@test "{MachineType} becomes this machine type and \$VARIABLES and ~ expand" {
	printf '%s\n' 'prompt-theme $DOTFILES_ROOT/Themes/Mine_{MachineType}.omp.json' >"$FOUNDATION_CONFIG_DIR/theme.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$output" = "$DOTFILES_ROOT/Themes/Mine_Work.omp.json" ]
	printf '%s\n' 'prompt-theme ~/themes/{MachineType}.json' >"$FOUNDATION_CONFIG_DIR/theme.local.conf"
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	[ "$output" = "$HOME/themes/Laptop.json" ]
}

@test "an @TYPE line picks the theme on that machine type only" {
	printf '%s\n' 'prompt-theme /themes/all.json' '@Laptop prompt-theme /themes/laptop.json' >"$FOUNDATION_CONFIG_DIR/theme.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$output" = /themes/all.json ]
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	[ "$output" = /themes/laptop.json ]
}

@test "every new shell runs it, so it keeps no session log even with logging on" {
	unset FOUNDATION_LOGGING
	export FOUNDATION_LOG_DIR="$BATS_TEST_TMPDIR/logs"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -d "$FOUNDATION_LOG_DIR" ] || [ -z "$(ls -A "$FOUNDATION_LOG_DIR")" ]
}
