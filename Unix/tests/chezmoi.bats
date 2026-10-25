#!/usr/bin/env bats
# The chezmoi source tree (Unix/.chezmoiroot -> Unix/home): every link template points at a file
# of the repository, and, when chezmoi is installed, applying the tree into a throwaway home (its
# own config, state and cache, so nothing outside the test folder is read or written) creates
# exactly those links, picks the machine type's fastfetch config with the Test fallback, keeps
# ~/.ssh and the ~/Library chain private, skips ~/.ssh/config and the Apple logo images in a clone
# without them and runs no first-apply script when bootstrapOnFirstApply is false. A fork's Codegen link script (not in Foundation) links the
# backslash-named file only with the payload, and Git/Unix/gitconfig.local carries the merge=ours
# driver.

load helpers

setup() {
	setup_foundation
	repo=$(cd "$UNIX_DIR/.." && pwd -P)
	source_root=$UNIX_DIR/$(cat "$UNIX_DIR/.chezmoiroot")
}

@test ".chezmoiroot names the home folder, which holds the config template and the scripts" {
	[ "$(cat "$UNIX_DIR/.chezmoiroot")" = home ]
	[ -f "$source_root/.chezmoi.toml.tmpl" ]
	[ -f "$source_root/.chezmoiscripts/run_once_after_bootstrap.sh.tmpl" ]
	grep -qF 'Unix/modules/Bootstrap/bin/bootstrap-first-run' "$source_root/.chezmoiscripts/run_once_after_bootstrap.sh.tmpl"
	[ -f "$UNIX_DIR/modules/Bootstrap/bin/bootstrap-first-run" ]
}

@test "every plain link template points at a file or folder of the repository" {
	count=0
	while IFS= read -r template; do
		line=$(cat "$template")
		case $line in
			"{{ .chezmoi.workingTree }}/"*) ;;
			*) continue ;; # a computed target (fastfetch's config), checked by the apply test
		esac
		target=$repo/${line#"{{ .chezmoi.workingTree }}/"}
		# .ssh/config, the Apple logo images and the terminal overrides are fork payloads
		# Foundation does not ship; .chezmoiignore skips their links when they are missing, so only
		# they may point at nothing.
		case $target in "$repo"/.ssh/config | "$repo"/FastFetch/Unix/AppleLogo*.png | "$repo"/WezTerm/wezterm.local.lua | "$repo"/Unix/ghostty/config.local) [ -e "$target" ] || continue ;; esac
		[ -e "$target" ] || {
			echo "missing target of $template: $target"
			return 1
		}
		count=$((count + 1))
	done < <(find "$source_root" -name 'symlink_*.tmpl')
	# The links every clone has, Foundation's included (the fork payloads above left out).
	[ "$count" -ge 13 ]
}

@test "applying the tree creates the links, the fastfetch fallback and a private ~/.ssh" {
	command -v chezmoi >/dev/null 2>&1 || skip "chezmoi is not installed"
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	config=$BATS_TEST_TMPDIR/chezmoi.toml
	printf 'sourceDir = "%s"\n\n[data]\n    machineType = "Work"\n    bootstrapOnFirstApply = false\n' "$UNIX_DIR" >"$config"
	run chezmoi --config "$config" --source "$UNIX_DIR" --destination "$HOME" \
		--persistent-state "$BATS_TEST_TMPDIR/state.boltdb" --cache "$BATS_TEST_TMPDIR/cache" --no-tty apply
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/.zshrc")" = "$repo/Unix/shell/zshrc" ]
	[ "$(readlink "$HOME/.bash_profile")" = "$repo/Unix/shell/bash_profile" ]
	[ "$(readlink "$HOME/.gitconfig.local")" = "$repo/Git/Unix/gitconfig.local" ]
	[ "$(readlink "$HOME/.config/btop/themes")" = "$repo/Btop/themes" ]
	if [ -f "$repo/FastFetch/Unix/config_Work.jsonc" ]; then
		[ "$(readlink "$HOME/.config/fastfetch/config.jsonc")" = "$repo/FastFetch/Unix/config_Work.jsonc" ]
	else
		[ "$(readlink "$HOME/.config/fastfetch/config.jsonc")" = "$repo/FastFetch/Unix/config_Test.jsonc" ]
	fi
	# A fork's .ssh/config payload is linked; Foundation ships none, so a clone of it gets no link.
	if [ -f "$repo/.ssh/config" ]; then
		[ "$(readlink "$HOME/.ssh/config")" = "$repo/.ssh/config" ]
		[ "$(stat -f %Lp "$HOME/.ssh" 2>/dev/null || stat -c %a "$HOME/.ssh")" = 700 ]
	else
		[ ! -L "$HOME/.ssh/config" ]
	fi
	[ "$(readlink "$HOME/.config/fastfetch/FastFetchLogo_Test.txt")" = "$repo/FastFetch/Unix/FastFetchLogo_Test.txt" ]
	# The Codegen link script, with a fork's Codegen payload: the one file whose name holds a backslash.
	links=18
	if [ -f "$repo/Codegen/Unix/.codegen.json" ]; then
		[ "$(readlink "$HOME/Library/Application Support\\.codegen.json")" = "$repo/Codegen/Unix/.codegen.json" ]
		links=$((links + 1))
	fi
	[ -f "$repo/.ssh/config" ] || links=$((links - 1))
	# The Apple logo images are a fork's payload: each one the clone lacks is one link fewer.
	for logo in AppleLogoBlack AppleLogoOriginal AppleLogoSilver; do
		[ -f "$repo/FastFetch/Unix/$logo.png" ] || links=$((links - 1))
	done
	# So are the terminal overrides: each one the clone has is one link more.
	for override in WezTerm/wezterm.local.lua Unix/ghostty/config.local; do
		[ -f "$repo/$override" ] && links=$((links + 1))
	done
	[ "$(find "$HOME" -type l | wc -l | tr -d ' ')" -eq "$links" ]
}

@test "a clone without .ssh/config gets no ~/.ssh/config link, the other links still apply" {
	command -v chezmoi >/dev/null 2>&1 || skip "chezmoi is not installed"
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	# A repository copy with the chezmoi tree but no .ssh payload, as a generic clone has.
	clone=$BATS_TEST_TMPDIR/clone
	mkdir -p "$clone/Unix"
	cp -R "$source_root" "$UNIX_DIR/.chezmoiroot" "$clone/Unix/"
	config=$BATS_TEST_TMPDIR/chezmoi.toml
	printf 'sourceDir = "%s"\nworkingTree = "%s"\n\n[data]\n    machineType = "Work"\n    bootstrapOnFirstApply = false\n' "$clone/Unix" "$clone" >"$config"
	run chezmoi --config "$config" --source "$clone/Unix" --destination "$HOME" \
		--persistent-state "$BATS_TEST_TMPDIR/state.boltdb" --cache "$BATS_TEST_TMPDIR/cache" --no-tty apply
	[ "$status" -eq 0 ]
	[ ! -e "$HOME/.ssh/config" ] && [ ! -L "$HOME/.ssh/config" ]
	[ "$(readlink "$HOME/.zshrc")" = "$clone/Unix/shell/zshrc" ]
	# No config_Work.jsonc in the clone: the machine type falls back to the shipped Test panel.
	[ "$(readlink "$HOME/.config/fastfetch/config.jsonc")" = "$clone/FastFetch/Unix/config_Test.jsonc" ]
	# No Codegen payload either: its link script renders empty and links nothing.
	[ ! -L "$HOME/Library/Application Support\\.codegen.json" ]
	# Nor the Apple logo images, which Foundation does not ship: no link to a missing file.
	for logo in AppleLogoBlack AppleLogoOriginal AppleLogoSilver; do
		[ ! -L "$HOME/.config/fastfetch/$logo.png" ]
	done
	# Nor the terminal overrides.
	[ ! -L "$HOME/.config/wezterm/wezterm.local.lua" ]
	[ ! -L "$HOME/.config/ghostty/config.local" ]
}

@test "a clone with the terminal overrides links each next to its shared config" {
	command -v chezmoi >/dev/null 2>&1 || skip "chezmoi is not installed"
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	clone=$BATS_TEST_TMPDIR/clone
	mkdir -p "$clone/Unix/ghostty" "$clone/WezTerm"
	cp -R "$source_root" "$UNIX_DIR/.chezmoiroot" "$clone/Unix/"
	echo 'return function(config) end' >"$clone/WezTerm/wezterm.local.lua"
	echo 'font-size = 14' >"$clone/Unix/ghostty/config.local"
	config=$BATS_TEST_TMPDIR/chezmoi.toml
	printf 'sourceDir = "%s"\nworkingTree = "%s"\n\n[data]\n    machineType = "Work"\n    bootstrapOnFirstApply = false\n' "$clone/Unix" "$clone" >"$config"
	run chezmoi --config "$config" --source "$clone/Unix" --destination "$HOME" \
		--persistent-state "$BATS_TEST_TMPDIR/state.boltdb" --cache "$BATS_TEST_TMPDIR/cache" --no-tty apply
	[ "$status" -eq 0 ]
	[ "$(readlink "$HOME/.config/wezterm/wezterm.local.lua")" = "$clone/WezTerm/wezterm.local.lua" ]
	[ "$(readlink "$HOME/.config/ghostty/config.local")" = "$clone/Unix/ghostty/config.local" ]
}

@test "the shared terminal configs load their local overrides" {
	grep -qF "wezterm.config_dir .. '/wezterm.local.lua'" "$repo/WezTerm/wezterm.lua"
	[ "$(tail -n 1 "$repo/Unix/ghostty/config")" = 'config-file = ?config.local' ]
}

@test "the Codegen link script leaves a real file alone and replaces a stale link" {
	command -v chezmoi >/dev/null 2>&1 || skip "chezmoi is not installed"
	# A fork's own script (Foundation does not ship it).
	[ -f "$source_root/.chezmoiscripts/run_after_codegen-link.sh.tmpl" ] || skip "no Codegen link script in this clone"
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME/Library" "$BATS_TEST_TMPDIR/tree/Codegen/Unix"
	touch "$BATS_TEST_TMPDIR/tree/Codegen/Unix/.codegen.json"
	printf 'sourceDir = "%s"\nworkingTree = "%s"\n\n[data]\n    machineType = "Work"\n    bootstrapOnFirstApply = false\n' \
		"$UNIX_DIR" "$BATS_TEST_TMPDIR/tree" >"$BATS_TEST_TMPDIR/chezmoi.toml"
	chezmoi --config "$BATS_TEST_TMPDIR/chezmoi.toml" --source "$UNIX_DIR" --destination "$HOME" --cache "$BATS_TEST_TMPDIR/cache" \
		execute-template --file "$source_root/.chezmoiscripts/run_after_codegen-link.sh.tmpl" >"$BATS_TEST_TMPDIR/link.sh" 2>/dev/null
	[ "$(head -1 "$BATS_TEST_TMPDIR/link.sh")" = "#!/bin/sh" ]
	link="$HOME/Library/Application Support\\.codegen.json"
	echo mine >"$link"
	run sh "$BATS_TEST_TMPDIR/link.sh"
	[ "$status" -eq 0 ]
	[[ $output == *"is a real file, left alone"* ]]
	[ "$(cat "$link")" = mine ]
	rm "$link"
	ln -s /elsewhere "$link"
	run sh "$BATS_TEST_TMPDIR/link.sh"
	[ "$status" -eq 0 ]
	[ "$(readlink "$link")" = "$BATS_TEST_TMPDIR/tree/Codegen/Unix/.codegen.json" ]
}

@test "the Unix git overrides register the merge=ours driver .gitattributes relies on" {
	[ "$(git config -f "$repo/Git/Unix/gitconfig.local" merge.ours.driver)" = true ]
	grep -q 'merge=ours' "$repo/.gitattributes"
}

@test "the first-apply script renders only when bootstrapOnFirstApply is true" {
	command -v chezmoi >/dev/null 2>&1 || skip "chezmoi is not installed"
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	script=$source_root/.chezmoiscripts/run_once_after_bootstrap.sh.tmpl
	for value in true false; do
		printf 'sourceDir = "%s"\n\n[data]\n    machineType = "Laptop"\n    bootstrapOnFirstApply = %s\n' "$UNIX_DIR" "$value" >"$BATS_TEST_TMPDIR/$value.toml"
	done
	run chezmoi --config "$BATS_TEST_TMPDIR/true.toml" --source "$UNIX_DIR" --destination "$HOME" --cache "$BATS_TEST_TMPDIR/cache" execute-template --file "$script"
	[ "$status" -eq 0 ]
	[[ ${lines[0]} == "#!/bin/sh" ]]
	[[ $output == *"exec \"$repo/Unix/modules/Bootstrap/bin/bootstrap-first-run\""* ]]
	run chezmoi --config "$BATS_TEST_TMPDIR/false.toml" --source "$UNIX_DIR" --destination "$HOME" --cache "$BATS_TEST_TMPDIR/cache" execute-template --file "$script"
	[ "$status" -eq 0 ]
	[ -z "$(printf '%s' "$output" | tr -d '[:space:]')" ]
}
