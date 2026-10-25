#!/usr/bin/env bats
# lib/state.sh: the instance keys of a workspace open more than once and the
# Resolve-TrackedWorkspaceWindow ladder (id, the app's only window, app and exact title; never a
# terminal window, never another instance's window).

load helpers

setup() {
	setup_foundation
	mkdir -p "$FOUNDATION_STATE_DIR"
}

# One as_windows line (pid 1). Usage: win ID TOKEN BUNDLE DESKTOP APP-NAME TITLE
win() { printf '%s\t%s\t%s\t1\t%s\t%s\t%s\n' "$@"; }

@test "instances: a further key per open, names without the suffix, forget one or all" {
	printf 'window\t1\tCode\tb\tt\n' | state_replace Demo
	[ "$(state_next_key demo)" = "demo#2" ]
	printf 'meta\talongside\n' | state_replace Demo#2
	[ "$(state_next_key Demo)" = "Demo#3" ]
	[ "$(state_workspaces)" = "Demo" ]
	[ "$(state_instances DEMO | tr '\n' ' ')" = "Demo Demo#2 " ]
	state_is_alongside Demo#2
	! state_is_alongside Demo || false
	state_forget Demo
	[ "$(state_next_key Demo)" = "Demo#3" ]
	state_forget_workspace demo
	[ -z "$(state_keys)" ]
	[ "$(state_next_key Demo)" = "Demo" ]
}

@test "the ladder: id, then the app's only live window, then app and exact title" {
	printf '%s\n' $'window\t10\tCode\tcom.microsoft.VSCode\tOld' $'window\t20\tFirefox\torg.mozilla.firefox\tDocs' $'window\t30\tSlack\tcom.tinyspeck.slackmacgap\tSlack' | state_replace Demo
	live=$(
		win 10 Code com.microsoft.VSCode 1 Code Old
		win 21 Firefox org.mozilla.firefox 1 Firefox Other
		win 22 Firefox org.mozilla.firefox 2 Firefox Docs
	)
	[ "$(state_resolve_windows Demo "$live")" = $'10\t10\tid\n20\t22\ttitle' ]
	live=$(win 11 Code com.microsoft.VSCode 1 Code New)
	[ "$(state_resolve_windows Demo "$live")" = $'10\t11\tbundle' ]
}

@test "the ladder never re-resolves a terminal window nor takes another instance's window" {
	printf '%s\n' $'window\t10\tWezTerm\tcom.github.wez.wezterm\tzsh' $'window\t20\tCode\tcom.microsoft.VSCode\tX' | state_replace Demo
	printf 'window\t21\tCode\tcom.microsoft.VSCode\tX\n' | state_replace Other
	live=$(
		win 11 WezTerm com.github.wez.wezterm 1 WezTerm zsh
		win 21 Code com.microsoft.VSCode 1 Code X
	)
	[ -z "$(state_resolve_windows Demo "$live")" ]
	[ "$(state_live_windows Other "$live")" = 21 ]
}

@test "protection: a plain open adopts its own alongside instances, an alongside open protects them" {
	printf 'window\t10\tCode\tcom.microsoft.VSCode\tA\n' | state_replace Demo
	printf 'window\t20\tSlack\tcom.tinyspeck.slackmacgap\tS\nmeta\talongside\n' | state_replace Demo#2
	live=$(
		win 10 Code com.microsoft.VSCode 1 Code A
		win 20 Slack com.tinyspeck.slackmacgap 6 Slack S
	)
	[ -z "$(state_protected_windows plain "$live" Demo)" ]
	[ "$(state_protected_windows plain "$live" Other)" = 20 ]
	[ "$(state_protected_windows alongside "$live" Demo | tr '\n' ' ')" = "10 20 " ]
	[ "$(state_instance_label Demo#2 "$live")" = "Demo (alongside, desktop 6)" ]
	[ "$(state_instance_label Demo "")" = "Demo (plain, instance 1)" ]
}
