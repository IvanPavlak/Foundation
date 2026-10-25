#!/usr/bin/env bats
# Determine-DotnetDependencies against a stub dotnet and a throwaway project tree: the target
# frameworks with their counts, excluded folders skipped, and the modern versions without an SDK
# reported with their Homebrew line.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	root=$BATS_TEST_TMPDIR/dev
	mkdir -p "$root/Api" "$root/Lib" "$root/Old" "$root/Web/node_modules/pkg" "$root/App/obj"
	printf '<Project><PropertyGroup><TargetFramework>net8.0</TargetFramework></PropertyGroup></Project>\n' >"$root/Api/Api.csproj"
	printf '<Project><PropertyGroup><TargetFrameworks>net6.0;netstandard2.0</TargetFrameworks></PropertyGroup></Project>\n' >"$root/Lib/Lib.fsproj"
	printf '<Project><PropertyGroup><TargetFramework>net48</TargetFramework></PropertyGroup></Project>\n' >"$root/Old/Old.csproj"
	printf '<Project><PropertyGroup><TargetFramework>net9.0</TargetFramework></PropertyGroup></Project>\n' >"$root/Web/node_modules/pkg/Pkg.csproj"
	printf '<Project><PropertyGroup><TargetFramework>net7.0</TargetFramework></PropertyGroup></Project>\n' >"$root/App/obj/Gen.csproj"
	stub_tool dotnet 'case "$1" in --list-sdks) echo "8.0.425 [/usr/local/share/dotnet/sdk]" ;; --list-runtimes) echo "Microsoft.NETCore.App 8.0.31 [/x]" ;; esac'
	cmd=$UNIX_DIR/modules/System/bin/Determine-DotnetDependencies
}

@test "frameworks are counted, excluded folders skipped, the missing SDK reported" {
	run "${BASH:-bash}" "$cmd" "$root" --list-projects
	[ "$status" -eq 0 ]
	[[ $output == *"Found 3 project file(s)"* ]]
	[[ $output == *"net8.0 (1 project(s))"* ]]
	[[ $output == *"    - Lib.fsproj"* ]]
	[[ $output != *net9.0* ]]
	[[ $output != *net7.0* ]]
	[[ $output == *".NET 8.0 SDK [OK]"* ]]
	[[ $output == *".NET 6.0 SDK [MISSING]"* ]]
	[[ $output == *"brew install dotnet@6"* ]]
	[[ $output != *"netstandard2.0 SDK"* ]]
	[[ $output != *"4.8 SDK"* ]]
}

@test "the search path comes from dotnet.conf, --exclude replaces the defaults" {
	printf 'projects-search-path %s\n' "$root" >"$FOUNDATION_CONFIG_DIR/dotnet.conf"
	run "${BASH:-bash}" "$cmd" --exclude Old
	[ "$status" -eq 0 ]
	[[ $output == *"Search Path => [$root]"* ]]
	[[ $output == *"Found 4 project file(s)"* ]]
	[[ $output == *"net9.0"* ]]
	[[ $output == *"net7.0"* ]]
}

@test "everything installed is a clean report; a missing search path fails" {
	rm "$root/Lib/Lib.fsproj"
	run "${BASH:-bash}" "$cmd" "$root"
	[ "$status" -eq 0 ]
	[[ $output == *"All required .NET SDKs are installed!"* ]]
	run "${BASH:-bash}" "$cmd" "$BATS_TEST_TMPDIR/nowhere"
	[ "$status" -ne 0 ]
}

@test "netcoreapp3.1, netcoreapp2.1 and net10.0 are required as 3.1, 2.1 and 10.0, in version order" {
	mkdir -p "$root/Core" "$root/Legacy" "$root/Next"
	printf '<Project><PropertyGroup><TargetFramework>netcoreapp3.1</TargetFramework></PropertyGroup></Project>\n' >"$root/Core/Core.csproj"
	printf '<Project><PropertyGroup><TargetFramework>netcoreapp2.1</TargetFramework></PropertyGroup></Project>\n' >"$root/Legacy/Legacy.csproj"
	printf '<Project><PropertyGroup><TargetFramework>net10.0</TargetFramework></PropertyGroup></Project>\n' >"$root/Next/Next.csproj"
	run "${BASH:-bash}" "$cmd" "$root"
	[ "$status" -eq 0 ]
	[[ $output == *".NET 3.1 SDK [MISSING]"* ]]
	[[ $output == *".NET 2.1 SDK [MISSING]"* ]]
	[[ $output == *".NET 10.0 SDK [MISSING]"* ]]
	[[ $output == *"brew install dotnet@10"* ]]
	# Numeric order: 2.1, 3.1, 6.0, 10.0 (10.0 is not sorted before 2.1 as text would).
	[[ $output == *".NET 2.1 SDK [MISSING]"*".NET 3.1 SDK [MISSING]"*".NET 6.0 SDK [MISSING]"*".NET 10.0 SDK [MISSING]"* ]]
}
