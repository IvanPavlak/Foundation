#!/usr/bin/env bats
# Bootstrap steps with their own logic: Homebrew (install when missing), Packages (taps, App Store
# apps, the bundle retry, which Brewfiles), the Dotfiles CHEZMOI guard, backup and stow-era links, the
# GitIdentity guard and its --only re-apply, and the ObsidianSettings link.
# Shares tests/bootstrap-command.bash with Bootstrap.bats.

load ../../helpers
load ../../bootstrap-command

setup() {
	setup_foundation
	bootstrap_sandbox
}

@test "Packages: taps trusted in both places, a missing App Store app got, one that cannot be got skipped" {
	{
		all_off
		echo "step Packages on"
		printf '[Packages]\ntrust cask some/tap/app\nbrewfile %s\n' "$brewfile"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(calls 'sudo -v' | wc -l | tr -d ' ')" -eq 1 ]
	[ "$(calls 'brew trust' | wc -l | tr -d ' ')" -eq 2 ]
	calls 'mas get 123' | grep -q .
	calls "brew bundle --file $brewfile" | grep -q .
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	MAS_FAIL=1 run "${BASH:-bash}" "$cmd"
	[[ $output == *"App Store app 123 skipped"* ]]
}

@test "Packages: a failed bundle is retried once, then fails the step" {
	{
		all_off
		echo "step Packages on"
		printf '[Packages]\nbrewfile %s\n' "$brewfile"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	MAS_LIST='123 Some App' BUNDLE_FAIL=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ "$(calls 'brew bundle' | wc -l | tr -d ' ')" -eq 2 ]
	[ -z "$(calls 'mas get')" ]
	[[ $output == *"failed step(s): Packages"* ]]
}

@test "Packages: without a brewfile line Unix/Brewfile then Unix/Brewfile.local; an @TYPE brewfile line only on that type" {
	{
		all_off
		echo "step Packages on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	# Brewfile.local is a fork's own list: a clone without one (Foundation's) bundles the base alone.
	want="brew bundle --file $FOUNDATION_UNIX/Brewfile"
	[ ! -r "$FOUNDATION_UNIX/Brewfile.local" ] || want="$want"$'\n'"brew bundle --file $FOUNDATION_UNIX/Brewfile.local"
	[ "$(grep -o 'brew bundle --file .*' <<<"$output")" = "$want" ]
	{
		all_off
		echo "step Packages on"
		printf '[Packages]\nbrewfile %s\n@Work brewfile %s.work\n' "$brewfile" "$brewfile"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	cp "$brewfile" "$brewfile.work"
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" --dry-run
	[ "$(grep -o 'brew bundle --file .*' <<<"$output")" = "brew bundle --file $brewfile" ]
	FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" --dry-run
	[ "$(grep -o 'brew bundle --file .*' <<<"$output")" = "brew bundle --file $brewfile"$'\n'"brew bundle --file $brewfile.work" ]
	[ -z "$(calls 'brew bundle')" ]
}

@test "Homebrew: installed when missing (a dry run downloads nothing), nothing run when present" {
	{
		all_off
		echo "step Homebrew on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	BOOTSTRAP_BREW=$BATS_TEST_TMPDIR/no-brew run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *'would run: /bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"'* ]]
	[ -z "$(calls curl)" ]
	# The curl stand-in prints no script, so the real run hands bash nothing to execute.
	BOOTSTRAP_BREW=$BATS_TEST_TMPDIR/no-brew run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(calls curl)" = "curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh" ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Homebrew present => $BATS_TEST_TMPDIR/tools/brew"* ]]
	[ -z "$(calls curl)" ]
	[ "$(calls brew)" = "brew shellenv" ]
}

@test "Dotfiles: init then apply, skipped when chezmoi runs Bootstrap, a dry run only diffs" {
	{
		all_off
		echo "step Dotfiles on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	CHEZMOI=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$(calls chezmoi)" ]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(calls chezmoi)" = $'chezmoi init --source '"$UNIX_DIR"$'\nchezmoi managed --include=symlinks --path-style=relative\nchezmoi apply' ]
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	mkdir -p "$HOME/.config/chezmoi"
	touch "$HOME/.config/chezmoi/chezmoi.toml"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$(calls chezmoi)" = $'chezmoi managed --include=symlinks --path-style=relative\nchezmoi diff' ]
}

@test "Dotfiles backs up a real file a link replaces before apply, and a failed backup skips apply" {
	{
		all_off
		echo "step Dotfiles on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	stub_tool chezmoi 'case $1 in managed) printf "%s\n" .zshrc .gitconfig .config/tool/rc ;; esac'
	printf 'mine\n' >"$HOME/.zshrc"
	ln -s /nonexistent "$HOME/.gitconfig"
	mkdir -p "$HOME/.config/chezmoi"
	touch "$HOME/.config/chezmoi/chezmoi.toml"
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output == *"Would back up ~/.zshrc => SymbolicLinks/Dotfiles.zshrc"* ]]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(cat "$FOUNDATION_BACKUP_ROOT"/SymbolicLinks/Dotfiles.zshrc/*/.zshrc)" = mine ]
	[ "$(ls "$FOUNDATION_BACKUP_ROOT/SymbolicLinks")" = Dotfiles.zshrc ]
	[ "$(calls chezmoi | tail -1)" = "chezmoi apply" ]
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	# A sink that cannot be created: a regular file where its folder goes.
	: >"$BATS_TEST_TMPDIR/not-a-folder"
	FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/not-a-folder run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"chezmoi apply skipped"* ]]
	[ -z "$(calls 'chezmoi apply')" ]
	[ "$(cat "$HOME/.zshrc")" = mine ]
}

@test "Dotfiles reports a link the stow layer left behind" {
	{
		all_off
		echo "step Dotfiles on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	mkdir -p "$HOME/.config/tool"
	ln -s ../../Development/Github/Dotfiles/Unix/stow/tool/dot-config/tool/rc "$HOME/.config/tool/rc"
	ln -s /elsewhere/file "$HOME/.keep"
	run "${BASH:-bash}" "$cmd"
	[[ $output == *"Stow-era link, points into the removed Unix/stow => $HOME/.config/tool/rc"* ]]
	[[ $output != *"$HOME/.keep"* ]]
}

@test "GitIdentity restores an unset identity from Git/.gitconfig and leaves a set one alone" {
	{
		all_off
		echo "step GitIdentity on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd"
	calls 'git config --global user.name My Name' | grep -q .
	calls 'git config --global user.email me@example.invalid' | grep -q .
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	GIT_SET=1 run "${BASH:-bash}" "$cmd"
	[ -z "$(calls 'git config --global user.name My Name')" ]
}

@test "GitIdentity takes an unset identity from git.local.conf before Git/.gitconfig" {
	{
		all_off
		echo "step GitIdentity on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	printf 'name Overlay Name\n' >"$FOUNDATION_CONFIG_DIR/git.local.conf"
	run "${BASH:-bash}" "$cmd"
	calls 'git config --global user.name Overlay Name' | grep -q .
	[[ $output == *"restored from git.local.conf => Overlay Name"* ]]
	# No email in the overlay: Git/.gitconfig still supplies it.
	calls 'git config --global user.email me@example.invalid' | grep -q .
}

@test "GitIdentity run alone replaces a set identity that differs from git.local.conf; the full run leaves it" {
	{
		all_off
		echo "step GitIdentity on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	printf 'name Overlay Name\n' >"$FOUNDATION_CONFIG_DIR/git.local.conf"
	GIT_SET=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$(calls 'git config --global user.name Overlay Name')" ]
	GIT_SET=1 run "${BASH:-bash}" "$cmd" --only GitIdentity
	[ "$status" -eq 0 ]
	calls 'git config --global user.name Overlay Name' | grep -q .
	[[ $output == *"Global git user.name differed from git.local.conf - replaced => set -> Overlay Name"* ]]
	# No email in the overlay: the set one stays, Git/.gitconfig is never forced over it.
	[ -z "$(calls 'git config --global user.email me@example.invalid')" ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	GIT_SET=1 run "${BASH:-bash}" "$cmd" --only GitIdentity --dry-run
	[[ $output == *"would run: git config --global user.name Overlay Name"* ]]
	[ -z "$(calls 'git config --global user.name Overlay Name')" ]
}

@test "ObsidianSettings: a real .obsidian is backed up and linked, a right link is left alone, a dry run changes nothing" {
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	# The vault comes from obsidian.conf here, never from the shell this suite runs in.
	unset OBSIDIAN_DIRECTORY
	# A repository with the settings folder, the relative `settings` path resolves against it.
	repo=$BATS_TEST_TMPDIR/repo
	vault=$BATS_TEST_TMPDIR/vault
	mkdir -p "$repo/Obsidian/.obsidian" "$vault/.obsidian"
	echo mine >"$vault/.obsidian/hotkeys.json"
	printf 'directory %s\nsettings Obsidian/.obsidian\n' "$vault" >"$FOUNDATION_CONFIG_DIR/obsidian.conf"
	{
		all_off
		echo "step ObsidianSettings on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	DOTFILES_ROOT=$repo run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"would back up and replace: $vault/.obsidian"* ]]
	[ ! -L "$vault/.obsidian" ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
	DOTFILES_ROOT=$repo run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$vault/.obsidian")" = "$repo/Obsidian/.obsidian" ]
	[ "$(cat "$FOUNDATION_BACKUP_ROOT"/SymbolicLinks/Obsidian/*/.obsidian/hotkeys.json)" = mine ]
	DOTFILES_ROOT=$repo run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(readlink "$vault/.obsidian")" = "$repo/Obsidian/.obsidian" ]
	[ "$(find "$FOUNDATION_BACKUP_ROOT/SymbolicLinks/Obsidian" -mindepth 1 -maxdepth 1 | wc -l | tr -d ' ')" -eq 1 ]
}

@test "ObsidianSettings: no settings line does nothing, a vault not cloned yet is skipped, a missing settings folder fails" {
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	# The vault comes from obsidian.conf here, never from the shell this suite runs in.
	unset OBSIDIAN_DIRECTORY
	repo=$BATS_TEST_TMPDIR/repo
	mkdir -p "$repo/Obsidian/.obsidian"
	{
		all_off
		echo "step ObsidianSettings on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	printf 'directory %s\n' "$BATS_TEST_TMPDIR/vault" >"$FOUNDATION_CONFIG_DIR/obsidian.conf"
	DOTFILES_ROOT=$repo run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/vault" ]
	printf 'directory %s\nsettings Obsidian/.obsidian\n' "$BATS_TEST_TMPDIR/vault" >"$FOUNDATION_CONFIG_DIR/obsidian.conf"
	DOTFILES_ROOT=$repo run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"Obsidian vault not found"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/vault" ]
	mkdir -p "$BATS_TEST_TMPDIR/vault"
	printf 'directory %s\nsettings Obsidian/Missing\n' "$BATS_TEST_TMPDIR/vault" >"$FOUNDATION_CONFIG_DIR/obsidian.conf"
	DOTFILES_ROOT=$repo run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/vault/.obsidian" ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}
