#!/usr/bin/env bats
# Invoke-Fastfetch against a stub fastfetch and a fake terminal: the image-logo line of
# greeting.conf for this machine type is passed as an image only in a terminal that shows images and
# only when the file exists; the panel is measured against the window (minus the command line,
# fastfetch-prompt-reserve and --extra-rows); in WezTerm the font is reset on every call and shrunk
# step by step until the panel fits, up to fastfetch-max-shrink-steps or the smallest font, and a
# panel that still overflows (or overflows anywhere else) is drawn without its logo;
# fastfetch off, fastfetch-auto-fit off, --no-resize and a missing terminal measure nothing; the
# per-call overrides of the greeting.conf numbers, an out-of-range number, --always and a missing
# fastfetch.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	# The measuring run (--pipe) prints a PANEL_ROWS x PANEL_COLUMNS panel; the drawing run prints nothing.
	stub_tool fastfetch 'case " $* " in *" --pipe "*) awk -v r="${PANEL_ROWS:-18}" -v c="${PANEL_COLUMNS:-80}" '"'"'BEGIN { for (i = 0; i < r; i++) printf "%" c "s\n", "x" }'"'"' ;; esac
exit 0'
	# The fake terminal: FOUNDATION_TTY collects the font steps wt_font_step writes, and stty answers
	# WINDOW_SIZE (rows columns) grown by 3 rows and 10 columns per step below the default font that
	# the last step reached, never more than FONT_FLOOR steps (the smallest font).
	cat >"$BATS_TEST_TMPDIR/tools/stty" <<'STUB'
#!/bin/sh
step=$(steps_in "$FOUNDATION_TTY" | awk '{ s = $1 } END { print s + 0 }')
[ "$step" -le "${FONT_FLOOR:-50}" ] || step=${FONT_FLOOR:-50}
set -- ${WINDOW_SIZE:-40 120}
echo "$(($1 + 3 * step)) $(($2 + 10 * step))"
STUB
	cat >"$BATS_TEST_TMPDIR/tools/steps_in" <<'STUB'
#!/bin/sh
tr '\007' '\n' <"$1" | sed -n 's/.*SetUserVar=FONT_STEP=//p' | while IFS= read -r value; do
	printf '%s' "$value" | base64 -d | cut -d' ' -f1
done
STUB
	chmod +x "$BATS_TEST_TMPDIR/tools/stty" "$BATS_TEST_TMPDIR/tools/steps_in"
	cmd=$UNIX_DIR/modules/System/bin/Invoke-Fastfetch
	image=$BATS_TEST_TMPDIR/logo.png
	: >"$image"
	printf '%s\n' "@Work image-logo $image 30x12" "@Laptop image-logo $BATS_TEST_TMPDIR/missing.png" >"$FOUNDATION_CONFIG_DIR/greeting.conf"
	export FOUNDATION_MACHINE_TYPE=Work
	unset TERM_PROGRAM
}

# A terminal to measure against: the stand-in file exists, so stty answers and font steps land in it.
with_terminal() { : >"$FOUNDATION_TTY"; }

# The font steps sent, in order, on one line ("0 1 2").
steps_sent() { [ -f "$FOUNDATION_TTY" ] && steps_in "$FOUNDATION_TTY" | paste -sd' ' -; }

# The drawing call (the last fastfetch line without --pipe) and whether a measuring call ran.
drawn() { grep '^fastfetch' "$BATS_TEST_TMPDIR/tool.log" | grep -v -- '--pipe' | tail -n 1 | sed 's/ *$//'; }
measured() { grep -q -- '^fastfetch .*--pipe' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null; }

@test "WezTerm and Ghostty get this machine type's image at its size" {
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" --no-resize
	[ "$status" -eq 0 ]
	[ "$(drawn)" = "fastfetch --logo $image --logo-type kitty-direct --logo-width 30 --logo-height 12 --logo-padding-top 2" ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	TERM_PROGRAM=ghostty run "${BASH:-bash}" "$cmd" --no-resize
	[[ $(drawn) == "fastfetch --logo $image "* ]]
}

@test "a terminal without images, a machine type without a line and a missing file keep the text logo" {
	TERM_PROGRAM=Apple_Terminal run "${BASH:-bash}" "$cmd" --no-resize
	[ "$(drawn)" = fastfetch ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	FOUNDATION_MACHINE_TYPE=PC TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" --no-resize
	[ "$(drawn)" = fastfetch ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	FOUNDATION_MACHINE_TYPE=Laptop TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" --no-resize
	[ "$(drawn)" = fastfetch ]
}

@test "without a size the image is 30x14" {
	printf '%s\n' "image-logo $image" >"$FOUNDATION_CONFIG_DIR/greeting.conf"
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" --no-resize
	[[ $(drawn) == *"--logo-width 30 --logo-height 14"* ]]
}

@test "a panel that fits is measured with the image logo and drawn with it" {
	with_terminal
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -q -- "^fastfetch --logo $image .*--pipe" "$BATS_TEST_TMPDIR/tool.log"
	[[ $(drawn) == "fastfetch --logo $image "* ]]
}

@test "--extra-rows counts against the height: 18 rows fit 24 with 4 more below, not with 5" {
	with_terminal
	export WINDOW_SIZE='24 120'
	run "${BASH:-bash}" "$cmd" --extra-rows 4
	[ "$(drawn)" = fastfetch ]
	run "${BASH:-bash}" "$cmd" --extra-rows 5
	[ "$status" -eq 0 ]
	[ "$(drawn)" = "fastfetch --logo none" ]
}

@test "fastfetch-prompt-reserve sets the rows kept free, and an out-of-range value falls back to 1" {
	with_terminal
	export WINDOW_SIZE='24 120'
	echo 'fastfetch-prompt-reserve 6' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$(drawn)" = "fastfetch --logo none" ]
	echo 'fastfetch-prompt-reserve 21' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$(drawn)" = fastfetch ]
}

@test "a panel wider than the window is drawn without its logo" {
	with_terminal
	export WINDOW_SIZE='40 79'
	run "${BASH:-bash}" "$cmd"
	[ "$(drawn)" = "fastfetch --logo none" ]
}

@test "--no-resize, fastfetch-auto-fit off and a missing terminal measure nothing" {
	export WINDOW_SIZE='5 10'
	run "${BASH:-bash}" "$cmd"
	! measured || false
	[ "$(drawn)" = fastfetch ]
	with_terminal
	run "${BASH:-bash}" "$cmd" --no-resize
	! measured || false
	echo 'fastfetch-auto-fit off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd"
	! measured || false
	[ "$(drawn)" = fastfetch ]
}

@test "fastfetch off draws nothing" {
	echo 'fastfetch off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	! grep -q '^fastfetch' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || false
}

@test "--extra-rows takes a whole number" {
	run "${BASH:-bash}" "$cmd" --extra-rows two
	[ "$status" -ne 0 ]
	! grep -q '^fastfetch' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || false
}

@test "WezTerm resets the font on every call, also when the panel fits" {
	with_terminal
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(steps_sent)" = 0 ]
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$(steps_sent)" = "0 0" ]
	[[ $(drawn) == "fastfetch --logo $image "* ]]
}

@test "WezTerm shrinks the font one step at a time until the panel fits, and keeps the logo" {
	with_terminal
	# 18 rows need 20 (the command line and the prompt reserve): 14 rows, then 17, then 20.
	export WINDOW_SIZE='14 120'
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(steps_sent)" = "0 1 2" ]
	[[ $(drawn) == "fastfetch --logo $image "* ]]
	# The next call starts from the default font again.
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$(steps_sent)" = "0 1 2 0 1 2" ]
}

@test "WezTerm stops at fastfetch-max-shrink-steps and then drops the logo" {
	with_terminal
	export WINDOW_SIZE='5 120'
	echo 'fastfetch-max-shrink-steps 2' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$(steps_sent)" = "0 1 2" ]
	[ "$(drawn)" = "fastfetch --logo none" ]
	echo 'fastfetch-max-shrink-steps 0' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	: >"$FOUNDATION_TTY"
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$(steps_sent)" = 0 ]
	[ "$(drawn)" = "fastfetch --logo none" ]
}

@test "WezTerm stops when a step leaves the window unchanged (the smallest font)" {
	with_terminal
	export WINDOW_SIZE='5 120' FONT_FLOOR=1
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$(steps_sent)" = "0 1 2" ]
	[ "$(drawn)" = "fastfetch --logo none" ]
}

@test "the font is left alone with --no-resize, fastfetch-auto-fit off and outside WezTerm" {
	with_terminal
	export WINDOW_SIZE='5 120'
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" --no-resize
	[ -z "$(steps_sent)" ]
	TERM_PROGRAM=ghostty run "${BASH:-bash}" "$cmd"
	[ -z "$(steps_sent)" ]
	[ "$(drawn)" = "fastfetch --logo none" ]
	echo 'fastfetch-auto-fit off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ -z "$(steps_sent)" ]
}

@test "without fastfetch it exits 0 and prints nothing" {
	FOUNDATION_FASTFETCH=$BATS_TEST_TMPDIR/no-fastfetch run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	FOUNDATION_FASTFETCH=$BATS_TEST_TMPDIR/no-fastfetch run "${BASH:-bash}" "$cmd" --always
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "--always draws even with fastfetch off" {
	echo 'fastfetch off' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --always --no-resize
	[ "$status" -eq 0 ]
	[ "$(drawn)" = fastfetch ]
}

@test "an out-of-range fastfetch-max-shrink-steps warns and falls back to 10" {
	with_terminal
	# A 60-row panel would need 19 steps: the cap of 10 stops it first.
	export WINDOW_SIZE='5 120' PANEL_ROWS=60
	echo 'fastfetch-max-shrink-steps 99' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"fastfetch-max-shrink-steps"*"99"* ]]
	[ "$(steps_sent)" = "0 1 2 3 4 5 6 7 8 9 10" ]
}

@test "--prompt-reserve, --max-shrink-steps and --reflow-timeout-milliseconds override greeting.conf for one call" {
	with_terminal
	export WINDOW_SIZE='24 120'
	echo 'fastfetch-prompt-reserve 6' >>"$FOUNDATION_CONFIG_DIR/greeting.conf"
	run "${BASH:-bash}" "$cmd" --prompt-reserve 1
	[ "$(drawn)" = fastfetch ]
	export WINDOW_SIZE='5 120'
	TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" -MaxShrinkSteps 0 -ReflowTimeoutMilliseconds 20
	[ "$status" -eq 0 ]
	[ "$(steps_sent)" = 0 ]
	[ "$(drawn)" = "fastfetch --logo none" ]
}

@test "an override out of its range stops the command before fastfetch runs" {
	for arguments in "--prompt-reserve 21" "--max-shrink-steps 51" "--reflow-timeout-milliseconds 0" "--max-shrink-steps two"; do
		# shellcheck disable=SC2086 # one flag and its value
		run "${BASH:-bash}" "$cmd" $arguments
		[ "$status" -ne 0 ]
	done
	! grep -q '^fastfetch' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || false
}

@test "FOUNDATION_STARTUP_SKIP naming FastfetchImageLogo, in any case, keeps the text logo" {
	FOUNDATION_STARTUP_SKIP='Prompt; fastfetchimagelogo' TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" --no-resize
	[ "$(drawn)" = fastfetch ]
	FOUNDATION_STARTUP_SKIP=Prompt TERM_PROGRAM=WezTerm run "${BASH:-bash}" "$cmd" --no-resize
	[[ $(drawn) == "fastfetch --logo $image "* ]]
}
