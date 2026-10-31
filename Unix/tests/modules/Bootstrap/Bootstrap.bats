#!/usr/bin/env bats
# Bootstrap: catalog order, defaults < config < overlay < --include < --skip, --only, initial
# steps, the failure summary, Rosetta and argument errors, the Desktop transcript and duration. The password rules are in
# Bootstrap.Sudo.bats, the Packages, Dotfiles and GitIdentity steps in Bootstrap.Steps.bats; all
# three share tests/bootstrap-command.bash.

load ../../helpers
load ../../bootstrap-command

setup() {
	setup_foundation
	bootstrap_sandbox
}

@test "--list shows the defaults, the config and its overlay; initial steps only with --with-initial-setup" {
	conf "step DockPins off" "step Power on"
	printf 'step DockPins on\nstep UpgradeAll on\n' >"$FOUNDATION_CONFIG_DIR/bootstrap.local.conf"
	run "${BASH:-bash}" "$cmd" --list
	[ "$status" -eq 0 ]
	[[ $output =~ DockPins\ +on\ +on ]]
	[[ $output =~ Power\ +off\ +on\ +sudo ]]
	[[ $output =~ UpgradeAll\ +off\ +on ]]
	[[ $output =~ RenameMachine\ +on\ +off ]]
	[[ $output =~ InitializeConfiguration\ +on\ +off\ +initial,interactive ]]
	run "${BASH:-bash}" "$cmd" --list --with-initial-setup
	[[ $output =~ RenameMachine\ +on\ +on ]]
	[[ $output =~ InitializeConfiguration\ +on\ +on ]]
	# The first-run writer comes first, so RenameMachine sees the name it recorded.
	[ "$(grep -oE '(InitializeConfiguration|RenameMachine)' <<<"$output" | head -1)" = InitializeConfiguration ]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}

@test "--include turns a step on, --skip wins over it with one warning, names in any case" {
	conf
	run "${BASH:-bash}" "$cmd" --list --include upgradeall,Power --skip power
	[[ $output =~ UpgradeAll\ +off\ +on ]]
	[[ $output =~ Power\ +off\ +off ]]
	[ "$(grep -c 'in both --skip and --include' <<<"$output")" -eq 1 ]
}

@test "steps run in catalog order, not argument order; off steps do not run" {
	conf
	run "${BASH:-bash}" "$cmd" --only CondaEnvironments,SystemDefaults,DotnetEf
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = $'cmd Set-SystemDefaults \ncmd Install-DotnetEf \ncmd Install-CondaEnvironments ' ]
	[[ $output == *"Ran: SystemDefaults DotnetEf CondaEnvironments"* ]]
}

@test "the default run follows the config: on steps run, off steps do not" {
	{
		all_off
		echo "step DockPins on"
		echo "step AiMarketplaces on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = $'cmd Set-DockPins \ncmd Deploy-AiMarketplaces ' ]
	[ -z "$(calls sudo)" ]
}

@test "a failed step does not stop the run; the summary names it and the run fails" {
	{
		all_off
		printf 'step %s on\n' SystemDefaults DockPins
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	FAIL_COMMANDS=Set-SystemDefaults run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	calls 'cmd Set-DockPins' | grep -q .
	[[ $output == *"failed step(s): SystemDefaults - rerun them with Bootstrap --only SystemDefaults"* ]]
}

@test "after InitializeConfiguration records this Mac's machine type, its @TYPE step lines govern the rest of the run" {
	unset MACHINE_TYPE
	stub_tool scutil 'echo bootstrap-test-host'
	# The fixture maps no host, so the machine type is its default (Laptop) until the stand-in
	# records this host as Work; NO_RECORD keeps it from writing.
	printf '#!/bin/sh\necho "cmd Initialize-Configuration $*" >>"%s/tool.log"\n[ -n "$NO_RECORD" ] || echo "host bootstrap-test-host Work" >>"%s/machines.conf"\n' \
		"$BATS_TEST_TMPDIR" "$FOUNDATION_CONFIG_DIR" >"$BOOTSTRAP_COMMAND_DIR/Initialize-Configuration"
	{
		all_off
		printf 'step %s off\n' RenameMachine Permissions
		echo "@Work step Power on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	NO_RECORD=1 run "${BASH:-bash}" "$cmd" --with-initial-setup --dry-run
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = "cmd Initialize-Configuration --dry-run" ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --with-initial-setup --dry-run
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = $'cmd Initialize-Configuration --dry-run\ncmd Set-PowerSettings --dry-run' ]
	# A real run asks for the one password after the type is recorded, as a root step turned on.
	cp "$FIXTURE_CONFIG/machines.conf" "$FOUNDATION_CONFIG_DIR/machines.conf"
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --with-initial-setup
	[ "$status" -eq 0 ]
	[ "$(grep -E '^(cmd Initialize-Configuration|sudo -v|cmd Set-PowerSettings)' "$BATS_TEST_TMPDIR/tool.log")" = $'cmd Initialize-Configuration \nsudo -v\ncmd Set-PowerSettings ' ]
}

@test "Rosetta installs without agreeing to the licence; Logout off prints the reminder" {
	{
		all_off
		echo "step Rosetta on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$(calls 'sudo softwareupdate')" = "sudo softwareupdate --install-rosetta" ]
	[[ $output == *"Log out and back in so keyboard and trackpad settings apply"* ]]
}

@test "an unknown step, an unknown argument and a value without a flag are errors" {
	run "${BASH:-bash}" "$cmd" --skip Nope
	[ "$status" -ne 0 ]
	[[ $output == *"Unknown step [Nope]"* ]]
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	run "${BASH:-bash}" "$cmd" DockPins
	[ "$status" -ne 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}

@test "the language steps pass the language.conf defaults; without one they apply nothing; a read-back follows them" {
	{
		all_off
		printf 'step %s on\n' Locale DisplayLanguage KeyboardLayouts
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	printf 'default-locale Croatian\ndefault-keyboard-set Croatian\n' >"$FOUNDATION_CONFIG_DIR/language.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = $'cmd Set-Locale Croatian\ncmd Set-KeyboardLayouts Croatian\ncmd Display-SystemLanguageSettings ' ]
	[[ $output == *"No default-display-language in language.conf"* ]]
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"would run: Set-Locale Croatian"* ]]
	[[ $output == *"would run: Display-SystemLanguageSettings"* ]]
}

@test "the language read-back runs once after any language step, and not in a run without one" {
	conf
	printf 'default-locale Croatian\n' >"$FOUNDATION_CONFIG_DIR/language.conf"
	run "${BASH:-bash}" "$cmd" --only Locale,DockPins
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = $'cmd Set-Locale Croatian\ncmd Display-SystemLanguageSettings \ncmd Set-DockPins ' ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --only SystemDefaults
	[ "$status" -eq 0 ]
	[ -z "$(calls 'cmd Display-SystemLanguageSettings')" ]
	# A failed language step is still read back.
	: >"$BATS_TEST_TMPDIR/tool.log"
	FAIL_COMMANDS=Set-Locale run "${BASH:-bash}" "$cmd" --only Locale
	[ "$status" -ne 0 ]
	calls 'cmd Display-SystemLanguageSettings' | grep -q .
}

@test "RepositoryUpdate updates the repository-scope groups of this machine type, every repository for All" {
	printf '[Private]\nMine /me/mine.git /tmp/mine\n[Work]\nTheirs /them/theirs.git /tmp/theirs\n' >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	conf "repository-scope All" "@Laptop repository-scope private, Work"
	FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" --only RepositoryUpdate
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = "cmd Update-Repositories --all" ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	FOUNDATION_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd" --only RepositoryUpdate
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = "cmd Update-Repositories Private Work" ]
	: >"$BATS_TEST_TMPDIR/tool.log"
	conf
	run "${BASH:-bash}" "$cmd" --only RepositoryUpdate
	[ "$(calls cmd)" = "cmd Update-Repositories --all" ]
}

@test "RepositoryUpdate takes group names only: a repository name or a typo updates nothing and fails the step" {
	printf '[Private]\nMyRepo /me/mine.git /tmp/mine\n' >"$FOUNDATION_CONFIG_DIR/repositories.conf"
	conf "repository-scope Private MyRepo"
	run "${BASH:-bash}" "$cmd" --only RepositoryUpdate
	[ "$status" -ne 0 ]
	[[ $output == *"Unknown repository group [MyRepo] in repository-scope - nothing updated. Configured groups => [Private]"* ]]
	[[ $output == *"failed step(s): RepositoryUpdate"* ]]
	[ -z "$(calls cmd)" ]
}

@test "PersonalSteps runs this machine type's lines in order; unknown, failing and other-type lines" {
	stub_tool my-tool
	conf "[PersonalSteps]" "Set-DockPins --flag" "nope-command arg" "Upgrade-All" "@Other Set-LoginItems" "my-tool one two"
	FAIL_COMMANDS=Upgrade-All FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" --only PersonalSteps
	[ "$status" -ne 0 ]
	[ "$(calls cmd)" = $'cmd Set-DockPins --flag\ncmd Upgrade-All ' ]
	calls 'my-tool one two' | grep -q .
	[[ $output == *"Personal step [nope-command] not found"* ]]
	[[ $output == *"Personal step [Upgrade-All] failed"* ]]
	[[ $output == *"failed step(s): PersonalSteps"* ]]
	: >"$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --only PersonalSteps --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"would run: Set-DockPins --flag"* ]]
	[ -z "$(calls cmd)" ]
}

@test "PersonalSteps without a line for this machine type says so and succeeds" {
	conf "[PersonalSteps]" "@Other Set-LoginItems"
	FOUNDATION_MACHINE_TYPE=Work run "${BASH:-bash}" "$cmd" --only PersonalSteps
	[ "$status" -eq 0 ]
	[[ $output == *"No personal steps configured for this [Work] machine!"* ]]
	[ -z "$(calls cmd)" ]
}

@test "AiProfileInit is off by default: with an AI profile active the run warns and names Initialize-AiProfile; --only stays quiet" {
	printf 'default Personal\n[Personal]\n' >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	all_off >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd" --list
	[[ $output =~ AiProfileInit\ +off\ +off\ +interactive ]]
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"AI profile [Personal] sign-ins skipped - run Initialize-AiProfile once on this Mac, or opt in with step AiProfileInit on"* ]]
	[ -z "$(calls 'cmd Initialize-AiProfile')" ]
	run "${BASH:-bash}" "$cmd" --only DockPins
	[[ $output != *"sign-ins skipped"* ]]
	# No profile: nothing to name.
	rm "$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output != *"sign-ins skipped"* ]]
}

@test "AiProfileInit on runs Initialize-AiProfile after AiMcpServers with a profile active, and only names it in a dry run" {
	printf 'default Personal\n[Personal]\n' >"$FOUNDATION_CONFIG_DIR/ai-profiles.conf"
	{
		all_off
		echo "step AiMcpServers on"
		echo "step AiProfileInit on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(calls cmd)" = $'cmd Deploy-AiMcpServers \ncmd Initialize-AiProfile ' ]
	[[ $output != *"sign-ins skipped"* ]]
	[[ $output == *"Ran: AiMcpServers AiProfileInit"* ]]
	rm "$BATS_TEST_TMPDIR/tool.log"
	run "${BASH:-bash}" "$cmd" --dry-run --only AiProfileInit
	[ "$status" -eq 0 ]
	[[ $output == *"would run: Initialize-AiProfile"* ]]
	[ -z "$(calls 'cmd Initialize-AiProfile')" ]
}

@test "AiProfileInit on without an AI profile warns and runs nothing" {
	{
		all_off
		echo "step AiProfileInit on"
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"AI profile sign-ins skipped - no AI profile is active (ai-profiles.conf)"* ]]
	[ -z "$(calls cmd)" ]
}

@test "a run keeps a plain transcript on the Desktop and ends with its path and the total duration; a dry run keeps none" {
	conf
	unset NO_COLOR
	LOG_FORCE_COLOR=1 TERM=xterm-256color run "${BASH:-bash}" "$cmd" --only DotnetEf
	[ "$status" -eq 0 ]
	transcripts=("$HOME"/Desktop/BootstrapLog_*.log)
	[ ${#transcripts[@]} -eq 1 ]
	[ -f "${transcripts[0]}" ]
	[[ $output == *"Log file location => ${transcripts[0]}"* ]]
	[[ $output == *"Total duration => "*" second"* ]]
	# The console keeps its colours; the transcript holds the same lines without them.
	[[ $output == *$'\033['* ]]
	grep -q 'Ran: DotnetEf' "${transcripts[0]}"
	grep -q 'Total duration => ' "${transcripts[0]}"
	! grep -q $'\033' "${transcripts[0]}" || false
	rm "${transcripts[0]}"
	run "${BASH:-bash}" "$cmd" --only DotnetEf --dry-run
	[ "$status" -eq 0 ]
	[ -z "$(ls -A "$HOME/Desktop")" ]
	[[ $output != *"Log file location"* ]]
	[[ $output == *"Total duration => "* ]]
}
