#!/usr/bin/env bats
# lib/aiprofile.sh and the manifest readers of lib/artifacts.sh against a throwaway config: which
# profile a machine runs (override, host line, default, none), the profile's lines, the
# ai-profile.conf text, the managed settings rendering, and the manifest rows and their scope.

load helpers

setup() {
	setup_foundation
	use_empty_config
	foundation_load aiprofile artifacts
	# The host name the resolver sees.
	foundation_hostname() { printf '%s' "${TEST_HOST:-My-Mac}"; }
	unset FOUNDATION_AI_PROFILE
}

# Writes ai-profiles.conf, one argument per line. Usage: profiles LINE...
profiles() {
	printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
}

@test "no file or no section: profiles are off" {
	run ai_profile_load
	[ "$status" -eq 1 ]
	profiles 'default Personal'
	run ai_profile_load
	[ "$status" -eq 1 ]
}

@test "the override, then the last matching host line, then the default" {
	profiles 'host other-mac Work' 'host MY-MAC Work' 'default Personal' '[Personal]' '[Work]' '[Home]'
	ai_profile_load
	[ "$AI_PROFILE" = Work ] && [ "$AI_PROFILE_HOW" = hostname ]
	TEST_HOST=Unmapped
	ai_profile_load
	[ "$AI_PROFILE" = Personal ] && [ "$AI_PROFILE_HOW" = default ]
	FOUNDATION_AI_PROFILE=home
	ai_profile_load
	[ "$AI_PROFILE" = Home ] && [ "$AI_PROFILE_HOW" = override ]
}

@test "a name that is no section, or nothing picking one, fails with the reason" {
	profiles 'default Nope' '[Personal]'
	run ai_profile_load
	[ "$status" -eq 2 ]
	ai_profile_load || true
	[ -z "$AI_PROFILE" ]
	[[ $AI_PROFILE_ERROR == *"[Nope], which is no section"* ]]
	profiles '[Personal]'
	run ai_profile_load
	[ "$status" -eq 2 ]
}

@test "machine-type lines work inside and outside the profiles" {
	profiles 'default Personal' '@Work default Work' '[Personal]' 'mcp a' '@Work mcp b' '[Work]'
	CONF_MACHINE_TYPE=Test ai_profile_load
	[ "$AI_PROFILE" = Personal ]
	[ "$(CONF_MACHINE_TYPE=Test ai_profile_words mcp)" = a ]
	CONF_MACHINE_TYPE=Work ai_profile_load
	[ "$AI_PROFILE" = Work ]
	[ "$(CONF_MACHINE_TYPE=Work ai_profile_words mcp Personal | paste -sd' ' -)" = 'a b' ]
}

@test "profile lines: words never glob, a bare line counts, the last value wins" {
	touch "$BATS_TEST_TMPDIR/github.com"
	profiles 'default P' '[P]' 'owns github.com/org/* github.com/x/y' 'owns *' 'mcp' 'unattended off' 'unattended on'
	ai_profile_load
	[ "$(ai_profile_words owns | paste -sd' ' -)" = 'github.com/org/* github.com/x/y *' ]
	ai_profile_has mcp
	[ -z "$(ai_profile_words mcp)" ]
	! ai_profile_has marketplaces || false
	ai_profile_unattended
	[ "$(ai_profile_value unattended)" = on ]
}

@test "ai_profile_conf_text: the active profile, every profile's owns, only its own autonomous lines" {
	profiles 'default A' 'default-owner b' 'shared github.com/me/s1 github.com/me/s2' \
		'[A]' 'plan Max u1 u2' 'autonomous github.com/me/a' 'owns github.com/me/*' \
		'[B]' 'owns github.com/org/*' 'autonomous github.com/org/b'
	ai_profile_load
	[ "$(ai_profile_conf_text)" = "# Written by Deploy-AiArtifacts from the AI profile configuration; do not edit.
profile A
default-owner B
unattended off
plan Max u1 u2
shared github.com/me/s1
shared github.com/me/s2
owns A github.com/me/*
owns B github.com/org/*
autonomous github.com/me/a" ]
}

@test "ai_render_managed_settings: the token always, the Plan and the guard only with a profile" {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	printf '{"a":"bash \\"{ManagedDir}/hooks/x.sh\\"","hooks":{"PreToolUse":[{"matcher":"Bash","hooks":[]}]}}\n' >"$BATS_TEST_TMPDIR/ms.json"
	run ai_render_managed_settings "$BATS_TEST_TMPDIR/ms.json" "/Library/Application Support/ClaudeCode"
	[ "$status" -eq 0 ]
	[[ $output == *'"a": "bash \"/Library/Application Support/ClaudeCode/hooks/x.sh\""'* ]]
	[[ $output != *forceLoginOrgUUID* ]] && [[ $output != *ai-ownership-guard* ]]
	profiles 'default P' '[P]' 'plan Max 0000000A-0000-0000-0000-000000000000'
	ai_profile_load
	ai_render_managed_settings "$BATS_TEST_TMPDIR/ms.json" /m >"$BATS_TEST_TMPDIR/out.json"
	value=$(python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); h=d["hooks"]; print(d["forceLoginOrgUUID"], len(h["PreToolUse"]), h["PreToolUse"][1]["matcher"], h["UserPromptSubmit"][0]["hooks"][0]["command"])' "$BATS_TEST_TMPDIR/out.json")
	[ "$value" = '0000000a-0000-0000-0000-000000000000 2 * bash "/m/ai-ownership-guard.sh" UserPromptSubmit' ]
	printf 'not json' >"$BATS_TEST_TMPDIR/bad.json"
	run ai_render_managed_settings "$BATS_TEST_TMPDIR/bad.json" /m
	[ "$status" -ne 0 ]
}

@test "ai_render_managed_settings: a plan line without a valid UUID fails closed, no plan line renders unpinned" {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	printf '{"hooks":{}}\n' >"$BATS_TEST_TMPDIR/ms.json"
	profiles 'default P' '[P]' 'plan Max a1d81f3-30fc-42e8-8804-285c2cd4dcf7'
	ai_profile_load
	run ai_render_managed_settings "$BATS_TEST_TMPDIR/ms.json" /m
	[ "$status" -ne 0 ]
	[[ $output == *"names no valid org UUID (a1d81f3-30fc-42e8-8804-285c2cd4dcf7)"* ]]
	[[ $output != *'"hooks"'* ]]
	profiles 'default P' '[P]' 'plan Max'
	ai_profile_load
	run ai_render_managed_settings "$BATS_TEST_TMPDIR/ms.json" /m
	[ "$status" -ne 0 ]
	profiles 'default P' '[P]'
	ai_profile_load
	run ai_render_managed_settings "$BATS_TEST_TMPDIR/ms.json" /m
	[ "$status" -eq 0 ]
	[[ $output != *forceLoginOrgUUID* ]]
}

@test "ai_manifest_rows: valid rows, a header, comments, CRLF and every reason a row is skipped" {
	sha=0123456789abcdef0123456789abcdef01234567
	{
		printf 'name\tkind\tscope\tsource\tref\tpath\tinstall\r\n'
		printf '# a comment\n\n'
		printf 'tdd\tSkills\t*\thttps://github.com/Owner/Repo.git\t%s\tskills/tdd\tclone rename=tdd2 strip-invocation-guard\r\n' "$sha"
		printf 'a\tskills\t*\thttps://gitlab.com/o/r\t%s\tp\tclone\n' "$sha"
		printf 'b\tskills\t*\thttps://github.com/o/r\tmain\tp\tclone\n' "$sha"
		printf 'c\tbogus\t*\thttps://github.com/o/r\t%s\tp\tclone\n' "$sha"
		printf 'd\tskills\t*\thttps://github.com/o/r\t%s\t../p\tclone\n' "$sha"
		printf 'e\tskills\t*\thttps://github.com/o/r\t%s\tp\tcopy\n' "$sha"
		printf 'f\tskills\t*\thttps://github.com/o/r\t%s\tp\tclone sideways\n' "$sha"
		printf 'g\tskills\t*\n'
	} >"$BATS_TEST_TMPDIR/m.tsv"
	run ai_manifest_rows "$BATS_TEST_TMPDIR/m.tsv"
	[ "${lines[0]}" = "ROW	tdd	skills	*	Owner	Repo	$sha	skills/tdd	tdd2	1" ]
	[ "$(grep -c '^WARN' <<<"$output")" -eq 7 ]
}

@test "ai_manifest_scope_applies and the item folder of a row" {
	run ai_manifest_scope_applies '*'
	[ "$status" -eq 0 ]
	run ai_manifest_scope_applies 'Work'
	[ "$status" -eq 1 ]
	AI_PROFILE=Work
	ai_manifest_scope_applies 'Personal, work'
	! ai_manifest_scope_applies 'repo:Work' || false
	export FOUNDATION_AI_MANIFEST_CACHE=/c
	[ "$(ai_manifest_item_dir o r abc skills/x x x 0)" = /c/o/r/abc/skills/x ]
	[ "$(ai_manifest_item_dir o r abc . x x 0)" = /c/o/r/abc ]
	[ "$(ai_manifest_item_dir o r abc skills/x x x 1)" = /c/o/r/abc.derived/x ]
	[ "$(ai_manifest_item_dir o r abc skills/x x y 0)" = /c/o/r/abc.derived/y ]
}

@test "ai_manifest_derive: a renamed copy gets the new frontmatter name, the clone stays as it was" {
	export FOUNDATION_AI_MANIFEST_CACHE=$BATS_TEST_TMPDIR/cache
	src=$FOUNDATION_AI_MANIFEST_CACHE/o/r/abc/skills/x
	mkdir -p "$src"
	printf -- '---\nname: x\ndisable-model-invocation: true\n---\nname: body line\n' >"$src/SKILL.md"
	ai_manifest_derive o r abc skills/x x y 0
	[ "$(cat "$FOUNDATION_AI_MANIFEST_CACHE/o/r/abc.derived/y/SKILL.md")" = $'---\nname: y\ndisable-model-invocation: true\n---\nname: body line' ]
	ai_manifest_derive o r abc skills/x x z 1
	[ "$(cat "$FOUNDATION_AI_MANIFEST_CACHE/o/r/abc.derived/z/SKILL.md")" = $'---\nname: z\n---\nname: body line' ]
	[ "$(cat "$src/SKILL.md")" = $'---\nname: x\ndisable-model-invocation: true\n---\nname: body line' ]
}

@test "ai_repository_dir: the folder of a repositories.conf line, a shallow mark dropped" {
	printf '[Group]\nMyRepo /me/MyRepo.git $HOME/MyRepo shallow\nNoDir /me/NoDir.git\n' >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	[ "$(ai_repository_dir "$FOUNDATION_CONFIG_DIR/repositories.conf" myrepo)" = "$HOME/MyRepo" ]
	run ai_repository_dir "$FOUNDATION_CONFIG_DIR/repositories.conf" NoDir
	[ "$status" -eq 1 ]
	run ai_repository_dir "$FOUNDATION_CONFIG_DIR/repositories.conf" Missing
	[ "$status" -eq 1 ]
}
