#!/usr/bin/env bats
# Set-SystemTheme against defaults and osascript stand-ins (the real appearance and wallpaper never
# change): the appearance is set only when it differs, Toggle flips it, --auto reads theme.conf,
# and the SetWallpaper step runs the real Set-Wallpaper unless theme.conf or --skip turns it off.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	export FOUNDATION_MACHINE_TYPE=Laptop
	walls=$BATS_TEST_TMPDIR/walls
	mkdir -p "$walls"
	touch "$walls/dark.jpg" "$walls/light.jpg"
	printf 'directory %s\n\n[Dark]\nDefault dark.jpg\n\n[Light]\nDefault light.jpg\n' "$walls" >"$FOUNDATION_CONFIG_DIR/wallpapers.conf"
	# One display; osascript-fails refuses every request.
	stub_tool osascript "[ \"\$1\" = - ] && cat >/dev/null; [ -f '$BATS_TEST_TMPDIR/osascript-fails' ] && exit 1
case \"\$*\" in *'count of desktops'*) echo 1 ;; esac
exit 0"
	stub_tool defaults "[ -f '$BATS_TEST_TMPDIR/dark' ] || exit 1; echo Dark"
	[ "$(command -v osascript)" = "$BATS_TEST_TMPDIR/tools/osascript" ]
	[ "$(command -v defaults)" = "$BATS_TEST_TMPDIR/tools/defaults" ]
	log=$BATS_TEST_TMPDIR/tool.log
	: >"$log"
	cmd=$UNIX_DIR/modules/System/bin/Set-SystemTheme
}

appearance_set() { # true|false
	grep -q "set dark mode to $1\$" "$log"
}

wallpaper_set() { # PICTURE
	grep -qx "osascript - 1 $walls/$1" "$log"
}

@test "Dark from Light sets dark mode, then the Dark wallpaper" {
	run "${BASH:-bash}" "$cmd" Dark
	[ "$status" -eq 0 ]
	appearance_set true
	wallpaper_set dark.jpg
}

@test "the appearance already in use is left alone; the wallpaper is still set" {
	run "${BASH:-bash}" "$cmd" --theme light
	[ "$status" -eq 0 ]
	! grep -q 'dark mode' "$log" || false
	wallpaper_set light.jpg
}

@test "Toggle flips the current appearance" {
	touch "$BATS_TEST_TMPDIR/dark"
	run "${BASH:-bash}" "$cmd" Toggle
	[ "$status" -eq 0 ]
	appearance_set false
	wallpaper_set light.jpg
	rm "$BATS_TEST_TMPDIR/dark"
	: >"$log"
	run "${BASH:-bash}" "$cmd" toggle
	appearance_set true
}

@test "--auto takes this machine type's theme from theme.conf" {
	run "${BASH:-bash}" "$cmd" --auto
	[ "$status" -eq 0 ]
	appearance_set true
	wallpaper_set dark.jpg
}

@test "--auto without a theme for this machine type changes nothing" {
	export FOUNDATION_MACHINE_TYPE=Work
	run "${BASH:-bash}" "$cmd" --auto
	[ "$status" -eq 0 ]
	! grep -q '^osascript' "$log" || false
}

@test "--skip SetWallpaper changes the appearance only" {
	run "${BASH:-bash}" "$cmd" Dark --skip SetWallpaper
	[ "$status" -eq 0 ]
	appearance_set true
	! grep -q '^osascript - ' "$log" || false
}

@test "theme.conf turns the step off, --include turns it back on, --skip wins over both" {
	echo 'step SetWallpaper off' >>"$FOUNDATION_CONFIG_DIR/theme.conf"
	run "${BASH:-bash}" "$cmd" Dark
	[ "$status" -eq 0 ]
	! grep -q '^osascript - ' "$log" || false
	: >"$log"
	run "${BASH:-bash}" "$cmd" Dark --include SetWallpaper
	wallpaper_set dark.jpg
	: >"$log"
	run "${BASH:-bash}" "$cmd" Dark --include SetWallpaper --skip SetWallpaper
	[ "$status" -eq 0 ]
	! grep -q '^osascript - ' "$log" || false
}

@test "a failing wallpaper step does not fail the theme" {
	rm "$FOUNDATION_CONFIG_DIR/wallpapers.conf"
	run "${BASH:-bash}" "$cmd" Dark
	[ "$status" -eq 0 ]
	appearance_set true
}

@test "a refused appearance change fails before the wallpaper" {
	touch "$BATS_TEST_TMPDIR/osascript-fails"
	run "${BASH:-bash}" "$cmd" Dark
	[ "$status" -ne 0 ]
	! grep -q '^osascript - ' "$log" || false
}

@test "an unknown theme fails and changes nothing" {
	run "${BASH:-bash}" "$cmd" Blue
	[ "$status" -ne 0 ]
	! grep -q '^osascript' "$log" || false
}

@test "--skip takes a comma list; an unknown step or flag changes nothing" {
	run "${BASH:-bash}" "$cmd" Dark --skip SetWallpaper,
	[ "$status" -eq 0 ]
	appearance_set true
	! wallpaper_set dark.jpg || false
	: >"$log"
	run "${BASH:-bash}" "$cmd" Dark --skip SetWalpaper
	[ "$status" -eq 1 ]
	[[ $output == *"Unknown step [SetWalpaper]"* ]]
	! appearance_set true || false
	run "${BASH:-bash}" "$cmd" Dark --bogus
	[ "$status" -eq 1 ]
	! appearance_set true || false
}

@test "without a theme or --auto it applies Dark, as on Windows" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	appearance_set true
	wallpaper_set dark.jpg
}
