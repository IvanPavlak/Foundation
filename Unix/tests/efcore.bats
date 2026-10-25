#!/usr/bin/env bats
# EF Core discovery (the EfCoreMigrationWizard helpers) against a fixture solution: migration
# projects and their provider (by name, path or snapshot), the active provider of appsettings,
# DbContext names, migrations.

load helpers

setup() {
	setup_foundation
	foundation_load efcore
	sol=$BATS_TEST_TMPDIR/sol
	mkdir -p "$sol/src/My.Api" "$sol/src/My.Migrations.Oracle" "$sol/src/My.Domain/Data/Migrations" "$sol/src/My.Data"
	touch "$sol/My.sln"
	echo '<Project><PackageReference Include="Microsoft.EntityFrameworkCore.Design" /></Project>' >"$sol/src/My.Api/My.Api.csproj"
	echo '<Project/>' >"$sol/src/My.Migrations.Oracle/My.Migrations.Oracle.csproj"
	echo '<Project/>' >"$sol/src/My.Domain/My.Domain.csproj"
	printf '// dev settings\n{ "DatabaseConfiguration": { "UseOracle": true, }, }\n' >"$sol/src/My.Api/appsettings.Development.json"
	printf 'namespace My.Data\n{\n    public sealed class AppDbContext : DbContext\n    {\n    }\n}\n' >"$sol/src/My.Data/AppDbContext.cs"
	legacy=$sol/src/My.Domain/Data/Migrations
	printf '[DbContext(typeof(My.Data.AppDbContext))]\nNpgsql\n' >"$legacy/AppDbContextModelSnapshot.cs"
	touch "$legacy/20260101000000_Init.cs" "$legacy/20260101000000_Init.Designer.cs" "$legacy/20260301000000_Next.cs"
}

@test "migration projects: dedicated by name, then the legacy Domain project with its subfolder" {
	mapfile -t projects < <(ef_migration_projects "$sol")
	[ ${#projects[@]} -eq 2 ]
	[ "$(printf '%s' "${projects[0]}" | cut -f1,4,5,7)" = "$(printf 'My.Migrations.Oracle\tOracle\t0\tsrc/My.Migrations.Oracle')" ]
	[ "$(printf '%s' "${projects[1]}" | cut -f1,4,5,8)" = "$(printf 'My.Domain (Legacy)\tPostgreSQL\t1\tData/Migrations')" ]
}

@test "current provider from appsettings.Development.json, comments and trailing commas allowed" {
	[ "$(ef_current_database_type "$sol")" = Oracle ]
}

@test "DbContext from the snapshot and from the sources" {
	[ "$(ef_snapshot_context "$legacy/AppDbContextModelSnapshot.cs")" = AppDbContext ]
	[ "$(ef_project_contexts "$sol/src/My.Data" | paste -sd' ' -)" = "AppDbContext My.Data.AppDbContext" ]
}

@test "migrations: sorted, without Designer and snapshot files" {
	[ "$(ef_migrations "$legacy" | xargs -n1 basename | paste -sd' ' -)" = "20260101000000_Init.cs 20260301000000_Next.cs" ]
}

@test "EF Core Design detection" {
	ef_has_design "$sol/src/My.Api/My.Api.csproj"
	! ef_has_design "$sol/src/My.Domain/My.Domain.csproj" || false
}

@test "provider: SqlServer and MsSql by name, PostgreSQL by path, the name beats the snapshot, else Unknown" {
	[ "$(ef_database_type My.SqlServer x)" = SqlServer ]
	[ "$(ef_database_type My.MsSql.Migrations x)" = SqlServer ]
	[ "$(ef_database_type My.Api src/Postgres)" = PostgreSQL ]
	[ "$(ef_database_type My.Api src/NpgSql/My.Api)" = PostgreSQL ]
	# The snapshot says Npgsql; the project name wins.
	[ "$(ef_database_type My.Oracle x "$legacy/AppDbContextModelSnapshot.cs")" = Oracle ]
	[ "$(ef_database_type My.Api src/My.Api "$legacy/AppDbContextModelSnapshot.cs")" = PostgreSQL ]
	[ "$(ef_database_type My.Api src/My.Api)" = Unknown ]
	printf 'nothing known here\n' >"$BATS_TEST_TMPDIR/empty.cs"
	[ "$(ef_database_type My.Api src/My.Api "$BATS_TEST_TMPDIR/empty.cs")" = Unknown ]
}
