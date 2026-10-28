#!/usr/bin/env bats
# Infrastructure-DocumentationLinks analog for the Unix pages: every relative (or docsify-rooted)
# Markdown link under docs/foundation reaches a file, and a link to a heading of a Markdown page reaches
# that heading's docsify anchor (docs/foundation/_sidebar.md included). Foundation's pages live in its
# own folder: its sidebar links only pages under /foundation/ (and the WinuX docs). The root docs
# landing (docs/README.md, docs/_sidebar.md) is a hallway file, the fork's or the root owner's, so
# only its link to the Foundation overview is checked, and docs/index.html, the docsify shell every
# project shares byte for byte, names no project.

load helpers
load doclinks

setup() {
	setup_foundation
	DOCS=$(dirname "$UNIX_DIR")/docs
}

@test "every link under docs/foundation reaches its file and anchor" {
	run doclinks_broken "$DOCS/foundation" "$DOCS"
	[ -z "$output" ] || {
		printf '%s\n' "$output"
		return 1
	}
}

@test "the Foundation sidebar links only Foundation pages and the WinuX docs" {
	# A docsify-rooted link outside /foundation/ would make the Foundation pages depend on a page of
	# another project or of the fork.
	run grep -noE '\]\(/[^)]*\)' "$DOCS/foundation/_sidebar.md"
	[ "$status" -eq 0 ]
	outside=$(printf '%s\n' "$output" | grep -vE '\]\(/foundation/' | grep -vE '\]\(/winux/README\.md\)' | grep -vE '\]\(/\)' || true)
	[ -z "$outside" ] || {
		printf '%s\n' "$outside"
		return 1
	}
}

@test "the root docs landing links the Foundation overview" {
	grep -qE '\]\((\./|/)?foundation/(README\.md)?\)' "$DOCS/README.md" "$DOCS/_sidebar.md"
}

@test "docs/index.html names no project" {
	[ -f "$DOCS/index.html" ]
	run grep -niE 'winux|foundation|dotfiles' "$DOCS/index.html"
	[ "$status" -eq 1 ] || {
		printf '%s\n' "$output"
		return 1
	}
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
