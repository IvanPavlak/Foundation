#!/usr/bin/env bats
# Deploy-AiMcpServers against a throwaway home and config: adds each server to Claude Code through
# the CLI only when ~/.claude.json does not carry it as configured, writes each server's table into
# ~/.codex/config.toml keeping every other line, skips what the deploy line or a machine line leaves
# out, and only warns without the CLI.

load ../../helpers

setup() {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	setup_foundation
	use_empty_config
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	unset CLAUDE_CONFIG_DIR CODEX_HOME
	export CONF_MACHINE_TYPE=PC
	cmd=$UNIX_DIR/modules/AI/bin/Deploy-AiMcpServers
	state=$HOME/.claude.json
	toml=$HOME/.codex/config.toml
	printf 'deploy claude-code codex\n[linear]\nurl https://mcp.linear.app/mcp\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	# A name that never exists means "no CLI" (foundation.sh puts Homebrew back on a trimmed PATH, so
	# trimming cannot hide the real claude).
	export FOUNDATION_CLAUDE_CLI=foundation-test-no-claude
}

# A claude stub that logs its arguments one per |-separated field and fails every call whose
# arguments start with $STUB_FAIL.
stub_claude() {
	mkdir -p "$BATS_TEST_TMPDIR/bin"
	cat >"$BATS_TEST_TMPDIR/bin/foundation-test-claude" <<'SH'
#!/bin/sh
line=''
for argument in "$@"; do line="$line$argument|"; done
printf '%s\n' "$line" >>"$BATS_TEST_TMPDIR/claude.log"
case "$*" in
	"${STUB_FAIL:-no failure}"*) exit 1 ;;
esac
exit 0
SH
	chmod +x "$BATS_TEST_TMPDIR/bin/foundation-test-claude"
	export PATH=$BATS_TEST_TMPDIR/bin:$PATH
	export FOUNDATION_CLAUDE_CLI=foundation-test-claude
}

@test "adds a server ~/.claude.json does not carry at user scope" {
	stub_claude
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/claude.log")" = 'mcp|add|--scope|user|--transport|http|linear|https://mcp.linear.app/mcp|' ]
}

@test "leaves a server carried as configured alone" {
	stub_claude
	printf '{"mcpServers":{"linear":{"type":"http","url":"https://mcp.linear.app/mcp"}}}' >"$state"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/claude.log" ]
	[[ $output == *"Claude Code MCP server [linear] already configured"* ]]
}

@test "removes and adds again a server carried with another definition" {
	stub_claude
	printf '{"mcpServers":{"linear":{"type":"http","url":"https://old.example.com/mcp"}}}' >"$state"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/claude.log")" = $'mcp|remove|--scope|user|linear|\nmcp|add|--scope|user|--transport|http|linear|https://mcp.linear.app/mcp|' ]
}

@test "passes headers whole and turns bearer-token-env into a header that names the variable" {
	stub_claude
	printf 'deploy claude-code\n[keyed]\nurl https://api.example.com/mcp\nheader X-Project My Project\nbearer-token-env MY_API_KEY\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/claude.log")" = 'mcp|add|--scope|user|--transport|http|keyed|https://api.example.com/mcp|--header|X-Project: My Project|--header|Authorization: Bearer ${MY_API_KEY}|' ]
}

@test "adds a stdio server with its variables, then its command and arguments after --" {
	stub_claude
	printf 'deploy claude-code\n[local]\ncommand /opt/my server/bin\narg -y\narg two words\nenv LOG_LEVEL info\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/claude.log")" = 'mcp|add|--scope|user|local|-e|LOG_LEVEL=info|--|/opt/my server/bin|-y|two words|' ]
}

@test "writes each server's table to config.toml, keeping every other line and replacing a table in place" {
	mkdir -p "$HOME/.codex"
	printf 'model = "gpt-5"\n\n[mcp_servers.linear]\nurl = "https://old.example.com/mcp"\n\n[mcp_servers.linear.env]\nOLD = "1"\n\n# The GitHub server\n[mcp_servers.github]\nurl = "x"\n' >"$toml"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$toml")" = "$(printf 'model = "gpt-5"\n\n[mcp_servers.linear]\nurl = "https://mcp.linear.app/mcp"\n\n# The GitHub server\n[mcp_servers.github]\nurl = "x"')" ]
	[[ $output == *"Updated Codex MCP server [linear]"* ]]
}

@test "writes a stdio table with escaped strings, arguments and variables" {
	printf 'deploy codex\n[local]\ncommand C:\\Tools\\server "x".exe\narg --port\narg 8080\nenv LOG_LEVEL info\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$toml")" = "$(printf '[mcp_servers.local]\ncommand = "C:\\\\Tools\\\\server \\"x\\".exe"\nargs = ["--port", "8080"]\nenv = { "LOG_LEVEL" = "info" }')" ]
}

@test "a second run leaves config.toml byte for byte as it was" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	cp "$toml" "$BATS_TEST_TMPDIR/before.toml"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	cmp "$BATS_TEST_TMPDIR/before.toml" "$toml"
	[[ $output == *"Codex MCP server [linear] already configured"* ]]
}

@test "writes to CODEX_HOME when it is set" {
	export CODEX_HOME=$BATS_TEST_TMPDIR/codex-home
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -f "$CODEX_HOME/config.toml" ]
	[ ! -e "$toml" ]
}

@test "skips an sse server for Codex and adds it to Claude Code" {
	stub_claude
	printf 'deploy claude-code codex\n[events]\nurl https://events.example.com/sse\ntransport sse\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$toml" ]
	[[ $output == *"MCP server [events] is an sse server"* ]]
	[ "$(cat "$BATS_TEST_TMPDIR/claude.log")" = 'mcp|add|--scope|user|--transport|sse|events|https://events.example.com/sse|' ]
}

@test "deploys only into the apps of the last deploy line for this machine type" {
	stub_claude
	printf 'deploy claude-code codex\n@PC deploy claude-code\n[linear]\nurl https://mcp.linear.app/mcp\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$toml" ]
	[ -s "$BATS_TEST_TMPDIR/claude.log" ]
}

@test "skips a server whose machine line names other machine types" {
	printf 'deploy codex\n[linear]\nurl https://mcp.linear.app/mcp\n[worktool]\nurl https://work.example.com/mcp\nmachine Work Laptop\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qF '[mcp_servers.linear]' "$toml"
	! grep -qF 'worktool' "$toml" || false
}

@test "skips an invalid server with its reason, fails and still deploys the rest" {
	printf 'deploy codex\n[both]\nurl https://x.example.com/mcp\ncommand npx\n[linear]\nurl https://mcp.linear.app/mcp\n[odd]\nurl https://y.example.com/mcp\ncolour blue\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"MCP server [both] needs exactly one url or command line - skipped!"* ]]
	[[ $output == *"MCP server [odd] has an unknown line"* ]]
	grep -qF '[mcp_servers.linear]' "$toml"
	! grep -qF 'both' "$toml" || false
}

@test "--check reports what is missing and changes nothing" {
	stub_claude
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *"MISSING Claude Code MCP server [linear]"* ]]
	[[ $output == *"MISSING Codex MCP server [linear]"* ]]
	[ ! -e "$toml" ]
	[ ! -e "$BATS_TEST_TMPDIR/claude.log" ]
}

@test "deploys Codex without the Claude Code CLI and warns" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Claude Code CLI (claude) not found"* ]]
	[ -f "$toml" ]
}

@test "deploys nothing to Claude Code when ~/.claude.json does not parse, and fails" {
	stub_claude
	printf '{ not json' >"$state"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ ! -e "$BATS_TEST_TMPDIR/claude.log" ]
	[ "$(cat "$state")" = '{ not json' ]
	[ -f "$toml" ]
}

@test "a failed add fails the run and the next server is still added" {
	stub_claude
	printf 'deploy claude-code\n[a]\nurl https://a.example.com/mcp\n[b]\nurl https://b.example.com/mcp\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	STUB_FAIL='mcp add --scope user --transport http a ' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"claude mcp add [a] failed"* ]]
	grep -qxF 'mcp|add|--scope|user|--transport|http|b|https://b.example.com/mcp|' "$BATS_TEST_TMPDIR/claude.log"
}

@test "warns and succeeds when nothing is configured or no app is named" {
	rm "$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"nothing to deploy"* ]]
	printf '[linear]\nurl https://mcp.linear.app/mcp\n' >"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"No deploy line names an app"* ]]
	[ ! -e "$toml" ]
}

# Writes ai-profiles.conf: a default profile and its section lines. Usage: profile NAME LINE...
profile() {
	local name=$1
	shift
	printf 'default %s\n[%s]\n' "$name" "$name" >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	[ $# -eq 0 ] || printf '%s\n' "$@" >>"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
}

@test "an AI profile's mcp line picks the servers; a name it lists that is not configured warns" {
	stub_claude
	printf '[mobbin]\nurl https://api.mobbin.com/mcp\n' >>"$FOUNDATION_CONFIG_DIR/ai-mcp-servers.conf"
	profile Personal 'mcp mobbin nope'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"MCP server [nope], which ai-mcp-servers.conf does not configure"* ]]
	[ "$(cat "$BATS_TEST_TMPDIR/claude.log")" = 'mcp|add|--scope|user|--transport|http|mobbin|https://api.mobbin.com/mcp|' ]
	grep -q '^\[mcp_servers.mobbin\]' "$toml"
	! grep -q 'mcp_servers.linear' "$toml" || false
	[ "$(sort "$FOUNDATION_STATE_DIR/ai-mcp-servers.state")" = $'claude-code\tmobbin\ncodex\tmobbin' ]
}

@test "without a profile nothing is recorded and nothing is removed" {
	stub_claude
	printf '{"mcpServers":{"linear":{"type":"http","url":"https://mcp.linear.app/mcp"}}}' >"$state"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$FOUNDATION_STATE_DIR/ai-mcp-servers.state" ]
	[ ! -e "$BATS_TEST_TMPDIR/claude.log" ]
}

@test "a bare mcp line removes a configured server the apps carry as configured, never a foreign one" {
	stub_claude
	printf '{"mcpServers":{"linear":{"type":"http","url":"https://mcp.linear.app/mcp"},"mine":{"type":"http","url":"https://mine.example.com"}}}' >"$state"
	mkdir -p "$HOME/.codex"
	printf '[mcp_servers.linear]\nurl = "https://mcp.linear.app/mcp"\n\n[mcp_servers.mine]\nurl = "https://mine.example.com"\n' >"$toml"
	profile Work 'mcp'
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *"REMOVE Claude Code MCP server [linear]"* ]]
	[[ $output == *"REMOVE Codex MCP server [linear]"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/claude.log" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/claude.log")" = 'mcp|remove|--scope|user|linear|' ]
	! grep -q 'mcp_servers.linear' "$toml" || false
	grep -q '^\[mcp_servers.mine\]' "$toml"
	[ ! -s "$FOUNDATION_STATE_DIR/ai-mcp-servers.state" ]
}

@test "a recorded server the profile drops is removed even when its definition changed" {
	stub_claude
	printf '{"mcpServers":{"linear":{"type":"http","url":"https://changed.example.com"}}}' >"$state"
	mkdir -p "$FOUNDATION_STATE_DIR"
	printf 'claude-code\tlinear\n' >"$FOUNDATION_STATE_DIR/ai-mcp-servers.state"
	profile Work 'mcp'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$BATS_TEST_TMPDIR/claude.log")" = 'mcp|remove|--scope|user|linear|' ]
}

@test "a failed removal stays recorded and fails the run" {
	stub_claude
	printf '{"mcpServers":{"linear":{"type":"http","url":"https://mcp.linear.app/mcp"}}}' >"$state"
	profile Work 'mcp'
	STUB_FAIL='mcp remove' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	grep -qx $'claude-code\tlinear' "$FOUNDATION_STATE_DIR/ai-mcp-servers.state"
}

@test "an override naming no profile stops before anything is deployed" {
	stub_claude
	profile Personal
	FOUNDATION_AI_PROFILE=Nope run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"[Nope], which is no section"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/claude.log" ]
}
