#!/usr/bin/env bats
# Show-Image: inside WezTerm the image is drawn inline (wezterm imgcat, --width); outside it (or with
# --window) the image opens in Quick Look; a missing file fails.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/Show-Image
}

@test "outside WezTerm the image goes to Quick Look, a missing file fails" {
	stub_tool qlmanage
	touch "$BATS_TEST_TMPDIR/pic.png"
	TERM_PROGRAM=Apple_Terminal run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/pic.png"
	[ "$status" -eq 0 ]
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		grep -q qlmanage "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null && break
		sleep 0.1
	done
	grep -q "qlmanage -p $BATS_TEST_TMPDIR/pic.png" "$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/missing.png"
	[ "$status" -ne 0 ]
}

@test "inside WezTerm the image is drawn inline with --width; --window still uses Quick Look" {
	stub_tool wezterm
	stub_tool qlmanage
	touch "$BATS_TEST_TMPDIR/pic.png"
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/pic.png" --width 50%
	[ "$status" -eq 0 ]
	grep -q "^wezterm imgcat --width 50% $BATS_TEST_TMPDIR/pic.png$" "$BATS_TEST_TMPDIR/tool.log"
	! grep -q qlmanage "$BATS_TEST_TMPDIR/tool.log" || false
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/pic.png" --window
	[ "$status" -eq 0 ]
	for _ in 1 2 3 4 5 6 7 8 9 10; do
		grep -q qlmanage "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null && break
		sleep 0.1
	done
	grep -q "qlmanage -p $BATS_TEST_TMPDIR/pic.png" "$BATS_TEST_TMPDIR/tool.log"
	[ "$(grep -c '^wezterm' "$BATS_TEST_TMPDIR/tool.log")" -eq 1 ]
}
