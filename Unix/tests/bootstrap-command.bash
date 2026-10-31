# The Bootstrap command with every Foundation command it calls replaced through BOOTSTRAP_COMMAND_DIR and
# every external tool by a stand-in (brew, mas, git, sudo, defaults, mdutil, socketfilterfw,
# softwareupdate, open, aerospace, osascript, arch, chezmoi, curl, uname), so nothing real runs.
# Load after helpers; call bootstrap_sandbox in setup, then run "$cmd". Shared by the
# Bootstrap*.bats suites, split so they run on separate workers.

COMMANDS="Initialize-Configuration Rename-Machine Display-SystemLanguageSettings Update-Repositories Set-SystemDefaults Set-SpecialFolders Set-PowerSettings Set-SystemTheme Set-Locale Set-DisplayLanguage Set-KeyboardLayouts Set-DockPins Set-LoginItems Deploy-FirefoxProfile Deploy-AiArtifacts Deploy-AiMarketplaces Deploy-AiMcpServers Initialize-AiProfile Enable-ObsidianCli Install-DotnetEf Install-CondaEnvironments Configure-NuGetConfig Configure-NpmConfig Configure-DockerDesktop Upgrade-All"
TOOLS="brew mas git sudo defaults mdutil socketfilterfw softwareupdate open aerospace osascript arch chezmoi curl uname"

# The sandbox: stand-ins logging to $BATS_TEST_TMPDIR/tool.log, a fixture config copy, a
# throwaway HOME, and $cmd.
bootstrap_sandbox() {
	copy_fixture_config
	export BOOTSTRAP_COMMAND_DIR=$BATS_TEST_TMPDIR/commands
	mkdir -p "$BOOTSTRAP_COMMAND_DIR" "$BATS_TEST_TMPDIR/prefix/bin"
	for name in $COMMANDS; do
		printf '#!/bin/sh\necho "cmd %s $*" >>"%s/tool.log"\ncase " $FAIL_COMMANDS " in *" %s "*) exit 1 ;; esac\nexit 0\n' \
			"$name" "$BATS_TEST_TMPDIR" "$name" >"$BOOTSTRAP_COMMAND_DIR/$name"
		chmod +x "$BOOTSTRAP_COMMAND_DIR/$name"
	done
	printf '#!/bin/sh\necho "GNU bash, version 5.3"\n' >"$BATS_TEST_TMPDIR/prefix/bin/bash"
	chmod +x "$BATS_TEST_TMPDIR/prefix/bin/bash"
	export BREW_PREFIX=$BATS_TEST_TMPDIR/prefix
	stub_tool brew 'case "$1" in --prefix) echo "$BREW_PREFIX" ;; shellenv) : ;; bundle) [ -z "$BUNDLE_FAIL" ] || exit 1 ;; esac'
	stub_tool mas 'case "$1" in list) echo "$MAS_LIST" ;; get) [ -z "$MAS_FAIL" ] || exit 1 ;; esac'
	stub_tool git 'case "$*" in "config --global user.name" | "config --global user.email") [ -n "$GIT_SET" ] && echo set || exit 1 ;; "config -f "*" user.name") echo "My Name" ;; "config -f "*" user.email") echo "me@example.invalid" ;; esac'
	stub_tool sudo 'case "$1" in -v) [ -z "$SUDO_REFUSE" ] || exit 1; exit 0 ;; -n) exit 0 ;; esac; exec "$@"'
	stub_tool uname 'case "$1" in -m) echo arm64 ;; *) echo Darwin ;; esac'
	stub_tool arch 'exit 1'
	for name in defaults mdutil socketfilterfw softwareupdate open aerospace osascript chezmoi curl; do stub_tool "$name"; done
	for name in $TOOLS; do
		[ "$(command -v "$name")" = "$BATS_TEST_TMPDIR/tools/$name" ] || {
			echo "stub guard: $name resolves to $(command -v "$name")" >&2
			return 1
		}
	done
	# Steps read and write under $HOME (the chezmoi config, stow-era links): never the real one.
	export HOME=$BATS_TEST_TMPDIR/user-home
	unset XDG_CONFIG_HOME
	# Backups (the Dotfiles and ObsidianSettings steps) go to a throwaway sink.
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	mkdir -p "$HOME"
	brewfile=$BATS_TEST_TMPDIR/Brewfile
	printf 'brew "jq"\nmas "Some App", id: 123\n' >"$brewfile"
	export MAS_LIST=''
	unset CHEZMOI
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Bootstrap
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"; }
calls() { grep "^$1" "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || true; }
# Turns every default-on step off, so a test turns on only what it checks.
all_off() {
	printf 'step %s off\n' Homebrew HomebrewBash Packages Dotfiles GitIdentity MachineType ObsidianSettings SystemDefaults SpecialFolders SystemTheme Locale DisplayLanguage KeyboardLayouts DockPins LoginItems DotnetEf CondaEnvironments PersonalSteps AeroSpace
}
