#!/usr/bin/env bats
# Update-AiArtifacts against a fixture upstream served by a curl stub: one source feeds several
# kinds (skills by default, mods by plugin.json, agents from folders and NAME.md files), pinned to
# a commit, without the skipped paths and the excluded items, an UPSTREAM.md per kind folder, only
# ever replacing what the previous manifest vendored, --check, the GitHub token, and the failures
# that leave the vendored copy untouched.

load ../../helpers

sha=0123456789abcdef0123456789abcdef01234567

setup() {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	setup_foundation
	foundation_load skills
	use_empty_config
	export DOTFILES_ROOT=$BATS_TEST_TMPDIR/repo
	mkdir -p "$DOTFILES_ROOT/AI"
	export FAKE_SHA=$sha FIXTURE_TGZ=$BATS_TEST_TMPDIR/upstream.tgz
	# The archive (the public codeload URL, or the API tarball when authenticated) is the fixture;
	# any other GitHub API request is the commit lookup. Every call lands in tool.log.
	stub_tool curl 'case "$*" in *codeload.github.com* | */tarball/*) cat "$FIXTURE_TGZ" ;; *api.github.com*) printf "%s" "$FAKE_SHA" ;; esac'
	# Anonymous by default: no token variables and a signed-out GitHub CLI.
	unset GITHUB_TOKEN GH_TOKEN
	stub_tool gh 'exit 1'
	cmd=$UNIX_DIR/modules/AI/bin/Update-AiArtifacts
	ai=$DOTFILES_ROOT/AI
	up=$BATS_TEST_TMPDIR/up/Repo-$sha
}

pack() {
	tar -czf "$FIXTURE_TGZ" -C "$BATS_TEST_TMPDIR/up" .
}

# Adds an upstream skill FOLDER/NAME. Usage: upstream_skill FOLDER NAME
upstream_skill() {
	mkdir -p "$up/$1/$2"
	printf -- '---\nname: %s\ndescription: The %s skill.\n---\n' "$2" "$2" >"$up/$1/$2/SKILL.md"
}

# The upstream: skills/alpha and skills/beta (beta with a tests folder), a folder without SKILL.md,
# plugins/neon (a mod named by its plugin.json), agents/reviewer/ and agents/linter.md, a license.
default_upstream() {
	rm -rf "$BATS_TEST_TMPDIR/up"
	upstream_skill skills alpha
	upstream_skill skills beta
	mkdir -p "$up/skills/beta/tests" "$up/skills/not-a-skill" "$up/plugins/neon-src/.claude-plugin" "$up/plugins/neon-src/design" "$up/agents/reviewer"
	printf 'test\n' >"$up/skills/beta/tests/t.sh"
	printf '{"name":"neon","description":"A | mod"}\n' >"$up/plugins/neon-src/.claude-plugin/plugin.json"
	printf 'png\n' >"$up/plugins/neon-src/design/shot.png"
	printf -- '---\ndescription: Reviews code.\n---\n' >"$up/agents/reviewer/claude.md"
	printf -- '---\ndescription: Lints code.\n---\n' >"$up/agents/linter.md"
	printf 'readme\n' >"$up/agents/README.md"
	printf 'MIT\n' >"$up/LICENSE"
	pack
}

# A fingerprint of everything under AI: every path and every file's bytes.
snapshot() {
	(
		cd "$ai" || exit 1
		find . -print | LC_ALL=C sort
		find . -type f -print0 | LC_ALL=C sort -z | xargs -0 cat
	) | cksum
}

conf() {
	printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
}

@test "without a kind line it vendors skills from the skills folder, pinned, with UPSTREAM.md and the license" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo' 'ref v1'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -f "$ai/Skills/vendor/alpha/SKILL.md" ]
	[ -f "$ai/Skills/vendor/beta/SKILL.md" ]
	[ ! -e "$ai/Skills/vendor/not-a-skill" ]
	# The default skip list leaves an item's tests folder upstream.
	[ ! -e "$ai/Skills/vendor/beta/tests" ]
	[ -f "$ai/Skills/vendor/LICENSE.Owner-Repo.txt" ]
	grep -qF -- "- **Commit:** \`$sha\` (ref \`v1\`)" "$ai/Skills/vendor/UPSTREAM.md"
	grep -qF '| `alpha` | `skills` | The alpha skill. |' "$ai/Skills/vendor/UPSTREAM.md"
	grep -qF 're-run `Update-AiArtifacts vendor` to refresh' "$ai/Skills/vendor/UPSTREAM.md"
	[ "$(skill_manifest_skills "$ai/Skills/vendor/UPSTREAM.md" | paste -sd, -)" = alpha,beta ]
	[ ! -e "$ai/Mods" ]
}

@test "one source feeds several kinds, each into its own folder with its own manifest" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo' 'skills skills' 'mods plugins' 'agents agents'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -f "$ai/Skills/vendor/alpha/SKILL.md" ]
	# A mod is named by its plugin.json and copied without the skipped paths.
	[ -f "$ai/Mods/vendor/neon/.claude-plugin/plugin.json" ]
	[ ! -e "$ai/Mods/vendor/neon/design" ]
	grep -qF '| `neon` | `plugins` | A \| mod |' "$ai/Mods/vendor/UPSTREAM.md"
	grep -qF '# Vendored AI mods: vendor' "$ai/Mods/vendor/UPSTREAM.md"
	# Agents: a folder is an item as it is; a NAME.md file becomes item NAME holding AGENT.md.
	[ -f "$ai/Agents/vendor/reviewer/claude.md" ]
	[ "$(cat "$ai/Agents/vendor/linter/AGENT.md")" = "$(cat "$up/agents/linter.md")" ]
	[ ! -e "$ai/Agents/vendor/README" ]
	[ "$(skill_manifest_skills "$ai/Agents/vendor/UPSTREAM.md" | paste -sd, -)" = linter,reviewer ]
	[ -f "$ai/Agents/vendor/LICENSE.Owner-Repo.txt" ]
}

@test "exclusions and an empty skip list" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo' 'exclude alpha' 'skip'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$ai/Skills/vendor/alpha" ]
	[ -f "$ai/Skills/vendor/beta/tests/t.sh" ]
	grep -qF -- '- **Excluded:** `alpha`' "$ai/Skills/vendor/UPSTREAM.md"
}

@test "replaces only what the previous manifest vendored; hand-made folders survive" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo'
	"${BASH:-bash}" "$cmd" >/dev/null 2>&1
	mkdir -p "$ai/Skills/vendor/mine"
	printf 'keep\n' >"$ai/Skills/vendor/mine/SKILL.md"
	rm -rf "$up/skills/beta"
	pack
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$ai/Skills/vendor/beta" ]
	[ -f "$ai/Skills/vendor/mine/SKILL.md" ]
	[[ $output == *"Removed skills no longer vendored => [beta]"* ]]
}

@test "--check reports not vendored, up to date and behind without writing" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo'
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *"Not vendored yet"* ]]
	[ ! -e "$ai/Skills" ]
	"${BASH:-bash}" "$cmd" >/dev/null 2>&1
	run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"Up to date at ${sha:0:7}"* ]]
	FAKE_SHA=fedcba9876543210fedcba9876543210fedcba98 run "${BASH:-bash}" "$cmd" --check
	[[ $output == *"Behind upstream"*"run Update-AiArtifacts vendor"* ]]
}

@test "named sources only, a comma list names several; an unknown one fails while the others vendor" {
	default_upstream
	conf '[one]' 'repository Owner/Repo' '[two]' 'repository Owner/Repo' '[three]' 'repository Owner/Repo'
	run "${BASH:-bash}" "$cmd" one,three nope
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown AI artifact source => [nope]"* ]]
	[ -d "$ai/Skills/one" ] && [ -d "$ai/Skills/three" ]
	[ ! -e "$ai/Skills/two" ]
}

@test "no sources configured is a warning, not a failure" {
	conf 'deploy claude-code'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"No AI artifact sources configured"* ]]
	rm "$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
}

@test "anonymous without a token: no Authorization header, the public archive" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	! grep -q 'Authorization' "$BATS_TEST_TMPDIR/tool.log" || false
	grep -q "codeload.github.com/Owner/Repo/tar.gz/$sha" "$BATS_TEST_TMPDIR/tool.log"
}

@test "GITHUB_TOKEN authenticates both requests, then GH_TOKEN, then the GitHub CLI's token" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo'
	GITHUB_TOKEN=env-token run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(grep -c 'Authorization: Bearer env-token' "$BATS_TEST_TMPDIR/tool.log")" -eq 2 ]
	grep -q "api.github.com/repos/Owner/Repo/tarball/$sha" "$BATS_TEST_TMPDIR/tool.log"
	[[ $output != *env-token* ]]
	GH_TOKEN=gh-env-token run "${BASH:-bash}" "$cmd" --check
	grep -q 'Authorization: Bearer gh-env-token' "$BATS_TEST_TMPDIR/tool.log"
	stub_tool gh 'echo cli-token'
	run "${BASH:-bash}" "$cmd" --check
	grep -q 'Authorization: Bearer cli-token' "$BATS_TEST_TMPDIR/tool.log"
}

@test "an unresolvable ref fails, hints at a private repository without a token, and downloads nothing" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo'
	FAKE_SHA=not-a-sha run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"private"*"GITHUB_TOKEN"* ]]
	! grep -q 'codeload' "$BATS_TEST_TMPDIR/tool.log" || false
	[ ! -e "$ai/Skills" ]
}

@test "a repository not in owner/name form fails before any request" {
	conf '[vendor]' 'repository not-a-repository'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"owner/name"* ]]
	! grep -q '^curl' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "a failed download, an empty archive or an upstream without items leaves the vendored copy byte-identical" {
	default_upstream
	conf '[vendor]' 'repository Owner/Repo' 'agents agents' 'skills skills'
	"${BASH:-bash}" "$cmd" >/dev/null 2>&1
	before=$(snapshot)
	FIXTURE_TGZ=$BATS_TEST_TMPDIR/no-such-archive.tgz run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"Downloading the archive failed"* ]]
	[ "$(snapshot)" = "$before" ]
	rm -rf "$BATS_TEST_TMPDIR/up"
	mkdir -p "$BATS_TEST_TMPDIR/up"
	pack
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[ "$(snapshot)" = "$before" ]
	rm -rf "$BATS_TEST_TMPDIR/up"
	mkdir -p "$up/skills/empty" "$up/agents"
	pack
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"No skills found"* ]]
	[[ $output == *"No agents found"* ]]
	[ "$(snapshot)" = "$before" ]
}

@test "the root line of ai-artifacts.conf moves where artifacts are vendored" {
	default_upstream
	conf "root $BATS_TEST_TMPDIR/elsewhere" '[vendor]' 'repository Owner/Repo'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -f "$BATS_TEST_TMPDIR/elsewhere/Skills/vendor/alpha/SKILL.md" ]
	[ ! -e "$ai/Skills" ]
}

# A local upstream for the manifest tests, reached through git's url.<base>.insteadOf (set in the
# environment only), so https://github.com/up/skills never leaves the test folder. Sets
# REMOTE_SHA to its head. Usage: manifest_upstream
manifest_upstream() {
	local remote=$BATS_TEST_TMPDIR/remotes/skills
	mkdir -p "$remote/skills/tdd"
	printf -- '---\nname: tdd\ndisable-model-invocation: true\n---\nbody\n' >"$remote/skills/tdd/SKILL.md"
	git -C "$remote" init -q
	git -C "$remote" add -A
	git -C "$remote" -c user.name=t -c user.email=t@example.com commit -qm one
	REMOTE_SHA=$(git -C "$remote" rev-parse HEAD)
	export GIT_CONFIG_COUNT=1 GIT_CONFIG_KEY_0="url.$remote.insteadOf" GIT_CONFIG_VALUE_0=https://github.com/up/skills
	export FOUNDATION_AI_MANIFEST_CACHE=$BATS_TEST_TMPDIR/cache
	printf 'name\tkind\tscope\tsource\tref\tpath\tinstall\n' >"$BATS_TEST_TMPDIR/m.tsv"
	printf 'tdd\tskills\t*\thttps://github.com/up/skills\t%s\tskills/tdd\tclone rename=tdd2 strip-invocation-guard\n' "$REMOTE_SHA" >>"$BATS_TEST_TMPDIR/m.tsv"
	printf 'work\tskills\tWork\thttps://github.com/up/skills\t%s\tskills/work\tclone\n' "$REMOTE_SHA" >>"$BATS_TEST_TMPDIR/m.tsv"
	printf '[pm]\nmanifest %s\n' "$BATS_TEST_TMPDIR/m.tsv" >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
}

# bats test_tags=integration
@test "a manifest source: the pinned clone is fetched once, the derived copy made, nothing vendored" {
	manifest_upstream
	run "${BASH:-bash}" "$cmd" pm
	[ "$status" -eq 0 ]
	clone=$FOUNDATION_AI_MANIFEST_CACHE/up/skills/$REMOTE_SHA
	[ -f "$clone/skills/tdd/SKILL.md" ]
	[ "$(git -C "$clone" rev-parse HEAD)" = "$REMOTE_SHA" ]
	grep -qx 'name: tdd2' "$clone.derived/tdd2/SKILL.md"
	! grep -q disable-model-invocation "$clone.derived/tdd2/SKILL.md" || false
	[ ! -e "$ai/Skills/pm" ]
	# No curl: a manifest source never reaches the GitHub API.
	! grep -q '^curl' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || false
	# A second run fetches nothing: the clone is kept as it is.
	touch "$clone/marker"
	run "${BASH:-bash}" "$cmd" pm
	[ "$status" -eq 0 ]
	[[ $output == *"(0 clone(s) fetched)"* ]]
	[ -e "$clone/marker" ]
}

# bats test_tags=integration
@test "a manifest source --check compares each pin with the upstream default branch" {
	manifest_upstream
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *"Every pin (1 row(s)) is at its upstream default branch"* ]]
	[ ! -e "$FOUNDATION_AI_MANIFEST_CACHE" ]
	git -C "$BATS_TEST_TMPDIR/remotes/skills" -c user.name=t -c user.email=t@example.com commit -q --allow-empty -m two
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *"tdd: up/skills has moved to"*"pinned at ${REMOTE_SHA:0:7}"* ]]
}

# bats test_tags=integration
@test "a manifest row that cannot be fetched fails the run and leaves no partial clone" {
	manifest_upstream
	sed -i.bak "s/$REMOTE_SHA/ffffffffffffffffffffffffffffffffffffffff/" "$BATS_TEST_TMPDIR/m.tsv"
	run "${BASH:-bash}" "$cmd" pm
	[ "$status" -eq 1 ]
	[ ! -e "$FOUNDATION_AI_MANIFEST_CACHE/up/skills/ffffffffffffffffffffffffffffffffffffffff" ]
	[ -z "$(find "$FOUNDATION_AI_MANIFEST_CACHE" -name '.fetch.*' 2>/dev/null)" ]
}

@test "a checkout source has nothing to vendor" {
	printf '[pm]\ncheckout %s\n' "$BATS_TEST_TMPDIR" >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"checkout source"*"nothing to vendor"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ] || ! grep -q '^curl' "$BATS_TEST_TMPDIR/tool.log"
}
