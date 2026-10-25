# shellcheck shell=bash
# Agent Skills helpers shared by the AI commands - the Get-AiSkillDescription
# and Get-AiSkillManifest of the Windows AI module, same rules so both halves write and read the
# same UPSTREAM.md files (only the re-run line names each half's own command form).

# Description of a SKILL.md frontmatter, continuation lines joined, surrounding quotes dropped,
# `|` escaped for a Markdown table. Empty when there is no frontmatter or no description.
skill_description() { # SKILL.md
	awk '
		NR == 1 { if ($0 !~ /^[[:space:]]*---[[:space:]]*$/) exit; next }
		/^[[:space:]]*---[[:space:]]*$/ { exit }
		!have {
			if ($0 ~ /^description:/) {
				value = $0; sub(/^description:[[:space:]]*/, "", value); sub(/[[:space:]]+$/, "", value)
				if (value == ">" || value == "|" || value == ">-" || value == "|-") value = ""
				desc = value; have = 1
			}
			next
		}
		/^[[:space:]]+[^[:space:]]/ { line = $0; sub(/^[[:space:]]+/, "", line); sub(/[[:space:]]+$/, "", line); desc = desc " " line; sub(/^ /, "", desc); next }
		{ exit }
		END {
			if (!have) exit
			n = length(desc)
			if (n >= 2 && ((substr(desc, 1, 1) == "\"" && substr(desc, n, 1) == "\"") || (substr(desc, 1, 1) == "\047" && substr(desc, n, 1) == "\047"))) {
				desc = substr(desc, 2, n - 2); gsub(/\\"/, "\"", desc)
			}
			gsub(/\|/, "\\|", desc)
			print desc
		}' "$1"
}

# Pinned commit of an UPSTREAM.md (empty when missing).
skill_manifest_commit() { # UPSTREAM.md
	[ -r "$1" ] || return 0
	sed -n 's/^- *\*\*Commit:\*\* *`\([0-9a-fA-F]*\)`.*/\1/p' "$1" | head -n 1
}

# Skill names of an UPSTREAM.md table, one per line.
skill_manifest_skills() { # UPSTREAM.md
	[ -r "$1" ] || return 0
	sed -n 's/^| *`\([^`]*\)` *|.*/\1/p' "$1"
}
