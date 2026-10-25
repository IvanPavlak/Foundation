#!/usr/bin/env bats
# Set-WorkspaceWindowLayout against the AeroSpace stand-in: the layout's windows are claimed and
# moved to their desktop, the zone set's column shares become widths, a stray window is parked,
# a window that never appears ends NotFound, a simple layout makes every desktop full size, the
# windows of other workspaces an open protects are never claimed or parked, and an alongside
# layout takes only new windows onto desktops shifted by --desktop-offset. The only untitled entry
# of an app takes all its windows, entries sharing a zone are stacked, and every desktop is read
# back (desktop and frame) and arranged again up to twice before the open ends Partial, the passes
# recorded as the layout's attempts.
# --layout-path applies a layout file from anywhere, --disable-auto-wait takes the windows that are
# there in one look. A bare call applies Fullscreen; an Applied layout ends with its drawing.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	stub_config
	for set in Work Laptop; do
		printf '[Demo]\nlayout 1 Five\n1 Left   Code\n1 Right  Browser  *Docs*\n' >"$FOUNDATION_CONFIG_DIR/layouts/$set/Demo_$set.conf"
		printf '[Missing]\nlayout 1 Zero\n1 Fullscreen Steam\n' >"$FOUNDATION_CONFIG_DIR/layouts/$set/Missing_$set.conf"
	done
	stub_window 200 com.microsoft.VSCode 3 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 4 Firefox "Docs - Mozilla Firefox"
	export FOUNDATION_STABLE_MS=0 FOUNDATION_RUN_DIR=$BATS_TEST_TMPDIR/run
	mkdir -p "$FOUNDATION_RUN_DIR"
	cmd=$UNIX_DIR/modules/Window/bin/Set-WorkspaceWindowLayout
}

@test "claimed windows move to their desktop and the left column gets its 67.25 percent" {
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 200 -- 1'
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1'
	# 67.25 % of the 1512-point work area.
	stub_called '^aerospace resize --window-id 200 width 1017'
	read -r _ _ found expected outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found/$expected $outcome" = "2/2 Applied" ]
}

@test "an Applied layout ends with its Visualize-Layouts drawing, as on Windows" {
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	[[ $output == *"Workspace layout applied successfully!"* ]]
	[[ $output == *"Desktop 1 (Primary) - Five"* ]]
	[[ ${output#*applied successfully!} == *"Browser *Docs*"* ]]
}

@test "without a workspace it applies Fullscreen, as on Windows" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Applying Fullscreen Workspace Layout"* ]]
	stub_called '^aerospace layout --window-id 200 h_accordion'
}

@test "a window on the desktop that is not in the layout is parked on P" {
	stub_window 400 com.tinyspeck.slackmacgap 1 Slack "General"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	stub_called '^aerospace move-node-to-workspace --window-id 400 -- P'
}

@test "a layout window that never appears ends NotFound" {
	run "${BASH:-bash}" "$cmd" Missing --timeout-seconds 1
	[ "$status" -ne 0 ]
	read -r _ _ found _ outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found $outcome" = "0 NotFound" ]
	! stub_called 'move-node-to-workspace' || false
}

@test "a simple layout (Fullscreen) makes every desktop one accordion, no window moves" {
	run "${BASH:-bash}" "$cmd" Fullscreen
	[ "$status" -eq 0 ]
	stub_called '^aerospace flatten-workspace-tree --workspace 3'
	stub_called '^aerospace flatten-workspace-tree --workspace 4'
	stub_called '^aerospace layout --window-id 200 h_accordion'
	! stub_called 'move-node-to-workspace' || false
}

@test "a simple layout shows each desktop before its accordion and returns to the desktop focused before" {
	touch "$BATS_TEST_TMPDIR/layout-needs-focus"
	echo 7 >"$BATS_TEST_TMPDIR/focused"
	run "${BASH:-bash}" "$cmd" Fullscreen
	[ "$status" -eq 0 ]
	stub_called '^aerospace layout --window-id 200 h_accordion'
	stub_called '^aerospace layout --window-id 300 h_accordion'
	[ "$(grep -nE '^aerospace workspace -- 3$' "$STUB_LOG" | cut -d: -f1)" -lt "$(grep -nE 'layout --window-id 200 h_accordion' "$STUB_LOG" | cut -d: -f1)" ]
	[ "$(cat "$BATS_TEST_TMPDIR/focused")" = 7 ]
	read -r _ _ _ _ outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$outcome" = Applied ]
}

@test "a simple layout AeroSpace refuses on a desktop ends Partial and fails" {
	touch "$BATS_TEST_TMPDIR/layout-needs-focus"
	# Desktop switches are refused, so every layout change lands on a hidden desktop.
	mv "$STUB_BIN/aerospace" "$STUB_BIN/aerospace-stub"
	printf '#!/bin/sh\nif [ "$1" = workspace ]; then echo "aerospace $*" >>"$STUB_LOG"; exit 1; fi\nexec "%s/aerospace-stub" "$@"\n' "$STUB_BIN" >"$STUB_BIN/aerospace"
	chmod +x "$STUB_BIN/aerospace"
	run "${BASH:-bash}" "$cmd" Fullscreen
	[ "$status" -ne 0 ]
	read -r _ _ _ _ outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$outcome" = Partial ]
}

@test "an unknown layout fails" {
	run "${BASH:-bash}" "$cmd" NoSuchLayoutAnywhere
	[ "$status" -ne 0 ]
}

@test "a project variant replaces its desktop's windows; an unknown project's variant is reported and skipped" {
	for set in Work Laptop; do
		printf 'project SampleApi\nlayout 1 Zero\n1 Fullscreen Browser *Docs*\nproject Ghost\nlayout 1 Zero\n1 Fullscreen Code\n' >>"$FOUNDATION_CONFIG_DIR/layouts/$set/Demo_$set.conf"
	done
	run "${BASH:-bash}" "$cmd" Demo --project SampleApi --timeout-seconds 3
	[ "$status" -eq 0 ]
	[[ $output == *"names unknown project [Ghost]"* ]]
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1'
	! stub_called '^aerospace move-node-to-workspace --window-id 200 ' || false
	read -r _ _ found expected outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found/$expected $outcome" = "1/1 Applied" ]
}

@test "without a project the variants stay out" {
	for set in Work Laptop; do
		printf 'project SampleApi\nlayout 1 Zero\n1 Fullscreen Browser *Docs*\n' >>"$FOUNDATION_CONFIG_DIR/layouts/$set/Demo_$set.conf"
	done
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 200 -- 1'
	read -r _ _ found expected _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found/$expected" = "2/2" ]
}

@test "a protected window of another workspace is never claimed or parked" {
	stub_window 210 com.microsoft.VSCode 1 Code "Other Code"
	stub_window 400 com.tinyspeck.slackmacgap 1 Slack "General"
	printf '200\n400\n' >"$FOUNDATION_RUN_DIR/protected"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 210 -- 1'
	! stub_called 'move-node-to-workspace --window-id 200 ' || false
	! stub_called 'move-node-to-workspace --window-id 400 ' || false
}

@test "--alongside takes only the windows this open created, on desktops shifted by --desktop-offset" {
	printf '200\n300\n' >"$FOUNDATION_RUN_DIR/pre-windows"
	stub_window 510 com.microsoft.VSCode 2 Code "New Code"
	stub_window 500 org.mozilla.firefox 2 Firefox "Docs - New"
	run "${BASH:-bash}" "$cmd" Demo --alongside --desktop-offset 4 --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 510 -- 5'
	stub_called '^aerospace move-node-to-workspace --window-id 500 -- 5'
	! stub_called 'move-node-to-workspace --window-id 200 ' || false
	! stub_called 'move-node-to-workspace --window-id 300 ' || false
}

@test "--alongside with no new window leaves the open ones alone and ends NotFound" {
	printf '200\n300\n' >"$FOUNDATION_RUN_DIR/pre-windows"
	run "${BASH:-bash}" "$cmd" Demo --alongside --timeout-seconds 1
	[ "$status" -ne 0 ]
	! stub_called 'move-node-to-workspace' || false
}

@test "the only untitled entry of an app takes every window of it, stacked in its zone" {
	stub_window 210 com.microsoft.VSCode 3 Code "Notes"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 210 -- 1'
	stub_called '^aerospace join-with --window-id 210 left'
	stub_called '^aerospace layout --window-id 210 v_accordion'
	read -r _ _ found expected outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found/$expected $outcome" = "2/2 Applied" ]
}

@test "two entries in one zone of a two-zone set are stacked, the last entry in front" {
	stub_window 210 com.microsoft.VSCode 3 Code "Notes"
	for set in Work Laptop; do
		printf '1 Right  Code  Notes\n' >>"$FOUNDATION_CONFIG_DIR/layouts/$set/Demo_$set.conf"
	done
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace join-with --window-id 210 left'
	stub_called '^aerospace layout --window-id 210 v_accordion'
	[ "$(grep '^aerospace focus --window-id' "$STUB_LOG" | tail -1)" = "aerospace focus --window-id 210" ]
	read -r _ _ found expected outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found/$expected $outcome" = "3/3 Applied" ]
}

@test "frames that match their zones are verified once and the layout is Applied" {
	printf '200 0 33 1017 949\n300 1017 33 495 949\n' >"$STUB_FRAMES"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	[ "$(grep -c '^aerospace flatten-workspace-tree --workspace 1' "$STUB_LOG")" -eq 1 ]
	read -r _ _ _ _ outcome attempts <"$FOUNDATION_RUN_DIR/layout-timings"
	# One arrange pass: the benchmark row's Attempts, no retries.
	[ "$outcome $attempts" = "Applied 1" ]
}

@test "a window off its zone is arranged again twice, then the open is Partial with Expected and Actual" {
	printf '200 0 33 1017 949\n300 0 33 100 100\n' >"$STUB_FRAMES"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -ne 0 ]
	[ "$(grep -c '^aerospace flatten-workspace-tree --workspace 1' "$STUB_LOG")" -eq 3 ]
	[[ $output == *"1/2 window(s) misplaced"* ]]
	[[ $output == *"Expected => 1017,33 495x949"* ]]
	[[ $output == *"Actual   => 0,33 100x100"* ]]
	read -r _ _ _ _ outcome attempts <"$FOUNDATION_RUN_DIR/layout-timings"
	# Three arrange passes of desktop 1 are its Attempts (two retries in the Timing line).
	[ "$outcome $attempts" = "Partial 3" ]
}

@test "a window that does not reach its desktop is retried and reported" {
	echo 300 >"$BATS_TEST_TMPDIR/stuck"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -ne 0 ]
	[ "$(grep -c '^aerospace flatten-workspace-tree --workspace 1' "$STUB_LOG")" -eq 3 ]
	[[ $output == *"Actual   => desktop 4"* ]]
}

@test "--layout-path applies that file's only layout and records the file's folder as the set" {
	mkdir -p "$BATS_TEST_TMPDIR/elsewhere/Custom"
	file=$BATS_TEST_TMPDIR/elsewhere/Custom/Solo.conf
	printf '[Solo]\nlayout 1 Five\n1 Left   Code\n1 Right  Browser  *Docs*\n' >"$file"
	run "${BASH:-bash}" "$cmd" --layout-path "$file" --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 200 -- 1'
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1'
	[ "$(cat "$FOUNDATION_STATE_DIR/current-layout")" = $'Solo\tCustom' ]
}

@test "--layout-path with several layouts takes the named one and fails without a name" {
	file=$BATS_TEST_TMPDIR/two.conf
	printf '[One]\nlayout 1 Zero\n1 Fullscreen Code\n\n[Two]\nlayout 1 Zero\n1 Fullscreen Browser\n' >"$file"
	run "${BASH:-bash}" "$cmd" --layout-path "$file" --timeout-seconds 3
	[ "$status" -ne 0 ]
	! stub_called 'move-node-to-workspace' || false
	run "${BASH:-bash}" "$cmd" two --layout-path "$file" --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1'
	! stub_called 'move-node-to-workspace --window-id 200 ' || false
}

@test "--layout-path to a missing file, or to a file without the named layout, fails before a window is placed" {
	run "${BASH:-bash}" "$cmd" --layout-path "$BATS_TEST_TMPDIR/no-such.conf"
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" Other --layout-path "$FOUNDATION_CONFIG_DIR/layouts/Work/Demo_Work.conf"
	[ "$status" -ne 0 ]
	! stub_called 'move-node-to-workspace' || false
}

@test "--disable-auto-wait places the windows that are there without waiting for their titles to settle" {
	# A title would have to hold for a minute; the wait would end at the timeout with a warning.
	export FOUNDATION_STABLE_MS=60000
	run "${BASH:-bash}" "$cmd" Demo --disable-auto-wait --timeout-seconds 5
	[ "$status" -eq 0 ]
	[[ $output != *"did not settle"* ]]
	stub_called '^aerospace move-node-to-workspace --window-id 200 -- 1'
	read -r wait_ms _ found expected outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found/$expected $outcome" = "2/2 Applied" ]
	[ "$wait_ms" -lt 5000 ]
}

@test "--disable-auto-wait with a window that is not there ends NotFound after one look" {
	run "${BASH:-bash}" "$cmd" Missing --disable-auto-wait --timeout-seconds 5
	[ "$status" -ne 0 ]
	read -r wait_ms _ found _ outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found $outcome" = "0 NotFound" ]
	[ "$wait_ms" -lt 5000 ]
}

@test "an Applied open remembers each entry's window; a rerun gives every entry the same window back" {
	for set in Work Laptop; do
		printf '[Twin]\nlayout 1 Zero\nlayout 2 Zero\n1 Fullscreen Browser *YouTube*\n2 Fullscreen Browser *YouTube*\n' >"$FOUNDATION_CONFIG_DIR/layouts/$set/Twin_$set.conf"
	done
	: >"$STUB_WINDOWS"
	stub_window 300 org.mozilla.firefox 3 Firefox "YouTube"
	stub_window 301 org.mozilla.firefox 3 Firefox "YouTube"
	run "${BASH:-bash}" "$cmd" Twin --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1'
	stub_called '^aerospace move-node-to-workspace --window-id 301 -- 2'
	ls "$FOUNDATION_STATE_DIR"/layout-pins/twin_* >/dev/null
	# The window list now names 301 first, both back on one desktop: without the pins entry 1
	# (desktop 1) would take 301.
	: >"$STUB_LOG"
	: >"$STUB_WINDOWS"
	stub_window 301 org.mozilla.firefox 3 Firefox "YouTube"
	stub_window 300 org.mozilla.firefox 3 Firefox "YouTube"
	run "${BASH:-bash}" "$cmd" Twin --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1'
	stub_called '^aerospace move-node-to-workspace --window-id 301 -- 2'
}

@test "a browser entry no window matches sends the unprotected browser windows to their first tab" {
	: >"$STUB_WINDOWS"
	stub_window 200 com.microsoft.VSCode 3 Code "Dotfiles"
	stub_window 300 org.mozilla.firefox 4 Firefox "Some other tab - Mozilla Firefox"
	stub_window 301 org.mozilla.firefox 5 Firefox "Another workspace - Mozilla Firefox"
	echo 301 >"$FOUNDATION_RUN_DIR/protected"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 1
	stub_called '^aerospace focus --window-id 300'
	stub_called 'keystroke "1" using command down'
	! stub_called '^aerospace focus --window-id 301' || false
	[ "$(grep -c 'keystroke "1"' "$STUB_LOG")" -eq 1 ]
}

@test "when every browser entry has its window, no tab is switched" {
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	! stub_called 'keystroke' || false
}

@test "a layout-override line makes the open read layouts/<Override>/" {
	export FOUNDATION_MACHINE_TYPE=Work
	printf 'layout-override Work Tower\n' >>"$FOUNDATION_CONFIG_DIR/machines.conf"
	mkdir -p "$FOUNDATION_CONFIG_DIR/layouts/Tower"
	printf '[Demo]\nlayout 1 Zero\n1 Fullscreen Code\n' >"$FOUNDATION_CONFIG_DIR/layouts/Tower/Demo_Tower.conf"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 200 -- 1'
	! stub_called 'move-node-to-workspace --window-id 300 ' || false
	[ "$(cat "$FOUNDATION_STATE_DIR/current-layout")" = $'Demo\tTower' ]
}

@test "with layout-early-move on each window goes to its desktop before the arrange pass" {
	printf 'layout-early-move on\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_RUN_DIR/layout-early-move")" = on ]
	first_move=$(grep -nE '^aerospace move-node-to-workspace --window-id 200 -- 1$' "$STUB_LOG" | head -1 | cut -d: -f1)
	arrange=$(grep -nE '^aerospace workspace -- 1$' "$STUB_LOG" | head -1 | cut -d: -f1)
	[ -n "$first_move" ] && [ -n "$arrange" ]
	[ "$first_move" -lt "$arrange" ]
	# Off (the fixture's line): the first move is the arrange pass's own.
	rm "$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$(cat "$FOUNDATION_RUN_DIR/layout-early-move")" = off ]
	first_move=$(grep -nE '^aerospace move-node-to-workspace' "$STUB_LOG" | head -1 | cut -d: -f1)
	arrange=$(grep -nE '^aerospace workspace -- 1$' "$STUB_LOG" | head -1 | cut -d: -f1)
	[ "$first_move" -gt "$arrange" ]
}

@test "parking-workspace \"\" leaves a stranger window on the desktop" {
	printf 'parking-workspace ""\n' >"$FOUNDATION_CONFIG_DIR/zones.local.conf"
	stub_window 400 com.tinyspeck.slackmacgap 1 Slack "General"
	run "${BASH:-bash}" "$cmd" Demo --timeout-seconds 3
	[ "$status" -eq 0 ]
	! stub_called 'move-node-to-workspace --window-id 400 ' || false
}

@test "a layout app that is not running ends NotFound after the absent grace, not the timeout" {
	printf 'layout-absent-grace-seconds 1\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	export FOUNDATION_POLL_SECONDS=0.1
	run "${BASH:-bash}" "$cmd" Missing --timeout-seconds 30
	[ "$status" -ne 0 ]
	read -r wait_ms _ found _ outcome _ <"$FOUNDATION_RUN_DIR/layout-timings"
	[ "$found $outcome" = "0 NotFound" ]
	[ "$wait_ms" -lt 10000 ]
	stub_called '^lsappinfo .*com.valvesoftware.steam'
}
