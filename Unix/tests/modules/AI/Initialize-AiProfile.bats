#!/usr/bin/env bats
# Initialize-AiProfile against a throwaway home and config with stand-ins for claude and gh: each
# step done is skipped, each step to do is described and offered (started only on a Yes from the
# answers file), the profile's env variables are reported by name, and Test-AiProfile's exit code
# is returned. Nothing reads or writes a secret.

load ../../helpers

setup() {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	setup_foundation
	use_empty_config
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME" "$BATS_TEST_TMPDIR/etc"
	export FOUNDATION_ETC_DIR=$BATS_TEST_TMPDIR/etc
	cd "$BATS_TEST_TMPDIR" || return 1
	unset CLAUDE_CONFIG_DIR ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN FOUNDATION_AI_PROFILE MY_KEY
	stub_tool launchctl 'exit 0'
	stub_tool foundation-test-claude 'exit 0'
	stub_tool foundation-test-gh '[ "$1 $2" = "auth status" ] && exit "${GH_STATUS:-0}"; exit 0'
	export FOUNDATION_CLAUDE_CLI=foundation-test-claude FOUNDATION_GH_CLI=foundation-test-gh
	cmd=$UNIX_DIR/modules/AI/bin/Initialize-AiProfile
	uuid=00000000-0000-0000-0000-000000000000
	managed=$BATS_TEST_TMPDIR/root/managed-settings.json
	printf 'deploy one\n' >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	printf '[one]\nrules file managed-settings.json +managed-settings %s\n' "$managed" >"$FOUNDATION_CONFIG_DIR/ai-harnesses.conf"
	printf '[remote]\nurl https://mcp.example.com/mcp\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	printf 'default Personal\n[Personal]\nplan Max %s\nenv MY_KEY\n' "$uuid" >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	mkdir -p "$(dirname "$managed")"
	printf '{"forceLoginOrgUUID":"%s"}\n' "$uuid" >"$managed"
}

signed_in() {
	printf '{"oauthAccount":{"organizationUuid":"%s"}}\n' "$uuid" >"$HOME/.claude.json"
}

@test "no profile configured exits 2" {
	rm "$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 2 ]
}

@test "done steps are skipped and Test-AiProfile's exit code is returned" {
	signed_in
	MY_KEY=set-value run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Signed in to the Max Plan"* ]]
	[[ $output == *"The GitHub CLI is signed in"* ]]
	[[ $output == *"MY_KEY is set"* ]]
	[[ $output != *set-value* ]]
	# Only gh auth status ran; no sign-in was started.
	! grep -q '^foundation-test-claude' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "without a terminal the sign-ins are described, never started, and the verdict fails" {
	GH_STATUS=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"Sign in with the account of the Max Plan (organization $uuid)"* ]]
	[[ $output == *"Skipped - run it yourself: foundation-test-gh auth login"* ]]
	[[ $output == *"remote"* ]]
	[[ $output == *"MY_KEY is not set"* ]]
	! grep -q '^foundation-test-claude' "$BATS_TEST_TMPDIR/tool.log" || false
	! grep -q '^foundation-test-gh auth login' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "a Yes starts the tool for the sign-in" {
	signed_in
	printf 'y\n' >"$FOUNDATION_TTY"
	GH_STATUS=1 run "${BASH:-bash}" "$cmd"
	grep -q '^foundation-test-gh auth login' "$BATS_TEST_TMPDIR/tool.log"
}
