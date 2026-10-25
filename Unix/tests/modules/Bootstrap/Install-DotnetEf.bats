#!/usr/bin/env bats
# Install-DotnetEf against a stand-in for dotnet (its global tools come from $DOTNET_TOOLS, an
# install or update fails when $DOTNET_FAIL is set): the latest or the configured version is
# installed, an installed tool is left alone, --update updates, --dry-run installs nothing, no SDK
# is skipped with a warning (hide_tool keeps the real dotnet out of reach).

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	export DOTNET_TOOLS=''
	stub_tool dotnet 'case "$1 $2" in "tool list") printf "Package Id      Version      Commands\n---------------------------------\n%s\n" "$DOTNET_TOOLS" ;; *) [ -z "$DOTNET_FAIL" ] || exit 1 ;; esac'
	[ "$(command -v dotnet)" = "$BATS_TEST_TMPDIR/tools/dotnet" ] || {
		echo "stub guard: dotnet resolves to $(command -v dotnet)" >&2
		return 1
	}
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Install-DotnetEf
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/dotnet.conf"; }
changes() { grep -E '^dotnet tool (install|update)' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || true; }

@test "the latest version is installed when ef-version is empty or dotnet.conf is missing" {
	conf "ef-version"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(changes)" = "dotnet tool install --global dotnet-ef" ]
	rm -f "$FOUNDATION_CONFIG_DIR/dotnet.conf" "$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd"
	[ "$(changes)" = "dotnet tool install --global dotnet-ef" ]
}

@test "the configured version is installed, an @TYPE line wins on its machine type" {
	conf "ef-version 8.0.11" "@Work ef-version 9.*"
	CONF_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	[ "$(changes)" = "dotnet tool install --global dotnet-ef --version 8.0.11" ]
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	CONF_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd"
	[ "$(changes)" = "dotnet tool install --global dotnet-ef --version 9.*" ]
}

@test "an installed dotnet-ef is left alone, --update updates it" {
	conf "ef-version 8.0.11"
	DOTNET_TOOLS='dotnet-ef       9.0.1        dotnet-ef' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"dotnet-ef 9.0.1 is already installed"* ]]
	[ -z "$(changes)" ]
	DOTNET_TOOLS='dotnet-ef       9.0.1        dotnet-ef' run "${BASH:-bash}" "$cmd" --update
	[ "$(changes)" = "dotnet tool update --global dotnet-ef" ]
}

@test "--dry-run prints the command and installs nothing" {
	conf "ef-version 8.*"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"dotnet tool install --global dotnet-ef --version 8.*"* ]]
	[ -z "$(changes)" ]
}

@test "a failed install fails the run, an unknown argument is an error" {
	DOTNET_FAIL=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
}

@test "no .NET SDK is skipped with a warning, not a failure, and nothing is installed" {
	conf "ef-version"
	hide_tool dotnet
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *".NET SDK is not installed"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}
