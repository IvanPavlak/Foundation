# shellcheck shell=bash
# The unified backup sink of the Unix half: Backup-RepositoryItem and the retention rules of
# Clear-OldBackups (docs/unix/backups.md). Every writer that replaces or displaces an
# existing file copies it first into
#
#   <repo>/Backups/Unix/<Category>/<Key>/<yyyy-MM-dd_HH-mm-ss>/
#
# (gitignored). Contract: skip, never destroy - when the copy fails the caller must not touch the
# original, and a half-taken backup folder is removed. Needs lib/config.sh.

backup_root() {
	printf '%s' "${FOUNDATION_BACKUP_ROOT:-$DOTFILES_ROOT/Backups/Unix}"
}

# Retention setting KEY of backups.conf (max-age-days, max-backups-per-key, max-total-size-mb),
# DEFAULT when unset; 0 disables a limit.
backup_setting() { # KEY DEFAULT
	local file value
	file=$(conf_path backups.conf) && value=$(conf_value "$file" "$1") && [ -n "$value" ] && {
		printf '%s' "$value"
		return 0
	}
	printf '%s' "$2"
}

# Copies PATH (file or directory, links kept as links) into the sink and prints the backup
# folder. Fails, leaving nothing behind, when PATH is missing or the copy fails.
# Usage: backup_item CATEGORY KEY PATH
backup_item() {
	local category=$1 key=$2 path=$3 folder
	[ -e "$path" ] || [ -L "$path" ] || {
		log_error "Nothing to back up at $path"
		return 1
	}
	folder=$(backup_root)/$category/$key/$(date +%Y-%m-%d_%H-%M-%S)
	# Two backups of one key within a second get a counter, never a merged folder.
	if [ -e "$folder" ]; then
		local n=2
		while [ -e "$folder-$n" ]; do n=$((n + 1)); done
		folder=$folder-$n
	fi
	if ! mkdir -p "$folder" || ! cp -pPR "$path" "$folder/"; then
		rm -rf "$folder"
		log_error "Backup of $path failed - left untouched"
		return 1
	fi
	log_debug "[backup] $path => $folder"
	backup_prune_key "$(dirname "$folder")"
	printf '%s\n' "$folder"
}

# The backups of KEY-DIR, oldest first: only folders named yyyy-MM-dd_HH-mm-ss (a -N counter may
# follow), which sort chronologically as plain names. Anything else in a key folder (a manual
# copy, an unpacked archive) is not a backup: never counted, never the newest, never removed.
backup_folders() { # KEY-DIR
	find "$1" -mindepth 1 -maxdepth 1 -type d -name '[0-9][0-9][0-9][0-9]-[0-9][0-9]-[0-9][0-9]_[0-9][0-9]-[0-9][0-9]-[0-9][0-9]*' | LC_ALL=C sort
}

# Keeps at most max-backups-per-key timestamped folders in KEY-DIR, newest retained (the
# opportunistic enforcement right after a backup).
backup_prune_key() { # KEY-DIR [DRY-RUN]
	local dir=$1 dry=${2:-0} max count folder
	max=$(backup_setting max-backups-per-key 10)
	[ "$max" -gt 0 ] 2>/dev/null || return 0
	count=$(backup_folders "$dir" | wc -l | tr -d ' ')
	[ "$count" -gt "$max" ] || return 0
	backup_folders "$dir" | head -n $((count - max)) | while IFS= read -r folder; do
		backup__remove "$folder" "more than $max backups of this key" "$dry"
	done
}

backup__remove() { # FOLDER REASON DRY-RUN
	local label=${1#"$(backup_root)"/}
	if [ "$3" -eq 1 ]; then
		log_step "would remove $label ($2)"
	else
		rm -rf "$1" && log_step "removed $label ($2)"
	fi
}

# Copies every real file or folder in the home folder that a chezmoi link would replace into
# SymbolicLinks/Dotfiles.<path> of the sink (dots for slashes, the leading dots dropped). A link
# already there carries no content of its own and is replaced as is. With DRY-RUN 1 it only lists
# what it would copy. Fails when a copy fails, so the caller applies nothing over an original that
# has no backup. Runs under bash 3.2 (bootstrap.sh). Usage: backup_chezmoi_targets CHEZMOI [DRY-RUN]
backup_chezmoi_targets() {
	local chezmoi=$1 dry=${2:-0} path key folder
	"$chezmoi" managed --include=symlinks --path-style=relative | while IFS= read -r path; do
		[ -e "$HOME/$path" ] && [ ! -L "$HOME/$path" ] || continue
		key=Dotfiles.$(printf '%s' "$path" | sed 's#^\.##; s#/\.#/#g; s#/#.#g')
		if [ "$dry" -eq 1 ]; then
			log_step "Would back up ~/$path => SymbolicLinks/$key"
		else
			folder=$(backup_item SymbolicLinks "$key" "$HOME/$path") || exit 1
			log_step "Backed up ~/$path => $folder"
		fi
	done
}
