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
	# A manifest fetch never reaches the network (local_github, below).
	export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$BATS_TEST_TMPDIR/no-github/.insteadOf" GIT_CONFIG_VALUE_0=https://github.com/
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

@test "+managed-settings writes a root-owned rendered copy through sudo; --check never calls it" {
	printf '{"hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[{"type":"command","command":"bash \\"{ManagedDir}/hooks/policy.sh\\""}]}]}}\n' >"$ai/Rules/own/Core/managed-settings.json"
	mkdir -p "$ai/Rules/own/Core/hooks"
	printf 'echo policy\n' >"$ai/Rules/own/Core/hooks/policy.sh"
	# chown root:wheel cannot run as the test user: the stand-in logs it and succeeds.
	stub_tool sudo 'case "$1" in chown) exit 0 ;; esac; exec "$@"'
	dir=$BATS_TEST_TMPDIR/root/ClaudeCode
	harness two "rules file managed-settings.json +managed-settings $dir/managed-settings.json"
	conf 'deploy two' 'use rules Core'
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"MISSING $dir/managed-settings.json"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -f "$dir/managed-settings.json" ] && [ ! -L "$dir/managed-settings.json" ]
	grep -qF "bash \\\"$dir/hooks/policy.sh\\\"" "$dir/managed-settings.json"
	! grep -q 'ManagedDir' "$dir/managed-settings.json" || false
	! grep -q forceLoginOrgUUID "$dir/managed-settings.json" || false
	cmp -s "$dir/hooks/policy.sh" "$ai/Rules/own/Core/hooks/policy.sh"
	grep -q "^sudo chown root:wheel $dir/managed-settings.json" "$BATS_TEST_TMPDIR/tool.log"
	grep -q "^sudo chmod 644 $dir/managed-settings.json" "$BATS_TEST_TMPDIR/tool.log"
	# Without a profile: no guard and no ai-profile.conf.
	[ ! -e "$dir/ai-ownership-guard.sh" ] && [ ! -e "$dir/ai-profile.conf" ]
	# Rewritten only when the rendering differs.
	rm "$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"fully deployed"* ]]
}

@test "+managed-settings replaces the link of an earlier run with the copy" {
	printf '{}\n' >"$ai/Rules/own/Core/managed-settings.json"
	stub_tool sudo 'case "$1" in chown) exit 0 ;; esac; exec "$@"'
	dir=$BATS_TEST_TMPDIR/root/ClaudeCode
	mkdir -p "$dir"
	ln -s "$ai/Rules/own/Core/managed-settings.json" "$dir/managed-settings.json"
	harness two "rules file managed-settings.json +managed-settings $dir/managed-settings.json"
	conf 'deploy two' 'use rules Core'
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"WRONG   $dir/managed-settings.json"* ]]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -f "$dir/managed-settings.json" ] && [ ! -L "$dir/managed-settings.json" ]
	[ -f "$ai/Rules/own/Core/managed-settings.json" ]
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

# Writes ai-profiles.conf, one argument per line. Usage: profiles LINE...
profiles() {
	printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
}

# The full SHA every manifest row of these tests pins.
SHA=0123456789abcdef0123456789abcdef01234567

# A skill in the manifest cache: OWNER/REPO at $SHA, PATH/SKILL.md with an invocation guard.
# Usage: cached_skill OWNER REPO PATH NAME
cached_skill() {
	local dir=$FOUNDATION_AI_MANIFEST_CACHE/$1/$2/$SHA/$3
	mkdir -p "$dir"
	printf -- '---\nname: %s\ndisable-model-invocation: true\ndescription: cached\n---\nbody\n' "$4" >"$dir/SKILL.md"
}

# Points every https://github.com/ URL git sees at a local folder of the test (environment only), so
# a manifest fetch never reaches the network; a missing folder makes every fetch fail fast.
# Usage: local_github [FOLDER]
local_github() {
	export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.${1:-$BATS_TEST_TMPDIR/no-github}/.insteadOf" GIT_CONFIG_VALUE_0=https://github.com/
}

# Writes the manifest of a [pm] manifest source, one row per argument (already tab-separated).
# Usage: manifest ROW...
manifest() {
	printf 'name\tkind\tscope\tsource\tref\tpath\tinstall\n' >"$BATS_TEST_TMPDIR/manifest.tsv"
	printf '%s\n' "$@" >>"$BATS_TEST_TMPDIR/manifest.tsv"
	printf '[pm]\nmanifest %s\n' "$BATS_TEST_TMPDIR/manifest.tsv" >>"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
}

@test "an AI profile's rules, deploy, include and exclude lines win; profiles off changes nothing" {
	rules own Other other-rules
	skill own gamma
	harness two 'skills each . ~/two/skills' 'rules file RULES.md ~/two/RULES.md'
	profiles 'default Work' '[Work]' 'rules Other' 'deploy two' 'include skills/alpha skills/gamma' 'exclude skills/gamma'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"AI profile      : Work (by default)"* ]]
	[ ! -e "$HOME/one" ]
	[ "$(readlink "$HOME/two/RULES.md")" = "$ai/Rules/own/Other/RULES.md" ]
	[ -L "$HOME/two/skills/alpha" ]
	[ ! -e "$HOME/two/skills/beta" ]
	[ ! -e "$HOME/two/skills/gamma" ]
}

@test "the override picks the profile; one naming no profile stops the run" {
	harness two 'skills each . ~/two/skills'
	profiles 'default Work' '[Work]' '[Home]' 'deploy two'
	FOUNDATION_AI_PROFILE=home run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"AI profile      : Home (by override)"* ]]
	[ -L "$HOME/two/skills/alpha" ]
	FOUNDATION_AI_PROFILE=Nope run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"[Nope], which is no section"* ]]
}

@test "+managed-settings with a profile pins its Plan, wires the guard and writes ai-profile.conf" {
	printf '{"forceLoginMethod":"claudeai"}\n' >"$ai/Rules/own/Core/managed-settings.json"
	stub_tool sudo 'case "$1" in chown) exit 0 ;; esac; exec "$@"'
	dir=$BATS_TEST_TMPDIR/root/ClaudeCode
	harness two "rules file managed-settings.json +managed-settings $dir/managed-settings.json"
	conf 'deploy two' 'use rules Core'
	profiles 'default Personal' 'default-owner personal' 'shared github.com/me/shared' \
		'[Personal]' 'plan Max 00000000-0000-0000-0000-000000000000' 'unattended on' 'autonomous github.com/me/mine' \
		'[Work]' 'plan Team 11111111-1111-1111-1111-111111111111' 'owns github.com/org/*' 'autonomous github.com/org/x'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	value=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); print(d["forceLoginOrgUUID"], d["hooks"]["UserPromptSubmit"][0]["hooks"][0]["command"], d["hooks"]["PreToolUse"][0]["matcher"])' "$dir/managed-settings.json")
	[ "$value" = "00000000-0000-0000-0000-000000000000 bash \"$dir/ai-ownership-guard.sh\" UserPromptSubmit *" ]
	cmp -s "$dir/ai-ownership-guard.sh" "$(dirname "$UNIX_DIR")/AI/Hooks/ai-ownership-guard.sh"
	[ "$(cat "$dir/ai-profile.conf")" = "# Written by Deploy-AiArtifacts from the AI profile configuration; do not edit.
profile Personal
default-owner Personal
unattended on
plan Max 00000000-0000-0000-0000-000000000000
shared github.com/me/shared
owns Work github.com/org/*
autonomous github.com/me/mine" ]
	# A changed Plan is a changed rendering: --check reports it, the next run rewrites it.
	profiles 'default Personal' '[Personal]' 'plan Max 22222222-2222-2222-2222-222222222222 33333333-3333-3333-3333-333333333333'
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"DIFFERS $dir/managed-settings.json"* ]]
	run "${BASH:-bash}" "$cmd"
	value=$(python3 -c 'import json,sys; print(json.load(open(sys.argv[1]))["forceLoginOrgUUID"])' "$dir/managed-settings.json")
	[ "$value" = "['22222222-2222-2222-2222-222222222222', '33333333-3333-3333-3333-333333333333']" ]
}

@test "a checkout source links its items in place, after own and before the product skills" {
	mkdir -p "$BATS_TEST_TMPDIR/checkout/skills/delta" "$BATS_TEST_TMPDIR/checkout/skills/group/alpha" "$BATS_TEST_TMPDIR/checkout/skills/product"
	printf -- '---\nname: delta\n---\n' >"$BATS_TEST_TMPDIR/checkout/skills/delta/SKILL.md"
	printf -- '---\nname: alpha\n---\n' >"$BATS_TEST_TMPDIR/checkout/skills/group/alpha/SKILL.md"
	printf -- '---\nname: product\n---\n' >"$BATS_TEST_TMPDIR/checkout/skills/product/SKILL.md"
	skill foundation product
	printf '[pm]\ncheckout %s\n' "$BATS_TEST_TMPDIR/checkout" >>"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/one/skills/delta")" = "$BATS_TEST_TMPDIR/checkout/skills/delta" ]
	[ "$(readlink "$HOME/one/skills/alpha")" = "$ai/Skills/own/alpha" ]
	[ "$(readlink "$HOME/one/skills/product")" = "$BATS_TEST_TMPDIR/checkout/skills/product" ]
	[[ $output == *"Duplicate skill [product]"*"keeping the one from [pm]"* ]]
	# Nothing is copied into the artifacts root for it.
	[ ! -e "$ai/Skills/pm" ]
}

@test "a missing checkout folder warns and the rest deploys" {
	printf '[pm]\ncheckout %s\n' "$BATS_TEST_TMPDIR/nowhere" >>"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Checkout source [pm]"*"is not a folder on this machine"* ]]
	[ -L "$HOME/one/skills/alpha" ]
}

@test "the product skills now win over a vendored source whose name sorts first" {
	skill foundation zeta
	skill aaa zeta
	printf '[aaa]\nrepository Owner/Repo\n' >>"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$(readlink "$HOME/one/skills/zeta")" = "$ai/Skills/foundation/zeta" ]
}

@test "manifest rows: scope, rename and strip-invocation-guard through a derived copy, never the clone" {
	export FOUNDATION_AI_MANIFEST_CACHE=$BATS_TEST_TMPDIR/cache
	cached_skill up skills skills/tdd tdd
	cached_skill up skills skills/plain plain
	cached_skill up skills skills/work work
	manifest "tdd	skills	*	https://github.com/up/skills	$SHA	skills/tdd	clone rename=tdd2 strip-invocation-guard" \
		"plain	skills	*	https://github.com/up/skills.git	$SHA	skills/plain	clone" \
		"work	skills	Work	https://github.com/up/skills	$SHA	skills/work	clone" \
		"bad	skills	*	https://example.com/up/skills	$SHA	skills/bad	clone"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	clone=$FOUNDATION_AI_MANIFEST_CACHE/up/skills/$SHA
	[ "$(readlink "$HOME/one/skills/plain")" = "$clone/skills/plain" ]
	[ "$(readlink "$HOME/one/skills/tdd2")" = "$clone.derived/tdd2" ]
	[ ! -e "$HOME/one/skills/tdd" ]
	# Without a profile only the * rows are read.
	[ ! -e "$HOME/one/skills/work" ]
	[[ $output == *"source is not https://github.com/OWNER/REPO"* ]]
	grep -qx 'name: tdd2' "$clone.derived/tdd2/SKILL.md"
	! grep -q disable-model-invocation "$clone.derived/tdd2/SKILL.md" || false
	grep -q disable-model-invocation "$clone/skills/tdd/SKILL.md"
	grep -qx 'name: tdd' "$clone/skills/tdd/SKILL.md"
	profiles 'default Work' '[Work]'
	run "${BASH:-bash}" "$cmd"
	[ "$(readlink "$HOME/one/skills/work")" = "$clone/skills/work" ]
}

@test "a manifest row whose fetch fails warns, is left out, and does not fail the run" {
	export FOUNDATION_AI_MANIFEST_CACHE=$BATS_TEST_TMPDIR/cache
	local_github
	manifest "gone	skills	*	https://github.com/up/skills	$SHA	skills/gone	clone"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[pm] Could not fetch up/skills@0123456 (row gone)"* ]]
	[[ $output == *"row gone (up/skills@0123456) is not fetched yet"* ]]
	[ ! -e "$HOME/one/skills/gone" ]
	[ -z "$(find "$FOUNDATION_AI_MANIFEST_CACHE" -name '.fetch.*' 2>/dev/null)" ]
}

# bats test_tags=integration
@test "a missing pinned clone is fetched before linking, once, and --check fetches nothing" {
	export FOUNDATION_AI_MANIFEST_CACHE=$BATS_TEST_TMPDIR/cache
	remote=$BATS_TEST_TMPDIR/github/up/skills
	mkdir -p "$remote/skills/tdd"
	printf -- '---\nname: tdd\ndisable-model-invocation: true\n---\n' >"$remote/skills/tdd/SKILL.md"
	git -C "$remote" init -q
	git -C "$remote" add -A
	git -C "$remote" -c user.name=t -c user.email=t@example.com commit -qm one
	sha=$(git -C "$remote" rev-parse HEAD)
	local_github "$BATS_TEST_TMPDIR/github"
	manifest "tdd	skills	*	https://github.com/up/skills	$sha	skills/tdd	clone rename=tdd2 strip-invocation-guard"
	run "${BASH:-bash}" "$cmd" --check
	[ ! -e "$FOUNDATION_AI_MANIFEST_CACHE" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[pm] fetching up/skills@${sha:0:7}"*"[pm] fetched up/skills@${sha:0:7}"* ]]
	clone=$FOUNDATION_AI_MANIFEST_CACHE/up/skills/$sha
	[ "$(readlink "$HOME/one/skills/tdd2")" = "$clone.derived/tdd2" ]
	grep -qx 'name: tdd2' "$clone.derived/tdd2/SKILL.md"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output != *"fetched up/skills"* ]]
	[[ $output != *"fetching up/skills"* ]]
}

@test "own and exclude by the row's owner beat a manifest row" {
	export FOUNDATION_AI_MANIFEST_CACHE=$BATS_TEST_TMPDIR/cache
	cached_skill up skills skills/alpha alpha
	cached_skill up skills skills/omega omega
	conf 'deploy one' 'use rules Core' 'exclude skills/up/omega'
	manifest "alpha	skills	*	https://github.com/up/skills	$SHA	skills/alpha	clone" \
		"omega	skills	*	https://github.com/up/skills	$SHA	skills/omega	clone"
	run "${BASH:-bash}" "$cmd"
	[ "$(readlink "$HOME/one/skills/alpha")" = "$ai/Skills/own/alpha" ]
	[[ $output == *"Duplicate skill [alpha]"*"keeping the one from [own]"* ]]
	[ ! -e "$HOME/one/skills/omega" ]
}

@test "a repo: row is linked into that repository's .claude/skills and listed in its .git/info/exclude" {
	export FOUNDATION_AI_MANIFEST_CACHE=$BATS_TEST_TMPDIR/cache
	cached_skill up design design design
	target=$BATS_TEST_TMPDIR/MyRepo
	git init -q "$target"
	printf '[Private]\nMyRepo /me/MyRepo.git %s\n' "$target" >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	manifest "design	skills	repo:MyRepo	https://github.com/up/design	$SHA	design	clone" \
		"other	skills	repo:Elsewhere	https://github.com/up/design	$SHA	design	clone"
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"MISSING $target/.claude/skills/design"* ]]
	[ ! -e "$target/.claude" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$target/.claude/skills/design")" = "$FOUNDATION_AI_MANIFEST_CACHE/up/design/$SHA/design" ]
	[ "$(grep -cx '/.claude/skills/design' "$target/.git/info/exclude")" -eq 1 ]
	[[ $output == *"repository [Elsewhere] of a manifest row is not on this machine"* ]]
	# Not in the harness destinations, and a second run adds no second exclude line.
	[ ! -e "$HOME/one/skills/design" ]
	run "${BASH:-bash}" "$cmd"
	[ "$(grep -cx '/.claude/skills/design' "$target/.git/info/exclude")" -eq 1 ]
	[ -z "$(git -C "$target" status --porcelain)" ]
}
