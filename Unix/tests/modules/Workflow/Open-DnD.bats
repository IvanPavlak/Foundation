#!/usr/bin/env bats
# Open-DnD against the platform and app stand-ins: a campaign of dnd.conf opens Obsidian, its pdf
# group and its browser group; a menu number names one, the menu picks one, an empty pick or an
# unknown campaign opens nothing, and --foundry-vtt starts FoundryVTT only when apps.conf knows it.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	export HOME=$BATS_TEST_TMPDIR/home
	export OBSIDIAN_DIRECTORY=$BATS_TEST_TMPDIR/vault
	mkdir -p "$HOME" "$OBSIDIAN_DIRECTORY" "$BATS_TEST_TMPDIR/pdfs"
	sheet=$BATS_TEST_TMPDIR/pdfs/sheet.pdf
	spells=$BATS_TEST_TMPDIR/pdfs/spells.pdf
	touch "$sheet" "$spells"
	printf '[SheetGroup]\n%s\n\n[SpellGroup]\n%s\n' "$sheet" "$spells" >"$FOUNDATION_CONFIG_DIR/pdfs.conf"
	printf '[Alpha]\npdf SheetGroup\nbrowser Search\n\n[Beta]\npdf SpellGroup\n' >"$FOUNDATION_CONFIG_DIR/dnd.conf"
	cmd=$UNIX_DIR/modules/Workflow/bin/Open-DnD
}

obsidian_opened() {
	stub_called '^open -g obsidian://open\?vault=vault'
}

@test "a campaign opens Obsidian, its pdf group and its browser group" {
	run "${BASH:-bash}" "$cmd" Alpha </dev/null
	[ "$status" -eq 0 ]
	obsidian_opened
	grep -qxF "open $sheet" "$STUB_LOG"
	! grep -qF "open $spells" "$STUB_LOG" || false
	stub_wait_for '^launch Firefox .*https://search\.example/'
}

@test "--campaign names the campaign case-insensitively; no browser line opens no browser" {
	run "${BASH:-bash}" "$cmd" --campaign beta </dev/null
	[ "$status" -eq 0 ]
	obsidian_opened
	grep -qxF "open $spells" "$STUB_LOG"
	! stub_called '^launch Firefox' || false
}

@test "a number names that entry of the menu, as -Campaign 2 does on Windows" {
	run "${BASH:-bash}" "$cmd" 2 </dev/null
	[ "$status" -eq 0 ]
	grep -qxF "open $spells" "$STUB_LOG"
	! grep -qF "open $sheet" "$STUB_LOG" || false
}

@test "without a campaign the menu pick is opened" {
	printf '2\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	grep -qxF "open $spells" "$STUB_LOG"
	! grep -qF "open $sheet" "$STUB_LOG" || false
}

@test "an empty menu pick opens nothing and succeeds" {
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -eq 0 ]
	! stub_called '^open' || false
	! stub_called '^launch' || false
}

@test "without a campaign and without a terminal nothing opens" {
	run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -ne 0 ]
	! stub_called '^open' || false
}

@test "an unknown campaign fails before anything opens" {
	run "${BASH:-bash}" "$cmd" NoSuchCampaign </dev/null
	[ "$status" -ne 0 ]
	! stub_called '^open' || false
	! stub_called '^launch' || false
}

@test "a missing dnd.conf is an error" {
	rm "$FOUNDATION_CONFIG_DIR/dnd.conf"
	run "${BASH:-bash}" "$cmd" Alpha </dev/null
	[ "$status" -ne 0 ]
	! stub_called '^open' || false
}

@test "--foundry-vtt starts FoundryVTT when apps.conf has it" {
	printf 'app FoundryVTT com.example.foundryvtt\n' >>"$FOUNDATION_CONFIG_DIR/apps.conf"
	run "${BASH:-bash}" "$cmd" Beta --foundry-vtt </dev/null
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.example\.foundryvtt'
	grep -qxF "open $spells" "$STUB_LOG"
}

@test "--foundry-vtt without FoundryVTT in apps.conf is skipped, the campaign still opens" {
	run "${BASH:-bash}" "$cmd" Beta --foundry-vtt </dev/null
	[ "$status" -eq 0 ]
	! stub_called 'foundry' || false
	grep -qxF "open $spells" "$STUB_LOG"
}

@test "a campaign with two pdf lines opens the last one's group, as one group" {
	printf '[Gamma]\npdf SheetGroup\npdf SpellGroup\n' >"$FOUNDATION_CONFIG_DIR/dnd.conf"
	run "${BASH:-bash}" "$cmd" Gamma </dev/null
	[ "$status" -eq 0 ]
	grep -qxF "open $spells" "$STUB_LOG"
	! grep -qF "open $sheet" "$STUB_LOG" || false
}
