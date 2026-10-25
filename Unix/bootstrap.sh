#!/bin/bash
# bootstrap.sh - the first command on a fresh Mac: links the dotfiles with chezmoi, whose first
# apply hands over to Bootstrap --with-initial-setup (Unix/modules/Bootstrap, every step
# switchable per machine). Rerunning it is safe; afterwards `Bootstrap` is the command to rerun.
#
# Usage: Unix/bootstrap.sh [--dry-run]
#
#   1 Command Line Tools  checked; missing = the installer opens, rerun when it is done
#   2 chezmoi             the installed one, else installed into ~/.local/bin (get.chezmoi.io)
#   3 chezmoi init        --source Unix; asks the machine type and whether the first apply runs
#                         Bootstrap, once per machine
#   4 backup              every real file or folder a link would replace is copied to
#                         Backups/Unix/SymbolicLinks/Dotfiles.<path>/ first
#   5 chezmoi apply       the links; on the first apply, bootstrap-first-run installs Homebrew
#                         and Homebrew bash, then runs Bootstrap --with-initial-setup
#
# --dry-run changes nothing: it says what it would install and run, and shows `chezmoi diff`
# once chezmoi is initialised on this Mac. Every line also goes to a session log in Unix/logs,
# which the first-run hand-over and Bootstrap write into too.
#
# Runs under the stock macOS bash 3.2 on purpose: the Unix commands need bash 4.4+, which
# Bootstrap installs. From a fresh Mac, clone the repository first (git ships with the Command
# Line Tools):
#   xcode-select --install
#   git clone https://github.com/IvanPavlak/Foundation.git ~/Development/GitHub/Foundation
#   ~/Development/GitHub/Foundation/Unix/bootstrap.sh

set -u
UNIX_DIR=$(cd "$(dirname "$0")" && pwd -P)
DOTFILES_ROOT=$(dirname "$UNIX_DIR")
export DOTFILES_ROOT
. "$UNIX_DIR/lib/foundation.sh" || exit 1
foundation_load config backup || exit 1
# Its own session log (Unix/logs/Session_<timestamp>_bootstrap.sh.log), as a module command opens:
# chezmoi's first apply, bootstrap-first-run and Bootstrap inherit it and write into it.
logfile_load_settings
logfile_start bootstrap.sh "$@"

dry=0
for argument in "$@"; do
	case $argument in
		--dry-run) dry=1 ;;
		-h | --help)
			sed -n '2,25p' "$0" | sed 's/^# \{0,1\}//'
			exit 0
			;;
		*)
			log_error "Unknown argument: $argument - steps are chosen with Bootstrap --only / --skip"
			exit 1
			;;
	esac
done

if [ "$(uname -s)" != "Darwin" ]; then
	log_error "Only macOS is supported by this bootstrap yet."
	exit 1
fi

# The chezmoi to use: the one on PATH, else the one this script installs.
chezmoi_bin() {
	command -v chezmoi 2>/dev/null && return 0
	[ -x "$HOME/.local/bin/chezmoi" ] && printf '%s\n' "$HOME/.local/bin/chezmoi"
}

log_title "1 Command Line Tools"
if xcode-select -p >/dev/null 2>&1; then
	log_step "Command Line Tools present => $(xcode-select -p)"
elif [ "$dry" -eq 1 ]; then
	log_step "Would run xcode-select --install"
else
	xcode-select --install
	log_error "Finish the Command Line Tools install that just opened, then rerun bootstrap.sh"
	exit 1
fi

log_title "2 chezmoi"
if chezmoi=$(chezmoi_bin); then
	log_step "$("$chezmoi" --version)"
elif [ "$dry" -eq 1 ]; then
	log_step "Would install chezmoi into ~/.local/bin (get.chezmoi.io)"
	log_step "Would run chezmoi init --source $UNIX_DIR, back up the real files the links replace, then chezmoi apply"
	exit 0
else
	sh -c "$(curl -fsLS https://get.chezmoi.io)" -- -b "$HOME/.local/bin" || {
		log_error "Installing chezmoi failed"
		exit 1
	}
	chezmoi=$HOME/.local/bin/chezmoi
fi

log_title "3 chezmoi init"
config=${XDG_CONFIG_HOME:-$HOME/.config}/chezmoi/chezmoi.toml
if [ "$dry" -eq 1 ]; then
	log_step "Would run chezmoi init --source $UNIX_DIR"
	if [ ! -f "$config" ]; then
		log_step "chezmoi is not initialised here yet - would back up the real files the links replace, then chezmoi apply"
		exit 0
	fi
else
	"$chezmoi" init --source "$UNIX_DIR" || {
		log_error "chezmoi init failed"
		exit 1
	}
fi

log_title "4 Backup"
backup_chezmoi_targets "$chezmoi" "$dry" || {
	log_error "A backup failed - nothing applied, the original is untouched"
	exit 1
}

log_title "5 chezmoi apply"
if [ "$dry" -eq 1 ]; then
	"$chezmoi" diff
	exit 0
fi
"$chezmoi" apply || {
	log_error "chezmoi apply failed - fix the error above, then rerun bootstrap.sh"
	exit 1
}
log_success "Dotfiles linked! Open a new terminal; Bootstrap reruns any provisioning step => Bootstrap --help"
