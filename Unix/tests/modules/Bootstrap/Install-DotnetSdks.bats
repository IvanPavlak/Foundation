#!/usr/bin/env bats
# Install-DotnetSdks against stand-ins for dotnet (its SDKs come from $DOTNET_SDKS), curl and sudo
# (both only log; nothing is downloaded or run as root): each sdk-channel line missing from
# `dotnet --list-sdks` is installed into the dotnet root of the dotnet on PATH, an installed channel
# and an empty config do nothing, --dry-run changes nothing.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	export DOTNET_SDKS='8.0.404 [/usr/local/share/dotnet/sdk]'
	stub_tool dotnet 'case "$1" in --list-sdks) printf "%s\n" "$DOTNET_SDKS" ;; esac'
	stub_tool curl 'while [ $# -gt 0 ]; do [ "$1" = -o ] && : >"$2"; shift; done'
	stub_tool sudo '[ -z "$SUDO_FAIL" ] || exit 1'
	for tool in dotnet curl sudo; do
		[ "$(command -v "$tool")" = "$BATS_TEST_TMPDIR/tools/$tool" ] || {
			echo "stub guard: $tool resolves to $(command -v "$tool")" >&2
			return 1
		}
	done
	tools=$(cd "$BATS_TEST_TMPDIR/tools" && pwd -P)
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Install-DotnetSdks
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/dotnet.conf"; }
installs() { grep '^sudo ' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || true; }

@test "a missing channel is installed into the dotnet root of the cask SDKs, an installed one is not" {
	conf "sdk-channel 6.0" "sdk-channel 8.0"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $(installs) == "sudo bash "*" --channel 6.0 --install-dir $tools --no-path" ]]
	[ "$(installs | grep -c .)" -eq 1 ]
	grep -q '^curl -fsSL https://dot.net/v1/dotnet-install.sh' "$BATS_TEST_TMPDIR/tool.log"
	[[ $output == *".NET SDK 8.0 is already installed"* ]]
}

@test "no sdk-channel line does nothing; --dry-run prints and installs nothing" {
	conf "ef-version"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ] || [ -z "$(installs)" ]
	conf "sdk-channel 6.0"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"would run: sudo bash dotnet-install.sh --channel 6.0 --install-dir $tools"* ]]
	[ -z "$(installs)" ]
	! grep -q '^curl' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "a failed install or a bad channel fails the run" {
	conf "sdk-channel 6.0"
	SUDO_FAIL=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"dotnet-install.sh failed for channel 6.0"* ]]
	conf "sdk-channel six"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"[six] is not a channel"* ]]
}
