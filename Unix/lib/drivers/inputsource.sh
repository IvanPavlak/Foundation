# shellcheck shell=bash
# Input-source driver - the keyboard layouts of macOS (the InputMethodTips of Windows'
# Get-WinUserLanguageList). The ONLY file that runs drivers/inputsource.swift, through the swift
# interpreter of the Command Line Tools. FOUNDATION_INPUTSOURCE_HELPER replaces the helper with any
# executable taking the same arguments (the suites' stand-in).

# Runs the helper with ARGS. Fails when there is no swift (the Command Line Tools are missing).
is_run() {
	if [ -n "${FOUNDATION_INPUTSOURCE_HELPER:-}" ]; then
		"$FOUNDATION_INPUTSOURCE_HELPER" "$@" </dev/null
		return
	fi
	command -v swift >/dev/null 2>&1 || {
		log_error "swift is needed for the keyboard layouts - install the Command Line Tools (xcode-select --install)"
		return 1
	}
	swift "$FOUNDATION_UNIX/lib/drivers/inputsource.swift" "$@" </dev/null
}

# The enabled keyboard layouts as ID<TAB>SELECTED(0/1)<TAB>NAME lines.
is_layouts() {
	is_run list
}

# Enables the keyboard layouts ID..., selects the first and disables every other enabled layout.
# Fails (3) for an id macOS does not have, before anything changes. Usage: is_apply ID...
is_apply() {
	is_run apply "$@"
}
