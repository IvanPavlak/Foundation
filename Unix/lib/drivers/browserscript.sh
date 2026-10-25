# shellcheck shell=bash
# Browser scripting driver - the ONLY file that scripts a browser (Apple events, through JXA).
# Safari and the Chromium family (Chrome, Brave, Edge, Chromium share Chrome's dictionary) list
# their windows' tabs with URL and title, close tabs and, for Safari, open a window of URLs; it is
# what the Windows half does with Ctrl+Tab / Ctrl+W and window titles (Close-BrowserTabsByPattern,
# Test-BrowserGroupAlreadyOpen). Firefox and Tor Browser have no tab dictionary and stay with the
# window titles AeroSpace lists. Needs lib/apps.sh.
#
# A browser that is not running is never started by a read or a close: they print nothing. The
# first call per browser makes macOS ask whether the terminal may control it (Privacy & Security >
# Automation); while that is refused every call fails with status 3 after one warning, and the
# callers fall back to whole windows.

# Bundle ids with a tab dictionary.
BS_SCRIPTABLE="com.apple.Safari com.google.Chrome com.brave.Browser com.microsoft.edgemac org.chromium.Chromium"

# Is the browser of apps.conf TOKEN scriptable? Usage: bs_scriptable TOKEN
bs_scriptable() {
	local bundle
	bundle=$(app_bundle "$1") || return 1
	case " $BS_SCRIPTABLE " in *" $bundle "*) return 0 ;; esac
	return 1
}

# Runs the JXA below for MODE on the browser of TOKEN. Status 3 (with one warning per browser
# and process) when Automation is refused, 1 on another failure.
bs__run() { # MODE TOKEN [ARGS...]
	local mode=$1 token=$2 bundle out
	shift 2
	bundle=$(app_bundle "$token") || return 1
	out=$(
		osascript -l JavaScript - "$mode" "$bundle" "$@" <<'JXA' 2>&1
function run(argv) {
	var mode = argv[0], id = argv[1], app = Application(id), safari = id === "com.apple.Safari";
	if (mode === "open") {
		var urls = argv.slice(2);
		app.documents.push(app.Document({ url: urls[0] }));
		var front = app.windows[0];
		for (var k = 1; k < urls.length; k++) front.tabs.push(app.Tab({ url: urls[k] }));
		return "";
	}
	if (!app.running()) return "";
	var needles = argv.slice(2).map(function (n) { return n.toLowerCase(); });
	var out = [], closed = 0, windows = app.windows(), i, j, tabs, url, title;
	for (i = windows.length - 1; i >= 0; i--) {
		try { tabs = windows[i].tabs(); } catch (e) { continue; }
		for (j = tabs.length - 1; j >= 0; j--) {
			url = ""; title = "";
			try { url = tabs[j].url() || ""; } catch (e) {}
			try { title = (safari ? tabs[j].name() : tabs[j].title()) || ""; } catch (e) {}
			if (mode === "tabs") {
				out.unshift([i + 1, url, title.replace(/[\t\n]/g, " ")].join("\t"));
			} else {
				var hay = (url + "\n" + title).toLowerCase();
				if (needles.some(function (n) { return n !== "" && hay.indexOf(n) >= 0; })) { tabs[j].close(); closed++; }
			}
		}
	}
	return mode === "tabs" ? out.join("\n") : String(closed);
}
JXA
	) || {
		case $out in
			*-1743* | *"Not authorized to send Apple events"* | *"Not authorised to send Apple events"*)
				case " ${bs__refused:-} " in
					*" $token "*) ;;
					*)
						log_warning "The terminal may not control $token - allow it in System Settings > Privacy & Security > Automation (falling back to whole windows)" >&2
						bs__refused="${bs__refused:-} $token"
						;;
				esac
				return 3
				;;
		esac
		case $out in
			# The first call per browser waits on macOS's Automation prompt; unanswered, it times out.
			*-1712*) log_warning "$token did not answer in time - if macOS asked whether the terminal may control $token, allow it and rerun" >&2 ;;
			*) log_debug "[browserscript] $mode $token failed => $out" >&2 ;;
		esac
		return 1
	}
	[ -n "$out" ] && printf '%s\n' "$out"
	return 0
}

# Every tab of every window of the running browser TOKEN: WINDOW<TAB>URL<TAB>TITLE, windows
# numbered front to back from 1. Usage: bs_tabs TOKEN
bs_tabs() {
	bs__run tabs "$1"
}

# Closes every tab of the running browser TOKEN whose URL or title contains one of the NEEDLEs
# (case-insensitive) and prints how many it closed. Usage: bs_close_tabs TOKEN NEEDLE...
bs_close_tabs() {
	local token=$1 out
	shift
	out=$(bs__run close "$token" "$@") || return
	printf '%s\n' "${out:-0}"
}

# Opens the URLs as a new window of the browser TOKEN (Safari): the first URL as the window's
# document, the rest as its tabs. Usage: bs_open TOKEN URL...
bs_open() {
	local token=$1
	shift
	[ $# -gt 0 ] || set -- "about:blank"
	bs__run open "$token" "$@"
}
