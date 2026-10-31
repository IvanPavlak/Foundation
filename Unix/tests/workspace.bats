#!/usr/bin/env bats
# Workspace templates and project scopes (lib/workspace.sh): an instance stamps out its template
# under its own name, set/replace/drop/add apply in that order, variables and {Workspace} are
# substituted last, every mistake is an error that resolves the workspace to nothing, and +A,B /
# +!A,B lines follow the open's projects, %A,B lines the layout set.

load helpers

setup() {
	setup_foundation
	foundation_load workspace
	copy_fixture_config
	cfg=$FOUNDATION_CONFIG_DIR
	cat >>"$cfg/workspace-templates.conf" <<'CONF'

[Base]
var Repository {Workspace}Repository
var Extra
Open-ClaudeDesktop
:project Open-Project {Workspace}
:browser Open-Browser {Repository} AI
Set-WorkspaceWindowLayout {Workspace}
Focus-VirtualDesktop 1

[Twice]
:first Focus-VirtualDesktop 1
:second Focus-VirtualDesktop 2

[Loop]
var A {B}
var B {A}
Open-Browser {A}

[Reserved]
var Workspace X
Focus-VirtualDesktop 1
CONF
	file=$cfg/workspaces.conf
}

add_workspace() { # NAME LINES
	printf '\n[%s]\n%s\n' "$1" "$2" >>"$file"
}

resolved() { # NAME [KEY=VALUE...]
	workspace_lines "$file" "$@" | paste -sd'|' -
}

@test "an instance runs its template under its own name, defaults referencing {Workspace}" {
	add_workspace Alpha 'template Base'
	[ "$(resolved Alpha)" = "Open-ClaudeDesktop|Open-Project Alpha|Open-Browser AlphaRepository AI|Set-WorkspaceWindowLayout Alpha|Focus-VirtualDesktop 1" ]
}

@test "set beats the default and the command line beats set, matched without dashes or case" {
	add_workspace Alpha $'template Base\nset Repository Fixed'
	[ "$(resolved Alpha | cut -d'|' -f3)" = "Open-Browser Fixed AI" ]
	workspace_resolve "$file" Alpha --repository=Cli --unrelated=x
	[ "${WORKSPACE_LINES[2]}" = "Open-Browser Cli AI" ]
	[ "${WORKSPACE_APPLIED[*]}" = "--repository=Cli" ]
	workspace_resolve "$file" Alpha -Repository=Windows
	[ "${WORKSPACE_LINES[2]}" = "Open-Browser Windows AI" ]
}

@test "replace and drop by action name or :ID, add lands before the template's layout or at an anchor" {
	add_workspace Alpha $'template Base\nreplace browser Open-Browser Other\ndrop Open-ClaudeDesktop\nadd Open-Obsidian\nadd after project Open-Notes {Workspace}\nadd before Focus-VirtualDesktop Open-Last'
	[ "$(resolved Alpha)" = "Open-Project Alpha|Open-Notes Alpha|Open-Browser Other|Open-Obsidian|Set-WorkspaceWindowLayout Alpha|Open-Last|Focus-VirtualDesktop 1" ]
}

@test "an action name that matches several template actions is an error; its :ID is not" {
	add_workspace Alpha $'template Twice\ndrop Focus-VirtualDesktop'
	run workspace_lines "$file" Alpha
	[ "$status" -ne 0 ]
	[[ $output == *"matches several actions"* ]]
	add_workspace Beta $'template Twice\ndrop second'
	[ "$(resolved Beta)" = "Focus-VirtualDesktop 1" ]
}

@test "every mistake resolves the workspace to nothing and names the problem" {
	add_workspace Unknown 'template NoSuchTemplate'
	add_workspace NoValue $'template Base\nadd Open-X {Extra}'
	add_workspace Typo $'template Base\nadd Open-X {Repositry}'
	add_workspace Mixed $'template Base\nOpen-Browser AI'
	add_workspace BadKey $'template Base\ndrop NoSuchAction'
	add_workspace BadAnchor $'template Base\nadd after NoSuchAction Open-X'
	add_workspace Cycle 'template Loop'
	add_workspace Reserved 'template Reserved'
	for name in Unknown NoValue Typo Mixed BadKey BadAnchor Cycle Reserved; do
		run workspace_lines "$file" "$name"
		[ "$status" -ne 0 ]
		[ -n "$output" ]
		workspace_resolve "$file" "$name" || true
		[ ${#WORKSPACE_LINES[@]} -eq 0 ]
	done
	run workspace_lines "$file" Unknown
	[[ $output == *"unknown template [NoSuchTemplate] (workspace-templates.conf defines: "*"Base"* ]]
	run workspace_lines "$file" NoValue
	[[ $output == *"variable [Extra] is used but has no value"* ]]
	run workspace_lines "$file" Typo
	[[ $output == *"unknown placeholder {Repositry}"* ]]
	run workspace_lines "$file" Cycle
	[[ $output == *"cycle"* ]]
	run workspace_lines "$file" Reserved
	[[ $output == *"reserved name [Workspace]"* ]]
}

@test "a variable without a value is fine when the command line gives one" {
	add_workspace Alpha $'template Base\nadd Open-X {Extra}'
	[[ "$(resolved Alpha --extra=Given)" == *"Open-X Given"* ]]
}

@test "a dropped or replaced action never reports the placeholder it had" {
	printf '\n[Needs]\nvar Extra\n:x Open-X {Extra}\n:y Open-Y {Extra}\nFocus-VirtualDesktop 1\n' >>"$cfg/workspace-templates.conf"
	add_workspace Alpha $'template Needs\ndrop x\nreplace y Open-Y fixed'
	[ "$(resolved Alpha)" = "Open-Y fixed|Focus-VirtualDesktop 1" ]
	add_workspace Beta 'template Needs'
	run workspace_lines "$file" Beta
	[ "$status" -ne 0 ]
}

@test "a plain workspace gets {Workspace} and keeps every other brace text" {
	add_workspace Plain 'Open-Browser {Workspace}Group {SelectedProjects} {Anything}'
	[ "$(resolved Plain)" = "Open-Browser PlainGroup {SelectedProjects} {Anything}" ]
}

@test "a local overlay template replaces the base one whole" {
	add_workspace Alpha 'template Base'
	printf '[Base]\nFocus-VirtualDesktop 9\n' >"$cfg/workspace-templates.local.conf"
	[ "$(resolved Alpha)" = "Focus-VirtualDesktop 9" ]
}

@test "@TYPE lines of a template and an instance follow the machine type, :ID after the prefix" {
	printf '\n[Typed]\n@Laptop :lap Focus-VirtualDesktop 3\n@Work Focus-VirtualDesktop 4\n' >>"$cfg/workspace-templates.conf"
	# The replace targets a Laptop-only line, so it is Laptop-only too: on Work the line it names
	# does not exist, and an unprefixed replace would be an error there.
	add_workspace Alpha $'template Typed\n@Laptop replace lap Focus-VirtualDesktop 5'
	[ "$(CONF_MACHINE_TYPE=Laptop resolved Alpha)" = "Focus-VirtualDesktop 5" ]
	[ "$(CONF_MACHINE_TYPE=Work resolved Alpha)" = "Focus-VirtualDesktop 4" ]
}

@test "project scopes: +A runs for A, +!A runs unless A, unscoped always" {
	lines=$'Open-A\n+Api,Web Open-B\n+!api Open-C'
	[ "$(printf '%s\n' "$lines" | workspace_for_projects | paste -sd'|' -)" = "Open-A|Open-C" ]
	[ "$(printf '%s\n' "$lines" | workspace_for_projects API | paste -sd'|' -)" = "Open-A|Open-B" ]
	[ "$(printf '%s\n' "$lines" | workspace_for_projects Other Web | paste -sd'|' -)" = "Open-A|Open-B|Open-C" ]
	[ "$(workspace_scope '+!A,B Open-X')" = '+!A,B' ]
	[ "$(workspace_scope_projects '+!A,B' | paste -sd' ' -)" = 'A B' ]
	[ "$(workspace_action_name '+A Open-X y')" = Open-X ]
}

@test "layout-set scopes: %A,B runs on layout set A or B, before a project scope, unscoped always" {
	lines=$'Open-A\n%Work,laptop Open-B\n%Work +Api Open-C'
	[ "$(printf '%s\n' "$lines" | workspace_for_layout Laptop | paste -sd'|' -)" = "Open-A|Open-B" ]
	[ "$(printf '%s\n' "$lines" | workspace_for_layout Work | workspace_for_projects | paste -sd'|' -)" = "Open-A|Open-B" ]
	[ "$(printf '%s\n' "$lines" | workspace_for_layout work | workspace_for_projects api | paste -sd'|' -)" = "Open-A|Open-B|Open-C" ]
	[ "$(workspace_layout_scope '%Work,Laptop Open-X')" = '%Work,Laptop' ]
	[ -z "$(workspace_layout_scope '+A Open-X')" ]
	[ "$(workspace_action_name '%Work +A Open-X y')" = Open-X ]
}

@test "a replace or drop finds an action behind its layout-set scope" {
	cat >>"$cfg/workspace-templates.conf" <<'CONF'

[Scoped]
%Work Open-Browser --no-menu --instances 2
Focus-VirtualDesktop 1
CONF
	add_workspace UsesScoped $'template Scoped\ndrop Open-Browser'
	[ "$(resolved UsesScoped)" = "Focus-VirtualDesktop 1" ]
}

@test "the fixture's Sample is a template instance" {
	workspace_is_templated "$file" Sample
	! workspace_is_templated "$file" Default || false
	[ "$(resolved Sample)" = "Open-Project Sample|Open-Browser Docs|Set-WorkspaceWindowLayout Sample|Focus-VirtualDesktop 1" ]
}

@test "only commands that just start apps, tabs or containers may run in the background" {
	workspace_may_background Open-Application
	workspace_may_background open-project
	workspace_may_background Start-Containers
	! workspace_may_background Open-Browser || false
	! workspace_may_background Open-ProjectSwagger || false
	! workspace_may_background Set-WorkspaceWindowLayout || false
	! workspace_may_background Focus-VirtualDesktop || false
}
