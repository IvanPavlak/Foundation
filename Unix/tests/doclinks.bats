#!/usr/bin/env bats
# Infrastructure-DocumentationLinks analog for the Unix pages: every relative (or docsify-rooted)
# Markdown link under docs/unix reaches a file, and a link to a heading of a Markdown page reaches
# that heading's docsify anchor (docs/unix/_sidebar.md included). In a clone that holds both halves
# the shared docs/_sidebar.md is WinuX's, byte for byte, so it carries no Unix or Decisions entry;
# in Foundation alone (no Windows/ folder) the root sidebar is Foundation's own and those two
# checks skip.

load helpers
load doclinks

setup() {
	setup_foundation
	DOCS=$(dirname "$UNIX_DIR")/docs
}

# Skips a test that holds only where WinuX's docs share the site.
need_both_halves() {
	[ -d "$(dirname "$UNIX_DIR")/Windows" ] || skip "Foundation alone: the root docs are its own"
}

@test "every link under docs/unix reaches its file and anchor" {
	run doclinks_broken "$DOCS/unix" "$DOCS"
	[ -z "$output" ] || {
		printf '%s\n' "$output"
		return 1
	}
}

@test "the shared docs sidebar carries no Unix or Decisions entry" {
	need_both_halves
	# The Unix pages are reached through docs/unix/_sidebar.md and the fork-owned custom page; an
	# entry here would make the shared sidebar differ from WinuX's.
	run grep -nE '\]\(/?(unix|adr)/' "$DOCS/_sidebar.md"
	[ "$status" -eq 1 ] || {
		printf '%s\n' "$output"
		return 1
	}
}

@test "the fork-owned custom page links the Foundation docs" {
	need_both_halves
	grep -qF '](../unix/README.md)' "$DOCS/custom/README.md"
}

@test "the checker itself: a missing file, a missing anchor and a link inside code" {
	page=$BATS_TEST_TMPDIR/docs/page.md
	mkdir -p "$(dirname "$page")"
	cat >"$page" <<'MD'
# Page

## A Heading: with `code` and [a link](https://example.invalid)

[fine](#a-heading-with-code-and-a-link) [anchor gone](#nowhere) [file gone](gone.md)

```bash
[inside code](gone-too.md)
```
MD
	run doclinks_broken "$BATS_TEST_TMPDIR/docs" "$BATS_TEST_TMPDIR/docs"
	[ "$(printf '%s\n' "$output" | cut -f2,3 | paste -sd'|' -)" = $'#nowhere\tmissing anchor|gone.md\tmissing file' ]
}
