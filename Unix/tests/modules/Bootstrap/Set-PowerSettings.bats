#!/usr/bin/env bats
# Set-PowerSettings against the fixture power.conf and stand-ins for pmset (its -g custom and
# -g cap output come from Unix/tests/fixtures/pmset) and sudo (logs, never elevates): one pmset
# call per source with only the keys that change, unsupported keys skipped, @TYPE lines, no
# battery section on a Mac without one, nothing changed by --list or --dry-run.

load ../../helpers

setup() {
	setup_foundation
	export PMSET_CUSTOM=$UNIX_DIR/tests/fixtures/pmset/custom.txt
	export PMSET_CAP=$UNIX_DIR/tests/fixtures/pmset/cap.txt
	stub_tool pmset 'case "$*" in "-g custom") cat "$PMSET_CUSTOM" ;; "-g cap") cat "$PMSET_CAP" ;; esac'
	stub_tool sudo 'exit ${SUDO_FAIL:-0}'
	for tool in pmset sudo; do
		[ "$(command -v "$tool")" = "$BATS_TEST_TMPDIR/tools/$tool" ] || {
			echo "stub guard: $tool resolves to $(command -v "$tool")" >&2
			return 1
		}
	done
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Set-PowerSettings
}

sudo_calls() { grep '^sudo ' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || true; }

@test "one pmset call per source with only the keys that change, in section order" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(sudo_calls)" = $'sudo pmset -c displaysleep 30 sleep 0\nsudo pmset -b displaysleep 5\nsudo pmset -a womp 1' ]
	[[ $output == *"does not support [lidwake]"* ]]
}

@test "an @TYPE line applies only on its machine type" {
	FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd"
	sudo_calls | grep -qxF 'sudo pmset -b displaysleep 5 sleep 20'
}

@test "a Mac without a battery skips [Battery]; [All] covers the sources it has" {
	sed '/^Battery Power:/,/^AC Power:/{/^AC Power:/!d;}' "$PMSET_CUSTOM" >"$BATS_TEST_TMPDIR/custom.txt"
	PMSET_CUSTOM=$BATS_TEST_TMPDIR/custom.txt run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Battery skipped (this Mac has no Battery Power)"* ]]
	! sudo_calls | grep -q -- ' -b ' || false
	! sudo_calls | grep -q -- ' -a ' || false
}

@test "nothing to change asks for no password" {
	copy_fixture_config
	printf '[AC]\nsleep 1\nwomp 1\n' >"$FOUNDATION_CONFIG_DIR/power.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$(sudo_calls)" ]
	[[ $output == *"already match"* ]]
}

@test "--dry-run prints the pmset commands, --list the current values, neither calls sudo" {
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"sudo pmset -c displaysleep 30 sleep 0"* ]]
	run "${BASH:-bash}" "$cmd" --list
	[ "$status" -eq 0 ]
	[[ $output == *"now: AC=10"* ]]
	[ -z "$(sudo_calls)" ]
}

@test "a failed pmset call fails the run" {
	SUDO_FAIL=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"failure(s)"* ]]
}

@test "a missing power.conf and an unknown argument are errors" {
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	use_empty_config
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"Missing Unix/config/power.conf"* ]]
}
