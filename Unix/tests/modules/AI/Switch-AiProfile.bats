#!/usr/bin/env bats
# Switch-AiProfile against a throwaway home, repository and config, with the real Deploy-AiArtifacts
# and Test-AiProfile behind it and a stand-in sudo: a switch writes the switch file next to the
# managed settings, every later command resolves the switched profile, the rules and the managed
# settings copy are the new profile's, --reset returns to the host or default pick, --dry-run and a
# refused name change nothing, and FOUNDATION_AI_PROFILE never redirects the switch.

load ../../helpers

setup() {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	setup_foundation
	use_empty_config
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME" "$BATS_TEST_TMPDIR/etc"
	export FOUNDATION_ETC_DIR=$BATS_TEST_TMPDIR/etc
	cd "$BATS_TEST_TMPDIR" || return 1
	unset CLAUDE_CONFIG_DIR ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN FOUNDATION_AI_PROFILE
	repo=$BATS_TEST_TMPDIR/repo
	ai=$repo/AI
	mkdir -p "$repo"
	ln -s "$UNIX_DIR" "$repo/Unix"
	export DOTFILES_ROOT=$repo
	export FOUNDATION_CLAUDE_CLI=foundation-test-no-claude
	rules Home home-rules
	rules Office office-rules
	stub_tool launchctl 'exit 0'
	# chown root:wheel cannot run as the test user: the stand-in logs it and succeeds.
	stub_tool sudo 'case "$1" in chown) exit 0 ;; esac; exec "$@"'
	dir=$BATS_TEST_TMPDIR/root/ClaudeCode
	switch=$dir/ai-profile.switch
	printf 'deploy one\n' >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	printf '[one]\nrules file RULES.md ~/one/RULES.md\nrules file managed-settings.json +managed-settings %s/managed-settings.json\n' "$dir" >"$FOUNDATION_CONFIG_DIR/ai-harnesses.conf"
	printf 'default Personal\n[Personal]\nrules Home\nplan Max 00000000-0000-0000-0000-00000000000a\n[Work]\nrules Office\nplan Team 11111111-1111-1111-1111-111111111111\n' >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	cmd=$UNIX_DIR/modules/AI/bin/Switch-AiProfile
}

# Creates the rules item AI/Rules/own/NAME with RULES.md holding TEXT and an empty
# managed-settings.json. Usage: rules NAME TEXT
rules() {
	mkdir -p "$ai/Rules/own/$1"
	printf '%s\n' "$2" >"$ai/Rules/own/$1/RULES.md"
	printf '{}\n' >"$ai/Rules/own/$1/managed-settings.json"
}

# The profile and how it was picked, as a later command resolves it. Usage: resolved
resolved() {
	"${BASH:-bash}" -c '. "$1/lib/foundation.sh" || exit 1; foundation_load config aiprofile; ai_profile_load; printf "%s %s" "$AI_PROFILE" "$AI_PROFILE_HOW"' _ "$UNIX_DIR"
}

@test "a switch records the pick, deploys the profile's rules and managed settings, and later commands resolve it" {
	run "${BASH:-bash}" "$cmd" work
	[ "$status" -eq 0 ]
	[ "$(cat "$switch")" = Work ]
	[ "$(resolved)" = 'Work switched' ]
	[ "$(cat "$HOME/one/RULES.md")" = office-rules ]
	grep -q '^profile Work$' "$dir/ai-profile.conf"
	grep -q '11111111-1111-1111-1111-111111111111' "$dir/managed-settings.json"
	grep -q "^sudo chown root:wheel $switch" "$BATS_TEST_TMPDIR/tool.log"
	grep -q "^sudo chmod 644 $switch" "$BATS_TEST_TMPDIR/tool.log"
	# Test-AiProfile ran as the switched profile.
	[[ $output == *"Profile => [Work] (picked by switched)"* ]]
}

@test "--reset removes the switch file and redeploys the host or default pick" {
	"${BASH:-bash}" "$cmd" Work
	run "${BASH:-bash}" "$cmd" --reset
	[ "$status" -eq 0 ]
	[ ! -e "$switch" ]
	[ "$(resolved)" = 'Personal default' ]
	[ "$(cat "$HOME/one/RULES.md")" = home-rules ]
	grep -q '^profile Personal$' "$dir/ai-profile.conf"
}

@test "the switch outranks a host line and FOUNDATION_AI_PROFILE outranks the switch" {
	stub_tool scutil 'echo My-Work-Mac'
	printf 'host my-work-mac Work\n' >"$FOUNDATION_CONFIG_DIR/ai-profiles.local.conf"
	[ "$(resolved)" = 'Work hostname' ]
	"${BASH:-bash}" "$cmd" Personal
	[ "$(resolved)" = 'Personal switched' ]
	[ "$(FOUNDATION_AI_PROFILE=Work resolved)" = 'Work override' ]
}

@test "with FOUNDATION_AI_PROFILE set the switch still deploys the profile it was given, and says so" {
	FOUNDATION_AI_PROFILE=Personal run "${BASH:-bash}" "$cmd" Work
	[ "$status" -eq 0 ]
	[ "$(cat "$switch")" = Work ]
	[ "$(cat "$HOME/one/RULES.md")" = office-rules ]
	grep -q '^profile Work$' "$dir/ai-profile.conf"
	[[ $output == *"unset FOUNDATION_AI_PROFILE"* ]]
}

@test "--dry-run writes nothing and never calls sudo; the Windows -WhatIf is the same" {
	run "${BASH:-bash}" "$cmd" Work --dry-run
	[ "$status" -eq 0 ]
	[ ! -e "$switch" ] && [ ! -e "$HOME/one/RULES.md" ] && [ ! -e "$dir/managed-settings.json" ]
	! grep -q '^sudo' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || false
	[[ $output == *"MISSING $HOME/one/RULES.md"* ]]
	run "${BASH:-bash}" "$cmd" Work -WhatIf
	[ "$status" -eq 0 ]
	[ ! -e "$switch" ]
}

@test "without a profile the menu offers the profiles: a pick switches, Reset resets, Enter changes nothing" {
	printf 'work\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$switch")" = Work ]
	[ "$(cat "$HOME/one/RULES.md")" = office-rules ]
	# Enter: nothing changes.
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$switch")" = Work ]
	# Reset is the third option while a switch is in effect.
	printf '3\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$switch" ]
	[ "$(cat "$HOME/one/RULES.md")" = home-rules ]
}

@test "profiles go by whatever names their sections carry" {
	printf 'default Studio-A\n[Studio-A]\nrules Home\n[night_shift]\nrules Office\n' >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd" NIGHT_SHIFT
	[ "$status" -eq 0 ]
	[ "$(cat "$switch")" = night_shift ]
	[ "$(resolved)" = 'night_shift switched' ]
	[ "$(cat "$HOME/one/RULES.md")" = office-rules ]
}

@test "without a profile, --reset and a terminal it reports and changes nothing" {
	"${BASH:-bash}" "$cmd" Work
	rm "$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Profile => [Work] (picked by switched)"* ]]
	[[ $output == *"Configured => [Personal, Work]"* ]]
	[[ $output == *"Switch file => [$switch] (set to [Work])"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}

@test "a name that is no profile, a profile with --reset, or an unknown flag changes nothing" {
	run "${BASH:-bash}" "$cmd" Nobody
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" Work --reset
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" Work --bogus
	[ "$status" -ne 0 ]
	[ ! -e "$switch" ] && [ ! -e "$HOME/one/RULES.md" ]
}

@test "no profile configured exits 2; no +managed-settings destination refuses the switch" {
	printf '[one]\nrules file RULES.md ~/one/RULES.md\n' >"$FOUNDATION_CONFIG_DIR/ai-harnesses.conf"
	run "${BASH:-bash}" "$cmd" Work
	[ "$status" -eq 1 ]
	[ ! -e "$HOME/one/RULES.md" ]
	rm "$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd" Work
	[ "$status" -eq 2 ]
}

@test "a switch file naming no profile fails every command with the reason until --reset" {
	mkdir -p "$dir"
	printf 'Gone\n' >"$switch"
	run "${BASH:-bash}" "$UNIX_DIR/modules/AI/bin/Test-AiProfile"
	[ "$status" -eq 1 ]
	[[ $output == *"Switch-AiProfile --reset"* ]]
	run "${BASH:-bash}" "$cmd" --reset
	[ "$status" -eq 0 ]
	[ ! -e "$switch" ]
	[ "$(resolved)" = 'Personal default' ]
}

@test "--full also runs the MCP server and marketplace deploys" {
	run "${BASH:-bash}" "$cmd" Work --full
	[[ $output == *"Deploy-AiMcpServers"* ]]
	[[ $output == *"Deploy-AiMarketplaces"* ]]
	[ "$(cat "$switch")" = Work ]
	[ "$(cat "$HOME/one/RULES.md")" = office-rules ]
}
