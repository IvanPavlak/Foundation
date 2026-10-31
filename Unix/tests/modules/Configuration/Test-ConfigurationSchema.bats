#!/usr/bin/env bats
# Test-ConfigurationSchema: broken references are reported, --strict fails, a consistent config passes.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	copy_fixture_config
	cmd=$UNIX_DIR/modules/Configuration/bin/Test-ConfigurationSchema
}

@test "a misspelled action and a foreign zone fail --strict, the fixed config passes" {
	cfg=$FOUNDATION_CONFIG_DIR
	rm -rf "$cfg" && mkdir -p "$cfg/layouts/Work"
	cp "$FIXTURE_CONFIG/apps.conf" "$FIXTURE_CONFIG/zones.conf" "$cfg/"
	printf '[Demo]\npath ROOT ~\naction Open-VSCode Demo\ntab ROOT\n' >"$cfg/projects.conf"
	printf '[Group]\nhttps://example.com\n' >"$cfg/browser-groups.conf"
	printf '[W]\nOpen-Project Demo\nOpen-Projekt Demo\nSet-WorkspaceWindowLayout W\n' >"$cfg/workspaces.conf"
	printf '[W]\nlayout 1 Five\n1 Middle Code\n' >"$cfg/layouts/Work/W_Work.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"unknown action [Open-Projekt]"* ]]
	[[ $output == *"zone [Middle] is not in zone set [Five]"* ]]
	printf '[W]\nOpen-Project Demo\nSet-WorkspaceWindowLayout W\n' >"$cfg/workspaces.conf"
	printf '[W]\nlayout 1 Five\n1 Left Code\n' >"$cfg/layouts/Work/W_Work.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "a layout missing from one layout set is reported" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '\n[OnlyWork]\nSet-WorkspaceWindowLayout OnlyWork\n' >>"$cfg/workspaces.conf"
	printf '[OnlyWork]\nlayout 1 Zero\n1 Fullscreen Code\n' >"$cfg/layouts/Work/OnlyWork_Work.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output == *"layout [OnlyWork] is missing from layouts/Laptop/"* ]]
}

@test "a layout file must hold one section named after it" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '[Other]\nlayout 1 Zero\n1 Fullscreen Code\n' >"$cfg/layouts/Work/Wrong_Work.conf"
	printf '[A]\nlayout 1 Zero\n\n[B]\nlayout 1 Zero\n' >"$cfg/layouts/Work/A_Work.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output == *"Wrong_Work.conf: section [Other] belongs in Other_Work.conf"* ]]
	[[ $output == *"A_Work.conf: holds 2 sections"* ]]
}

@test "an unknown machine type in machines.conf or an @TYPE prefix is reported" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf 'host Somewhere Desk\nlayout-override Phone Work\n' >>"$cfg/machines.conf"
	printf '@Laptop,Phone sleep 5\n' >>"$cfg/power.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output == *"host names unknown machine type [Desk]"* ]]
	[[ $output == *"layout-override names unknown machine type [Phone]"* ]]
	[[ $output == *"power.conf: @Phone names an unknown machine type"* ]]
	[[ $output != *"[Laptop]"* ]]
}

@test "a layout set need not be a machine type: a layouts/ folder or an override target with one" {
	cfg=$FOUNDATION_CONFIG_DIR
	# A temporary monitor's set, as Windows' LayoutMachineTypeOverrides @{ Test = "Temp" }.
	mkdir -p "$cfg/layouts/Temp" "$cfg/layouts/Server"
	printf 'layout-override Laptop Temp\nsmall-display Temp\n' >>"$cfg/machines.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output != *"layout set [Temp]"* ]]
	[[ $output != *"machine type [Temp]"* ]]
	[[ $output != *"layouts/Server/"* ]]
	# A target that is neither a type nor a folder is still reported.
	printf 'layout-override Laptop Tower\n' >>"$cfg/machines.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output == *"layout-override names unknown layout set [Tower] (neither a machine type nor a layouts/Tower/ folder)"* ]]
}

@test "a machines.conf without type lines is reported" {
	printf 'default Laptop\n' >"$FOUNDATION_CONFIG_DIR/machines.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output == *"machines.conf: no type lines"* ]]
}

@test "a layout set no machine uses need not hold every layout, one a host maps to must" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '\n[OnlyHere]\nSet-WorkspaceWindowLayout OnlyHere\n' >>"$cfg/workspaces.conf"
	for set in Laptop Work; do printf '[OnlyHere]\nlayout 1 Zero\n1 Fullscreen Code\n' >"$cfg/layouts/$set/OnlyHere_$set.conf"; done
	mkdir -p "$cfg/layouts/Test"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output != *"missing from layouts/Test/"* ]]
	printf 'host SomeMac Test\n' >>"$cfg/machines.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output == *"layout [OnlyHere] is missing from layouts/Test/"* ]]
}

@test "template errors, unknown project scopes, unknown variant projects and unused templates are reported" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '\n[Unused]\nFocus-VirtualDesktop 1\n' >>"$cfg/workspace-templates.conf"
	printf '\n[BrokenSpace]\ntemplate Project\nadd Open-X {Nope}\n\n[Scoped]\n+Ghost Focus-VirtualDesktop 2\n' >>"$cfg/workspaces.conf"
	printf 'project Phantom\n1 Left Code\n' >>"$cfg/layouts/Work/Sample_Work.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"workspaces.conf [BrokenSpace]: unknown placeholder {Nope}"* ]]
	[[ $output == *"workspaces.conf [Scoped]: scope [+Ghost] names unknown project [Ghost]"* ]]
	[[ $output == *"Sample_Work.conf [Sample]: project variant [Phantom] names unknown project [Phantom]"* ]]
	[[ $output == *"template [Unused] is used by no workspace"* ]]
}

@test "a layout-set scope must name a machine type or a layout set" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '\n[SetScoped]\n%%Laptop,Ghost +Ghost2 Focus-VirtualDesktop 2\n%%work Focus-VirtualDesktop 3\n' >>"$cfg/workspaces.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"workspaces.conf [SetScoped]: layout-set scope [%Laptop,Ghost] names [Ghost]"* ]]
	[[ $output == *"scope [+Ghost2] names unknown project [Ghost2]"* ]]
	[[ $output != *"names [Laptop]"* ]]
	[[ $output != *"[%work]"* ]]
	[[ $output != *"unknown action"* ]]
}

@test "a trailing & is accepted on a command that may run in the background, reported on any other" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '\n[Backgrounded]\nOpen-Code &\nOpen-Application Code &\nFocus-VirtualDesktop 2 &\n' >>"$cfg/workspaces.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[[ $output == *"workspaces.conf [Backgrounded]: [Focus-VirtualDesktop] cannot run in the background"* ]]
	[[ $output != *"[Open-Code] cannot run"* ]]
	[[ $output != *"[Open-Application] cannot run"* ]]
	[[ $output != *"unknown action"* ]]
}

@test "a variant's zone is checked against the zone set it ends up with" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf 'project Sample\nlayout 1 Zero\n1 Left Code\n' >>"$cfg/layouts/Work/Sample_Work.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output == *"project variant [Sample]: zone [Left] is not in zone set [Zero]"* ]]
}

@test "only the last default line names a used layout set, as the machine type resolves it" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '\n[OnlyHere]\nSet-WorkspaceWindowLayout OnlyHere\n' >>"$cfg/workspaces.conf"
	for set in Laptop Work; do printf '[OnlyHere]\nlayout 1 Zero\n1 Fullscreen Code\n' >"$cfg/layouts/$set/OnlyHere_$set.conf"; done
	mkdir -p "$cfg/layouts/Test"
	printf 'type Test\ndefault Test\n' >>"$cfg/machines.conf"
	printf 'default Laptop\n' >"$cfg/machines.local.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output != *"missing from layouts/Test/"* ]]
}

@test "the shipped base files alone, as a fresh clone has them, pass --strict" {
	cfg=$BATS_TEST_TMPDIR/fresh
	mkdir -p "$cfg/layouts"
	cp "$UNIX_DIR"/config/*.conf "$cfg/"
	rm -f "$cfg"/*.local.conf
	cp -R "$UNIX_DIR/config/layouts/Test" "$cfg/layouts/"
	FOUNDATION_CONFIG_DIR=$cfg run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
}

@test "a run key that is only a path (no tab line) is reported, since Run-Project types only into tabs" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '\n[RunOnlyPath]\npath ROOT ~\npath API ~\ntab ROOT\nrun ROOT make\nrun API make\nrun NOPE make\n' >>"$cfg/projects.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output == *"projects.conf [RunOnlyPath]: run [API] has no tab [API] line"* ]]
	[[ $output == *"projects.conf [RunOnlyPath]: run [NOPE] names no tab"* ]]
	[[ $output != *"run [ROOT]"* ]]
}

@test "an unset git identity is a note, not a problem: --strict passes and --quiet leaves it out" {
	cfg=$BATS_TEST_TMPDIR/fresh
	mkdir -p "$cfg/layouts"
	cp "$UNIX_DIR"/config/*.conf "$cfg/"
	rm -f "$cfg"/*.local.conf
	cp -R "$UNIX_DIR/config/layouts/Test" "$cfg/layouts/"
	# A stand-in git with no global identity.
	stub_tool git 'exit 1'
	FOUNDATION_CONFIG_DIR=$cfg run "${BASH:-bash}" "$cmd" --strict
	[ "$status" -eq 0 ]
	[[ $output == *"git name is set in neither"* ]]
	[[ $output == *"git email is set in neither"* ]]
	[[ $output == *"Configuration is consistent!"* ]]
	FOUNDATION_CONFIG_DIR=$cfg run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 0 ]
	[ -z "$output" ]
	# git.local.conf holds the name, the global git config the email.
	printf 'name My Name\n' >"$cfg/git.local.conf"
	stub_tool git '[ "$3" = user.email ] && echo me@example.com; exit 0'
	FOUNDATION_CONFIG_DIR=$cfg run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output != *"is set in neither"* ]]
}

@test "a shell.conf line foundation-shell-settings would skip is a problem; the overlay counts too" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf 'edit-mode windows\nkey UpArrow HistorySearchBackward\n' >"$cfg/shell.conf"
	printf 'key Tab NoSuchFunction\nlist-lines 5\n' >"$cfg/shell.local.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"shell.conf: key Tab: unknown function NoSuchFunction"* ]]
	[[ $output == *"shell.conf: unknown line kind list-lines"* ]]
	printf 'key Tab Complete\n' >"$cfg/shell.local.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[[ $output != *shell.conf* ]]
}

@test "a list-color line of theme.conf with an unknown key or colour is a problem" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf 'list-color user #FFA500\nlist-color colour red\nlist-color date orange\n' >"$cfg/theme.local.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"theme.conf: list-color colour: unknown key"* ]]
	[[ $output == *"theme.conf: list-color date: [orange] is not a colour"* ]]
	[[ $output != *"list-color user"* ]]
}

@test "ai-profiles.conf: names that are no profile, harness, server or marketplace, a bad UUID and an unknown line are problems" {
	cfg=$FOUNDATION_CONFIG_DIR
	printf '[one]\nskills each . ~/one\n' >"$cfg/ai-harnesses.conf"
	printf '[linear]\nurl https://mcp.linear.app/mcp\n' >"$cfg/ai-mcp-servers.conf"
	printf 'host My-Mac Nope\ndefault Personal\ndefault-owner Ghost\nbogus x\n[Personal]\nplan Max not-a-uuid\ndeploy two\nmcp linear nope\nmarketplaces none\nunattended maybe\ninclude tdd\nwhatever 1\n' >"$cfg/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd" --strict --quiet
	[ "$status" -eq 1 ]
	[[ $output == *"host [My-Mac Nope] names no profile section"* ]]
	[[ $output == *"default-owner [Ghost] names no profile section"* ]]
	[[ $output == *"unknown line before the first section => bogus x"* ]]
	[[ $output == *"plan UUID [not-a-uuid] is not a UUID"* ]]
	[[ $output == *"deploy names [two]"* ]]
	[[ $output == *"mcp names [nope]"* ]]
	[[ $output != *"mcp names [linear]"* ]]
	[[ $output == *"marketplaces names [none]"* ]]
	[[ $output == *"unattended is on or off"* ]]
	[[ $output == *"include [tdd] is not KIND/NAME"* ]]
	[[ $output == *"unknown line => whatever 1"* ]]
	printf 'default Personal\n[Personal]\nplan Max 00000000-0000-0000-0000-000000000000\ndeploy one\nmcp linear\nmcp\nunattended on\nowns github.com/me/*\n' >"$cfg/ai-profiles.conf"
	run "${BASH:-bash}" "$cmd" --quiet
	[[ $output != *ai-profiles.conf* ]]
}
