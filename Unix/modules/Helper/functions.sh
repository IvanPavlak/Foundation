# shellcheck shell=bash
# Helper shell functions, sourced by Unix/shell/shellrc.sh. Functions, not executables: only the
# shell itself can change its directory.

Cd-Desktop() {
	cd "$HOME/Desktop" || return
}
