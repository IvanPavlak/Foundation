#!/usr/bin/env bats
# Set-KeyboardLayouts against a stand-in input-source helper that keeps the enabled layouts in a
# file: applies the set's layouts in order, skips a set already applied unless --override, picks
# the default on Enter, and changes nothing for an unknown layout or an empty config.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	state=$BATS_TEST_TMPDIR/layouts
	calls=$BATS_TEST_TMPDIR/calls
	# Layout ids this pretend Mac has; the enabled ones start as Croatian-PC, selected.
	export KNOWN='com.apple.keylayout.Croatian-PC com.apple.keylayout.US'
	printf 'com.apple.keylayout.Croatian-PC\t1\tCroatian PC\n' >"$state"
	helper=$BATS_TEST_TMPDIR/inputsource
	cat >"$helper" <<-EOF
		#!/bin/sh
		echo "\$*" >>"$calls"
		case \$1 in
			list) cat "$state" ;;
			apply)
				shift
				for id; do case " \$KNOWN " in *" \$id "*) ;; *) echo "No keyboard layout [\$id]" >&2; exit 3 ;; esac; done
				: >"$state"
				first=1
				for id; do printf '%s\t%s\t%s\n' "\$id" "\$first" "\$id" >>"$state"; first=0; done
				;;
		esac
	EOF
	chmod +x "$helper"
	export FOUNDATION_INPUTSOURCE_HELPER=$helper
	cat >"$FOUNDATION_CONFIG_DIR/language.conf" <<-EOF
		keyboard-layout Croatian com.apple.keylayout.Croatian-PC
		keyboard-layout US com.apple.keylayout.US
		keyboard-set Croatian Croatian
		keyboard-set US-Croatian US Croatian
		default-keyboard-set Croatian
	EOF
	cmd=$UNIX_DIR/modules/System/bin/Set-KeyboardLayouts
}

@test "applies the set's layouts in order with the first selected" {
	run "${BASH:-bash}" "$cmd" us-croatian
	[ "$status" -eq 0 ]
	grep -qx 'apply com.apple.keylayout.US com.apple.keylayout.Croatian-PC' "$calls"
	[ "$(awk -F'\t' '$2 == 1 { print $1 }' "$state")" = com.apple.keylayout.US ]
}

@test "a set already applied changes nothing unless --override" {
	run "${BASH:-bash}" "$cmd" Croatian
	[ "$status" -eq 0 ]
	[[ $output == *"already configured"* ]]
	! grep -q '^apply' "$calls" || false
	run "${BASH:-bash}" "$cmd" Croatian --override
	[ "$status" -eq 0 ]
	grep -qx 'apply com.apple.keylayout.Croatian-PC' "$calls"
}

@test "the same layouts with another one selected are applied again" {
	printf 'com.apple.keylayout.Croatian-PC\t1\tx\ncom.apple.keylayout.US\t0\tx\n' >"$state"
	run "${BASH:-bash}" "$cmd" US-Croatian
	[ "$status" -eq 0 ]
	grep -q '^apply' "$calls"
}

@test "Enter in the menu picks the default, a number picks that set" {
	printf 'com.apple.keylayout.US\t1\tx\n' >"$state"
	printf '\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qx 'apply com.apple.keylayout.Croatian-PC' "$calls"
	printf '2\n' >"$FOUNDATION_TTY"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qx 'apply com.apple.keylayout.US com.apple.keylayout.Croatian-PC' "$calls"
}

@test "a layout the Mac lacks or the config lacks fails and changes nothing" {
	printf 'keyboard-layout Klingon com.apple.keylayout.Klingon\nkeyboard-set Alien Klingon\nkeyboard-set Broken Nope\n' >>"$FOUNDATION_CONFIG_DIR/language.conf"
	run "${BASH:-bash}" "$cmd" Alien
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" Broken
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" Missing
	[ "$status" -eq 1 ]
	[ "$(cat "$state")" = "$(printf 'com.apple.keylayout.Croatian-PC\t1\tCroatian PC')" ]
}

@test "no keyboard sets change nothing" {
	: >"$FOUNDATION_CONFIG_DIR/language.conf"
	run "${BASH:-bash}" "$cmd" Croatian
	[ "$status" -eq 0 ]
	[ ! -e "$calls" ]
}

@test "the Windows -LayoutSet SET works like a bare SET" {
	run "${BASH:-bash}" "$cmd" -LayoutSet US-Croatian
	[ "$status" -eq 0 ]
	grep -qx 'apply com.apple.keylayout.US com.apple.keylayout.Croatian-PC' "$calls"
}
