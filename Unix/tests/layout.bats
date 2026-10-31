#!/usr/bin/env bats
# The desktop arranging logic, with the AeroSpace driver replaced by a recorder: the tests check
# which commands would be sent, in which order, without touching any window.

load helpers

setup() {
	setup_foundation
	LOG="$BATS_TEST_TMPDIR/driver.log"
	: >"$LOG"
	# Recorder stubs for every driver call layout_arrange_desktop makes.
	as_exit_native_fullscreen() { return 1; }
	as_focus_workspace() { echo "focus-workspace $1" >>"$LOG"; }
	as_workspace_windows() { :; }
	as_move_window() { echo "move $1 $2" >>"$LOG"; }
	as_set_tiling() { :; }
	as_flatten() { echo "flatten $1" >>"$LOG"; }
	as_layout() { echo "layout $1 $2" >>"$LOG"; }
	as_focus_window() { :; }
	as_move_left() { echo "move-left $1" >>"$LOG"; }
	as_join_with() { echo "join $1 $2" >>"$LOG"; }
	as_balance() { echo "balance $1" >>"$LOG"; }
	as_resize_width() { echo "resize $1 $2" >>"$LOG"; }
	# The batched calls, recorded as the single calls they stand for (no real AeroSpace is asked).
	as_eval_check() { :; }
	as_exit_native_fullscreen_each() { :; }
	as_park_windows() {
		local ws=$1
		shift
		for id in "$@"; do echo "move $id $ws" >>"$LOG"; done
	}
	as_gather_tiled() {
		local ws=$1
		shift
		for id in "$@"; do echo "move $id $ws" >>"$LOG"; done
		echo "flatten $ws" >>"$LOG"
	}
	# The tree already has the insertion order: the walk returns the ids as moved in.
	as_workspace_order() { awk '$1 == "move" { print $2 }' "$LOG"; }
	# No frames unless a test gives some: the wait then judges stability by title alone.
	as_window_frames() { :; }
}

@test "Five: two columns, left one resized to 67.25 percent" {
	layout_arrange_desktop 1 3440 "11:0:67.25:0" "12:1:32.75:0"
	grep -q "^resize 11 2313$" "$LOG"
	! grep -q "^join" "$LOG" || false
}

@test "One: equal columns are balanced" {
	layout_arrange_desktop 3 3440 "12:1:50:0" "11:0:50:0"
	# Moved left zone first regardless of argument order.
	[ "$(awk '$1 == "move" { print $2 }' "$LOG" | tr '\n' ' ')" = "11 12 " ]
	grep -q "^balance 3$" "$LOG"
}

@test "Nine: six windows in three halved columns, bottoms joined under tops" {
	layout_arrange_desktop 8 3000 \
		"25:2:33.34:1" "20:0:33.33:0" "23:1:33.33:1" "21:0:33.33:1" "22:1:33.33:0" "24:2:33.34:0"
	[ "$(awk '$1 == "move" { print $2 }' "$LOG" | tr '\n' ' ')" = "20 21 22 23 24 25 " ]
	[ "$(grep '^join' "$LOG" | tr '\n' ' ')" = "join 21 left join 23 left join 25 left " ]
	grep -q "^balance 8$" "$LOG"
}

@test "Six: full-height left column plus a halved right column" {
	layout_arrange_desktop 7 2000 "30:0:50:0" "31:1:50:0" "32:1:50:1"
	[ "$(grep '^join' "$LOG")" = "join 32 left" ]
	grep -q "^balance 7$" "$LOG"
}

@test "Seven: unequal columns resize by column, not by window" {
	layout_arrange_desktop 9 3000 "40:0:33.33:0" "41:1:33.33:0" "42:2:33.34:0" "43:2:33.34:1"
	# 33.33 and 33.34 round to the same share, so the columns are balanced.
	grep -q "^balance 9$" "$LOG"
	[ "$(grep -c '^join' "$LOG")" -eq 1 ]
}

@test "several windows in one zone of a multi-zone set: an accordion in that column, the last entry in front" {
	as_focus_window() { echo "focus-window $1" >>"$LOG"; }
	layout_arrange_desktop 2 2000 "50:0:50:0" "51:1:50:0" "52:1:50:0" "53:1:50:0"
	[ "$(awk '$1 == "move" { print $2 }' "$LOG" | tr '\n' ' ')" = "50 51 52 53 " ]
	[ "$(grep -E '^(join|layout 52|move-left)' "$LOG" | tr '\n' '|')" = "join 52 left|layout 52 v_accordion|move-left 53|" ]
	[ "$(grep '^focus-window' "$LOG" | tail -1)" = "focus-window 53" ]
	grep -q "^balance 2$" "$LOG"
}

@test "a stacked bottom half: joined under the top, then the extra window moved in and joined up into an accordion" {
	as_focus_window() { echo "focus-window $1" >>"$LOG"; }
	layout_arrange_desktop 7 2000 "30:0:50:0" "31:1:50:0" "32:1:50:1" "33:1:50:1"
	[ "$(grep -E '^(join|layout 33|move-left|focus-window)' "$LOG" | tr '\n' '|')" = "join 32 left|focus-window 32|move-left 33|join 33 up|layout 33 accordion|focus-window 33|" ]
}

@test "a stacked top half over one bottom window" {
	layout_arrange_desktop 7 2000 "30:0:50:0" "31:1:50:0" "34:1:50:0" "32:1:50:1"
	[ "$(grep -E '^(join|layout 34|move-left)' "$LOG" | tr '\n' '|')" = "join 34 left|layout 34 v_accordion|join 32 left|" ]
}

@test "a bottom zone alone in its column fills it: nothing is joined" {
	layout_arrange_desktop 7 2000 "40:0:50:0" "41:1:50:1"
	! grep -q "^join" "$LOG" || false
}

@test "layout_expected_frames: column shares as arranged, a halved column split, a stack sharing its zone" {
	[ "$(layout_expected_frames 0 33 1512 949 0 0 "11:0:67.25:0" "12:1:32.75:0" | paste -sd'|' -)" = "11 0 33 1017 949|12 1017 33 495 949" ]
	[ "$(layout_expected_frames 0 33 1512 949 0 0 "30:0:50:0" "31:1:50:0" "32:1:50:1" "33:1:50:1" | paste -sd'|' -)" = "30 0 33 756 949|31 756 33 756 474|32 756 507 756 474|33 756 507 756 474" ]
	# One zone holding every window: the whole work area.
	[ "$(layout_expected_frames 0 33 1512 949 0 0 "60:0:100:0" "61:0:100:0" | paste -sd'|' -)" = "60 0 33 1512 949|61 0 33 1512 949" ]
	# A bottom zone alone fills its column.
	[ "$(layout_expected_frames 0 33 1512 949 0 0 "40:0:50:0" "41:1:50:1" | paste -sd'|' -)" = "40 0 33 756 949|41 756 33 756 949" ]
}

@test "layout_expected_frames: AeroSpace's gaps, any size, between windows and at the edges" {
	# 3 points everywhere: the tile area loses the outer gaps, each window half the inner gap on
	# every side facing a neighbour, so every edge and every seam is 3 points.
	read -r x y w h gh gv <<<"$(layout_tile_area 0 33 1512 949 3 3 3 3 3 3)"
	[ "$x $y $w $h $gh $gv" = "3 36 1506 943 3 3" ]
	[ "$(layout_expected_frames "$x" "$y" "$w" "$h" "$gh" "$gv" "11:0:67.25:0" "12:1:32.75:0" | paste -sd'|' -)" = "11 3 36 1012 943|12 1018 36 492 943" ]
	[ "$(layout_expected_frames "$x" "$y" "$w" "$h" "$gh" "$gv" "30:0:50:0" "31:1:50:0" "32:1:50:1" | paste -sd'|' -)" = "30 3 36 752 943|31 758 36 752 470|32 758 509 752 470" ]
	[ "$(layout_expected_frames "$x" "$y" "$w" "$h" "$gh" "$gv" "60:0:100:0" | paste -sd'|' -)" = "60 3 36 1506 943" ]
	# Different outer and inner gaps, each on its own side.
	read -r x y w h gh gv <<<"$(layout_tile_area 0 33 1512 949 10 6 1 2 3 4)"
	[ "$x $y $w $h $gh $gv" = "1 35 1508 943 10 6" ]
	[ "$(layout_expected_frames "$x" "$y" "$w" "$h" "$gh" "$gv" "40:0:50:0" "41:1:50:0" "42:1:50:1" | paste -sd'|' -)" = "40 1 35 749 943|41 760 35 749 468|42 760 509 749 468" ]
}

@test "as_gaps: every TOML spelling of the gaps, the main monitor's value, AeroSpace's 0 without a file" {
	foundation_load drivers/aerospace
	run as_gaps
	[ "$output" = "0 0 0 0 0 0" ]
	FOUNDATION_AEROSPACE_CONFIG=$BATS_TEST_TMPDIR/aerospace.toml
	printf 'gaps.inner.horizontal = 3\ngaps.inner.vertical = 4 # comment\ngaps.outer.left = 5\ngaps.outer.top = [{ monitor.main = 16 }, 24]\ngaps.outer.right = [{ monitor."Other" = 9 }, 7]\n' >"$FOUNDATION_AEROSPACE_CONFIG"
	run as_gaps
	[ "$output" = "3 4 5 16 7 0" ]
	printf '[gaps]\ninner = { horizontal = 6, vertical = 8 }\n[gaps.outer]\nleft = 1\nbottom = 2\ntop = 3\nright = 4\n[mode.main.binding]\nalt-h = "focus left"\n' >"$FOUNDATION_AEROSPACE_CONFIG"
	run as_gaps
	[ "$output" = "6 8 1 3 4 2" ]
}

@test "the repository's aerospace.toml: as_gaps reads exactly the gaps it sets, whatever they are" {
	# No value is pinned: every fork sets its own spacing. Each plain `gaps.KIND.SIDE = N` line of
	# the file must come back in its place, and a gap the file leaves out as AeroSpace's 0.
	foundation_load drivers/aerospace
	file=$UNIX_DIR/aerospace/aerospace.toml
	FOUNDATION_AEROSPACE_CONFIG=$file
	run as_gaps
	[ "$status" -eq 0 ]
	[[ $output =~ ^[0-9]+( [0-9]+){5}$ ]]
	read -r -a got <<<"$output"
	keys=(inner.horizontal inner.vertical outer.left outer.top outer.right outer.bottom)
	for i in 0 1 2 3 4 5; do
		want=$(awk -v k="gaps.${keys[i]}" '{ sub(/#.*/, "") } $1 == k && $2 == "=" && $3 ~ /^[0-9]+$/ { v = $3 } END { print v }' "$file")
		[ "${got[i]}" = "${want:-0}" ] || {
			echo "gaps.${keys[i]}: file ${want:-unset}, as_gaps ${got[i]}"
			return 1
		}
	done
}

@test "layout_verify_desktop: a window off its frame or off its desktop is reported, one within 50 points is not" {
	as_windows() { printf '11\tCode\tb\t1\t3\tCode\tA\n12\tFirefox\tb\t2\t3\tFirefox\tB\n13\tSlack\tb\t3\t4\tSlack\tC\n'; }
	as_window_frames() { printf '11 10 40 1000 940\n12 1300 33 212 949\n'; }
	run layout_verify_desktop 3 0 33 1512 949 0 0 "11:0:67.25:0" "12:1:32.75:0" "13:1:32.75:0"
	[ "$status" -eq 1 ]
	[ "${#lines[@]}" -eq 2 ]
	[ "${lines[0]}" = $'12\t1017,33 495x949\t1300,33 212x949' ]
	[ "${lines[1]}" = $'13\tdesktop 3\tdesktop 4' ]
}

@test "layout_verify_desktop: a window whose frame cannot be read is checked only for its desktop" {
	as_windows() { printf '11\tCode\tb\t1\t3\tCode\tA\n'; }
	as_window_frames() { return 1; }
	run layout_verify_desktop 3 0 33 1512 949 0 0 "11:0:50:0"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "as_window_frames: windows of one app with the same title each get their own frame, by window id" {
	foundation_load drivers/aerospace
	osascript() {
		# The script must arrive on stdin and read the window list, not System Events.
		grep -q CGWindowListCopyWindowInfo || return 1
		while [ $# -gt 0 ] && [ "$1" != frames ]; do shift; done
		shift
		# Only window ids are passed: no pid or title to confuse same-titled windows.
		[ $# -eq 2 ] && [ "$1" = 4563 ] && [ "$2" = 4575 ] || return 1
		printf '4575 756 33 756 948\n4563 0 33 756 948\n9999 1 2 3\n'
	}
	run as_window_frames 4563 4575
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "$output" | sort | paste -sd'|' -)" = "4563 0 33 756 948|4575 756 33 756 948" ]
	run as_window_frames
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "the only untitled entry of an app takes every window of it no titled sibling asks for" {
	as_windows() {
		printf '1\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'
		printf '2\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tMyApi\n'
		printf '3\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tNotes\n'
	}
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "1 2 3" Code Code -- "" "*Api*"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -v '^ ' | paste -sd'|' -)" = $'0\t1|1\t2|0\t3' ]
}

@test "untitled duplicates of one app take one window each" {
	as_windows() {
		printf '1\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'
		printf '2\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tMyApi\n'
		printf '3\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tNotes\n'
	}
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "1 2 3" Code Code -- "" ""
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -v '^ ' | paste -sd'|' -)" = $'0\t1|1\t2' ]
}

@test "entries whose app differs only in case are siblings: untitled ones take one window each" {
	as_windows() {
		printf '1\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'
		printf '2\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tMyApi\n'
		printf '3\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tNotes\n'
	}
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "1 2 3" code Code -- "" ""
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -v '^ ' | paste -sd'|' -)" = $'0\t1|1\t2' ]
}

@test "layout_no_wait: one look with TIMEOUT 0, a new window is ready at once, no settle warning" {
	as_windows() {
		printf '1\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'
	}
	layout_no_wait=1
	FOUNDATION_STABLE_MS=60000 run layout_wait 0 "" Code Browser -- "" ""
	[ "$status" -eq 0 ]
	[[ $output != *"did not settle"* ]]
	[[ $output == *"No window found for Browser"* ]]
	printf '%s\n' "${lines[@]}" | grep -qx $'0\t1'
}

@test "single-zone set with several windows is stacked, the last entry in front" {
	as_focus_window() { echo "focus-window $1" >>"$LOG"; }
	layout_arrange_desktop 1 2000 "62:0:100:0" "60:0:100:0" "61:0:100:0"
	grep -q "^layout 62 h_accordion$" "$LOG"
	[ "$(grep '^focus-window' "$LOG" | tail -1)" = "focus-window 61" ]
}

@test "an entry without a title leaves a titled sibling's window alone" {
	as_windows() {
		printf '300\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\tDocs - Mozilla Firefox\n'
		printf '301\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\tOther - Mozilla Firefox\n'
	}
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "300 301" Browser Browser -- "" "*Docs*"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -v '^ ' | sort | paste -sd'|' -)" = $'0\t301|1\t300' ]
}

@test "a remembered pin gives its entry the same window again, even when another window comes first" {
	as_windows() {
		printf '300\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\tYouTube\n'
		printf '301\tFirefox\torg.mozilla.firefox\t1\t2\tFirefox\tYouTube\n'
	}
	layout_pins=([0]=301 [1]=300)
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "300 301" Browser Browser -- "*YouTube*" "*YouTube*"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -v '^ ' | sort | paste -sd'|' -)" = $'0\t301|1\t300' ]
	# A pin that no longer matches (another title) is ignored: the entry claims as usual.
	layout_pins=([0]=301)
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "300 301" Browser -- "*Docs*"
	[[ $output == *"No window found for Browser [*Docs*]"* ]]
}

@test "without a pin a window already on the entry's desktop is preferred" {
	as_windows() {
		printf '300\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\tYouTube\n'
		printf '301\tFirefox\torg.mozilla.firefox\t1\t2\tFirefox\tYouTube\n'
	}
	layout_entry_desktop=(2 1)
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "300 301" Browser Browser -- "*YouTube*" "*YouTube*"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -v '^ ' | sort | paste -sd'|' -)" = $'0\t301|1\t300' ]
}

@test "a new window is ready only once its title and its frame both held" {
	as_windows() { printf '500\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'; }
	# The frame grows on every read (VS Code restoring its bounds): never stable within the wait.
	as_window_frames() {
		local n
		n=$(($(cat "$BATS_TEST_TMPDIR/reads" 2>/dev/null || echo 0) + 1))
		echo "$n" >"$BATS_TEST_TMPDIR/reads"
		printf '500 0 0 %s 600\n' "$((800 + n))"
	}
	FOUNDATION_POLL_SECONDS=0.05 FOUNDATION_STABLE_MS=150 run layout_wait 1 "" Code -- ""
	[[ $output == *"did not settle in time"* ]]
	# The same window with a frame that holds settles.
	as_window_frames() { printf '500 0 0 800 600\n'; }
	FOUNDATION_POLL_SECONDS=0.05 FOUNDATION_STABLE_MS=150 run layout_wait 1 "" Code -- ""
	[[ $output != *"did not settle"* ]]
	printf '%s\n' "${lines[@]}" | grep -qx $'0\t500'
}

@test "a frame read once never makes a window ready, even when the pass is slower than stable-ms" {
	# A slow pass (a loaded CI runner): each window-list read takes longer than the stability
	# window, so by the first frame read the claim is already older than stable-ms. That first
	# frame alone must not count as held; the frame still grows on every read, so the window never
	# settles.
	as_windows() {
		sleep 0.3
		printf '500\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'
	}
	as_window_frames() {
		local n
		n=$(($(cat "$BATS_TEST_TMPDIR/reads" 2>/dev/null || echo 0) + 1))
		echo "$n" >"$BATS_TEST_TMPDIR/reads"
		printf '500 0 0 %s 600\n' "$((800 + n))"
	}
	FOUNDATION_POLL_SECONDS=0.05 FOUNDATION_STABLE_MS=150 run layout_wait 1 "" Code -- ""
	[[ $output == *"did not settle in time"* ]]
	# The same slow reads with a frame that holds: the second matching read makes it ready.
	as_window_frames() { printf '500 0 0 800 600\n'; }
	FOUNDATION_POLL_SECONDS=0.05 FOUNDATION_STABLE_MS=150 run layout_wait 2 "" Code -- ""
	[[ $output != *"did not settle"* ]]
	printf '%s\n' "${lines[@]}" | grep -qx $'0\t500'
}

@test "layout_render: proportional columns, halved column split, labels in their cells" {
	expected='┌───────────────────┬───────────────────┐
│                   │    [Top-Right]    │
│      [Left]       │                   │
│       Code        ├───────────────────┤
│                   │  [Bottom-Right]   │
│                   │     Terminal      │
└───────────────────┴───────────────────┘'
	actual=$(printf '0\t0\tCode\n1\t1\tTerminal\n' | layout_render Six 41)
	[ "$actual" = "$expected" ] || {
		printf 'got:\n%s\n' "$actual"
		return 1
	}
}

@test "layout_render: unknown zone set fails" {
	run layout_render NoSuchSet </dev/null
	[ "$status" -ne 0 ]
}

@test "benchmark_record: one CSV row per open with the layout phases and outcome" {
	copy_fixture_config
	# Settings go before the first section: the overlay's top lines (an append to the base file
	# would land in its last workspace).
	printf 'benchmark-display line\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	foundation_load config benchmark
	export FOUNDATION_STATE_DIR="$BATS_TEST_TMPDIR/state"
	layout_type() { echo Work; }
	echo "1500 300 2 3 Partial" >"$BATS_TEST_TMPDIR/timings"
	run benchmark_record Demo 4200 2000 1900 "$BATS_TEST_TMPDIR/timings"
	[[ $output == *" Timing [Demo] => actions 2.0s | wait 1.5s | arrange 0.3s | other 0.4s | outcome Partial 2/3"* ]]
	[ "$(head -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f12)" = Outcome ]
	[ "$(tail -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f2,5-12)" = "Demo,4.2,2.0,1.9,1.5,0.3,2,3,Partial" ]
	run benchmark_record Plain 900 900 0 "$BATS_TEST_TMPDIR/missing"
	[[ $output == *" Timing [Plain] => actions 0.9s"* ]]
	[[ $output != *outcome* ]]
	[ "$(tail -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f12)" = NoLayout ]
}

@test "benchmark_record: the mode and the layout attempts are recorded, retries shown" {
	copy_fixture_config
	printf 'benchmark-display line\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	foundation_load config benchmark
	export FOUNDATION_STATE_DIR="$BATS_TEST_TMPDIR/state"
	layout_type() { echo Work; }
	echo "1500 300 3 3 Applied 3" >"$BATS_TEST_TMPDIR/timings"
	run benchmark_record Demo 4200 2000 1900 "$BATS_TEST_TMPDIR/timings" Alongside
	[[ $output == *" Timing [Demo] => actions 2.0s | wait 1.5s | arrange 0.3s | other 0.4s | retries 2"* ]]
	[ "$(head -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f15,16)" = "Mode,Attempts" ]
	[ "$(tail -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f12,15,16)" = "Applied,Alongside,3" ]
	# A first-try layout shows no retries; without MODE the open is Plain; a timings file of an
	# older writer (five fields) counts as one attempt; no layout at all is 0.
	echo "1500 300 3 3 Applied 1" >"$BATS_TEST_TMPDIR/timings"
	run benchmark_record Demo 4200 2000 1900 "$BATS_TEST_TMPDIR/timings"
	[[ $output != *retries* ]]
	[ "$(tail -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f15,16)" = "Plain,1" ]
	echo "1500 300 3 3 Applied" >"$BATS_TEST_TMPDIR/timings"
	run benchmark_record Demo 4200 2000 1900 "$BATS_TEST_TMPDIR/timings"
	[ "$(tail -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f12,16)" = "Applied,1" ]
	run benchmark_record Plain 900 900 0 "$BATS_TEST_TMPDIR/missing"
	[ "$(tail -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f12,16)" = "NoLayout,0" ]
}

@test "benchmark_record: a file from before the newer columns keeps its rows and gains the header" {
	copy_fixture_config
	printf 'benchmark-display none\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	foundation_load config benchmark
	export FOUNDATION_STATE_DIR="$BATS_TEST_TMPDIR/state"
	layout_type() { echo Work; }
	mkdir -p "$FOUNDATION_STATE_DIR"
	csv=$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv
	printf 'Timestamp,Workspace,Machine,LayoutSet,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,ArrangeSeconds,Found,Expected,Outcome\n2026-01-01T10:00:00,Old,PC,Work,1.0,1.0,0.0,0.0,0.0,0,0,NoLayout\n' >"$csv"
	run benchmark_record New 900 900 0 "$BATS_TEST_TMPDIR/missing"
	[ "$(head -1 "$csv")" = 'Timestamp,Workspace,Machine,LayoutSet,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,ArrangeSeconds,Found,Expected,Outcome,EarlyMove,Source,Mode,Attempts' ]
	[ "$(sed -n 2p "$csv")" = '2026-01-01T10:00:00,Old,PC,Work,1.0,1.0,0.0,0.0,0.0,0,0,NoLayout' ]
	[ "$(tail -1 "$csv" | cut -d, -f2,15,16)" = "New,Plain,0" ]
	# A current header is left alone.
	run benchmark_record New 900 900 0 "$BATS_TEST_TMPDIR/missing"
	[ "$(head -1 "$csv" | tr ',' '\n' | grep -c .)" -eq 16 ]
}

@test "benchmark_record: off without a benchmark line; display none is silent, table the default" {
	copy_fixture_config
	foundation_load config benchmark
	export FOUNDATION_STATE_DIR="$BATS_TEST_TMPDIR/state"
	layout_type() { echo Work; }
	grep -v '^benchmark ' "$FIXTURE_CONFIG/workspaces.conf" >"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run benchmark_record Demo 900 900 0 "$BATS_TEST_TMPDIR/missing"
	[ -z "$output" ]
	[ ! -e "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" ]
	# The settings in the overlay's top lines, before any section.
	printf 'benchmark on\nbenchmark-display none\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run benchmark_record Demo 900 900 0 "$BATS_TEST_TMPDIR/missing"
	[ -z "$output" ]
	[ "$(tail -1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f2)" = Demo ]
	printf 'benchmark on\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	run benchmark_record Demo 900 900 0 "$BATS_TEST_TMPDIR/missing"
	[[ $output == *"Workspace Benchmark"* ]]
	[[ $output != *"Timing [Demo]"* ]]
}

@test "layout_stable_ms: FOUNDATION_STABLE_MS, else layout-stable-ms, else the base 500" {
	use_empty_config
	file=$FOUNDATION_CONFIG_DIR/workspaces.conf
	printf 'layout-stable-ms 800\n' >"$file"
	[ "$(layout_stable_ms)" = 800 ]
	FOUNDATION_STABLE_MS=0
	[ "$(layout_stable_ms)" = 0 ]
	unset FOUNDATION_STABLE_MS
	# A missing line behaves like the shipped base line, not like an older code default.
	printf 'layout-early-move off\n' >"$file"
	[ "$(layout_stable_ms)" = 500 ]
	printf 'layout-stable-ms soon\n' >"$file"
	[ "$(layout_stable_ms)" = 500 ]
}

@test "windows_select: app token or name and title patterns; centered frame in the work area" {
	foundation_load windows
	as_windows() {
		printf '1\tFirefox\torg.mozilla.firefox\t11\t1\tFirefox\tYouTube - Watch\n'
		printf '2\tCode\tcom.microsoft.VSCode\t12\t2\tCode\tDotfiles\n'
		printf '3\tFirefox\torg.mozilla.firefox\t11\t2\tFirefox\tGitHub\n'
	}
	[ "$(windows_select Firefox '' | cut -f1 | paste -sd, -)" = "1,3" ]
	[ "$(windows_select '' '*YouTube*' | cut -f1)" = "1" ]
	[ "$(windows_select '(firefox|code)' '' 2 | cut -f1 | paste -sd, -)" = "2,3" ]
	# Both patterns: a window matching EITHER, as Get-WindowHandle (and Windows) match.
	[ "$(windows_select Code '*YouTube*' | cut -f1 | paste -sd, -)" = "1,2" ]
	# A role matches its member apps, as in Get-WindowHandle.
	[ "$(windows_select Browser '' | cut -f1 | paste -sd, -)" = "1,3" ]
	as_primary_monitor() { echo "1512 982 0 38 1512 944"; }
	[ "$(windows_centered_frame 40 50)" = "454 274 604 472" ]
}

@test "layout_render: a label longer than its cell ends in ~, multibyte labels keep every line the same width" {
	dash=$(printf '\342\200\224')
	long=$(printf 'L%.0s' $(seq 1 40))
	actual=$(printf '0\t0\t%s\n0\t0\tDocs %s Code\n1\t0\tAbc%sdefg\n' "$long" "$dash" "$dash" | layout_render Five 21)
	# Characters per line, counted as layout_render counts them: bytes less UTF-8 continuation bytes.
	widths=$(printf '%s\n' "$actual" | env LC_ALL=C awk '{ c = $0; n = gsub(/[\200-\277]/, "", c); print length($0) - n }' | sort -u)
	[ "$widths" = 21 ] || {
		printf 'widths %s, got:\n%s\n' "$widths" "$actual"
		return 1
	}
	# 18 inner points: the left cell is 12 wide, so the long label keeps 11 characters and a ~.
	[[ $actual == *"│LLLLLLLLLLL~│"* ]]
	[[ $actual == *"Docs ${dash} Code"* ]]
	# A cut through the multibyte character drops its partial bytes before the ~.
	[[ $actual == *"Abc~"* ]]
}

@test "layout_type: this machine type's layout-override names the set" {
	use_empty_config
	printf 'layout-override Work Tower\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	FOUNDATION_MACHINE_TYPE=Work
	[ "$(layout_type)" = Tower ]
}

@test "layout_type: another type's override, or one without a set, is ignored" {
	use_empty_config
	FOUNDATION_MACHINE_TYPE=Work
	printf 'layout-override Laptop Tower\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	[ "$(layout_type)" = Work ]
	printf 'layout-override Work\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	[ "$(layout_type)" = Work ]
}

@test "layout_type: an override beats the small-display rule" {
	use_empty_config
	FOUNDATION_MACHINE_TYPE=Work
	as_primary_monitor() { echo "1512 982 0 33 1512 949"; }
	printf 'small-display Laptop\nlayout-override Work Tower\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	[ "$(layout_type)" = Tower ]
}

@test "layout_type: small-display applies up to small-display-width points, the limit itself included" {
	use_empty_config
	FOUNDATION_MACHINE_TYPE=Work
	printf 'small-display Laptop\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	as_primary_monitor() { echo "3000 1000 0 33 3000 967"; }
	[ "$(layout_type)" = Laptop ]
	as_primary_monitor() { echo "3001 1000 0 33 3001 967"; }
	[ "$(layout_type)" = Work ]
	printf 'small-display Laptop\nsmall-display-width 1512\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	[ "$(layout_type 1512)" = Laptop ]
	[ "$(layout_type 1513)" = Work ]
}

@test "layout_type: without a small-display line the display is never measured; without machines.conf the machine type" {
	use_empty_config
	FOUNDATION_MACHINE_TYPE=Work
	as_primary_monitor() { touch "$BATS_TEST_TMPDIR/measured"; }
	printf 'type Work\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	[ "$(layout_type)" = Work ]
	[ ! -e "$BATS_TEST_TMPDIR/measured" ]
	rm "$FOUNDATION_CONFIG_DIR/machines.conf"
	[ "$(layout_type)" = Work ]
}

@test "layout_wait: a new window is ready only once its title held; a pre-existing one at once" {
	# The title changes on the second look, then holds.
	as_windows() {
		local n title=Loading
		n=$(($(cat "$BATS_TEST_TMPDIR/looks" 2>/dev/null || echo 0) + 1))
		echo "$n" >"$BATS_TEST_TMPDIR/looks"
		[ "$n" -lt 2 ] || title=Dotfiles
		printf '500\tCode\tcom.microsoft.VSCode\t1\t1\tCode\t%s\n' "$title"
	}
	start=$(foundation_now_ms)
	FOUNDATION_POLL_SECONDS=0.05 FOUNDATION_STABLE_MS=300 run layout_wait 5 "" Code -- ""
	[ $(($(foundation_now_ms) - start)) -ge 300 ]
	[[ $output != *"did not settle"* ]]
	printf '%s\n' "${lines[@]}" | grep -qx $'0\t500'
	[ "$(cat "$BATS_TEST_TMPDIR/looks")" -ge 4 ]
	# Pre-existing: nothing has to hold, a minute of stability or not.
	start=$(foundation_now_ms)
	FOUNDATION_POLL_SECONDS=0.05 FOUNDATION_STABLE_MS=60000 run layout_wait 5 "500" Code -- ""
	[ $(($(foundation_now_ms) - start)) -lt 3000 ]
	[[ $output != *"did not settle"* ]]
	printf '%s\n' "${lines[@]}" | grep -qx $'0\t500'
}

@test "layout_wait: a window whose title drifts out of the pattern is released and the other match claimed" {
	as_windows() {
		local n title='Docs A'
		n=$(($(cat "$BATS_TEST_TMPDIR/looks" 2>/dev/null || echo 0) + 1))
		echo "$n" >"$BATS_TEST_TMPDIR/looks"
		[ "$n" -lt 2 ] || title='Something else'
		printf '300\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\t%s\n' "$title"
		printf '301\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\tDocs B\n'
	}
	FOUNDATION_POLL_SECONDS=0.05 FOUNDATION_STABLE_MS=100 run layout_wait 5 "" Browser -- "*Docs*"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -v '^ ' | paste -sd'|' -)" = $'0\t301' ]
}

@test "layout_wait: a window this open created is claimed before a pre-existing one" {
	as_windows() {
		printf '300\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\tYouTube old\n'
		printf '301\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\tYouTube new\n'
	}
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "300" Browser -- "*YouTube*"
	[ "$status" -eq 0 ]
	[ "$(printf '%s\n' "${lines[@]}" | grep -v '^ ' | paste -sd'|' -)" = $'0\t301' ]
}

@test "layout_wait: with layout_early_desktop a window moves to its desktop the moment it is claimed" {
	as_windows() { printf '500\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'; }
	layout_early_desktop=([0]=3)
	FOUNDATION_STABLE_MS=0 run layout_wait 1 "" Code -- ""
	[ "$status" -eq 0 ]
	[ "$(cat "$LOG")" = "move 500 3" ]
}

@test "layout_wait: a title still changing at the timeout is placed anyway, with a warning" {
	as_windows() { printf '500\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'; }
	FOUNDATION_STABLE_MS=60000 run layout_wait 0 "" Code -- ""
	[ "$status" -eq 0 ]
	[[ $output == *"Window 500 for Code did not settle in time - placing it anyway"* ]]
	printf '%s\n' "${lines[@]}" | grep -qx $'0\t500'
}

@test "layout_wait: past the grace an entry whose app is not running is given up, not waited for until the timeout" {
	copy_fixture_config
	printf 'layout-absent-grace-seconds 1\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	as_windows() { printf '500\tCode\tcom.microsoft.VSCode\t1\t1\tCode\tDotfiles\n'; }
	app_pids() { :; }
	start=$(foundation_now_ms)
	FOUNDATION_POLL_SECONDS=0.1 FOUNDATION_STABLE_MS=0 run layout_wait 30 "" Code Steam -- "" ""
	[ $(($(foundation_now_ms) - start)) -lt 10000 ]
	[[ $output == *"No window found for Steam"* ]]
	printf '%s\n' "${lines[@]}" | grep -qx $'0\t500'
}

@test "layout_wait: past the grace an entry whose only matches are protected windows is given up" {
	copy_fixture_config
	printf 'layout-absent-grace-seconds 1\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	as_windows() { printf '300\tFirefox\torg.mozilla.firefox\t1\t1\tFirefox\tDocs\n'; }
	# Firefox runs: the entry is given up for its protected window alone.
	app_pids() { echo 99999999; }
	layout_protected=' 300 '
	start=$(foundation_now_ms)
	FOUNDATION_POLL_SECONDS=0.1 FOUNDATION_STABLE_MS=0 run layout_wait 30 "" Browser -- "*Docs*"
	[ $(($(foundation_now_ms) - start)) -lt 10000 ]
	[[ $output == *"No window found for Browser [*Docs*]"* ]]
}

@test "layout_wait: a running app is waited for until the timeout, and grace 0 never gives up" {
	copy_fixture_config
	printf 'layout-absent-grace-seconds 1\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	as_windows() { :; }
	app_pids() { echo 99999999; }
	start=$(foundation_now_ms)
	FOUNDATION_POLL_SECONDS=0.1 run layout_wait 2 "" Steam -- ""
	[ $(($(foundation_now_ms) - start)) -ge 2000 ]
	app_pids() { :; }
	printf 'layout-absent-grace-seconds 0\n' >"$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	start=$(foundation_now_ms)
	FOUNDATION_POLL_SECONDS=0.1 run layout_wait 2 "" Steam -- ""
	[ $(($(foundation_now_ms) - start)) -ge 2000 ]
	[ "$(layout_absent_grace_seconds)" = 0 ]
	rm "$FOUNDATION_CONFIG_DIR/workspaces.local.conf"
	[ "$(layout_absent_grace_seconds)" = 10 ]
}

@test "zones.conf is read again when it changes during the process" {
	copy_fixture_config
	# The first lookup fills the per-process copy; the change below must still be seen.
	zone_set_known One
	! zone_set_known Extra || false
	printf 'Extra Left:50 Right:50\n' >>"$FOUNDATION_CONFIG_DIR/zones.local.conf"
	zone_set_known Extra
	[ "$(zone_column Extra Right)" = "1 50 0" ]
	[ "$(zone_column One Right)" = "1 50 0" ]
}
