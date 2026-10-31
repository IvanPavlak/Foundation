# shellcheck shell=bash
# Application map (config/apps.conf) and macOS app lifecycle: launch by bundle id, quit the way
# Cmd+Q does. The only place `open -b` and `osascript quit` are spelled.

apps__file() {
	conf_path apps.conf
}

# The lines of apps.conf (conf_lines) and the app list built from them (apps_list), read once per
# process instead of at every lookup: app_matches runs for every window and layout entry on each
# poll of a layout wait, and one conf_lines costs several processes. Read again when
# conf_cache_key changes, so a file written during the process is seen. Filled in the calling
# shell: a lookup inside $(...) still answers right but keeps nothing, so a hot loop calls
# apps__load before it. Fails when there is no apps.conf. Usage: apps__load
APPS__CACHE_KEY=''
APPS__CACHE_LINES=''
APPS__CACHE_LIST=''
apps__load() {
	conf_cache_key apps.conf || return 1
	[ "$CONF_CACHE_KEY" = "$APPS__CACHE_KEY" ] && return 0
	APPS__CACHE_LINES=$(conf_lines "$FOUNDATION_CONFIG_DIR/apps.conf")
	APPS__CACHE_LIST=$(printf '%s\n' "$APPS__CACHE_LINES" | awk '
		$1 == "app" {
			binary = ""
			if (NF > 3) { binary = $0; sub(/^[[:space:]]*app[[:space:]]+[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", binary) }
			key = tolower($2)
			if (!(key in entry)) order[++n] = key
			entry[key] = $2 "\t" $3 "\t" binary
		}
		END { for (i = 1; i <= n; i++) print entry[order[i]] }')
	APPS__CACHE_KEY=$CONF_CACHE_KEY
}

# Prints "TOKEN<TAB>BUNDLE<TAB>BINARY" for every app token, once: when several app lines name the
# same token (case-insensitive), the last one gives its bundle id and binary, so an overlay line
# overrides the base line as in conf_value; the token keeps the place of its first line. BINARY
# may contain spaces.
apps_list() {
	apps__load || return 0
	[ -z "$APPS__CACHE_LIST" ] || printf '%s\n' "$APPS__CACHE_LIST"
}

# The app entry NAME resolves to, as "TOKEN<TAB>BUNDLE<TAB>BINARY": the last entry whose token or
# bundle id equals NAME, case-insensitive. Fails when none does.
apps__entry() {
	local name=$1 token bundle binary hit=''
	while IFS=$'\t' read -r token bundle binary; do
		if foundation_ieq "$token" "$name" || foundation_ieq "$bundle" "$name"; then
			hit=$token$'\t'$bundle$'\t'$binary
		fi
	done < <(apps_list)
	[ -n "$hit" ] || return 1
	printf '%s' "$hit"
}

# Resolve a name to its canonical token: a token (case-insensitive), a bundle id, or an app
# name as AeroSpace reports it ("Visual Studio Code" is not a token, so it stays unresolved).
app_token() {
	local entry
	entry=$(apps__entry "$1") || return 1
	printf '%s' "${entry%%$'\t'*}"
}

app_bundle() {
	local entry rest
	entry=$(apps__entry "$1") || return 1
	rest=${entry#*$'\t'}
	printf '%s' "${rest%%$'\t'*}"
}

app_binary() {
	local entry binary
	entry=$(apps__entry "$1") || return 1
	binary=${entry#*$'\t'*$'\t'}
	[ -n "$binary" ] || return 1
	printf '%s' "$binary"
}

# The last `KIND NAME ...` line of apps.conf (role, browser) whose NAME equals NAME,
# case-insensitive: a later line (the .local overlay) overrides an earlier one, as in conf_value.
# Fails when no line matches. Usage: apps__last_line KIND NAME
apps__last_line() {
	apps__find_last "$1" "$2" || return 1
	printf '%s' "$APPS__HIT"
}

# apps__last_line without a process: sets APPS__HIT, so a caller in a loop stays in its own shell
# (and keeps the cache apps__load fills). Usage: apps__find_last KIND NAME
apps__find_last() {
	local kind=$1 name=$2 line first second found=1
	APPS__HIT=''
	apps__load || return 1
	while IFS= read -r line; do
		read -r first second _ <<<"$line"
		if [ "$first" = "$kind" ] && foundation_ieq "$second" "$name"; then
			APPS__HIT=$line
			found=0
		fi
	done <<<"$APPS__CACHE_LINES"
	return $found
}

# Members of a role ("Terminal" -> WezTerm), one per line, from its last role line; fails when
# NAME is no role.
app_role_members() {
	local line
	line=$(apps__last_line role "$1") || return 1
	set -- $line
	shift 2
	printf '%s\n' "$@"
}

# Browser launch arguments of its last browser line: prints "NEW-WINDOW-ARG PRIVATE-ARG".
app_browser_args() {
	local line
	if line=$(apps__last_line browser "$1"); then
		set -- $line
		printf '%s %s' "${3:---new-window}" "${4:-}"
		return 0
	fi
	printf -- '--new-window '
}

# How a browser is started: "open" (LaunchServices), "script" (the browser scripting driver, for
# a browser without new-window arguments: Safari) or "exec" (its binary, the default), from the
# launch= field of its last browser line.
app_browser_launch_mode() {
	local line field
	if line=$(apps__last_line browser "$1"); then
		for field in $line; do
			case $field in
				launch=open | launch=script)
					printf '%s' "${field#launch=}"
					return 0
					;;
			esac
		done
	fi
	printf 'exec'
}

# The .app bundle a binary lives in (/Applications/X.app/Contents/MacOS/x -> /Applications/X.app).
app_bundle_path() {
	local path=$1
	case $path in
		*.app/*) printf '%s' "${path%%.app/*}.app" ;;
		*) return 1 ;;
	esac
}

# The installed .app of a bundle id, as Spotlight knows it; fails when none is installed.
app_installed() {
	local found
	found=$(mdfind "kMDItemCFBundleIdentifier == '$1'" 2>/dev/null | grep -m 1 '\.app$') || return 1
	printf '%s' "$found"
}

app_default_browser() {
	local file
	file=$(apps__file) || {
		printf 'Firefox'
		return 0
	}
	conf_value "$file" default-browser || printf 'Firefox'
}

# Does window token TOKEN satisfy app pattern PATTERN (a token, a role, or a Windows-style
# process pattern)?
app_matches() {
	local pattern=$1 token=$2 member members
	[ -n "$pattern" ] || return 0
	# The role's members, as app_role_members prints them, read in this shell: no process per call.
	if apps__find_last role "$pattern"; then
		set -- $APPS__HIT
		shift 2
		members=("$@")
		[ ${#members[@]} -gt 0 ] || members=('')
		for member in "${members[@]}"; do
			foundation_ieq "$member" "$token" && return 0
		done
		return 1
	fi
	foundation_match_process "$pattern" "$token"
}

# ---------------------------------------------------------------------------------------------
# Lifecycle (macOS)
# ---------------------------------------------------------------------------------------------

# Launch (or bring forward) an app by token or bundle id. Extra arguments go to the app.
app_launch() {
	local name=$1 bundle
	shift
	bundle=$(app_bundle "$name") || bundle=$name
	if [ $# -gt 0 ]; then
		foundation_launch open -b "$bundle" --args "$@" </dev/null >/dev/null 2>&1
	else
		foundation_launch open -b "$bundle" </dev/null >/dev/null 2>&1
	fi
}

# Prepares app_browser_launch for the browser of apps.conf TOKEN (Open-Browser, Open-SecureBrowser),
# from its browser line; launch=script needs drivers/browserscript.sh loaded. Sets
# BROWSER_LAUNCH_MODE (exec, open or script, app_browser_launch_mode), BROWSER_BINARY,
# BROWSER_BUNDLE_PATH, BROWSER_NEW_WINDOW_ARG and BROWSER_PRIVATE_ARG (empty for script, and the
# private one empty when none is configured). Fails, logged, when the browser cannot be launched:
# launch=script on a browser without a tab dictionary, no binary, or a binary that is missing.
# Usage: app_browser_prepare TOKEN
app_browser_prepare() {
	BROWSER_TOKEN=$1
	BROWSER_LAUNCH_MODE=$(app_browser_launch_mode "$1")
	BROWSER_BINARY=''
	BROWSER_BUNDLE_PATH=''
	BROWSER_NEW_WINDOW_ARG=''
	BROWSER_PRIVATE_ARG=''
	if [ "$BROWSER_LAUNCH_MODE" = script ]; then
		bs_scriptable "$1" && return 0
		log_error "[$1] has launch=script in apps.conf but no tab dictionary - only Safari and the Chromium browsers can be scripted"
		return 1
	fi
	BROWSER_BINARY=$(app_binary "$1") || {
		log_error "apps.conf gives no binary for [$1] - cannot launch it with URLs"
		return 1
	}
	[ -x "$BROWSER_BINARY" ] || {
		log_error "Browser binary not found => [$BROWSER_BINARY]"
		return 1
	}
	# shellcheck disable=SC2034 # the window arguments are read by the commands that source this file
	read -r BROWSER_NEW_WINDOW_ARG BROWSER_PRIVATE_ARG <<<"$(app_browser_args "$1")"
	BROWSER_BUNDLE_PATH=$(app_bundle_path "$BROWSER_BINARY") || BROWSER_BUNDLE_PATH=''
}

# Starts the browser app_browser_prepare prepared with ARGS (a window argument, then URLs): script
# opens a window of the URLs through the scripting driver (empty arguments dropped), open starts it
# through LaunchServices, exec runs its binary in the background. Usage: app_browser_launch [ARG...]
app_browser_launch() {
	# The browser's stderr (GPU/XPC noise, read by nobody): in the run directory of a workspace open,
	# which goes when the open ends, else discarded. A fixed file in TMPDIR was shared by concurrent
	# opens and never removed.
	local errors=/dev/null
	[ -n "${FOUNDATION_RUN_DIR:-}" ] && [ -d "$FOUNDATION_RUN_DIR" ] && errors=$FOUNDATION_RUN_DIR/browser-launch.err
	if [ "$BROWSER_LAUNCH_MODE" = script ]; then
		local urls=() argument
		for argument in "$@"; do [ -n "$argument" ] && urls+=("$argument"); done
		bs_open "$BROWSER_TOKEN" ${urls[@]+"${urls[@]}"}
		return
	fi
	if [ "$BROWSER_LAUNCH_MODE" = "open" ] && [ -n "$BROWSER_BUNDLE_PATH" ]; then
		# LaunchServices: the browser runs as itself, not as a child of this terminal, so macOS
		# lets it at its own profile folder. -n starts a fresh process that hands the arguments
		# to a running instance, so every call still gets its own window.
		foundation_launch open -na "$BROWSER_BUNDLE_PATH" --args "$@" </dev/null >/dev/null 2>"$errors"
		return
	fi
	# Browsers write GPU/XPC noise to both streams; keep the console clean.
	foundation_launch nohup "$BROWSER_BINARY" "$@" </dev/null >/dev/null 2>"$errors" &
}

# PIDs of a running app, by bundle id (LaunchServices, no window manager needed).
app_pids() {
	# Output looks like `pid = 55687 !cgsConnection ...` (older releases print `"pid"=55687`).
	lsappinfo info -only pid -app "$1" 2>/dev/null | sed -n 's/.*"\{0,1\}pid"\{0,1\} \{0,1\}= \{0,1\}\([0-9][0-9]*\).*/\1/p'
}

# The window titles of a running app, by bundle id, one per line, from the Accessibility API
# (System Events) - the window list for when AeroSpace does not answer. Prints nothing when the app
# is not running or the Accessibility permission is missing. Usage: app_window_titles BUNDLE
app_window_titles() {
	osascript -l JavaScript - titles "$1" 2>/dev/null <<'JS'
function run(argv) {
	var procs = Application("System Events").processes.whose({ bundleIdentifier: argv[1] });
	if (procs.length === 0) return "";
	return procs[0].windows.name().filter(function (t) { return t; }).join("\n");
}
JS
}

# Stop-Application: ask the app to quit (Cmd+Q semantics), then kill it after TIMEOUT seconds
# when --force is given. Usage: app_quit NAME [--force] [TIMEOUT]
app_quit() {
	local name=$1 force=${2:-} timeout=${3:-5} bundle pids pid waited=0
	bundle=$(app_bundle "$name") || bundle=$name
	pids=$(app_pids "$bundle")
	if [ -z "$pids" ]; then
		log_debug "[app_quit] $name is not running"
		return 0
	fi
	osascript -e "quit app id \"$bundle\"" </dev/null >/dev/null 2>&1
	log_debug "[app_quit] asked $name ($bundle) to quit"
	[ "$force" = "--force" ] || return 0
	while [ "$waited" -lt $((timeout * 5)) ]; do
		local alive=0
		for pid in $pids; do
			kill -0 "$pid" 2>/dev/null && alive=1
		done
		[ "$alive" -eq 0 ] && return 0
		sleep 0.2
		waited=$((waited + 1))
	done
	for pid in $pids; do
		kill -9 "$pid" 2>/dev/null
	done
	log_debug "[app_quit] $name ignored the quit request - killed"
	return 0
}

# Waits up to SECONDS for the apps of BUNDLE... to exit after a quit request, polling
# LaunchServices every 0.2 s, and prints the bundles still running, one per line (nothing when
# every one is gone). Never kills: the caller decides what a survivor means.
# Usage: app_wait_quit SECONDS BUNDLE...
app_wait_quit() {
	local seconds=$1 polls=0 bundle left
	shift
	while :; do
		left=()
		for bundle in "$@"; do
			[ -n "$(app_pids "$bundle")" ] && left+=("$bundle")
		done
		[ ${#left[@]} -gt 0 ] || return 0
		[ "$polls" -lt $((seconds * 5)) ] || break
		sleep 0.2
		polls=$((polls + 1))
	done
	printf '%s\n' "${left[@]}"
}
