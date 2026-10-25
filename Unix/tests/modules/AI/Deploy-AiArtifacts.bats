#!/usr/bin/env bats
# Deploy-AiArtifacts against a throwaway home, repository and config (every destination under the
# test folder, never the real ~/.claude): the roster rules (own first with a clash warning, the
# sources read, exclude by name and by source, use for a file destination, the file variants),
# the each, copy and file placements, a destination two harnesses share, the hooks, pruning only
# dangling links into the artifacts root, the backup of a real item, and --check.

load ../../helpers

setup() {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	setup_foundation
	use_empty_config
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	repo=$BATS_TEST_TMPDIR/repo
	ai=$repo/AI
	mkdir -p "$repo"
	ln -s "$UNIX_DIR" "$repo/Unix"
	export DOTFILES_ROOT=$repo
	skill own alpha
	skill own beta
	# A folder without SKILL.md is not a skill.
	mkdir -p "$ai/Skills/own/not-a-skill"
	rules own Core own-rules
	export FOUNDATION_CLAUDE_CLI=foundation-test-no-claude
	conf 'deploy one' 'use rules Core'
	harness one 'skills each . ~/one/skills' 'rules file RULES.md ~/one/RULES.md'
	cmd=$UNIX_DIR/modules/AI/bin/Deploy-AiArtifacts
}

# Creates AI/Skills/SOURCE/NAME/SKILL.md. Usage: skill SOURCE NAME
skill() {
	mkdir -p "$ai/Skills/$1/$2"
	printf -- '---\nname: %s\ndescription: %s of %s\n---\n' "$2" "$2" "$1" >"$ai/Skills/$1/$2/SKILL.md"
}

# Creates AI/Rules/SOURCE/NAME/RULES.md holding TEXT. Usage: rules SOURCE NAME TEXT
rules() {
	mkdir -p "$ai/Rules/$1/$2"
	printf '%s\n' "$3" >"$ai/Rules/$1/$2/RULES.md"
}

# Writes ai-artifacts.conf, one argument per line. Usage: conf LINE...
conf() {
	printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
}

# Appends a harness section to ai-harnesses.conf. Usage: harness NAME LINE...
harness() {
	local name=$1
	shift
	printf '[%s]\n' "$name" >>"$FOUNDATION_CONFIG_DIR/ai-harnesses.conf"
	printf '%s\n' "$@" >>"$FOUNDATION_CONFIG_DIR/ai-harnesses.conf"
}

@test "links every skill into an each destination and the used rules into a file destination" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/one/skills/alpha")" = "$ai/Skills/own/alpha" ]
	[ "$(readlink "$HOME/one/skills/beta")" = "$ai/Skills/own/beta" ]
	[ ! -e "$HOME/one/skills/not-a-skill" ]
	[ "$(readlink "$HOME/one/RULES.md")" = "$ai/Rules/own/Core/RULES.md" ]
}

@test "a second run changes nothing and --check is all clear" {
	"${BASH:-bash}" "$cmd" >/dev/null 2>&1
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output != *"linked "* ]]
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *"fully deployed (3 items)"* ]]
}

@test "--check reports what is missing and creates nothing" {
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *"MISSING $HOME/one/skills/alpha"* ]]
	[[ $output == *"MISSING $HOME/one/RULES.md"* ]]
	[[ $output == *"incomplete: 3 item(s)"* ]]
	[ ! -e "$HOME/one" ]
}

@test "own is read first and wins a name clash with a configured source, with a warning" {
	skill vendor alpha
	skill vendor gamma
	printf '[vendor]\nrepository Owner/Repo\n' >>"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Duplicate skill [alpha]"*"keeping the one from [own]"* ]]
	[ "$(readlink "$HOME/one/skills/alpha")" = "$ai/Skills/own/alpha" ]
	[ "$(readlink "$HOME/one/skills/gamma")" = "$ai/Skills/vendor/gamma" ]
}

@test "own wins a clash even with a source whose name sorts first" {
	skill aaa alpha
	printf '[aaa]\nrepository Owner/Repo\n' >>"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$(readlink "$HOME/one/skills/alpha")" = "$ai/Skills/own/alpha" ]
}

@test "foundation and example are read; an unconfigured source folder is not" {
	skill foundation product
	skill example sample
	skill winux other
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -L "$HOME/one/skills/product" ]
	[ -L "$HOME/one/skills/sample" ]
	[ ! -e "$HOME/one/skills/other" ]
}

@test "exclude KIND/NAME drops the item from every source, KIND/SOURCE/NAME from one" {
	skill foundation alpha
	skill foundation delta
	conf 'deploy one' 'use rules Core' 'exclude skills/beta skills/own/alpha' 'exclude skills/DELTA'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$HOME/one/skills/beta" ]
	[ ! -e "$HOME/one/skills/delta" ]
	# own's alpha is excluded, so foundation's takes its place without a clash warning.
	[ "$(readlink "$HOME/one/skills/alpha")" = "$ai/Skills/foundation/alpha" ]
	[[ $output != *"Duplicate"* ]]
}

@test "the example rules lose to own, and excluding them by source silences the clash" {
	rules example Core example-rules
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"Duplicate rule [Core]"* ]]
	[ "$(readlink "$HOME/one/RULES.md")" = "$ai/Rules/own/Core/RULES.md" ]
	conf 'deploy one' 'use rules Core' 'exclude rules/example/Core'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output != *"Duplicate"* ]]
}

@test "without a use line a file destination links nothing; the last use line wins" {
	rules own Other other-rules
	conf 'deploy one'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *'no `use rules NAME` line'* ]]
	[ ! -e "$HOME/one/RULES.md" ]
	conf 'deploy one' 'use rules Core' 'use rules Other'
	run "${BASH:-bash}" "$cmd"
	[ "$(readlink "$HOME/one/RULES.md")" = "$ai/Rules/own/Other/RULES.md" ]
}

@test "a use line naming no item warns and links nothing" {
	conf 'deploy one' 'use rules Missing'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *'`use rules Missing` names no rule item'* ]]
	[ ! -e "$HOME/one/RULES.md" ]
}

@test "file variants: the first file the item has, linked with that file's extension" {
	mkdir -p "$ai/Agents/own/reviewer" "$ai/Agents/own/portable" "$ai/Agents/own/tomlonly"
	printf 'claude\n' >"$ai/Agents/own/reviewer/claude.md"
	printf 'portable\n' >"$ai/Agents/own/reviewer/AGENT.md"
	printf 'portable\n' >"$ai/Agents/own/portable/AGENT.md"
	printf 'toml\n' >"$ai/Agents/own/tomlonly/codex.toml"
	harness two 'agents each claude.md,AGENT.md ~/two/agents' 'agents each copilot.agent.md,codex.toml ~/three/agents'
	conf 'deploy two'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/two/agents/reviewer.md")" = "$ai/Agents/own/reviewer/claude.md" ]
	[ "$(readlink "$HOME/two/agents/portable.md")" = "$ai/Agents/own/portable/AGENT.md" ]
	# An item with none of the files is left out of that destination.
	[ ! -e "$HOME/two/agents/tomlonly.md" ]
	[ "$(readlink "$HOME/three/agents/tomlonly.toml")" = "$ai/Agents/own/tomlonly/codex.toml" ]
	[ ! -e "$HOME/three/agents/reviewer.toml" ]
}

@test "a destination no item goes to is never created" {
	harness two 'prompts each PROMPT.md ~/two/prompts' 'skills each . ~/two/skills'
	conf 'deploy two'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$HOME/two/prompts" ]
	[ -L "$HOME/two/skills/alpha" ]
}

@test "a destination two harnesses name is filled once, for the first" {
	harness two 'skills each . ~/one/skills'
	conf 'deploy one two' 'use rules Core'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(grep -c "linked  $HOME/one/skills/alpha" <<<"$output")" -eq 1 ]
	[[ $output != *"differently"* ]]
}

@test "the same destination with another placement or file list keeps the first, with a warning" {
	harness two 'skills copy . ~/one/skills'
	conf 'deploy one two'
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"Harness [two] names $HOME/one/skills differently"* ]]
	[ -L "$HOME/one/skills/alpha" ]
}

@test "copy places a copy, refreshes one that differs and backs the old one up" {
	harness two 'skills copy . ~/two/skills'
	conf 'deploy two'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -f "$HOME/two/skills/alpha/SKILL.md" ] && [ ! -L "$HOME/two/skills/alpha" ]
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"fully deployed"* ]]
	printf 'edited\n' >"$HOME/two/skills/alpha/SKILL.md"
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"DIFFERS $HOME/two/skills/alpha"* ]]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	cmp -s "$HOME/two/skills/alpha/SKILL.md" "$ai/Skills/own/alpha/SKILL.md"
	[ "$(cat "$(find "$repo/Backups/Unix/SymbolicLinks/AiArtifacts.skills.alpha" -name SKILL.md)")" = edited ]
}

@test "no deploy line is a warning, not a failure, and touches nothing" {
	conf 'use rules Core'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"No harness to deploy into"* ]]
	[ ! -e "$HOME/one" ]
}

@test "the last deploy line for this machine type wins" {
	harness two 'skills each . ~/two/skills'
	conf 'deploy one' '@Test deploy two' '@Work deploy one two'
	CONF_MACHINE_TYPE=Test run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -L "$HOME/two/skills/alpha" ]
	[ ! -e "$HOME/one" ]
}

@test "an unknown harness and a malformed line warn; the rest deploys" {
	harness two 'skills sideways . ~/two/skills' 'bogus'
	conf 'deploy nope two one' 'use rules Core'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Harness [nope] of the deploy line is no section"* ]]
	[[ $output == *"Harness [two]: not KIND PLACEMENT FILES"*"skills sideways"* ]]
	[ -L "$HOME/one/skills/alpha" ]
}

@test "a path with spaces is the rest of the line" {
	harness two 'rules file RULES.md ~/Application Support/App/rules.md'
	conf 'deploy two' 'use rules Core'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/Application Support/App/rules.md")" = "$ai/Rules/own/Core/RULES.md" ]
}

@test "--kind deploys only those kinds" {
	run "${BASH:-bash}" "$cmd" --kind rules
	[ "$status" -eq 0 ]
	[ -L "$HOME/one/RULES.md" ]
	[ ! -e "$HOME/one/skills" ]
	run "${BASH:-bash}" "$cmd" --kind bogus
	[ "$status" -eq 1 ]
}

@test "a real folder where a link goes is backed up into the sink, then replaced" {
	mkdir -p "$HOME/one/skills/alpha"
	printf 'mine\n' >"$HOME/one/skills/alpha/notes.md"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/one/skills/alpha")" = "$ai/Skills/own/alpha" ]
	backup=$(find "$repo/Backups/Unix/SymbolicLinks/AiArtifacts.skills.alpha" -name notes.md)
	[ "$(cat "$backup")" = mine ]
}

@test "a real rules file is backed up under its kind, item and file name" {
	mkdir -p "$HOME/one"
	printf 'old rules\n' >"$HOME/one/RULES.md"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -L "$HOME/one/RULES.md" ]
	[ "$(cat "$(find "$repo/Backups/Unix/SymbolicLinks/AiArtifacts.rules.Core.RULES.md" -name RULES.md)")" = 'old rules' ]
}

@test "a failed backup leaves the folder in place and fails the run" {
	mkdir -p "$HOME/one/skills/alpha"
	printf 'mine\n' >"$HOME/one/skills/alpha/notes.md"
	printf 'file\n' >"$BATS_TEST_TMPDIR/sink"
	FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ ! -L "$HOME/one/skills/alpha" ]
	[ "$(cat "$HOME/one/skills/alpha/notes.md")" = mine ]
}

@test "prunes only dangling links into the artifacts root; other links are never touched" {
	mkdir -p "$HOME/one/skills"
	ln -s "$ai/Skills/own/gone" "$HOME/one/skills/gone"
	ln -s "$BATS_TEST_TMPDIR/elsewhere-gone" "$HOME/one/skills/foreign-dangling"
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere"
	ln -s "$BATS_TEST_TMPDIR/elsewhere" "$HOME/one/skills/foreign"
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"STALE   $HOME/one/skills/gone"* ]]
	[ -L "$HOME/one/skills/gone" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -L "$HOME/one/skills/gone" ]
	[ -L "$HOME/one/skills/foreign-dangling" ]
	[ -L "$HOME/one/skills/foreign" ]
}

@test "a folder destination that links into the repository becomes a real folder" {
	mkdir -p "$HOME/one"
	ln -s "$ai/Skills/own" "$HOME/one/skills"
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"WRONG   $HOME/one/skills is a folder link into the repository"* ]]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -d "$HOME/one/skills" ] && [ ! -L "$HOME/one/skills" ]
	[ -L "$HOME/one/skills/alpha" ]
}

@test "a folder destination that links elsewhere is skipped and fails the run" {
	mkdir -p "$HOME/one" "$BATS_TEST_TMPDIR/elsewhere"
	ln -s "$BATS_TEST_TMPDIR/elsewhere" "$HOME/one/skills"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"SKIPPED $HOME/one/skills (a link to somewhere Foundation does not manage)"* ]]
	[ -z "$(ls "$BATS_TEST_TMPDIR/elsewhere")" ]
	# The rules still deploy.
	[ -L "$HOME/one/RULES.md" ]
}

@test "+claude-plugin-dirs lists the mod links in the settings, keeps foreign entries and every other key" {
	mkdir -p "$ai/Mods/own/m1/.claude-plugin" "$ai/Mods/own/m2/.claude-plugin"
	printf '{"name":"m1"}\n' >"$ai/Mods/own/m1/.claude-plugin/plugin.json"
	printf '{"name":"m2"}\n' >"$ai/Mods/own/m2/.claude-plugin/plugin.json"
	harness two 'mods each . +claude-plugin-dirs ~/.claude/mods'
	conf 'deploy two'
	mkdir -p "$HOME/.claude"
	printf '{"theme":"dark","env":{"OTHER":"1","CLAUDE_CODE_PLUGIN_DIRS":"/opt/dev-mod:%s/.claude/mods/stale"}}\n' "$HOME" >"$HOME/.claude/settings.json"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -L "$HOME/.claude/mods/m1" ]
	value=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["env"]["CLAUDE_CODE_PLUGIN_DIRS"], d["theme"], d["env"]["OTHER"])' "$HOME/.claude/settings.json")
	[ "$value" = "$HOME/.claude/mods/m1:$HOME/.claude/mods/m2:/opt/dev-mod dark 1" ]
	# The CLI is missing: only a warning.
	[[ $output == *"Claude Code CLI (claude) not found"* ]]
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"is up to date"* ]]
	[[ $output == *"fully deployed"* ]]
}

@test "+claude-plugin-dirs: a CLI that rejects a mod only warns, naming it" {
	mkdir -p "$ai/Mods/own/m1/.claude-plugin" "$BATS_TEST_TMPDIR/bin"
	printf '{"name":"m1"}\n' >"$ai/Mods/own/m1/.claude-plugin/plugin.json"
	printf '#!/bin/sh\nexit 1\n' >"$BATS_TEST_TMPDIR/bin/foundation-test-claude"
	chmod +x "$BATS_TEST_TMPDIR/bin/foundation-test-claude"
	harness two 'mods each . +claude-plugin-dirs ~/.claude/mods'
	conf 'deploy two'
	PATH=$BATS_TEST_TMPDIR/bin:$PATH FOUNDATION_CLAUDE_CLI=foundation-test-claude run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"claude plugin validate failed for [m1]"* ]]
}

@test "+claude-plugin-dirs leaves an unparseable settings file untouched and fails" {
	mkdir -p "$ai/Mods/own/m1/.claude-plugin" "$HOME/.claude"
	printf '{"name":"m1"}\n' >"$ai/Mods/own/m1/.claude-plugin/plugin.json"
	printf 'not json\n' >"$HOME/.claude/settings.json"
	harness two 'mods each . +claude-plugin-dirs ~/.claude/mods'
	conf 'deploy two'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ "$(cat "$HOME/.claude/settings.json")" = 'not json' ]
}

@test "+managed-settings links through sudo; --check never calls it" {
	printf '{}\n' >"$ai/Rules/own/Core/managed-settings.json"
	stub_tool sudo 'exec "$@"'
	harness two "rules file managed-settings.json +managed-settings $BATS_TEST_TMPDIR/root/ClaudeCode/managed-settings.json"
	conf 'deploy two' 'use rules Core'
	run "${BASH:-bash}" "$cmd" --check
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$BATS_TEST_TMPDIR/root/ClaudeCode/managed-settings.json")" = "$ai/Rules/own/Core/managed-settings.json" ]
	grep -q '^sudo ln -s' "$BATS_TEST_TMPDIR/tool.log"
}

@test "+managed-settings leaves out a rules item without that file" {
	stub_tool sudo 'exec "$@"'
	harness two "rules file managed-settings.json +managed-settings $BATS_TEST_TMPDIR/root/managed-settings.json"
	conf 'deploy two' 'use rules Core'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Core has none of managed-settings.json - left out"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/root" ]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}

@test "the root line of ai-artifacts.conf moves where the artifacts are read from" {
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere/Skills/own/zeta"
	printf -- '---\nname: zeta\n---\n' >"$BATS_TEST_TMPDIR/elsewhere/Skills/own/zeta/SKILL.md"
	conf "root $BATS_TEST_TMPDIR/elsewhere" 'deploy one'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/one/skills/zeta")" = "$BATS_TEST_TMPDIR/elsewhere/Skills/own/zeta" ]
	[ ! -e "$HOME/one/skills/alpha" ]
}

@test "the base catalogue is inactive and every line of it is well formed" {
	cp "$UNIX_DIR/config/ai-artifacts.conf" "$UNIX_DIR/config/ai-harnesses.conf" "$FOUNDATION_CONFIG_DIR/"
	foundation_load config artifacts
	[ -z "$(ai_deployed_harnesses)" ]
	for name in claude-code codex gemini-cli copilot; do
		run ai_harness_destinations "$name"
		[ "$status" -eq 0 ] && [ -n "$output" ]
		[[ $output != *INVALID* ]]
	done
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"No harness to deploy into"* ]]
}
