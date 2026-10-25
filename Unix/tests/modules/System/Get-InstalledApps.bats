#!/usr/bin/env bats
# Get-InstalledApps against brew, mas, defaults and scutil stand-ins: the formulae installed on
# request with their versions, the casks, the App Store apps and the app bundles, each under its
# heading, in the file given (default ~/Desktop/installed_apps.txt); a missing brew or mas leaves a
# note under its heading (hide_tool keeps the real ones out of reach).

load ../../helpers

setup() {
	setup_foundation
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME/Applications/Fake Tool.app/Contents"
	stub_tool brew 'case "$*" in
		leaves) printf "bash\nwget\n" ;;
		"list --formula --versions") printf "bash 5.3.20\nreadline 8.3\nwget 1.25.0\n" ;;
		"list --cask --versions") printf "firefox 144.0\n" ;;
	esac'
	stub_tool mas 'printf "497799835  Xcode  (26.0)\n"'
	stub_tool defaults 'echo 1.2'
	stub_tool scutil 'echo MyMac'
	cmd=$UNIX_DIR/modules/System/bin/Get-InstalledApps
}

@test "formulae on request, casks, App Store apps and bundles land under their headings on the Desktop" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	file=$HOME/Desktop/installed_apps.txt
	[ "$(head -1 "$file" | cut -d, -f1)" = "Installed applications on MyMac" ]
	grep -qx 'bash 5.3.20' "$file"
	grep -qx 'wget 1.25.0' "$file"
	! grep -q readline "$file" || false
	grep -qx 'firefox 144.0' "$file"
	grep -q 'Xcode' "$file"
	grep -qx 'Fake Tool 1.2' "$file"
	[ "$(grep -c '^\[' "$file")" -eq 4 ]
}

@test "--output writes elsewhere, creating its folder, and the Desktop stays untouched" {
	run "${BASH:-bash}" "$cmd" --output "$BATS_TEST_TMPDIR/out/apps.txt"
	[ "$status" -eq 0 ]
	grep -qx 'firefox 144.0' "$BATS_TEST_TMPDIR/out/apps.txt"
	[ ! -e "$HOME/Desktop/installed_apps.txt" ]
}

@test "a missing brew and mas leave a note under their headings, the other sections still fill" {
	hide_tool brew
	hide_tool mas
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	file=$HOME/Desktop/installed_apps.txt
	grep -qx '(Homebrew is not installed)' "$file"
	grep -qx '(mas is not installed)' "$file"
	grep -qx 'Fake Tool 1.2' "$file"
	! grep -q '^brew \|^mas ' "$BATS_TEST_TMPDIR/tool.log" || false
}
