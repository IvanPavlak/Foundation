#!/usr/bin/env bats
# Open-Workspace (w) against the platform stand-ins: a workspace is named or numbered as in the
# menu, actions run in order, a Return stops the open,
# unknown actions are skipped, the windows the open created are recorded for Close-Workspace, the
# positional arguments bind like the Windows parameters, and --alongside relaunches in a new
# WezTerm window, shifts the desktops past the other workspaces and marks its record. A fixed
# Open-Project keeps its project and flags, a rerun from the workspace's own project tab keeps that
# tab, %SET lines follow the layout set, pre-existing windows the layout placed are adopted unless
# Kill-All keeps the app, and the default workspace, benchmark off and multi-workspace runs behave.

load ../../helpers
load ../../platform

setup() {
	setup_foundation
	platform_stubs
	copy_fixture_config
	cat >>"$FOUNDATION_CONFIG_DIR/workspaces.conf" <<'CONF'

[Launch]
Open-Application Code
Focus-VirtualDesktop 2

[Stops]
Focus-VirtualDesktop 3
Return
Focus-VirtualDesktop 4

[Unknown]
Open-NoSuchAppAnywhere
Focus-VirtualDesktop 5

[Side]
Focus-VirtualDesktop 1

[Closes]
Open-Application Code
Terminate-WindowsTerminalTabs --only-current

[Fails]
Focus-VirtualDesktop 0
Focus-VirtualDesktop 6
CONF
	stub_window 100 com.github.wez.wezterm 1 WezTerm "[1/1] zsh"
	cmd=$UNIX_DIR/modules/Workflow/bin/Open-Workspace
}

@test "actions run in order and the windows the open created are recorded" {
	run "${BASH:-bash}" "$cmd" Launch
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.microsoft\.VSCode'
	stub_called '^aerospace workspace -- 2'
	record=$FOUNDATION_STATE_DIR/open-workspaces
	grep -qE $'^Launch\twindow\t900\t' "$record"
	# The terminal that was open before is not the workspace's to close.
	! grep -qE $'\twindow\t100\t' "$record" || false
}

@test "a Return action stops the open where it stands" {
	run "${BASH:-bash}" "$cmd" Stops
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 3'
	! stub_called '^aerospace workspace -- 4' || false
}

@test "a number names that entry of the workspace menu, as -Workspace 2 does on Windows" {
	foundation_load config
	n=$(conf_sections "$(conf_path workspaces.conf)" | grep -nx Stops | cut -d: -f1)
	run "${BASH:-bash}" "$cmd" "$n"
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 3'
	! stub_called '^aerospace workspace -- 4' || false
}

@test "an unknown action is reported and skipped, the rest still runs" {
	run "${BASH:-bash}" "$cmd" Unknown
	[ "$status" -eq 0 ]
	[[ $output == *"Open-NoSuchAppAnywhere"* ]]
	stub_called '^aerospace workspace -- 5'
}

@test "first word is the workspace, further words are projects (w MyWorkspace MyProject)" {
	run "${BASH:-bash}" "$cmd" NoSuchWorkspace,Another api,web -v
	[[ $output == *"workspaces [NoSuchWorkspace Another] projects [api web]"* ]]
}

@test "every open appends a benchmark row" {
	run "${BASH:-bash}" "$cmd" Launch
	# A plain open without a layout: Mode Plain, no layout attempt.
	[ "$(tail -n 1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f2,12,15,16)" = "Launch,NoLayout,Plain,0" ]
}

@test "apps started by an open do not inherit Foundation's environment" {
	# The open stand-in records the FOUNDATION_ variables it was started with.
	printf '#!/bin/sh\necho "open $*" >>"$STUB_LOG"\nenv | grep "^FOUNDATION_" >>"$BATS_TEST_TMPDIR/launched-env"\nexit 0\n' >"$STUB_BIN/open"
	run "${BASH:-bash}" "$cmd" Launch
	stub_called '^open -b com\.microsoft\.VSCode'
	[ ! -s "$BATS_TEST_TMPDIR/launched-env" ]
}

# Template instances of the fixture's [Project] template (Open-Project {Workspace}, Open-Browser
# {Repository}, Set-WorkspaceWindowLayout {Workspace}, Focus-VirtualDesktop 1). The browser and the
# project are swapped for desktop focuses so only the stand-ins answer.
templated() {
	cat >>"$FOUNDATION_CONFIG_DIR/workspaces.conf" <<'CONF'

[Templated]
template Project
drop Open-Browser
replace project Focus-VirtualDesktop 6
add +SampleApi Focus-VirtualDesktop 7
add +!SampleApi Focus-VirtualDesktop 8

[Vars]
template Project
drop Open-Browser
drop project
set LayoutType Work
add Focus-VirtualDesktop 3

[Broken]
template NoSuchTemplate

[Menu]
Open-Project
+SampleApi Focus-VirtualDesktop 7
+!SampleApi Focus-VirtualDesktop 8

[Fixed]
Open-Project SampleApi
Set-WorkspaceWindowLayout Fixed
CONF
}

@test "a template instance runs the expanded actions, and with no project only +! lines are scoped in" {
	templated
	run "${BASH:-bash}" "$cmd" Templated -v
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 6'
	stub_called '^aerospace workspace -- 8'
	! stub_called '^aerospace workspace -- 7' || false
	[[ $output == *"=> Set-WorkspaceWindowLayout Templated"* ]]
}

@test "the open's projects pick the scoped lines and reach the layout" {
	templated
	run "${BASH:-bash}" "$cmd" Templated SampleApi -v
	stub_called '^aerospace workspace -- 7'
	! stub_called '^aerospace workspace -- 8' || false
	[[ $output == *"=> Set-WorkspaceWindowLayout Templated --project SampleApi"* ]]
}

@test "a flag naming a template variable sets it and is not forwarded" {
	templated
	run "${BASH:-bash}" "$cmd" Vars --layout-type Laptop -v
	[[ $output == *"variable --layout-type = [Laptop]"* ]]
	[[ $output == *"=> Set-WorkspaceWindowLayout Vars"* ]]
	[[ $output != *"--layout-type Laptop"* ]]
	stub_called '^aerospace workspace -- 3'
}

@test "a broken template opens nothing and records nothing" {
	templated
	run "${BASH:-bash}" "$cmd" Broken
	[[ $output == *"unknown template [NoSuchTemplate]"* ]]
	[[ $output == *"Workspace [Broken] not opened"* ]]
	! stub_called '^aerospace workspace -- ' || false
	! grep -qs '^Broken' "$FOUNDATION_STATE_DIR/open-workspaces" || false
}

@test "a bare Open-Project asks for the project up front and hands the pick on" {
	templated
	printf 'SampleApi\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" Menu -v
	[[ $output == *"[Available projects]"* ]]
	[[ $output == *"=> Open-Project SampleApi"* ]]
	stub_called '^aerospace workspace -- 7'
	! stub_called '^aerospace workspace -- 8' || false
}

@test "an empty pick skips the bare Open-Project instead of asking again" {
	templated
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" Menu -v
	[[ $output == *"No project selected!"* ]]
	[[ $output != *"=> Open-Project"* ]]
	stub_called '^aerospace workspace -- 8'
}

@test "the projects a fixed Open-Project names are the open's projects" {
	templated
	run "${BASH:-bash}" "$cmd" Fixed -v
	[[ $output == *"=> Set-WorkspaceWindowLayout Fixed --project SampleApi"* ]]
	[[ $output != *"[Available projects]"* ]]
}

# Another workspace in the record: Code window 300 on desktop 4, opened alongside or not.
other_workspace() {
	stub_window 300 com.microsoft.VSCode 4 Code "Other"
	printf 'Other\twindow\t300\tCode\tcom.microsoft.VSCode\tOther\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	[ "${1:-}" = alongside ] && printf 'Other\tmeta\talongside\n' >>"$FOUNDATION_STATE_DIR/open-workspaces"
	return 0
}

@test "an alongside open (in its own shell) starts after the other workspaces' desktops and is marked" {
	other_workspace
	FOUNDATION_ALONGSIDE_SHELL=1 run "${BASH:-bash}" "$cmd" Side --alongside
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 5'
	record=$FOUNDATION_STATE_DIR/open-workspaces
	grep -qxF $'Side\tmeta\talongside' "$record"
	grep -qF $'Other\twindow\t300\t' "$record"
	# Its benchmark row is marked Alongside, so its medians stay apart from the plain opens'.
	[ "$(tail -n 1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f2,15)" = "Side,Alongside" ]
}

@test "a plain open next to an alongside workspace keeps its desktops and its record" {
	other_workspace alongside
	run "${BASH:-bash}" "$cmd" Side
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 1'
	record=$FOUNDATION_STATE_DIR/open-workspaces
	! grep -qF $'Side\tmeta' "$record" || false
	grep -qxF $'Other\tmeta\talongside' "$record"
}

@test "--alongside relaunches the open in a new WezTerm window that it owns" {
	cat >"$STUB_BIN/wezterm" <<'SH'
#!/bin/sh
echo "wezterm $*" >>"$STUB_LOG"
case "$*" in
	*" list "* | *" list") cat "$STUB_PANES" ;;
	*spawn*)
		echo "800|com.github.wez.wezterm|99999999|1|WezTerm|zsh" >>"$STUB_WINDOWS"
		echo 701
		;;
esac
exit 0
SH
	run "${BASH:-bash}" "$cmd" Side --alongside
	[ "$status" -eq 0 ]
	stub_called 'send-text --pane-id 701 --no-paste  FOUNDATION_ALONGSIDE_SHELL=1 FOUNDATION_ALONGSIDE_PANE=701 FOUNDATION_ALONGSIDE_TERMINAL=800 FOUNDATION_OPEN_START_MS=[0-9]+ .*Open-Workspace Side --alongside'
	! stub_called '^aerospace workspace' || false
	[ ! -s "$FOUNDATION_STATE_DIR/open-workspaces" ]
}

@test "--alongside of a workspace with no section warns here and opens no window" {
	run "${BASH:-bash}" "$cmd" NoSuchWorkspace --alongside
	[ "$status" -eq 1 ]
	[[ $output == *"No actions configured for workspace [NoSuchWorkspace]"* ]]
	[[ $output != *"Workspace(s) opened in"* ]]
	! stub_called 'spawn' || false
	! stub_called 'send-text' || false
}

@test "the relaunched alongside open drops an unknown workspace silently, the first shell already reported it" {
	FOUNDATION_ALONGSIDE_SHELL=1 run "${BASH:-bash}" "$cmd" NoSuchWorkspace,Side --alongside
	[ "$status" -eq 0 ]
	[[ $output != *"No actions configured"* ]]
	stub_called '^aerospace workspace -- 1'
}

@test "--alongside without a running WezTerm opens in this shell" {
	printf '#!/bin/sh\necho "wezterm $*" >>"$STUB_LOG"\nexit 1\n' >"$STUB_BIN/wezterm"
	other_workspace
	run "${BASH:-bash}" "$cmd" Side --alongside
	[ "$status" -eq 0 ]
	[[ $output == *"WezTerm is not running"* ]]
	stub_called '^aerospace workspace -- 5'
}

@test "an action that closes this tab comes after the record and the summary" {
	run "${BASH:-bash}" "$cmd" Closes
	[ "$status" -eq 0 ]
	grep -qE $'^Closes\twindow\t900\t' "$FOUNDATION_STATE_DIR/open-workspaces"
	[ "$(grep -c 'Workspace(s) opened in' <<<"$output")" -eq 1 ]
	summary=$(grep -n 'Workspace(s) opened in' <<<"$output" | cut -d: -f1)
	terminate=$(grep -n 'Terminate-WindowsTerminalTabs\|Not running inside WezTerm\|Closing the current' <<<"$output" | head -1 | cut -d: -f1)
	[ -z "$terminate" ] || [ "$summary" -lt "$terminate" ]
}

@test "a failed action is reported, the rest still runs, and the closing line names it instead of the success line" {
	run "${BASH:-bash}" "$cmd" Fails
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 6'
	[[ $output == *"Action [Focus-VirtualDesktop] reported a failure"* ]]
	[[ $output == *"but Focus-VirtualDesktop failed - see above!"* ]]
	[[ $output != *"seconds!"* ]]
}

@test "an alongside open of a workspace already open is a second instance, its windows protected" {
	stub_window 300 com.microsoft.VSCode 4 Code "Side"
	printf 'Side\twindow\t300\tCode\tcom.microsoft.VSCode\tSide\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	FOUNDATION_ALONGSIDE_SHELL=1 run "${BASH:-bash}" "$cmd" Side --alongside
	[ "$status" -eq 0 ]
	# Desktops start after the first instance's desktop 4: its window counts as another's.
	stub_called '^aerospace workspace -- 5'
	record=$FOUNDATION_STATE_DIR/open-workspaces
	grep -qxF $'Side\twindow\t300\tCode\tcom.microsoft.VSCode\tSide' "$record"
	grep -qxF $'Side#2\tmeta\talongside' "$record"
}

@test "a plain open replaces every instance of its workspace" {
	printf 'Side\twindow\t300\tCode\tcom.microsoft.VSCode\tSide\nSide#2\tmeta\talongside\nOther\tpane\t7\tT\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	run "${BASH:-bash}" "$cmd" Side
	[ "$status" -eq 0 ]
	record=$FOUNDATION_STATE_DIR/open-workspaces
	! grep -q '^Side#2' "$record" || false
	! grep -qF $'Side\twindow\t300\t' "$record" || false
	grep -qxF $'Other\tpane\t7\tT' "$record"
}

@test "the relaunched alongside open counts from the start the original invocation handed over" {
	start=$(($(foundation_now_ms) - 5000))
	FOUNDATION_ALONGSIDE_SHELL=1 FOUNDATION_OPEN_START_MS=$start run "${BASH:-bash}" "$cmd" Side --alongside
	[ "$status" -eq 0 ]
	[[ $output == *"Workspace(s) opened in "[5-9].* ]]
}

@test "command-line projects fill only a bare Open-Project: a fixed one keeps its project and flags" {
	# Projects without action lines, so Open-Project starts nothing.
	printf '\n[Bare]\npath ROOT $DOTFILES_ROOT\n' >>"$FOUNDATION_CONFIG_DIR/projects.conf"
	printf '\n[Runs]\nOpen-Project SampleApi --run-app\nOpen-Project --new-window\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run "${BASH:-bash}" "$cmd" Runs Bare -v
	[[ $output == *"=> Open-Project SampleApi --run-app"* ]]
	[[ $output == *"=> Open-Project --new-window Bare"* ]]
	[[ $output != *"=> Open-Project Bare"* ]]
}

# This shell runs in WezTerm pane 5 (its tty is ours), in a tab titled TITLE. Usage: in_tab TITLE
in_tab() {
	printf '[{"window_id":1,"tab_id":2,"pane_id":5,"is_active":true,"tab_title":"%s","title":"zsh","cwd":"file:///x","tty_name":"/dev/ttys005"}]\n' "$1" >"$STUB_PANES"
	export WEZTERM_PANE=5 STUB_TTY=ttys005
	printf '\n[Rerun]\nOpen-Project\nTerminate-WindowsTerminalTabs --only-current\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
}

@test "a rerun from the workspace's own project tab keeps that tab" {
	in_tab SampleApi.ROOT
	run "${BASH:-bash}" "$cmd" Rerun SampleApi -v
	[ "$status" -eq 0 ]
	[[ $output == *"own project tab [SampleApi.ROOT]"* ]]
	! stub_called 'kill-pane' || false
	# The open still ends recorded: it creates nothing to own, so its benchmark row shows it.
	[ "$(tail -n 1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f2)" = Rerun ]
}

@test "a rerun from another tab still closes it" {
	in_tab Other.ROOT
	run "${BASH:-bash}" "$cmd" Rerun SampleApi
	[ "$status" -eq 0 ]
	stub_called 'kill-pane --pane-id 5'
}

@test "a %SET line runs only on the layout set this machine applies, not its machine type" {
	printf '\n[Scoped]\n%%Laptop Focus-VirtualDesktop 2\n%%Work,Test Focus-VirtualDesktop 3\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run "${BASH:-bash}" "$cmd" Scoped
	stub_called '^aerospace workspace -- 2'
	! stub_called '^aerospace workspace -- 3' || false
	printf 'layout-override Laptop Work\n' >>"$FOUNDATION_CONFIG_DIR/machines.conf"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" Scoped
	stub_called '^aerospace workspace -- 3'
	! stub_called '^aerospace workspace -- 2' || false
}

# A layout that places Code, and a Code window that was open before the open.
adopt() {
	for set in Work Laptop; do
		printf '[Adopt]\nlayout 1 Zero\n1 Fullscreen Code\n' >"$FOUNDATION_CONFIG_DIR/layouts/$set/Adopt_$set.conf"
	done
	printf '\n[Adopt]\nSet-WorkspaceWindowLayout Adopt\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	stub_window 300 com.microsoft.VSCode 4 Code "Dotfiles"
	export FOUNDATION_STABLE_MS=0
}

@test "a window open before the open that its layout placed is adopted into the record" {
	adopt
	run "${BASH:-bash}" "$cmd" Adopt --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1'
	grep -qE $'^Adopt\twindow\t300\t' "$FOUNDATION_STATE_DIR/open-workspaces"
}

@test "a placed window of an app Kill-All keeps is not adopted" {
	adopt
	printf 'keep Code\n' >>"$FOUNDATION_CONFIG_DIR/kill-all.conf"
	run "${BASH:-bash}" "$cmd" Adopt --timeout-seconds 3
	[ "$status" -eq 0 ]
	stub_called '^aerospace move-node-to-workspace --window-id 300 -- 1'
	! grep -qE $'\twindow\t300\t' "$FOUNDATION_STATE_DIR/open-workspaces" || false
}

# workspaces.conf with its default-workspace line swapped for LINE (none when empty).
default_line() {
	awk -v line="$1" '/^default-workspace/ { if (line != "") print line; next } { print }' "$FOUNDATION_CONFIG_DIR/workspaces.conf" >"$BATS_TEST_TMPDIR/ws.conf"
	mv "$BATS_TEST_TMPDIR/ws.conf" "$FOUNDATION_CONFIG_DIR/workspaces.conf"
}

@test "an empty Enter at the menu opens the default workspace" {
	default_line 'default-workspace Side'
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	stub_called '^aerospace workspace -- 1'
	[ "$(tail -n 1 "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" | cut -d, -f2)" = Side ]
}

@test "an empty Enter without a default workspace opens nothing" {
	default_line ''
	printf '\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"No workspace selected"* ]]
	! stub_called '^aerospace workspace' || false
}

@test "benchmark off writes no benchmark row" {
	awk '/^benchmark[[:space:]]/ { print "benchmark off"; next } { print }' "$FOUNDATION_CONFIG_DIR/workspaces.conf" >"$BATS_TEST_TMPDIR/ws.conf"
	mv "$BATS_TEST_TMPDIR/ws.conf" "$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run "${BASH:-bash}" "$cmd" Launch
	[ "$status" -eq 0 ]
	[ ! -s "$FOUNDATION_STATE_DIR/WorkspaceBenchmark.csv" ]
}

@test "a Return in an earlier workspace stops the later ones; an unknown one does not" {
	run "${BASH:-bash}" "$cmd" Stops,Side
	stub_called '^aerospace workspace -- 3'
	! stub_called '^aerospace workspace -- 1' || false
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$cmd" NoSuchWorkspace,Side
	[[ $output == *"No actions configured for workspace [NoSuchWorkspace]"* ]]
	stub_called '^aerospace workspace -- 1'
}

@test "an Open-<App> line of an apps.conf app launches it through Open-Application" {
	printf '\n[Generic]\nOpen-Code\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run "${BASH:-bash}" "$cmd" Generic
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.microsoft\.VSCode'
}

@test "a trailing & runs an action in the background, waited for before the next window action" {
	printf '\n[Background]\nOpen-Application Code &\nFocus-VirtualDesktop 2\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run "${BASH:-bash}" "$cmd" Background -v
	[ "$status" -eq 0 ]
	[[ $output == *"=> Open-Application Code (background)"* ]]
	stub_called '^open -b com\.microsoft\.VSCode'
	# Its output comes before the action that waited for it.
	opened=$(grep -n 'Opening Code' <<<"$output" | head -1 | cut -d: -f1)
	focused=$(grep -n 'Focusing Virtual Desktop 2' <<<"$output" | head -1 | cut -d: -f1)
	[ -n "$opened" ] && [ -n "$focused" ] && [ "$opened" -lt "$focused" ]
	grep -qE $'^Background\twindow\t900\t' "$FOUNDATION_STATE_DIR/open-workspaces"
	[[ $output == *"seconds!"* ]]
}

@test "a background action at the end of a workspace is waited for before the record" {
	printf '\n[BackgroundLast]\nOpen-Code &\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run "${BASH:-bash}" "$cmd" BackgroundLast
	[ "$status" -eq 0 ]
	stub_called '^open -b com\.microsoft\.VSCode'
	grep -qE $'^BackgroundLast\twindow\t900\t' "$FOUNDATION_STATE_DIR/open-workspaces"
}

@test "a failed background action is reported like one run in place" {
	printf '\n[BackgroundFails]\nOpen-Application NoSuchAppAnywhere &\nFocus-VirtualDesktop 2\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run "${BASH:-bash}" "$cmd" BackgroundFails
	[ "$status" -eq 0 ]
	[[ $output == *"apps.conf has no entry for [NoSuchAppAnywhere]"* ]]
	[[ $output == *"Action [Open-Application] reported a failure"* ]]
	[[ $output == *"but Open-Application failed - see above!"* ]]
	stub_called '^aerospace workspace -- 2'
}

@test "a trailing & on a command that may not run in the background runs it in place" {
	printf '\n[NotBackground]\nFocus-VirtualDesktop 2 &\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	run "${BASH:-bash}" "$cmd" NotBackground -v
	[ "$status" -eq 0 ]
	[[ $output == *"Action [Focus-VirtualDesktop] cannot run in the background - running it in place"* ]]
	[[ $output != *"(background)"* ]]
	stub_called '^aerospace workspace -- 2'
}

@test "a bare Open-Project in the background still asks up front and runs with the pick" {
	printf '\n[MenuBackground]\nOpen-Project &\n+SampleApi Focus-VirtualDesktop 7\n+!SampleApi Focus-VirtualDesktop 8\n' >>"$FOUNDATION_CONFIG_DIR/workspaces.conf"
	printf 'SampleApi\n' >"$BATS_TEST_TMPDIR/answers"
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/answers run "${BASH:-bash}" "$cmd" MenuBackground -v
	[[ $output == *"[Available projects]"* ]]
	[[ $output == *"=> Open-Project SampleApi (background)"* ]]
	stub_called '^aerospace workspace -- 7'
	! stub_called '^aerospace workspace -- 8' || false
}
