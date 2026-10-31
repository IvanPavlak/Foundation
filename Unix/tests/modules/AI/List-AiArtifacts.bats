#!/usr/bin/env bats
# List-AiArtifacts against a fixture AI tree, config and a HOME in the test folder: the roster
# grouped by kind and source (own first, the first source winning a duplicate name, exclude lines
# applied), the --kind / --source / --name filters by pattern, number or menu, --quiet, and every
# finding of --list-discrepancies against the deploy plan, with its exit status.

load ../../helpers

setup() {
	command -v python3 >/dev/null 2>&1 || skip "python3 is required"
	setup_foundation
	use_empty_config
	export DOTFILES_ROOT=$BATS_TEST_TMPDIR/repo
	export HOME=$BATS_TEST_TMPDIR/home
	ai=$DOTFILES_ROOT/AI
	mkdir -p "$HOME"
	skill own alpha-skill 'Does the alpha thing.'
	skill own beta-skill 'Does the beta thing.'
	skill vendor gamma-skill 'Does the gamma thing.'
	# A folder without SKILL.md is not a skill.
	mkdir -p "$ai/Skills/vendor/not-a-skill" "$ai/Mods/own/neon/.claude-plugin" "$ai/Rules/own/Core"
	printf '{"name":"neon","description":"Draws a band."}\n' >"$ai/Mods/own/neon/.claude-plugin/plugin.json"
	printf -- '---\ndescription: The core rules.\n---\n' >"$ai/Rules/own/Core/RULES.md"
	printf 'deploy one\nuse rules Core\n[vendor]\nrepository Owner/Repo\n' >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	printf '[one]\nskills each . ~/one/skills\nskills each . ~/two/skills\nrules file RULES.md ~/one/RULES.md\n' >"$FOUNDATION_CONFIG_DIR/ai-harnesses.conf"
	cmd=$UNIX_DIR/modules/AI/bin/List-AiArtifacts
}

# Creates AI/Skills/SOURCE/NAME/SKILL.md with DESCRIPTION. Usage: skill SOURCE NAME DESCRIPTION
skill() {
	mkdir -p "$ai/Skills/$1/$2"
	printf -- '---\nname: %s\ndescription: %s\n---\n# %s\n' "$2" "$3" "$2" >"$ai/Skills/$1/$2/SKILL.md"
}

# Links every skill of own and vendor into FOLDER, as Deploy-AiArtifacts does. Usage: link_into FOLDER
link_into() {
	local dir
	mkdir -p "$1"
	for dir in "$ai"/Skills/own/*/ "$ai"/Skills/vendor/*/; do
		dir=${dir%/}
		if [ -f "$dir/SKILL.md" ]; then ln -s "$dir" "$1/${dir##*/}"; fi
	done
}

# Deploys everything the plan names.
link_all() {
	link_into "$HOME/one/skills"
	link_into "$HOME/two/skills"
	ln -s "$ai/Rules/own/Core/RULES.md" "$HOME/one/RULES.md"
}

@test "lists every item grouped by kind and source with its description and path" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[skills - own (own)]"*"alpha-skill"*"Does the alpha thing."*"Path => AI/Skills/own/alpha-skill"* ]]
	[[ $output == *"[skills - vendor (vendored)]"*"gamma-skill"* ]]
	[[ $output == *"[mods - own (own)]"*"neon"*"Draws a band."* ]]
	[[ $output == *"[rules - own (own)]"*"Core"*"The core rules."* ]]
	[[ $output != *"not-a-skill"* ]]
	[[ $output == *"5 item(s)"* ]]
}

@test "--quiet prints the names only; --kind picks kinds" {
	run "${BASH:-bash}" "$cmd" --kind skills --quiet
	[ "$status" -eq 0 ]
	[ "$output" = $'alpha-skill\nbeta-skill\ngamma-skill' ]
	run "${BASH:-bash}" "$cmd" --kind mods,RULES --quiet
	[ "$output" = $'neon\nCore' ]
	run "${BASH:-bash}" "$cmd" --kind bogus
	[ "$status" -eq 1 ]
}

@test "a source folder that is not configured is not listed" {
	skill winux delta-skill 'Not read here.'
	run "${BASH:-bash}" "$cmd" --kind skills --quiet
	[[ $output != *delta-skill* ]]
}

@test "exclude lines leave items out" {
	printf 'deploy one\nuse rules Core\nexclude skills/beta-skill\n[vendor]\nrepository Owner/Repo\n' >"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	run "${BASH:-bash}" "$cmd" --kind skills --quiet
	[ "$output" = $'alpha-skill\ngamma-skill' ]
}

@test "--source picks sources, a comma list picks several" {
	run "${BASH:-bash}" "$cmd" --kind skills --source vendor --quiet
	[ "$output" = gamma-skill ]
	run "${BASH:-bash}" "$cmd" --kind skills --source OWN,vendor --quiet
	[ "$output" = $'alpha-skill\nbeta-skill\ngamma-skill' ]
}

@test "--name filters names with wildcards, case-insensitively" {
	run "${BASH:-bash}" "$cmd" --name 'B*' --quiet
	[ "$output" = beta-skill ]
	run "${BASH:-bash}" "$cmd" --source own --name '*alpha*' --quiet
	[ "$output" = alpha-skill ]
}

@test "a filter that matches nothing warns and exits 0" {
	run "${BASH:-bash}" "$cmd" --name nomatch
	[ "$status" -eq 0 ]
	[[ $output == *"No item matched the filter!"* ]]
}

@test "--source and --name take a number: the position in the sorted list" {
	run "${BASH:-bash}" "$cmd" --kind skills --source 2 --quiet
	[ "$output" = gamma-skill ]
	run "${BASH:-bash}" "$cmd" --kind skills --name 1,3 --quiet
	[ "$output" = $'alpha-skill\ngamma-skill' ]
}

@test "a bare --source opens the source menu" {
	printf '2\n' >"$BATS_TEST_TMPDIR/tty"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/tty run "${BASH:-bash}" "$cmd" --kind skills --source --quiet
	[ "$status" -eq 0 ]
	[[ $output == *"[Available Sources]"* ]]
	[[ $output == *gamma-skill ]]
	[[ $output != *alpha-skill* ]]
}

@test "a bare --name without a terminal fails and lists nothing" {
	run "${BASH:-bash}" "$cmd" --name
	[ "$status" -eq 1 ]
	[[ $output == *"No selection possible without a terminal"* ]]
	[[ $output != *"item(s)"* ]]
}

@test "a repository without the artifacts root is an error" {
	rm -rf "$ai"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
}

@test "--list-discrepancies: everything deployed is all clear, --quiet silences the banner" {
	link_all
	run "${BASH:-bash}" "$cmd" --list-discrepancies
	[ "$status" -eq 0 ]
	[[ $output == *"No discrepancies"* ]]
	run "${BASH:-bash}" "$cmd" --list-discrepancies --quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "--list-discrepancies: a missing destination folder and an unlinked item are findings" {
	link_into "$HOME/one/skills"
	rm "$HOME/one/skills/beta-skill"
	run "${BASH:-bash}" "$cmd" --list-discrepancies --kind skills
	[ "$status" -eq 1 ]
	[[ $output == *"~/two/skills does not exist"* ]]
	[[ $output == *"[skills] beta-skill is not linked as ~/one/skills/beta-skill"* ]]
	[[ $output != *"alpha-skill is not linked as ~/one"* ]]
}

@test "--list-discrepancies: a real file that shadows an item and a link elsewhere are findings" {
	link_all
	rm "$HOME/one/skills/alpha-skill" "$HOME/one/RULES.md"
	mkdir "$HOME/one/skills/alpha-skill"
	ln -s "$BATS_TEST_TMPDIR/elsewhere" "$HOME/one/RULES.md"
	run "${BASH:-bash}" "$cmd" --list-discrepancies
	[ "$status" -eq 1 ]
	[[ $output == *"~/one/skills/alpha-skill is a real file that shadows [skills] alpha-skill"* ]]
	[[ $output == *"~/one/RULES.md points elsewhere"* ]]
}

@test "--list-discrepancies: a dangling link into the artifacts root is a finding, foreign links are not" {
	link_all
	ln -s "$BATS_TEST_TMPDIR/not-ours" "$HOME/one/skills/foreign"
	run "${BASH:-bash}" "$cmd" --list-discrepancies
	[ "$status" -eq 0 ]
	ln -s "$ai/Skills/own/gone-skill" "$HOME/one/skills/gone-skill"
	run "${BASH:-bash}" "$cmd" --list-discrepancies
	[ "$status" -eq 1 ]
	[[ $output == *"gone-skill is a dangling link"* ]]
	[[ $output != *"foreign"* ]]
}

@test "--list-discrepancies checks only the filtered roster" {
	link_all
	rm "$HOME/one/skills/gamma-skill"
	run "${BASH:-bash}" "$cmd" --list-discrepancies --source own
	[ "$status" -eq 0 ]
	run "${BASH:-bash}" "$cmd" --list-discrepancies --source vendor
	[ "$status" -eq 1 ]
}

@test "a name two sources carry is listed once, from own, and is a discrepancy" {
	link_all
	skill vendor alpha-skill 'Another alpha.'
	run "${BASH:-bash}" "$cmd" --kind skills --quiet
	[ "$output" = $'alpha-skill\nbeta-skill\ngamma-skill' ]
	run "${BASH:-bash}" "$cmd" --list-discrepancies
	[ "$status" -eq 1 ]
	[[ $output == *"Duplicate item name: skills/alpha-skill is in [vendor] and [own]"* ]]
}

@test "checkout and manifest sources are listed with their kind; a manifest row outside the profile's scope is not" {
	sha=0123456789abcdef0123456789abcdef01234567
	export FOUNDATION_AI_MANIFEST_CACHE=$BATS_TEST_TMPDIR/cache
	mkdir -p "$BATS_TEST_TMPDIR/checkout/skills/delta-skill" "$FOUNDATION_AI_MANIFEST_CACHE/up/r/$sha/s/epsilon" "$FOUNDATION_AI_MANIFEST_CACHE/up/r/$sha/s/zeta"
	printf -- '---\nname: delta-skill\ndescription: Delta.\n---\n' >"$BATS_TEST_TMPDIR/checkout/skills/delta-skill/SKILL.md"
	printf -- '---\nname: epsilon\ndescription: Epsilon.\n---\n' >"$FOUNDATION_AI_MANIFEST_CACHE/up/r/$sha/s/epsilon/SKILL.md"
	printf -- '---\nname: zeta\ndescription: Zeta.\n---\n' >"$FOUNDATION_AI_MANIFEST_CACHE/up/r/$sha/s/zeta/SKILL.md"
	printf 'name\tkind\tscope\tsource\tref\tpath\tinstall\nepsilon\tskills\t*\thttps://github.com/up/r\t%s\ts/epsilon\tclone\nzeta\tskills\tWork\thttps://github.com/up/r\t%s\ts/zeta\tclone\n' "$sha" "$sha" >"$BATS_TEST_TMPDIR/m.tsv"
	printf '[pm]\ncheckout %s\nmanifest %s\n' "$BATS_TEST_TMPDIR/checkout" "$BATS_TEST_TMPDIR/m.tsv" >>"$FOUNDATION_CONFIG_DIR/ai-artifacts.conf"
	printf 'default Personal\n[Personal]\n[Work]\n' >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd" --kind skills
	[ "$status" -eq 0 ]
	[[ $output == *"[skills - pm (checkout)]"*"delta-skill"* ]]
	[[ $output == *"[skills - up (manifest)]"*"epsilon"* ]]
	[[ $output != *zeta* ]]
	FOUNDATION_AI_PROFILE=Work run "${BASH:-bash}" "$cmd" --kind skills --quiet
	[[ $output == *zeta* ]]
}

@test "an AI profile's include and exclude lines shape the list" {
	printf 'default P\n[P]\ninclude skills/alpha-skill skills/gamma-skill\nexclude skills/gamma-skill\n' >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd" --kind skills --quiet
	[ "$output" = alpha-skill ]
}
