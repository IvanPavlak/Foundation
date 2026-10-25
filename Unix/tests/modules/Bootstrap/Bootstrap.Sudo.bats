#!/usr/bin/env bats
# Bootstrap: one sudo prompt only for root steps (Packages and AiArtifacts run without it), a
# refused password, --dry-run without sudo and with each command's own dry run, and the inline
# Spotlight and Firewall sections. Shares tests/bootstrap-command.bash with Bootstrap.bats.

load ../../helpers
load ../../bootstrap-command

setup() {
	setup_foundation
	bootstrap_sandbox
}

@test "the password is asked once, only when a root step runs" {
	{
		all_off
		printf 'step %s on\n' Power Firewall SoftwareUpdate
		printf '[Firewall]\nstealthmode on\n[SoftwareUpdate]\ndefaults /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true\n'
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(calls 'sudo -v' | wc -l | tr -d ' ')" -eq 1 ]
	calls 'socketfilterfw --setstealthmode on' | grep -q .
	calls 'defaults write /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true' | grep -q .
	calls 'cmd Set-PowerSettings' | grep -q .
}

@test "a refused password skips the root steps, runs the rest (sudo-optional ones too) and fails the run" {
	{
		all_off
		printf 'step %s on\n' Power DockPins AiArtifacts
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	SUDO_REFUSE=1 run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ -z "$(calls 'cmd Set-PowerSettings')" ]
	calls 'cmd Set-DockPins' | grep -q .
	calls 'cmd Deploy-AiArtifacts' | grep -q .
	[[ $output == *"Skipped without administrator rights: Power"* ]]
}

@test "--dry-run never asks for the password and passes each command its own dry run" {
	{
		all_off
		printf 'step %s on\n' Power Firewall SystemDefaults AiArtifacts FirefoxProfile UpgradeAll
		printf '[Firewall]\nglobalstate on\n'
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[ -z "$(calls sudo)" ]
	[ "$(calls cmd)" = $'cmd Set-SystemDefaults --dry-run\ncmd Set-PowerSettings --dry-run\ncmd Deploy-FirefoxProfile --check\ncmd Deploy-AiArtifacts --check' ]
	[[ $output == *"would run: sudo $BATS_TEST_TMPDIR/tools/socketfilterfw --setglobalstate on"* ]]
	[[ $output == *"would run: Upgrade-All"* ]]
}

@test "the inline sections: Spotlight, Firewall with an @TYPE line, unknown keys warned" {
	{
		all_off
		printf 'step %s on\n' Spotlight Firewall
		printf '[Spotlight]\nindex / off\n[Firewall]\n@Laptop stealthmode on\n@Work stealthmode off\nbogus on\n'
	} >"$FOUNDATION_CONFIG_DIR/bootstrap.conf"
	CONF_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	calls 'sudo mdutil -i off /' | grep -q .
	calls 'socketfilterfw --setstealthmode on' | grep -q .
	[ -z "$(calls 'socketfilterfw --setstealthmode off')" ]
	[[ $output == *"Unknown [Firewall] key, skipped"* ]]
}
