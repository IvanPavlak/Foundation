#!/usr/bin/env bats
# The shipped base config (Unix/config/*.conf without the .local.conf overlays, as a fresh clone has
# it) stays generic: the standing form of the extraction's personal-data sweep, and the Unix
# counterpart of VanillaConfiguration.Tests.ps1. Personal values belong in the overlays; a failure
# here means one leaked back into a tracked base file. The second half pins the base keys whose
# value must equal the fallback the code uses for a missing line, so the documented defaults stay
# true for anyone reading either place.

load helpers

setup() {
	setup_foundation
	base=$BATS_TEST_TMPDIR/base
	mkdir -p "$base"
	cp "$UNIX_DIR"/config/*.conf "$base/"
	rm -f "$base"/*.local.conf
	export FOUNDATION_CONFIG_DIR=$base CONF_MACHINE_TYPE=Test
}

# The data lines of a base file: no comments, no blank lines.
data_lines() { grep -vE '^[[:space:]]*(#|$)' "$base/$1" || true; }

@test "machines.conf ships only the Test type: no host, dev-root or other type lines" {
	run data_lines machines.conf
	[[ $output != *host* ]]
	[[ $output != *dev-root* ]]
	run awk '$1 == "type" { print $2 }' "$base/machines.conf"
	[ "$output" = Test ]
}

@test "every @TYPE prefix of a base file names a base type" {
	run awk '/^[[:space:]]*@/ { t = $1; sub(/^@/, "", t); n = split(t, a, ","); for (i = 1; i <= n; i++) if (a[i] != "Test") print FILENAME ": @" a[i] }' "$base"/*.conf
	[ -z "$output" ]
}

@test "the personal files ship empty" {
	for file in git.conf language.conf wake-on-lan.conf special-folders.conf pdfs.conf dnd.conf package-pins.conf; do
		run data_lines "$file"
		[ -z "$output" ] || {
			echo "$file must stay empty in the tracked base => $output"
			return 1
		}
	done
}

@test "the base ships no git identity and no personal Bootstrap steps" {
	run conf_value "$base/git.conf" name
	[ "$status" -ne 0 ]
	run conf_value "$base/git.conf" email
	[ "$status" -ne 0 ]
	run conf_section "$base/bootstrap.conf" PersonalSteps
	[ -z "$output" ]
}

@test "the base value of each key equals the fallback its code uses for a missing line" {
	# FILE KEY VALUE CODE-FILE TEXT: the base line of FILE must read VALUE, and CODE-FILE (under
	# Unix/) must still hold TEXT, the place that falls back to VALUE.
	local failed=0 file key value code text actual
	while IFS='|' read -r file key value code text; do
		[ -n "$file" ] || continue
		actual=$(conf_value "$base/$file" "$key" 2>/dev/null) || actual='<missing>'
		[ "$actual" = "$value" ] || {
			echo "$file $key: base [$actual], fallback [$value]"
			failed=1
		}
		grep -qF -- "$text" "$UNIX_DIR/$code" || {
			echo "$code no longer holds [$text] (the $key fallback) - update this row"
			failed=1
		}
	done <<'ROWS'
greeting.conf|clear|on|modules/System/bin/Invoke-Clear|"$(conf_value "$file" clear 2>/dev/null)" = off
greeting.conf|fastfetch|on|modules/System/bin/Invoke-Fastfetch|"$(setting fastfetch)" = off
greeting.conf|fastfetch-auto-fit|on|modules/System/bin/Invoke-Fastfetch|"$(setting fastfetch-auto-fit)" = off
greeting.conf|fastfetch-max-shrink-steps|10|modules/System/bin/Invoke-Fastfetch|number_setting fastfetch-max-shrink-steps 0 50 10
greeting.conf|fastfetch-reflow-timeout-ms|10|modules/System/bin/Invoke-Fastfetch|number_setting fastfetch-reflow-timeout-ms 1 10000 10
greeting.conf|fastfetch-prompt-reserve|1|modules/System/bin/Invoke-Fastfetch|number_setting fastfetch-prompt-reserve 0 20 1
greeting.conf|onefetch|off|modules/System/bin/Invoke-Onefetch|"$(setting onefetch)" = on ] ||
greeting.conf|onefetch-auto-fit|on|modules/System/bin/Invoke-Onefetch|"$(setting onefetch-auto-fit)" != off
greeting.conf|onefetch-in-project-terminals|on|modules/Workflow/bin/Open-ProjectTerminals|onefetch-in-project-terminals 2>/dev/null)" = off ]
workspaces.conf|benchmark|off|lib/benchmark.sh|benchmark 2>/dev/null)")" = on ] || return 0
workspaces.conf|benchmark-history|10|modules/Workflow/bin/Get-WorkspaceBenchmark|[ -n "$last" ] || last=10
workspaces.conf|layout-early-move|off|modules/Window/bin/Set-WorkspaceWindowLayout|layout-early-move 2>/dev/null) || early=off
workspaces.conf|layout-stable-ms|500|lib/layout.sh|*[!0-9]*) value=500 ;;
workspaces.conf|layout-absent-grace-seconds|10|lib/layout.sh|*[!0-9]*) value=10 ;;
backups.conf|max-age-days|0|modules/Helper/bin/Clear-OldBackups|backup_setting max-age-days 0
backups.conf|max-backups-per-key|10|lib/backup.sh|backup_setting max-backups-per-key 10
backups.conf|max-total-size-mb|500|modules/Helper/bin/Clear-OldBackups|backup_setting max-total-size-mb 500
logging.conf|max-age-days|7|lib/logfile.sh|logfile_setting max-age-days 7
logging.conf|max-session-files|20|lib/logfile.sh|logfile_setting max-session-files 20
logging.conf|max-total-size-mb|50|lib/logfile.sh|logfile_setting max-total-size-mb 50
logging.conf|max-error-file-size-mb|5|lib/logfile.sh|logfile_setting max-error-file-size-mb 5
logging.conf|error-file|Errors.log|lib/logfile.sh|"${name:-Errors.log}"
logging.conf|maintenance|on|lib/logfile.sh|logfile_setting maintenance on
logging.conf|maintenance-interval-hours|24|lib/logfile.sh|logfile_setting maintenance-interval-hours 24
machines.conf|default|Test|lib/config.sh|printf '%s' "${fallback:-Test}"
machines.conf|small-display-width|3000|lib/layout.sh|small-display-width) || limit=3000
repositories.conf|startup-schedule|daily|modules/Git/bin/Invoke-StartupRepositoryUpdate|setting startup-schedule daily
repositories.conf|startup-day-start-hour|6|modules/Git/bin/Invoke-StartupRepositoryUpdate|setting startup-day-start-hour 6
ROWS
	[ "$failed" -eq 0 ]
}

@test "upstream.conf is a plain manifest: the four keys once, own and mirror lines, nothing per machine" {
	manifest=$UNIX_DIR/config/upstream.conf
	run awk '!/^[[:space:]]*(#|$)/ { print $1 }' "$manifest"
	[ -z "$(printf '%s\n' "$output" | grep -vxE 'name|url|tag-prefix|changelog|own|mirror')" ]
	for key in name url tag-prefix changelog; do
		[ "$(printf '%s\n' "$output" | grep -cx -- "$key")" -eq 1 ]
	done
	[ "$(awk '$1 == "name" { print $2 }' "$manifest")" = foundation ]
	[ ! -e "$UNIX_DIR/config/upstream.local.conf" ]
}
