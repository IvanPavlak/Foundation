#!/usr/bin/env bats
# DotnetPublish: finds the solution and the project with a publish profile, publishes to the Desktop
# folder; with several projects or profiles the menus pick them, and a failed publish fails.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off
	cmd=$UNIX_DIR/modules/Helper/bin/DotnetPublish
}

@test "the one project with a profile is published into ~/Desktop/<Project>_<Profile>_<date>" {
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME/Desktop" "$BATS_TEST_TMPDIR/sol/src/Api/Properties/PublishProfiles" "$BATS_TEST_TMPDIR/sol/src/Lib"
	touch "$BATS_TEST_TMPDIR/sol/My.sln" "$BATS_TEST_TMPDIR/sol/src/Api/Api.csproj" "$BATS_TEST_TMPDIR/sol/src/Lib/Lib.csproj" "$BATS_TEST_TMPDIR/sol/src/Api/Properties/PublishProfiles/Folder.pubxml"
	stub_tool dotnet
	cd "$BATS_TEST_TMPDIR/sol/src"
	run "${BASH:-bash}" "$cmd" </dev/null
	grep -q "^dotnet publish -p:PublishProfile=Folder -o $HOME/Desktop/Api_Folder_$(date +%Y_%m_%d)" "$BATS_TEST_TMPDIR/tool.log"
}

@test "without a solution nearby it fails" {
	stub_tool dotnet
	# Deep enough that every level Find-Item climbs (the start and 4 parents, each searched with its
	# whole subtree, as on Windows) stays inside this test's folder, away from other tests' files.
	mkdir -p "$BATS_TEST_TMPDIR/a/b/c/d/empty"
	cd "$BATS_TEST_TMPDIR/a/b/c/d/empty"
	run "${BASH:-bash}" "$cmd" </dev/null
	[ "$status" -ne 0 ]
	! grep -q publish "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || false
}

# A solution with two projects that have publish profiles: Api (Folder) and Web (A and B).
two_projects() {
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME/Desktop" "$BATS_TEST_TMPDIR/sol/src/Api/Properties/PublishProfiles" "$BATS_TEST_TMPDIR/sol/src/Web/Properties/PublishProfiles"
	touch "$BATS_TEST_TMPDIR/sol/My.sln" "$BATS_TEST_TMPDIR/sol/src/Api/Api.csproj" "$BATS_TEST_TMPDIR/sol/src/Web/Web.csproj"
	touch "$BATS_TEST_TMPDIR/sol/src/Api/Properties/PublishProfiles/Folder.pubxml"
	touch "$BATS_TEST_TMPDIR/sol/src/Web/Properties/PublishProfiles/A.pubxml" "$BATS_TEST_TMPDIR/sol/src/Web/Properties/PublishProfiles/B.pubxml"
	cd "$BATS_TEST_TMPDIR/sol/src"
}

@test "with several projects and profiles the menus pick them: answer 2 publishes the second of each" {
	two_projects
	stub_tool dotnet
	# Every menu reads the first line: 2 = Web, then its profile B, then No to opening the folder.
	printf '2\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -q "^dotnet publish -p:PublishProfile=B -o $HOME/Desktop/Web_B_$(date +%Y_%m_%d)" "$BATS_TEST_TMPDIR/tool.log"
	! grep -q 'PublishProfile=Folder' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "a failed dotnet publish fails the command" {
	two_projects
	stub_tool dotnet 'case "$1" in publish) exit 1 ;; esac'
	printf '1\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	grep -q '^dotnet publish -p:PublishProfile=Folder' "$BATS_TEST_TMPDIR/tool.log"
	[[ $output == *"Publish failed"* ]]
	[[ $output != *"Successfully published"* ]]
}
