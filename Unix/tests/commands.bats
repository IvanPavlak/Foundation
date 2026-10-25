#!/usr/bin/env bats
# Test-ManifestCompleteness analog: every executable has a man-style header, the modules (the
# engine's and the Custom area's) agree with their manifests and pages, nothing outside the
# drivers calls a platform tool, and the commands that close, move, rename, restart, upgrade or
# write refuse a flag they do not know before they act.

load helpers
load platform

setup() { setup_foundation; }

# The documented commands: the `command` lines of every module manifest, as MODULE-DIR NAME.
commands() {
	local dir
	while IFS= read -r dir; do
		awk -v d="$dir" '$1 == "command" { print d, $2 }' "$dir/module.conf"
	done < <(foundation_module_dirs)
}

# The helper scripts: the `helper` lines of every module manifest, as MODULE-DIR NAME.
helpers() {
	local dir
	while IFS= read -r dir; do
		awk -v d="$dir" '$1 == "helper" { print d, $2 }' "$dir/module.conf"
	done < <(foundation_module_dirs)
}

# Every executable of every module's bin, one per line.
executables() {
	local dir file
	while IFS= read -r dir; do
		for file in "$dir"/bin/*; do [ -f "$file" ] && printf '%s\n' "$file"; done
	done < <(foundation_module_dirs)
}

# The executables and the libraries (not the drivers), into the array FILES.
scripts() {
	local file
	FILES=("$UNIX_DIR"/lib/*.sh)
	while IFS= read -r file; do FILES+=("$file"); done < <(executables)
}

@test "every command prints a usage header" {
	while read -r dir c; do
		run foundation_usage "$dir/bin/$c"
		[[ ${lines[0]} == "$c - "* ]] || {
			echo "bad header: $c => ${lines[0]}"
			return 1
		}
	done < <(commands)
}

@test "every module has a manifest and a page" {
	while IFS= read -r dir; do
		[ -r "$dir/module.conf" ] || {
			echo "no manifest: $dir"
			return 1
		}
		[ -r "$DOTFILES_ROOT/$(foundation_module_page "$(foundation_module_name "$dir")")" ] || {
			echo "no page: $dir"
			return 1
		}
	done < <(foundation_module_dirs)
}

@test "no Custom command shares its name with an engine command" {
	# The engine wins on PATH and in foundation_command_path, so such a Custom command would never run.
	output=$(foundation_commands | cut -f2 | sort | uniq -d)
	[ -z "$output" ] || {
		echo "duplicate: $output"
		return 1
	}
}

@test "modules, manifests and pages agree (List-Functions --list-discrepancies)" {
	run "${BASH:-bash}" "$UNIX_DIR/modules/Helper/bin/List-Functions" --list-discrepancies
	[ "$status" -eq 0 ] || {
		echo "$output"
		return 1
	}
}

@test "no aerospace or wezterm literal outside the drivers" {
	# Invocations only: comments and `foundation_load drivers/...` do not count.
	scripts
	run grep -nE '(^|[^_a-z/.-])(aerospace|wezterm) ' "${FILES[@]}"
	output=$(printf '%s\n' "$output" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep . || true)
	[ -z "$output" ] || {
		echo "$output"
		return 1
	}
}

@test "nothing writes to /dev/tty" {
	# Prompts draw on stderr and read FOUNDATION_TTY: a write to /dev/tty reaches the terminal a suite
	# runs in and breaks the Run-Tests status line.
	scripts
	run grep -nE '>[[:space:]]*/dev/tty' "${FILES[@]}" "$UNIX_DIR"/lib/drivers/*.sh
	output=$(printf '%s\n' "$output" | grep -vE '^[^:]+:[0-9]+:[[:space:]]*#' | grep . || true)
	[ -z "$output" ] || {
		echo "$output"
		return 1
	}
}

@test "every executable parses" {
	scripts
	for f in "${FILES[@]}" "$UNIX_DIR"/lib/drivers/*.sh "$UNIX_DIR"/modules/*/functions.sh "$UNIX_DIR"/modules/Custom/*/functions.sh "$UNIX_DIR"/bootstrap.sh; do
		[ -f "$f" ] || continue
		bash -n "$f" || {
			echo "syntax: $f"
			return 1
		}
	done
}

@test "every executable is tracked as executable (git mode 100755)" {
	# A commit from Windows records a new file as 100644: the suites run each command through bash, so
	# only this catches a command PATH and Bootstrap cannot run.
	git -C "$UNIX_DIR" rev-parse --is-inside-work-tree >/dev/null 2>&1 || skip "not a git checkout"
	while IFS= read -r file; do
		mode=$(git -C "$UNIX_DIR" ls-files -s -- "$file" | cut -d' ' -f1)
		[ -z "$mode" ] || [ "$mode" = 100755 ] || {
			echo "not executable in git ($mode): ${file#"$UNIX_DIR"/}"
			return 1
		}
	done < <(executables)
}

@test "every command and helper has its tests/modules/<Module>/<Command>.bats" {
	# A Custom command's suite is tests/modules/Custom/<Module>/<Command>.bats. The `helper` lines (the
	# undocumented scripts of bin, ports of exported Windows functions) need one as much.
	while read -r dir c; do
		module=$(foundation_module_name "$dir")
		[ -f "$UNIX_DIR/tests/modules/$module/$c.bats" ] || {
			echo "no test file: tests/modules/$module/$c.bats"
			return 1
		}
	done < <(
		commands
		helpers
	)
}

@test "no negated assertion is silently skipped" {
	# bats runs a test under errexit, which ignores a `! cmd` that is not the test's last
	# command: such an assertion can never fail. `! cmd || false` (or `|| return 1`) can.
	run grep -rnE '^[[:space:]]+! ' "$UNIX_DIR/tests" --include='*.bats'
	output=$(printf '%s\n' "$output" | grep -vE '\|\|[[:space:]]*(false|return( 1)?)[[:space:]]*$' | grep . || true)
	[ -z "$output" ] || {
		echo "$output"
		return 1
	}
}

@test "an unknown flag or -WhatIf stops the commands that act, before any tool runs" {
	# Every tool these commands reach is a stand-in, so a command that ignored the flag would only
	# reach stand-ins; each must stop before calling any of them.
	platform_stubs
	stub_config
	for tool in scutil sudo brew mas softwareupdate defaults killall obsidian; do stub_tool "$tool"; done
	for tool in scutil sudo brew mas softwareupdate defaults killall obsidian aerospace wezterm osascript open docker lsappinfo; do
		case $(command -v "$tool") in
			"$BATS_TEST_TMPDIR"/*) ;;
			*)
				echo "stub guard: $tool resolves to $(command -v "$tool")"
				return 1
				;;
		esac
	done
	# No hostname lookup (scutil) for the machine type.
	export FOUNDATION_TOR_APP=$BATS_TEST_TMPDIR/no-tor-browser FOUNDATION_MACHINE_TYPE=Test
	local name flag
	for name in Kill-All Terminate-WindowsTerminalTabs Rename-Machine Restart-Machine Upgrade-All Set-SystemDefaults \
		Move-Windows Reset-Windows Focus-VirtualDesktop Set-WorkspaceWindowLayout Docker-Cleanup Add-BrowserGroup \
		Open-Docker Open-Terminal Open-Obsidian Open-SecureBrowser Close-ProjectTerminals Close-Workspace Close-Project \
		Run-Project Start-Containers Send-WakeOnLan Add-Project Add-Workspace Add-WindowLayout Add-SymbolicLink \
		Open-Browser Open-VSCode Open-Project Visualize-Layouts GitBranchDeleteAndPrune; do
		for flag in --bogus-flag -WhatIf; do
			# Set-SystemDefaults and Close-Workspace document --dry-run, so -WhatIf is their dry run
			# (below).
			case "$name $flag" in "Set-SystemDefaults -WhatIf" | "Close-Workspace -WhatIf") continue ;; esac
			: >"$STUB_LOG"
			rm -f "$BATS_TEST_TMPDIR/tool.log"
			run "${BASH:-bash}" "$(foundation_command_path "$name")" "$flag" </dev/null
			[ "$status" -eq 1 ] || {
				echo "$name $flag => status $status: $output"
				return 1
			}
			[ ! -s "$STUB_LOG" ] && [ ! -e "$BATS_TEST_TMPDIR/tool.log" ] || {
				echo "$name $flag reached a tool:"
				cat "$STUB_LOG" "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null
				return 1
			}
		done
	done
	run "${BASH:-bash}" "$(foundation_command_path Set-SystemDefaults)" -WhatIf
	[ "$status" -eq 0 ]
	[ ! -s "$STUB_LOG" ]
	# Close-Workspace's dry run closes nothing: no quit, no window close, no tab kill.
	printf 'Demo\twindow\t200\tCode\tcom.microsoft.VSCode\tDotfiles\n' >"$FOUNDATION_STATE_DIR/open-workspaces"
	: >"$STUB_LOG"
	run "${BASH:-bash}" "$(foundation_command_path Close-Workspace)" Demo -WhatIf </dev/null
	[ "$status" -eq 0 ]
	! grep -qE 'quit app id|^aerospace close|kill-pane' "$STUB_LOG" || false
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}

@test "every command answers --help with its own header and acts on nothing" {
	# The pass-through wrappers (DotnetRun, GitPull, Open-ClaudeDesktop, ...) included: a leading
	# --help never reaches the tool they wrap. Every tool a command could reach is a stand-in.
	platform_stubs
	stub_config
	for tool in scutil sudo brew mas softwareupdate defaults killall obsidian dotnet npm git code python3 ping pgrep; do stub_tool "$tool"; done
	export FOUNDATION_MACHINE_TYPE=Test
	while read -r dir c; do
		: >"$STUB_LOG"
		rm -f "$BATS_TEST_TMPDIR/tool.log"
		run "${BASH:-bash}" "$dir/bin/$c" --help </dev/null
		[ "$status" -eq 0 ] && [[ ${lines[0]} == "$c - "* ]] || {
			echo "$c --help => status $status: ${lines[0]}"
			return 1
		}
		[ ! -s "$STUB_LOG" ] && [ ! -e "$BATS_TEST_TMPDIR/tool.log" ] || {
			echo "$c --help reached a tool:"
			cat "$STUB_LOG" "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null
			return 1
		}
	done < <(commands)
}
