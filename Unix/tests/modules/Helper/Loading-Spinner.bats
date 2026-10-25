#!/usr/bin/env bats
# Loading-Spinner: the wrapped command's output and exit status pass through; without a command it fails.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/Loading-Spinner
}

@test "output and exit status of the wrapped command pass through" {
	run "${BASH:-bash}" "$cmd" --label Busy -- sh -c 'echo out; exit 3'
	[ "$status" -eq 3 ]
	[[ $output == *out* ]]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
}

@test "a delay of 1000 ms or more sleeps whole seconds plus the remainder" {
	foundation_load spinner
	[ "$(spinner__seconds 80)" = 0.080 ]
	[ "$(spinner__seconds 999)" = 0.999 ]
	[ "$(spinner__seconds 1000)" = 1.000 ]
	[ "$(spinner__seconds 1500)" = 1.500 ]
	[ "$(spinner__seconds 080)" = 0.080 ]
}

@test "the last line of a style name wins, so an overlay replaces a base style" {
	foundation_load spinner
	use_empty_config
	printf 'default  Line\nLine  120  - \\ | /\nArc  100  a b\n' >"$FOUNDATION_CONFIG_DIR/spinners.conf"
	printf 'line  60  x y\n' >"$FOUNDATION_CONFIG_DIR/spinners.local.conf"
	[ "$(spinner_style)" = '60 x y' ]
	[ "$(spinner_style ARC)" = '100 a b' ]
	[ "$(spinner_style Missing)" = '120 - \ | /' ]
}

@test "the Windows Preview-LoadingSpinners is an alias of Loading-Spinner --preview" {
	grep -qE "^[[:space:]]*alias Preview-LoadingSpinners='Loading-Spinner --preview'$" "$UNIX_DIR/shell/shellrc.sh"
}
