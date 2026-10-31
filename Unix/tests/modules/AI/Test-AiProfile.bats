#!/usr/bin/env bats
# Test-AiProfile against a throwaway home, config and /etc: exit 2 without profiles, 0 when the
# logged-in Plan and the managed settings match the profile's Plan, 1 on any mismatch or
# pay-per-use credential (process, launchd, shell files, apiKeyHelper), and the OAuth servers listed.

load ../../helpers

setup() {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	setup_foundation
	use_empty_config
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME" "$BATS_TEST_TMPDIR/etc"
	export FOUNDATION_ETC_DIR=$BATS_TEST_TMPDIR/etc
	# The project settings read are the current folder's.
	cd "$BATS_TEST_TMPDIR" || return 1
	unset CLAUDE_CONFIG_DIR ANTHROPIC_API_KEY ANTHROPIC_AUTH_TOKEN CLAUDE_CODE_OAUTH_TOKEN FOUNDATION_AI_PROFILE
	# No launchd environment unless a test sets one.
	stub_tool launchctl 'exit 0'
	cmd=$UNIX_DIR/modules/AI/bin/Test-AiProfile
	managed=$BATS_TEST_TMPDIR/root/managed-settings.json
	uuid=00000000-0000-0000-0000-000000000000
	printf 'deploy one\n' >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	printf '[one]\nrules file managed-settings.json +managed-settings %s\n' "$managed" >"$FOUNDATION_CONFIG_DIR/ai-harnesses.conf"
	printf 'default Personal\n[Personal]\nplan Max %s\nunattended on\n' "$uuid" >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	signed_in "$uuid"
	mkdir -p "$(dirname "$managed")"
	printf '{"forceLoginOrgUUID":"%s"}\n' "$uuid" >"$managed"
}

# Writes ~/.claude.json signed in to org UUID. Usage: signed_in UUID
signed_in() {
	printf '{"oauthAccount":{"organizationUuid":"%s","organizationName":"My Org"}}\n' "$1" >"$HOME/.claude.json"
}

@test "everything matching exits 0 and names the profile and how it was picked" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Personal (picked by default)"* ]]
	[[ $output == *"Logged-in Plan : My Org ($uuid)"* ]]
	[[ $output == *"Unattended     : on"* ]]
	[[ $output == *"Default policy : branch"* ]]
	[[ $output != *"Policy         :"* ]] && [[ $output != *"No-CI merges"* ]]
}

@test "the repository policy is listed in file order and never a mismatch" {
	printf 'default Personal
[Personal]
plan Max %s
unattended on
policy branch github.com/me/* github.com/x/y
autonomous github.com/me/a
policy nolevel github.com/me/z
default-policy nolevel
merge-without-checks github.com/me/a
' "$uuid" >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Default policy : readonly"* ]]
	[[ $output == *"default-policy is not a level [nolevel] - readonly is used"* ]]
	[[ $output == *"unknown level [nolevel]"* ]]
	[[ $output != *"github.com/me/z"* ]]
	[ "$(printf '%s\n' "$output" | sed -n 's/.*Policy         : //p' | tr -s ' ')" = "branch github.com/me/*
branch github.com/x/y
autonomous github.com/me/a" ]
	[[ $output == *"No-CI merges   : github.com/me/a"* ]]
}

@test "no profile configured exits 2" {
	rm "$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 2 ]
}

@test "another organization, no login, or no plan line is a mismatch" {
	signed_in 99999999-9999-9999-9999-999999999999
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"signed in to another organization"* ]]
	rm "$HOME/.claude.json"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"not signed in"* ]]
	printf 'default Personal\n[Personal]\n' >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"no \`plan NAME UUID...\` line"* ]]
}

@test "managed settings that are missing or pin another Plan are a mismatch; an array matches as a set" {
	printf '{"forceLoginOrgUUID":"11111111-1111-1111-1111-111111111111"}\n' >"$managed"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"not the profile's Plan"* ]]
	printf 'default Personal\n[Personal]\nplan Max %s 11111111-1111-1111-1111-111111111111\n' "$uuid" >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	printf '{"forceLoginOrgUUID":["11111111-1111-1111-1111-111111111111","%s"]}\n' "$uuid" >"$managed"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	rm "$managed"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"not deployed"* ]]
}

@test "a credential in the process, launchd, a shell file or apiKeyHelper is reported, never its value" {
	ANTHROPIC_API_KEY=sk-secret-value run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"ANTHROPIC_API_KEY is set in this shell's environment"* ]]
	[[ $output != *sk-secret-value* ]]
	stub_tool launchctl '[ "$2" = CLAUDE_CODE_OAUTH_TOKEN ] && echo token-value; exit 0'
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"CLAUDE_CODE_OAUTH_TOKEN is set in the user's launchd environment"* ]]
	[[ $output != *token-value* ]]
	stub_tool launchctl 'exit 0'
	printf '# export ANTHROPIC_AUTH_TOKEN=commented\nexport ANTHROPIC_AUTH_TOKEN=x\n' >"$HOME/.zshrc"
	printf 'ANTHROPIC_API_KEY=y\n' >"$FOUNDATION_ETC_DIR/zshenv"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"ANTHROPIC_AUTH_TOKEN is set in $HOME/.zshrc"* ]]
	[[ $output == *"ANTHROPIC_API_KEY is set in $FOUNDATION_ETC_DIR/zshenv"* ]]
	rm "$HOME/.zshrc" "$FOUNDATION_ETC_DIR/zshenv"
	mkdir -p "$HOME/.claude"
	printf '{"apiKeyHelper":"/usr/local/bin/key"}\n' >"$HOME/.claude/settings.json"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"apiKeyHelper is set in $HOME/.claude/settings.json"* ]]
}

@test "a commented credential line is not a credential" {
	printf '# export ANTHROPIC_API_KEY=x\n' >"$HOME/.zprofile"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
}

@test "the profile's OAuth MCP servers are listed, keyed ones are not" {
	printf '[remote]\nurl https://mcp.example.com/mcp\n[keyed]\nurl https://api.example.com/mcp\nbearer-token-env MY_KEY\n[other]\nurl https://other.example.com/mcp\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	printf 'mcp remote keyed\n' >>"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"OAuth MCP      : remote ("* ]]
}

@test "a host line picks the profile; an unknown override is a mismatch" {
	stub_tool scutil 'echo My-Work-Mac'
	printf 'host my-work-mac Work\ndefault Personal\n[Personal]\nplan Max %s\n[Work]\nplan Team %s\n' "$uuid" "$uuid" >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Work (picked by hostname)"* ]]
	FOUNDATION_AI_PROFILE=Nope run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
}

@test "an unknown argument is an error" {
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
}
