#!/usr/bin/env bats
# EfCoreMigrationWizard against a fixture solution and a dotnet stand-in: the dotnet ef commands
# each menu action runs (add, redo, remove, squash, sync) with the discovered migration project,
# startup project and DbContext, the confirmations and empty answers that stop it, and a failing
# step aborting the rest. The answers are fed one per prompt through a pipe as FOUNDATION_TTY.

load ../../helpers

setup() {
	setup_foundation
	sol=$BATS_TEST_TMPDIR/sol
	pg=$sol/src/My.Migrations.PostgreSQL
	mkdir -p "$sol/src/My.Api" "$pg/Migrations"
	touch "$sol/My.sln"
	echo '<Project><PackageReference Include="Microsoft.EntityFrameworkCore.Design" /></Project>' >"$sol/src/My.Api/My.Api.csproj"
	echo '<Project/>' >"$pg/My.Migrations.PostgreSQL.csproj"
	printf '[DbContext(typeof(My.Data.AppDbContext))]\n' >"$pg/Migrations/AppDbContextModelSnapshot.cs"
	touch "$pg/Migrations/20260101000000_Init.cs" "$pg/Migrations/20260101000000_Init.Designer.cs" "$pg/Migrations/20260301000000_Next.cs"
	# dotnet ef: `dbcontext list` prints $BATS_TEST_TMPDIR/contexts, a call containing the text of
	# $BATS_TEST_TMPDIR/ef-fails fails. Every call lands in tool.log.
	stub_tool dotnet 'case "$*" in "ef dbcontext list"*) cat "$BATS_TEST_TMPDIR/contexts" 2>/dev/null ;; esac
pattern=$(cat "$BATS_TEST_TMPDIR/ef-fails" 2>/dev/null)
if [ -n "$pattern" ]; then case "$*" in *"$pattern"*) exit 1 ;; esac; fi
exit 0'
	log=$BATS_TEST_TMPDIR/tool.log
	common='--project src/My.Migrations.PostgreSQL --startup-project src/My.Api'
	cmd=$UNIX_DIR/modules/Workflow/bin/EfCoreMigrationWizard
}

# The answers, one per prompt: every prompt reopens FOUNDATION_TTY, so a pipe (shared by every open)
# hands each prompt the next line where a plain file would give the first line every time.
answers() {
	exec 7< <(printf '%s\n' "$@")
	export FOUNDATION_TTY=/dev/fd/7
}

wizard() {
	cd "$sol"
	run "${BASH:-bash}" "$cmd"
}

ef_calls() {
	grep '^dotnet ef ' "$log" 2>/dev/null | grep -v 'dbcontext list' | sed 's/^dotnet ef //'
}

oracle_project() {
	mkdir -p "$sol/src/My.Migrations.Oracle"
	echo '<Project/>' >"$sol/src/My.Migrations.Oracle/My.Migrations.Oracle.csproj"
}

@test "add: the named migration is added to the migration project with the startup project" {
	# Actions: 1 Add, 2 Redo, 3 Remove, 4 Squash, 5 Exit.
	answers 1 AddUsers
	wizard
	[ "$status" -eq 0 ]
	[ "$(ef_calls)" = "migrations add AddUsers $common" ]
}

@test "add: an empty name adds nothing" {
	answers 1 ''
	wizard
	[ "$status" -ne 0 ]
	[ -z "$(ef_calls)" ]
}

@test "add: a failing dotnet ef is a failure" {
	echo 'migrations add' >"$BATS_TEST_TMPDIR/ef-fails"
	answers 1 AddUsers
	wizard
	[ "$status" -eq 1 ]
}

@test "redo: reverts to the next to last migration, removes the last, re-adds it by name" {
	answers 2
	wizard
	[ "$status" -eq 0 ]
	[ "$(ef_calls | paste -sd'|' -)" = "database update 20260101000000_Init $common|migrations remove $common|migrations add Next $common" ]
}

@test "redo: a failed database revert aborts before anything is removed" {
	echo 'database update' >"$BATS_TEST_TMPDIR/ef-fails"
	answers 2
	wizard
	[ "$status" -ne 0 ]
	[ "$(ef_calls | wc -l | tr -d ' ')" -eq 1 ]
	! ef_calls | grep -q 'migrations remove' || false
}

@test "remove: reverts the database to the next to last migration, then removes the last" {
	answers 3
	wizard
	[ "$status" -eq 0 ]
	[ "$(ef_calls | paste -sd'|' -)" = "database update 20260101000000_Init $common|migrations remove $common" ]
}

@test "remove with a single migration reverts the database to its initial state" {
	rm "$pg/Migrations/20260301000000_Next.cs"
	# Actions: 1 Add, 2 Remove, 3 Squash, 4 Exit.
	answers 2
	wizard
	[ "$status" -eq 0 ]
	[ "$(ef_calls | paste -sd'|' -)" = "database update 0 $common|migrations remove $common" ]
}

@test "squash, confirmed: every migration file is deleted and initial-migration is added" {
	answers 4 Yes
	wizard
	[ "$status" -eq 0 ]
	[ -z "$(find "$pg/Migrations" -name '*.cs')" ]
	[ -f "$pg/My.Migrations.PostgreSQL.csproj" ]
	[ "$(ef_calls)" = "migrations add initial-migration $common" ]
}

@test "squash, declined: nothing is deleted and nothing runs" {
	answers 4 No
	wizard
	[ "$status" -eq 0 ]
	[ -f "$pg/Migrations/20260101000000_Init.cs" ]
	[ -f "$pg/Migrations/AppDbContextModelSnapshot.cs" ]
	[ -z "$(ef_calls)" ]
}

@test "exit, or no action picked, runs nothing" {
	answers 5
	wizard
	[ "$status" -eq 0 ]
	[ -z "$(ef_calls)" ]
	answers
	wizard
	[ "$status" -eq 0 ]
	[ -z "$(ef_calls)" ]
}

@test "no solution file is an error before any dotnet call" {
	answers 5
	# Deep enough that every level Find-Item climbs (the start and 4 parents, each searched with its
	# whole subtree, as on Windows) stays inside this test's folder, away from other tests' files.
	mkdir -p "$BATS_TEST_TMPDIR/a/b/c/d/empty"
	cd "$BATS_TEST_TMPDIR/a/b/c/d/empty"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -e "$log" ]
}

@test "a solution without migration projects is an error" {
	rm -rf "$pg"
	answers 1 AddUsers
	wizard
	[ "$status" -eq 1 ]
	[ -z "$(ef_calls)" ]
}

@test "without an Api project the migration project with EF Core Design is the startup project" {
	rm -rf "$sol/src/My.Api"
	echo '<Project><PackageReference Include="Microsoft.EntityFrameworkCore.Design" /></Project>' >"$pg/My.Migrations.PostgreSQL.csproj"
	answers 1 AddUsers
	wizard
	[ "$status" -eq 0 ]
	[ "$(ef_calls)" = "migrations add AddUsers --project src/My.Migrations.PostgreSQL --startup-project src/My.Migrations.PostgreSQL" ]
}

@test "several migration projects: the picked one is used" {
	oracle_project
	# Projects: 1 Oracle (empty), 2 PostgreSQL. Actions of PostgreSQL: 1 Add ... 5 Sync, 6 Exit.
	answers 2 1 AddUsers
	wizard
	[ "$status" -eq 0 ]
	[ "$(ef_calls)" = "migrations add AddUsers $common" ]
}

@test "several DbContexts from the EF CLI: the picked one is passed as --context" {
	oracle_project
	printf 'Build started...\nBuild succeeded.\nMy.Data.AppDbContext\nMy.Data.AuditDbContext\n' >"$BATS_TEST_TMPDIR/contexts"
	# Project 1 Oracle (no snapshot, so the CLI is asked), context 2 AuditDbContext, then
	# actions 1 Add (no migrations yet: Add, Sync, Exit).
	answers 1 2 1 Init
	wizard
	[ "$status" -eq 0 ]
	grep -qF 'dotnet ef dbcontext list --project src/My.Migrations.Oracle --startup-project src/My.Api' "$log"
	[ "$(ef_calls)" = "migrations add Init --project src/My.Migrations.Oracle --startup-project src/My.Api --context AuditDbContext" ]
}

@test "a single DbContext from the EF CLI runs without --context" {
	oracle_project
	printf 'My.Data.AppDbContext\n' >"$BATS_TEST_TMPDIR/contexts"
	answers 1 1 Init
	wizard
	[ "$status" -eq 0 ]
	[ "$(ef_calls)" = "migrations add Init --project src/My.Migrations.Oracle --startup-project src/My.Api" ]
}

@test "sync: the last migration's name is added to the other project when run now" {
	oracle_project
	# Project 2 PostgreSQL, action 5 Sync, keep the name Next (Yes), target 1 Oracle, run now (Yes).
	answers 2 5 Yes 1 Yes
	wizard
	[ "$status" -eq 0 ]
	[ "$(ef_calls)" = "migrations add Next --project src/My.Migrations.Oracle --startup-project src/My.Api" ]
}

@test "sync: a typed name, and only the command shown when not run now" {
	oracle_project
	answers 2 5 No Renamed 1 2
	wizard
	[ "$status" -eq 0 ]
	[ -z "$(ef_calls)" ]
	[[ $output == *"dotnet ef migrations add Renamed --project src/My.Migrations.Oracle"* ]]
}
