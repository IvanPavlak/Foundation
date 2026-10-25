# shellcheck shell=bash
# Obsidian on its official command line interface (the `obsidian` CLI of Obsidian 1.12.4+,
# /opt/homebrew/bin/obsidian -> Obsidian.app/Contents/MacOS/obsidian-cli) - the Get-ObsidianCliPath,
# Get-ObsidianWorkspaceNames, Start-ObsidianDetached, Wait-ObsidianCli and
# Invoke-ObsidianWorkspaceLoad family of Windows. Needs lib/config.sh.

# The vault folder: OBSIDIAN_DIRECTORY, else obsidian.conf `directory` (~ and $VARIABLES expand).
# Prints nothing and fails when neither is set.
obsidian_directory() {
	local file value=${OBSIDIAN_DIRECTORY:-}
	[ -n "$value" ] || { file=$(conf_path obsidian.conf) && value=$(conf_value "$file" directory 2>/dev/null); } || return 1
	[ -n "$value" ] || return 1
	foundation_expand_path "$value"
}

# obsidian.conf value KEY (vault, default-workspace), or DEFAULT.
obsidian_setting() { # KEY DEFAULT
	local file value
	file=$(conf_path obsidian.conf) && value=$(conf_value "$file" "$1" 2>/dev/null) && [ -n "$value" ] && {
		printf '%s' "$value"
		return 0
	}
	printf '%s' "$2"
}

# The repository folder the vault's .obsidian links to (the Obsidian link of SymbolicLinkMaker):
# obsidian.conf `settings`, relative to the repository root or absolute (~ and $VARIABLES expand).
# Prints nothing and fails without a line.
obsidian_settings() {
	local value
	value=$(obsidian_setting settings '')
	[ -n "$value" ] || return 1
	value=$(foundation_expand_path "$value")
	case $value in /*) ;; *) value=$DOTFILES_ROOT/$value ;; esac
	printf '%s' "$value"
}

# The vault name: obsidian.conf `vault`, else the folder name of the vault directory; empty
# when neither is configured.
obsidian_vault() {
	local dir
	dir=$(obsidian_directory) && dir=$(basename "$dir")
	obsidian_setting vault "$dir"
}

# The Obsidian CLI: `obsidian` on PATH, else the one inside the app bundle. FOUNDATION_OBSIDIAN_CLI,
# when set, is the only candidate (the suites' seam: the app's own CLI exists on a Mac with Obsidian).
obsidian_cli() {
	local cli
	if [ -n "${FOUNDATION_OBSIDIAN_CLI:-}" ]; then
		cli=$FOUNDATION_OBSIDIAN_CLI
	else
		cli=$(command -v obsidian 2>/dev/null) || cli=/Applications/Obsidian.app/Contents/MacOS/obsidian-cli
	fi
	[ -x "$cli" ] || return 1
	printf '%s' "$cli"
}

# Saved workspaces (the core Workspaces plugin), one per line, in the order of workspaces.json.
obsidian_workspace_names() {
	local file
	file=$(obsidian_directory)/.obsidian/workspaces.json || return 0
	[ -r "$file" ] || return 0
	python3 -c 'import json,sys
try: print("\n".join(json.load(open(sys.argv[1])).get("workspaces", {}).keys()))
except Exception: pass' "$file" 2>/dev/null
}

obsidian_running() {
	pgrep -xq Obsidian
}

# Start-ObsidianDetached: `open` hands the app to LaunchServices, so closing the terminal never
# closes Obsidian (the WMI launch of Windows). -g keeps focus where it is until the layout runs.
obsidian_start() { # VAULT
	foundation_launch open -g "obsidian://open?vault=$(obsidian_uri_encode "$1")" </dev/null >/dev/null 2>&1 || foundation_launch open -g -b md.obsidian </dev/null >/dev/null 2>&1
}

obsidian_uri_encode() {
	local text=$1 out='' i char
	for ((i = 0; i < ${#text}; i++)); do
		char=${text:i:1}
		case $char in [A-Za-z0-9._~-]) out+=$char ;; *) out+=$(printf '%%%02X' "'$char") ;; esac
	done
	printf '%s' "$out"
}

# Seconds a CLI call may take before it is killed (Invoke-ObsidianCli's 5 s): a CLI that never
# hears back from Obsidian must not stall the caller, or a whole workspace open.
OBSIDIAN_CLI_CALL_SECONDS=5

# Seconds Open-Obsidian waits for the CLI to reach a starting Obsidian: FOUNDATION_OBSIDIAN_CLI_WAIT
# (the suites' seam), else 10.
obsidian_cli_wait() {
	local value=${FOUNDATION_OBSIDIAN_CLI_WAIT:-}
	foundation_whole_number "$value" 1 600 && printf '%s' "$value" || printf '10'
}

# Wait-ObsidianCli: polls `workspaces` until the CLI reaches the running vault (while Obsidian is
# still starting it answers "The CLI is unable to find Obsidian"), at most TIMEOUT seconds; each
# probe is bounded by the time left, so a hung CLI cannot outlast the deadline.
obsidian_wait_cli() { # VAULT TIMEOUT
	local cli deadline left out
	cli=$(obsidian_cli) || return 1
	deadline=$((SECONDS + ${2:-10}))
	while :; do
		left=$((deadline - SECONDS))
		[ "$left" -gt 0 ] || return 1
		[ "$left" -le "$OBSIDIAN_CLI_CALL_SECONDS" ] || left=$OBSIDIAN_CLI_CALL_SECONDS
		out=$(foundation_timeout "$left" "$cli" "vault=$1" workspaces 2>&1 </dev/null)
		[ $? -ne 124 ] || continue
		case $out in *"unable to find Obsidian"*) sleep 0.5 ;; *) return 0 ;; esac
	done
}

# Invoke-ObsidianWorkspaceLoad: 0 when the CLI accepted the load; 1 with the refusal printed on
# stdout (the CLI switched off, an unknown workspace, Obsidian not reachable).
obsidian_load_workspace() { # VAULT NAME
	local cli out
	cli=$(obsidian_cli) || {
		echo "The Obsidian CLI was not found (Obsidian 1.12.4+ ships it)"
		return 1
	}
	out=$(foundation_timeout "$OBSIDIAN_CLI_CALL_SECONDS" "$cli" "vault=$1" workspace:load "name=$2" 2>&1 </dev/null)
	if [ $? -eq 124 ]; then
		echo "The Obsidian CLI did not answer within $OBSIDIAN_CLI_CALL_SECONDS s"
		return 1
	fi
	case $out in
		*"not enabled"*)
			echo "The Obsidian command line interface is off - run Enable-ObsidianCli (or Settings > General > Advanced > Command line interface)"
			return 1
			;;
		*"unable to find Obsidian"*)
			echo "Obsidian did not answer the CLI"
			return 1
			;;
		*[Ee]rror* | *"not found"* | *"No workspace"*)
			printf '%s\n' "$out" | head -n 1
			return 1
			;;
	esac
	return 0
}
