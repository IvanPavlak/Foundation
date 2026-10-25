#!/usr/bin/env bats
# The Agent Skills helpers: description and manifest parsing identical to the Windows
# Get-AiSkillDescription / Get-AiSkillManifest, so both halves write the same UPSTREAM.md. The
# manifest tests read the vendored source of tests/fixtures/skills, never a fork's AI/Skills.

load helpers

setup() {
	setup_foundation
	foundation_load skills
	dir=$BATS_TEST_TMPDIR
	source_dir=$UNIX_DIR/tests/fixtures/skills/example-source
}

@test "skill_description: plain value" {
	printf -- '---\nname: x\ndescription: Does a thing.\n---\n# X\n' >"$dir/SKILL.md"
	[ "$(skill_description "$dir/SKILL.md")" = "Does a thing." ]
}

@test "skill_description: folded block and continuation lines are joined" {
	printf -- '---\ndescription: >\n  First part\n  second part.\nname: x\n---\n' >"$dir/SKILL.md"
	[ "$(skill_description "$dir/SKILL.md")" = "First part second part." ]
}

@test "skill_description: surrounding quotes dropped, pipes escaped for the table" {
	printf -- '---\ndescription: "Use a | b"\n---\n' >"$dir/SKILL.md"
	[ "$(skill_description "$dir/SKILL.md")" = 'Use a \| b' ]
}

@test "skill_description: no frontmatter gives nothing" {
	printf '# Just a heading\ndescription: not frontmatter\n' >"$dir/SKILL.md"
	[ -z "$(skill_description "$dir/SKILL.md")" ]
}

@test "skill_manifest: commit and skill names of a vendored UPSTREAM.md" {
	manifest=$source_dir/UPSTREAM.md
	[[ $(skill_manifest_commit "$manifest") =~ ^[0-9a-f]{40}$ ]]
	skill_manifest_skills "$manifest" | grep -qx tdd
	[ -z "$(skill_manifest_commit "$dir/missing.md")" ]
}

@test "skill_description matches every row of a vendored UPSTREAM.md" {
	manifest=$source_dir/UPSTREAM.md
	while IFS= read -r skill; do
		row=$(grep -F "| \`$skill\` |" "$manifest")
		want=${row#*\` | \`*\` | }
		want=${want% |}
		got=$(skill_description "$source_dir/$skill/SKILL.md")
		[ "$got" = "$want" ] || {
			echo "$skill: [$got] != [$want]"
			return 1
		}
	done < <(skill_manifest_skills "$manifest")
}
