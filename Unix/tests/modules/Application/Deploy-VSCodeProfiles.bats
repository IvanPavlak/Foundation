#!/usr/bin/env bats
# Deploy-VSCodeProfiles against a throwaway home and a stub `code`: links the profile files (a real
# file backed up first), registers a profile VS Code does not know, installs missing and re-pinned
# extensions additively, prunes on request, links the local extensions instead of installing or
# pruning them, and --check changes nothing.

load ../../helpers

setup() {
	setup_foundation
	use_empty_config
	export HOME=$BATS_TEST_TMPDIR/home FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	repo=$BATS_TEST_TMPDIR/repo
	local_root=$BATS_TEST_TMPDIR/extensions
	extensions_dir=$HOME/.vscode/extensions
	user="$HOME/Library/Application Support/Code/User"
	[ "$(uname -s)" = Darwin ] || user="$HOME/.config/Code/User"
	mkdir -p "$repo/Main/snippets" "$user"
	printf '{"main":1}\n' >"$repo/Main/settings.json"
	printf '{}\n' >"$repo/Main/snippets/cs.json"
	cat >"$FOUNDATION_CONFIG_DIR/vscode-profiles.conf" <<-EOF
		root $repo
		extensions $local_root
		profile Main Default
		profile Side
		deploy Main
	EOF
	# The installed list the stub reports, and VS Code not running.
	export CODE_LIST="a.keep@1.0.0
b.extra@2.0.0
c.pinned@1.0.0"
	stub_tool code 'case "$*" in *--list-extensions*) printf "%s\n" "$CODE_LIST" ;; esac'
	stub_tool pgrep 'exit ${VSCODE_RUNNING:-1}'
	cmd=$UNIX_DIR/modules/Application/bin/Deploy-VSCodeProfiles
}

@test "links the profile files into Default, backing a real file up first" {
	printf 'mine\n' >"$user/settings.json"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$user/settings.json")" = "$repo/Main/settings.json" ]
	[ "$(readlink "$user/snippets")" = "$repo/Main/snippets" ]
	[ ! -e "$user/keybindings.json" ]
	[ ! -e "$user/tasks.json" ]
	grep -q mine "$(find "$FOUNDATION_BACKUP_ROOT/SymbolicLinks" -name settings.json)"
}

@test "replaces a stale link without a backup and leaves a correct one alone" {
	ln -s "$repo/gone.json" "$user/settings.json"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$user/settings.json")" = "$repo/Main/settings.json" ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/SymbolicLinks" ]
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output != *MISSING* ]]
}

@test "installs missing and re-pinned extensions with --do-not-sync, keeps extras" {
	printf '# why\na.keep\nc.pinned@2.0.0\nd.new  # comment\n' >"$repo/Main/extensions.txt"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qx 'code --install-extension d.new --do-not-sync' "$BATS_TEST_TMPDIR/tool.log"
	grep -qx 'code --install-extension c.pinned@2.0.0 --do-not-sync --force' "$BATS_TEST_TMPDIR/tool.log"
	! grep -q 'a.keep\|uninstall' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "settings-sync on drops --do-not-sync; --prune uninstalls what the list does not name" {
	printf 'settings-sync on\n' >>"$FOUNDATION_CONFIG_DIR/vscode-profiles.conf"
	printf 'a.keep\nc.pinned\n' >"$repo/Main/extensions.txt"
	run "${BASH:-bash}" "$cmd" --prune
	[ "$status" -eq 0 ]
	grep -qx 'code --uninstall-extension b.extra' "$BATS_TEST_TMPDIR/tool.log"
	! grep -q 'do-not-sync\|--install-extension' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "registers a profile VS Code does not know, keeping storage.json's other keys" {
	mkdir -p "$repo/Side" "$user/globalStorage"
	printf '{}\n' >"$repo/Side/settings.json"
	printf 'x.one\n' >"$repo/Side/extensions.txt"
	printf '{"theme":"dark","userDataProfiles":[{"location":"abc","name":"Other"}]}\n' >"$user/globalStorage/storage.json"
	run "${BASH:-bash}" "$cmd" Side
	[ "$status" -eq 0 ]
	[ "$(jq -r '.theme' "$user/globalStorage/storage.json")" = dark ]
	[ "$(jq -r '.userDataProfiles[] | select(.name == "Side") | .location' "$user/globalStorage/storage.json")" = foundation-side ]
	[ "$(readlink "$user/profiles/foundation-side/settings.json")" = "$repo/Side/settings.json" ]
	grep -qx 'code --install-extension x.one --profile Side --do-not-sync' "$BATS_TEST_TMPDIR/tool.log"
	[ -n "$(find "$FOUNDATION_BACKUP_ROOT/VSCodeProfiles" -name storage.json)" ]
}

@test "refuses to register while VS Code runs, and --check changes nothing" {
	mkdir -p "$repo/Side"
	printf '{}\n' >"$repo/Side/settings.json"
	VSCODE_RUNNING=0 run "${BASH:-bash}" "$cmd" Side
	[ "$status" -eq 1 ]
	[ ! -e "$user/globalStorage/storage.json" ]
	printf 'd.new\n' >"$repo/Main/extensions.txt"
	run "${BASH:-bash}" "$cmd" Side Main --check
	[ "$status" -eq 0 ]
	[ ! -e "$user/globalStorage/storage.json" ]
	[ ! -L "$user/settings.json" ]
	! grep -q 'install-extension' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "an unknown name fails, a missing folder is skipped, an empty selection deploys nothing" {
	run "${BASH:-bash}" "$cmd" Nope
	[ "$status" -eq 1 ]
	run "${BASH:-bash}" "$cmd" Side
	[ "$status" -eq 0 ]
	[ ! -e "$user/globalStorage/storage.json" ]
	printf 'root %s\nextensions %s\n' "$repo" "$local_root" >"$FOUNDATION_CONFIG_DIR/vscode-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -L "$user/settings.json" ]
}

@test "the last deploy line for the machine type wins" {
	mkdir -p "$repo/Side"
	printf '{}\n' >"$repo/Side/settings.json"
	printf '@Work deploy Main Side\n' >>"$FOUNDATION_CONFIG_DIR/vscode-profiles.conf"
	CONF_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$user/globalStorage/storage.json" ]
	CONF_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -L "$user/profiles/foundation-side/settings.json" ]
}

# A local extension folder. Usage: local_extension FOLDER PUBLISHER NAME VERSION
local_extension() {
	mkdir -p "$local_root/$1"
	printf '{"publisher":"%s","name":"%s","version":"%s"}\n' "$2" "$3" "$4" >"$local_root/$1/package.json"
}

@test "links a local extension and never installs or prunes it, even with no profile selected" {
	local_extension Themes Me themes 1.0.0
	printf 'a.keep\nme.themes\n' >"$repo/Main/extensions.txt"
	export CODE_LIST="a.keep@1.0.0
me.themes@1.0.0"
	run "${BASH:-bash}" "$cmd" --prune
	[ "$status" -eq 0 ]
	[ "$(readlink "$extensions_dir/me.themes-1.0.0")" = "$local_root/Themes" ]
	! grep -q 'me.themes' "$BATS_TEST_TMPDIR/tool.log" || false
	printf 'a.keep\n' >"$repo/Main/extensions.txt"
	run "${BASH:-bash}" "$cmd" --prune
	[ "$status" -eq 0 ]
	! grep -q 'me.themes' "$BATS_TEST_TMPDIR/tool.log" || false
	rm "$extensions_dir/me.themes-1.0.0"
	printf 'root %s\nextensions %s\n' "$repo" "$local_root" >"$FOUNDATION_CONFIG_DIR/vscode-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -L "$extensions_dir/me.themes-1.0.0" ]
}

@test "a version bump replaces the old link, a real folder is backed up, --check changes nothing" {
	local_extension Themes Me themes 2.0.0
	mkdir -p "$extensions_dir/me.themes-2.0.0" "$BATS_TEST_TMPDIR/elsewhere"
	printf 'old\n' >"$extensions_dir/me.themes-2.0.0/file"
	ln -s "$local_root/Themes" "$extensions_dir/me.themes-1.0.0"
	ln -s "$BATS_TEST_TMPDIR/elsewhere" "$extensions_dir/me.themes-0.9.0"
	run "${BASH:-bash}" "$cmd" --check
	[ "$status" -eq 0 ]
	[[ $output == *STALE*me.themes-1.0.0* ]]
	[[ $output == *MISSING*me.themes-2.0.0* ]]
	[ -L "$extensions_dir/me.themes-1.0.0" ]
	[ ! -L "$extensions_dir/me.themes-2.0.0" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$extensions_dir/me.themes-1.0.0" ]
	[ -L "$extensions_dir/me.themes-0.9.0" ]
	[ "$(readlink "$extensions_dir/me.themes-2.0.0")" = "$local_root/Themes" ]
	grep -q old "$(find "$FOUNDATION_BACKUP_ROOT/SymbolicLinks" -name file)"
}

@test "a manifest that is not JSON or lacks a field is skipped; a folder without one is ignored" {
	mkdir -p "$local_root/Broken" "$local_root/Plain"
	printf 'not json\n' >"$local_root/Broken/package.json"
	local_extension Partial Me "" 1.0.0
	local_extension Good Me good 1.0.0
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(find "$extensions_dir" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" = 1 ]
	[ -L "$extensions_dir/me.good-1.0.0" ]
}

@test "the Windows -Name and a comma list name the entries" {
	run "${BASH:-bash}" "$cmd" -Name Main,Side
	[ "$status" -eq 0 ]
	[ "$(readlink "$user/settings.json")" = "$repo/Main/settings.json" ]
	run "${BASH:-bash}" "$cmd" Main,Nope
	[ "$status" -eq 1 ]
}

@test "prune on in vscode-profiles.conf uninstalls without --prune" {
	printf 'prune on\n' >>"$FOUNDATION_CONFIG_DIR/vscode-profiles.conf"
	printf 'a.keep\nc.pinned\n' >"$repo/Main/extensions.txt"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qx 'code --uninstall-extension b.extra' "$BATS_TEST_TMPDIR/tool.log"
	! grep -q 'uninstall-extension a.keep\|uninstall-extension c.pinned' "$BATS_TEST_TMPDIR/tool.log" || false
}

@test "a failed install is reported, the next extension is still installed and the exit is 1" {
	stub_tool code 'case "$*" in *--list-extensions*) printf "%s\n" "$CODE_LIST" ;; *"--install-extension d.broken"*) exit 1 ;; esac'
	printf 'd.broken\ne.next\n' >"$repo/Main/extensions.txt"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 1 ]
	[[ $output == *"--install-extension [d.broken] failed"* ]]
	grep -qx 'code --install-extension e.next --do-not-sync' "$BATS_TEST_TMPDIR/tool.log"
}

@test "without the VS Code command line the files are still linked and the extensions skipped" {
	printf 'd.new\n' >"$repo/Main/extensions.txt"
	FOUNDATION_VSCODE_CLI=$BATS_TEST_TMPDIR/no-code run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"command line (code) not found"* ]]
	[ "$(readlink "$user/settings.json")" = "$repo/Main/settings.json" ]
	! grep -q '^code ' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || false
}

@test "an unreadable storage.json is left as it is and the profile is skipped" {
	mkdir -p "$repo/Side" "$user/globalStorage"
	printf '{}\n' >"$repo/Side/settings.json"
	printf 'not json' >"$user/globalStorage/storage.json"
	run "${BASH:-bash}" "$cmd" Side
	[ "$status" -eq 1 ]
	[ "$(cat "$user/globalStorage/storage.json")" = 'not json' ]
	[ ! -d "$user/profiles" ]
	[ ! -d "$FOUNDATION_BACKUP_ROOT/VSCodeProfiles" ]
}
