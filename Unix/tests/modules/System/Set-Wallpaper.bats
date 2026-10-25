#!/usr/bin/env bats
# Set-Wallpaper against defaults and osascript stand-ins (no desktop picture ever changes): the
# machine type's line of the theme's section (else Default) is set per display, cycling when there
# are more displays than pictures; Auto follows the appearance, --dry-run sets nothing.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	export FOUNDATION_MACHINE_TYPE=Laptop
	walls=$BATS_TEST_TMPDIR/walls
	mkdir -p "$walls"
	touch "$walls/dark-1.jpg" "$walls/dark two.jpg" "$walls/dark-default.jpg" "$walls/light.jpg"
	cat >"$FOUNDATION_CONFIG_DIR/wallpapers.conf" <<EOF
directory $walls

[Dark]
Laptop   dark-1.jpg "dark two.jpg"
Default  dark-default.jpg

[Light]
Default  $walls/light.jpg
EOF
	# The display count is the file displays (no file: the count fails); set-fails fails a set.
	stub_tool osascript "case \"\$*\" in *'count of desktops'*) cat '$BATS_TEST_TMPDIR/displays' 2>/dev/null || exit 1 ;; esac
[ \"\$1\" = - ] && { cat >/dev/null; [ -f '$BATS_TEST_TMPDIR/set-fails' ] && exit 1; }
exit 0"
	stub_tool defaults "[ -f '$BATS_TEST_TMPDIR/dark' ] || exit 1; echo Dark"
	[ "$(command -v osascript)" = "$BATS_TEST_TMPDIR/tools/osascript" ]
	[ "$(command -v defaults)" = "$BATS_TEST_TMPDIR/tools/defaults" ]
	echo 1 >"$BATS_TEST_TMPDIR/displays"
	log=$BATS_TEST_TMPDIR/tool.log
	: >"$log"
	cmd=$UNIX_DIR/modules/System/bin/Set-Wallpaper
}

# The pictures set, one "DISPLAY PATH" per line, in order.
set_pictures() {
	sed -n 's/^osascript - //p' "$log"
}

@test "the machine type's pictures go to the displays in order" {
	echo 2 >"$BATS_TEST_TMPDIR/displays"
	run "${BASH:-bash}" "$cmd" --theme Dark
	[ "$status" -eq 0 ]
	[ "$(set_pictures)" = "$(printf '1 %s\n2 %s' "$walls/dark-1.jpg" "$walls/dark two.jpg")" ]
}

@test "more displays than pictures cycle through them" {
	echo 3 >"$BATS_TEST_TMPDIR/displays"
	run "${BASH:-bash}" "$cmd" --theme dark
	[ "$status" -eq 0 ]
	[ "$(set_pictures | tail -n 1)" = "3 $walls/dark-1.jpg" ]
}

@test "a failing display count sets display 1 only" {
	rm "$BATS_TEST_TMPDIR/displays"
	run "${BASH:-bash}" "$cmd" Dark
	[ "$status" -eq 0 ]
	[ "$(set_pictures)" = "1 $walls/dark-1.jpg" ]
}

@test "a machine type without a line takes Default; an absolute path is used as is" {
	export FOUNDATION_MACHINE_TYPE=Work
	run "${BASH:-bash}" "$cmd" --theme Dark
	[ "$(set_pictures)" = "1 $walls/dark-default.jpg" ]
	: >"$log"
	run "${BASH:-bash}" "$cmd" --theme Light
	[ "$status" -eq 0 ]
	[ "$(set_pictures)" = "1 $walls/light.jpg" ]
}

@test "Auto (the default) follows the system appearance" {
	run "${BASH:-bash}" "$cmd"
	[ "$(set_pictures)" = "1 $walls/light.jpg" ]
	: >"$log"
	touch "$BATS_TEST_TMPDIR/dark"
	run "${BASH:-bash}" "$cmd" --auto
	[ "$status" -eq 0 ]
	[ "$(set_pictures)" = "1 $walls/dark-1.jpg" ]
}

@test "--dry-run says which picture each display would get and sets none" {
	run "${BASH:-bash}" "$cmd" --theme Dark --dry-run
	[ "$status" -eq 0 ]
	[ -z "$(set_pictures)" ]
	[[ $output == *dark-1.jpg* ]]
}

@test "a missing picture fails before anything is set" {
	rm "$walls/dark two.jpg"
	echo 2 >"$BATS_TEST_TMPDIR/displays"
	run "${BASH:-bash}" "$cmd" --theme Dark
	[ "$status" -ne 0 ]
	[ -z "$(set_pictures)" ]
}

@test "a failed set fails the command" {
	touch "$BATS_TEST_TMPDIR/set-fails"
	run "${BASH:-bash}" "$cmd" --theme Dark
	[ "$status" -ne 0 ]
}

@test "no line for the machine type and no Default sets nothing and succeeds" {
	printf '[Dark]\nWork dark-1.jpg\n' >"$FOUNDATION_CONFIG_DIR/wallpapers.conf"
	run "${BASH:-bash}" "$cmd" --theme Dark
	[ "$status" -eq 0 ]
	! grep -q '^osascript' "$log" || false
}

@test "a theme without a section, an unknown theme, or no wallpapers.conf fails" {
	printf '[Dark]\nDefault dark-1.jpg\n' >"$FOUNDATION_CONFIG_DIR/wallpapers.conf"
	run "${BASH:-bash}" "$cmd" --theme Light
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --theme Blue
	[ "$status" -ne 0 ]
	rm "$FOUNDATION_CONFIG_DIR/wallpapers.conf"
	run "${BASH:-bash}" "$cmd" --theme Dark
	[ "$status" -ne 0 ]
	! grep -q '^osascript' "$log" || false
}
