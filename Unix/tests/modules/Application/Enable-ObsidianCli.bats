#!/usr/bin/env bats
# Enable-ObsidianCli against a throwaway home: sets "cli": true keeping the rest, backs up first,
# refuses while Obsidian runs and when the file is missing unless --create-if-missing.

load ../../helpers

setup() {
	setup_foundation
	export HOME=$BATS_TEST_TMPDIR/home FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	file="$HOME/Library/Application Support/obsidian/obsidian.json"
	[ "$(uname)" = Darwin ] || file="$HOME/.config/obsidian/obsidian.json"
	unset XDG_CONFIG_HOME
	mkdir -p "$BATS_TEST_TMPDIR/bin"
	printf '#!/bin/sh\nexit ${OBSIDIAN_RUNNING:-1}\n' >"$BATS_TEST_TMPDIR/bin/pgrep"
	chmod +x "$BATS_TEST_TMPDIR/bin/pgrep"
	export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
	cmd=$UNIX_DIR/modules/Application/bin/Enable-ObsidianCli
}

@test "sets cli true, keeps the vault list, backs the file up" {
	mkdir -p "$(dirname "$file")"
	printf '{"vaults":{"a":{"path":"/v"}}}' >"$file"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	python3 -c 'import json,sys; d=json.load(open(sys.argv[1])); assert d["cli"] is True and d["vaults"]["a"]["path"] == "/v"' "$file"
	[ -n "$(find "$FOUNDATION_BACKUP_ROOT" -name obsidian.json)" ]
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
}

@test "refuses while Obsidian runs, and a missing file without --create-if-missing" {
	mkdir -p "$(dirname "$file")"
	printf '{}' >"$file"
	OBSIDIAN_RUNNING=0 run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	rm "$file"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -f "$file" ]
	run "${BASH:-bash}" "$cmd" --create-if-missing
	[ "$status" -eq 0 ]
	grep -q '"cli":true' "$file"
}

@test "--settings-path works on that file instead, the -SettingsPath of Windows" {
	other=$BATS_TEST_TMPDIR/elsewhere/obsidian.json
	mkdir -p "$(dirname "$other")"
	printf '{"vaults":{}}' >"$other"
	run "${BASH:-bash}" "$cmd" -SettingsPath "$other"
	[ "$status" -eq 0 ]
	python3 -c 'import json,sys; assert json.load(open(sys.argv[1]))["cli"] is True' "$other"
	[ ! -e "$file" ]
}

@test "--check on a CLI that is off fails and writes nothing" {
	mkdir -p "$(dirname "$file")"
	printf '{}' >"$file"
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 1 ]
	[ "$(cat "$file")" = '{}' ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT" ]
}

@test "an already enabled file is not rewritten and not backed up" {
	mkdir -p "$(dirname "$file")"
	printf '{"cli": true, "vaults": {}}' >"$file"
	touch -t 202001010000 "$file"
	touch "$BATS_TEST_TMPDIR/before"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$file")" = '{"cli": true, "vaults": {}}' ]
	[ -z "$(find "$file" -newer "$BATS_TEST_TMPDIR/before")" ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT" ]
}

@test "a file that is not JSON fails and keeps its content" {
	mkdir -p "$(dirname "$file")"
	printf 'not json' >"$file"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ "$(cat "$file")" = 'not json' ]
}

@test "an unknown argument fails and touches nothing" {
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	[[ $output == *"Unknown argument => --bogus"* ]]
	[ ! -e "$file" ]
}
