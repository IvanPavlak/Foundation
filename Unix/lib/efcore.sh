# shellcheck shell=bash
# Entity Framework Core discovery for EfCoreMigrationWizard - ports of the Helper functions
# Find-EfMigrationProjects, Get-DatabaseTypeFromProject, Get-EfCurrentDatabaseType,
# Find-EfStartupProject, Test-HasEfCoreDesign, Get-DbContextFromSnapshot,
# Get-DbContextsFromProject, Get-EfCoreDbContexts and Get-EfMigrations. Pattern matches are
# case-insensitive, as PowerShell -match is.

# Project files of a solution, without bin/obj.
ef_csproj_files() { # SOLUTION-ROOT
	find "$1" -name '*.csproj' -type f -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | LC_ALL=C sort
}

ef__imatch() { # TEXT ERE
	printf '%s' "$1" | grep -qiE -- "$2"
}

# Get-DatabaseTypeFromProject: from the project name or path, else the snapshot content.
ef_database_type() { # NAME PATH [SNAPSHOT-FILE]
	local name=$1 path=$2 snapshot=${3:-}
	if ef__imatch "$name" 'Postgre|NpgSql' || ef__imatch "$path" 'Postgre|NpgSql'; then
		echo PostgreSQL
	elif ef__imatch "$name" Oracle || ef__imatch "$path" Oracle; then
		echo Oracle
	elif ef__imatch "$name" 'SqlServer|MsSql' || ef__imatch "$path" 'SqlServer|MsSql'; then
		echo SqlServer
	elif [ -n "$snapshot" ] && grep -qiE 'Npgsql|PostgreSQL' "$snapshot"; then
		echo PostgreSQL
	elif [ -n "$snapshot" ] && grep -qi Oracle "$snapshot"; then
		echo Oracle
	elif [ -n "$snapshot" ] && grep -qi SqlServer "$snapshot"; then
		echo SqlServer
	else
		echo Unknown
	fi
}

# Find-EfMigrationProjects. One line per project:
#   NAME<TAB>DIR<TAB>CSPROJ<TAB>DBTYPE<TAB>HAS-MIGRATIONS(0/1)<TAB>SNAPSHOT<TAB>RELATIVE<TAB>SUBFOLDER
# Dedicated projects (*Migration(s)* in the file or folder name) first, then Domain projects
# with a Migrations folder holding a snapshot (Legacy), unless already covered.
ef_migration_projects() { # SOLUTION-ROOT
	local root=$1 csproj dir base snapshot type folder sub covered=' '
	while IFS= read -r csproj; do
		dir=$(dirname "$csproj")
		base=$(basename "$csproj" .csproj)
		ef__imatch "$(basename "$csproj")" 'Migrations?' || ef__imatch "$(basename "$dir")" 'Migrations?' || continue
		snapshot=$(find "$dir" -name '*ModelSnapshot.cs' -type f 2>/dev/null | LC_ALL=C sort | head -n 1)
		type=$(ef_database_type "$base" "$dir" "$snapshot")
		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$base" "$dir" "$csproj" "$type" "$([ -n "$snapshot" ] && echo 1 || echo 0)" "$snapshot" "${dir#"$root"/}" ''
		covered="$covered$dir $snapshot "
	done < <(ef_csproj_files "$root")
	while IFS= read -r csproj; do
		base=$(basename "$csproj" .csproj)
		ef__imatch "$base.csproj" Domain || continue
		ef__imatch "$base.csproj" Migrations && continue
		dir=$(dirname "$csproj")
		folder=$(find "$dir" -type d -name Migrations 2>/dev/null | LC_ALL=C sort | head -n 1)
		[ -n "$folder" ] || continue
		snapshot=$(find "$folder" -maxdepth 1 -name '*ModelSnapshot.cs' -type f 2>/dev/null | LC_ALL=C sort | head -n 1)
		[ -n "$snapshot" ] || continue
		case $covered in *" $dir "* | *" $snapshot "*) continue ;; esac
		type=$(ef_database_type "$base" "$folder" "$snapshot")
		sub=${folder#"$dir"}
		sub=${sub#/}
		printf '%s\t%s\t%s\t%s\t%s\t%s\t%s\t%s\n' "$base (Legacy)" "$dir" "$csproj" "$type" 1 "$snapshot" "${dir#"$root"/}" "$sub"
	done < <(ef_csproj_files "$root")
}

# Get-EfCurrentDatabaseType: DatabaseConfiguration.UseNpgSql/UseOracle/UseSqlServer of the first
# appsettings*.json under an Api/Web/Startup folder (Development first, then appsettings.json).
ef_current_database_type() { # SOLUTION-ROOT
	local file
	file=$(find "$1" -name 'appsettings*.json' -type f -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null |
		while IFS= read -r f; do
			ef__imatch "$(basename "$(dirname "$f")")" 'Api|Web|Startup' || continue
			case $(basename "$f") in appsettings.Development.json) r=0 ;; appsettings.json) r=1 ;; *) r=2 ;; esac
			printf '%s\t%s\n' "$r" "$f"
		done | LC_ALL=C sort -n | head -n 1 | cut -f2)
	[ -n "$file" ] || return 0
	python3 - "$file" <<'PY' 2>/dev/null
import json, re, sys
text = open(sys.argv[1], encoding="utf-8-sig").read()
try:
    data = json.loads(text)
except ValueError:
    # appsettings files may carry comments and trailing commas, which System.Text.Json allows.
    text = re.sub(r'^\s*//.*$', '', text, flags=re.M)
    text = re.sub(r',(\s*[}\]])', r'\1', text)
    data = json.loads(text)
config = data.get("DatabaseConfiguration") or {}
for key, name in (("UseNpgSql", "PostgreSQL"), ("UseOracle", "Oracle"), ("UseSqlServer", "SqlServer")):
    if config.get(key) is True:
        print(name)
        break
PY
}

ef_has_design() { # CSPROJ
	grep -q 'Microsoft\.EntityFrameworkCore\.Design' "$1" 2>/dev/null
}

# Get-DbContextFromSnapshot: the simple name in [DbContext(typeof(X))].
ef_snapshot_context() { # SNAPSHOT
	[ -r "$1" ] || return 0
	sed -n 's/.*\[DbContext(typeof(\([^)]*\)))\].*/\1/p' "$1" | head -n 1 | awk -F. '{ print $NF }'
}

# Get-DbContextsFromProject: classes deriving from DbContext in the sources, as simple and
# namespace-qualified names, sorted and unique.
ef_project_contexts() { # DIR
	[ -d "$1" ] || return 0
	find "$1" -name '*.cs' -type f -not -path '*/bin/*' -not -path '*/obj/*' 2>/dev/null | while IFS= read -r f; do
		awk '
			ns == "" && /^[[:space:]]*namespace[[:space:]]+[A-Za-z0-9_.]+[[:space:]]*[;{]?/ { n = $0; sub(/^[[:space:]]*namespace[[:space:]]+/, "", n); sub(/[^A-Za-z0-9_.].*/, "", n); ns = n }
			/^[[:space:]]*((public|internal|protected|private)[[:space:]]+)?((abstract|sealed|partial)[[:space:]]+)*class[[:space:]]+[A-Za-z_][A-Za-z0-9_]*[[:space:]]*:[[:space:]]*([A-Za-z_][A-Za-z0-9_]*\.)*DbContext([^A-Za-z0-9_]|$)/ {
				c = $0; sub(/.*class[[:space:]]+/, "", c); sub(/[^A-Za-z0-9_].*/, "", c); classes[++k] = c
			}
			END { for (i = 1; i <= k; i++) { print classes[i]; if (ns != "") print ns "." classes[i] } }' "$f"
	done | LC_ALL=C sort -u
}

# Get-EfCoreDbContexts: `dotnet ef dbcontext list`, noise lines dropped.
ef_cli_contexts() { # PROJECT STARTUP WORKDIR
	[ -d "$3" ] || return 0
	(cd "$3" && dotnet ef dbcontext list --project "$1" --startup-project "$2" 2>&1) | sed 's/^[[:space:]]*//; s/[[:space:]]*$//' |
		grep -vE '^(Build started|Build succeeded\.|Using project|Using startup project|Writing|dotnet msbuild|MSBUILD|Command exited|Unable to retrieve|No DbContext|The Entity Framework tools version|See https://aka\.ms)' |
		grep -vE '^\[[0-9]{2}:[0-9]{2}:[0-9]{2}[[:space:]]+[A-Z]{3}\]' |
		grep -E '^[A-Za-z_][A-Za-z0-9_.]*$' | LC_ALL=C sort -u
}

# Get-EfMigrations: migration files of a folder by name, without Designer and snapshot files.
ef_migrations() { # FOLDER
	[ -d "$1" ] || return 0
	find "$1" -maxdepth 1 -name '*.cs' -type f ! -name '*.Designer.cs' ! -name '*Snapshot.cs' 2>/dev/null | LC_ALL=C sort
}
