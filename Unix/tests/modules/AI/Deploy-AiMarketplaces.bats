#!/usr/bin/env bats
# Deploy-AiMarketplaces against a throwaway home and config: registers every marketplace, writes
# the variables its plugins need and sets each plugin's options in ~/.claude/settings.json keeping
# everything else, adds and installs through the Claude Code CLI only what the CLI does not list
# yet, and only warns without the CLI.

load ../../helpers

setup() {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	setup_foundation
	use_empty_config
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	cmd=$UNIX_DIR/modules/AI/bin/Deploy-AiMarketplaces
	settings=$HOME/.claude/settings.json
	printf '[my-marketplace]\nrepository MyOrg/MyMarketplace\nplugins my-plugin\nenv CLAUDE_CODE_ENABLE_FUNCTION_HOOKS 1\noption my-plugin theme dark\noption my-plugin pulse true\noption my-plugin cell ●\n' >"$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	# The deployers call the CLI FOUNDATION_CLAUDE_CLI names: a name that never exists means "no CLI",
	# and the stand-in below has a name of its own, so the real claude is never reached (foundation.sh
	# puts Homebrew back on a trimmed PATH, so trimming cannot hide it).
	export FOUNDATION_CLAUDE_CLI=foundation-test-no-claude
}

# A claude stub that logs its arguments, lists $STUB_MARKETPLACES and $STUB_PLUGINS (JSON) and
# fails every call whose arguments start with $STUB_FAIL.
stub_claude() {
	mkdir -p "$BATS_TEST_TMPDIR/bin"
	cat >"$BATS_TEST_TMPDIR/bin/foundation-test-claude" <<'SH'
#!/bin/sh
printf '%s\n' "$*" >>"$BATS_TEST_TMPDIR/claude.log"
case "$*" in
	"${STUB_FAIL:-no failure}"*) exit 1 ;;
esac
case "$*" in
	"plugin marketplace list --json") printf '%s\n' "${STUB_MARKETPLACES:-[]}" ;;
	"plugin list --json") printf '%s\n' "${STUB_PLUGINS:-[]}" ;;
esac
exit 0
SH
	chmod +x "$BATS_TEST_TMPDIR/bin/foundation-test-claude"
	export PATH=$BATS_TEST_TMPDIR/bin:$PATH
	export FOUNDATION_CLAUDE_CLI=foundation-test-claude
}

json() {
	python3 -c 'import json,sys; d=json.load(open(sys.argv[1], encoding="utf-8")); print(json.dumps(eval(sys.argv[2], {"d": d}), ensure_ascii=False, sort_keys=True))' "$settings" "$1"
}

@test "registers the marketplace, writes its variable and sets the plugin's options, JSON values typed and text kept" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(json 'd["extraKnownMarketplaces"]["my-marketplace"]')" = '{"source": {"repo": "MyOrg/MyMarketplace", "source": "github"}}' ]
	[ "$(json 'd["env"]')" = '{"CLAUDE_CODE_ENABLE_FUNCTION_HOOKS": "1"}' ]
	[ "$(json 'd["pluginConfigs"]["my-plugin@my-marketplace"]["options"]')" = '{"cell": "●", "pulse": true, "theme": "dark"}' ]
}

@test "the last section to name a variable wins and a value with spaces is kept whole" {
	printf '[a]\nrepository MyOrg/A\nenv SHARED first\n[b]\nrepository MyOrg/B\nenv SHARED two words here\n' >"$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(json 'd["env"]["SHARED"]')" = '"two words here"' ]
}

@test "keeps every other setting and variable and replaces only the options key of the plugin" {
	mkdir -p "$HOME/.claude"
	printf '{"effortLevel":"high","env":{"CLAUDE_CODE_PLUGIN_DIRS":"/x"},"enabledPlugins":{"my-plugin@my-marketplace":true},"pluginConfigs":{"my-plugin@my-marketplace":{"options":{"stale":1},"other":2},"x@y":{"options":{"a":1}}}}' >"$settings"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(json 'd["effortLevel"]')" = '"high"' ]
	[ "$(json 'd["env"]')" = '{"CLAUDE_CODE_ENABLE_FUNCTION_HOOKS": "1", "CLAUDE_CODE_PLUGIN_DIRS": "/x"}' ]
	[ "$(json 'd["enabledPlugins"]')" = '{"my-plugin@my-marketplace": true}' ]
	[ "$(json 'd["pluginConfigs"]["my-plugin@my-marketplace"]["other"]')" = '2' ]
	[ "$(json '"stale" in d["pluginConfigs"]["my-plugin@my-marketplace"]["options"]')" = 'false' ]
	[ "$(json 'd["pluginConfigs"]["x@y"]')" = '{"options": {"a": 1}}' ]
}

@test "leaves an unparseable settings file untouched and fails" {
	mkdir -p "$HOME/.claude"
	printf '{ not json' >"$settings"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ "$(cat "$settings")" = '{ not json' ]
}

@test "leaves an env entry that is not an object untouched and fails" {
	mkdir -p "$HOME/.claude"
	printf '{"env":"not an object"}' >"$settings"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ "$(cat "$settings")" = '{"env":"not an object"}' ]
}

@test "rejects an env line without a valid variable name and fails" {
	printf '[my-marketplace]\nrepository MyOrg/MyMarketplace\nenv NOT-VALID 1\n' >"$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"valid variable name"* ]]
	[ "$(json '"env" in d')" = 'false' ]
}

@test "--check reports a difference and changes nothing" {
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *"DIFFERS env.CLAUDE_CODE_ENABLE_FUNCTION_HOOKS"* ]]
	[[ $output == *"DIFFERS pluginConfigs.my-plugin@my-marketplace.options"* ]]
	[ ! -e "$settings" ]
}

@test "deploys the settings without the Claude Code CLI and warns" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Claude Code CLI (claude) not found"* ]]
	[ -f "$settings" ]
}

@test "adds the marketplace and installs the plugin the CLI does not list" {
	stub_claude
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qxF "plugin marketplace add MyOrg/MyMarketplace" "$BATS_TEST_TMPDIR/claude.log"
	grep -qxF "plugin install my-plugin@my-marketplace" "$BATS_TEST_TMPDIR/claude.log"
}

@test "leaves a listed marketplace and an installed plugin alone" {
	stub_claude
	export STUB_MARKETPLACES='[{"name":"my-marketplace"}]' STUB_PLUGINS='[{"id":"my-plugin@my-marketplace"}]'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	! grep -q "marketplace add\|plugin install" "$BATS_TEST_TMPDIR/claude.log" || false
}

@test "warns about a CLAUDE_CODE_PLUGIN_DIRS folder holding an installed plugin and keeps the entry" {
	mkdir -p "$BATS_TEST_TMPDIR/clone/.claude-plugin" "$BATS_TEST_TMPDIR/other/.claude-plugin" "$HOME/.claude"
	printf '{"name":"my-plugin"}' >"$BATS_TEST_TMPDIR/clone/.claude-plugin/plugin.json"
	printf '{"name":"other-mod"}' >"$BATS_TEST_TMPDIR/other/.claude-plugin/plugin.json"
	printf '{"env":{"CLAUDE_CODE_PLUGIN_DIRS":"%s:%s"}}' "$BATS_TEST_TMPDIR/other" "$BATS_TEST_TMPDIR/clone" >"$settings"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Plugin [my-plugin@my-marketplace] is installed from its marketplace and also loaded from [$BATS_TEST_TMPDIR/clone]"* ]]
	[[ $output != *"other-mod"* ]]
	[ "$(json 'd["env"]["CLAUDE_CODE_PLUGIN_DIRS"]')" = "\"$BATS_TEST_TMPDIR/other:$BATS_TEST_TMPDIR/clone\"" ]
}

@test "skips a marketplace without a valid repository and fails" {
	printf '[broken]\nrepository not-a-repo\n' >"$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -e "$settings" ]
}

@test "warns and succeeds when nothing is configured" {
	rm "$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"nothing to deploy"* ]]
}

@test "a [plugin:NAME] section writes its options and config lines beneath pluginConfigs.NAME" {
	printf '[plugin:my-mod]\noption theme dark\noption size 3\nconfig enabled true\n' >"$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	mkdir -p "$HOME/.claude"
	printf '{"pluginConfigs":{"my-mod":{"options":{"stale":1},"kept":"yes"}}}' >"$settings"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(json 'd["pluginConfigs"]["my-mod"]')" = '{"enabled": true, "kept": "yes", "options": {"size": 3, "theme": "dark"}}' ]
	[ "$(json '"extraKnownMarketplaces" in d')" = 'false' ]
}

@test "a config line in a marketplace section sets one child key of the plugin's entry" {
	printf '[my-marketplace]\nrepository MyOrg/MyMarketplace\nplugins my-plugin\nconfig my-plugin level ["a","b"]\n' >"$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(json 'd["pluginConfigs"]["my-plugin@my-marketplace"]')" = '{"level": ["a", "b"]}' ]
}

@test "a [plugin:NAME] line that is neither option nor config fails, the rest is still written" {
	printf '[plugin:my-mod]\nrepository MyOrg/Nope\noption theme dark\n' >"$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"unknown line"* ]]
	[ "$(json 'd["pluginConfigs"]["my-mod"]["options"]')" = '{"theme": "dark"}' ]
}

@test "a failed plugin install fails the run and the next marketplace is still handled" {
	printf '[a]\nrepository MyOrg/A\nplugins one\n[b]\nrepository MyOrg/B\nplugins two\n' >"$FOUNDATION_CONFIG_DIR/ai-marketplaces.conf"
	stub_claude
	STUB_FAIL='plugin install one@a' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"claude plugin install [one@a] failed"* ]]
	grep -qxF "plugin marketplace add MyOrg/B" "$BATS_TEST_TMPDIR/claude.log"
	grep -qxF "plugin install two@b" "$BATS_TEST_TMPDIR/claude.log"
}

@test "a failed marketplace add fails the run and the plugin install is still tried" {
	stub_claude
	STUB_FAIL='plugin marketplace add' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"claude plugin marketplace add [MyOrg/MyMarketplace] failed"* ]]
	grep -qxF "plugin install my-plugin@my-marketplace" "$BATS_TEST_TMPDIR/claude.log"
}
