#!/usr/bin/env bats
# Show-TerminalGreeting and Reload-Profile, the shell functions of Unix/modules/System/functions.sh,
# sourced into bash and zsh with stand-in Invoke-Clear, Invoke-Fastfetch and Invoke-Onefetch first
# on PATH: onefetch is measured first and its height passed as --extra-rows; --no-clear,
# --no-fastfetch and --no-onefetch skip their step (and the measurement where it has no use); the
# Invoke-Fastfetch flags reach it one word each, in any spelling PowerShell accepts; an unknown word
# is warned about and the greeting still draws. Reload-Profile execs a login shell that lists the
# reloaded modules.

load ../../helpers

setup() {
	setup_foundation
	stub_tool Invoke-Clear
	stub_tool Invoke-Fastfetch
	stub_tool Invoke-Onefetch 'case " $* " in *" --measure "*) echo 4 ;; *) echo PANEL ;; esac'
	functions=$UNIX_DIR/modules/System/functions.sh
}

# Sources the functions into SHELL (zsh without its rc files) and calls Show-TerminalGreeting with
# ARGS. Usage: greet SHELL ARGS...
greet() {
	local shell=$1 flags=()
	shift
	case ${shell##*/} in zsh) flags=(-f) ;; esac
	"$shell" "${flags[@]}" -c '. "$1"; . "$2"; shift 2; Show-TerminalGreeting "$@"' _ "$UNIX_DIR/lib/log.sh" "$functions" "$@"
}

# The stand-in calls, in order, on one line each.
calls() { cat "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null | sed 's/ *$//'; }

@test "onefetch is measured first, its height goes to Invoke-Fastfetch, then the panel is drawn" {
	run greet "${BASH:-bash}"
	[ "$status" -eq 0 ]
	[ "$(calls)" = "$(printf '%s\n' 'Invoke-Onefetch --measure' Invoke-Clear 'Invoke-Fastfetch --extra-rows 4' Invoke-Onefetch)" ]
	[[ $output == *PANEL* ]]
}

@test "--no-onefetch skips measuring and drawing; --no-resize skips measuring and reaches Invoke-Fastfetch" {
	run greet "${BASH:-bash}" --no-onefetch
	[ "$(calls)" = "$(printf '%s\n' Invoke-Clear 'Invoke-Fastfetch --extra-rows 0')" ]
	[[ $output != *PANEL* ]]
	: >"$BATS_TEST_TMPDIR/tool.log"
	run greet "${BASH:-bash}" --no-resize --settle
	[ "$(calls)" = "$(printf '%s\n' Invoke-Clear 'Invoke-Fastfetch --extra-rows 0 --no-resize --settle' Invoke-Onefetch)" ]
}

@test "--no-clear and --no-fastfetch skip their step; without fastfetch nothing is measured" {
	run greet "${BASH:-bash}" --no-clear
	[ "$(calls)" = "$(printf '%s\n' 'Invoke-Onefetch --measure' 'Invoke-Fastfetch --extra-rows 4' Invoke-Onefetch)" ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	run greet "${BASH:-bash}" --no-fastfetch
	[ "$(calls)" = "$(printf '%s\n' Invoke-Clear Invoke-Onefetch)" ]
	[[ $output == *PANEL* ]]
}

@test "Windows-style flags work in any case, and the number flags reach Invoke-Fastfetch with their value" {
	run greet "${BASH:-bash}" -NoResize -MaxShrinkSteps 0 -noclear --Prompt-Reserve 3 -ReflowTimeoutMilliseconds 50
	[ "$status" -eq 0 ]
	[ "$(calls)" = "$(printf '%s\n' 'Invoke-Fastfetch --extra-rows 0 --no-resize --max-shrink-steps 0 --prompt-reserve 3 --reflow-timeout-milliseconds 50' Invoke-Onefetch)" ]
}

@test "an unknown word is warned about and ignored; the greeting still draws" {
	run greet "${BASH:-bash}" --no-such-flag -NoOnefetch
	[ "$status" -eq 0 ]
	[[ $output == *"--no-such-flag"* ]]
	[ "$(calls)" = "$(printf '%s\n' Invoke-Clear 'Invoke-Fastfetch --extra-rows 0')" ]
}

@test "zsh: the flags reach Invoke-Fastfetch one word each" {
	command -v zsh >/dev/null 2>&1 || skip "zsh is not installed"
	run greet "$(command -v zsh)" -NoResize --max-shrink-steps 2 --settle
	[ "$status" -eq 0 ]
	[ "$(calls)" = "$(printf '%s\n' Invoke-Clear 'Invoke-Fastfetch --extra-rows 0 --no-resize --max-shrink-steps 2 --settle' Invoke-Onefetch)" ]
	[[ $output == *PANEL* ]]
}

@test "Reload-Profile replaces the shell with a login shell that knows it is a reload" {
	cat >"$BATS_TEST_TMPDIR/login-shell" <<'SH'
#!/bin/sh
echo "reloading=$FOUNDATION_RELOADING args=$*"
SH
	chmod +x "$BATS_TEST_TMPDIR/login-shell"
	run env SHELL="$BATS_TEST_TMPDIR/login-shell" "${BASH:-bash}" -c '. "$1"; Reload-Profile; echo "not replaced"' _ "$functions"
	[ "$status" -eq 0 ]
	[ "$output" = "reloading=1 args=-l" ]
}
