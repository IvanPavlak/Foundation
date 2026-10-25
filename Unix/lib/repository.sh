# shellcheck shell=bash
# Updating one cloned repository without ever losing or misplacing local work - the Unix port of
# the Windows Update-Repository, Restore-RepositoryStash, Resolve-RepositoryDefaultBranch,
# Update-RepositoryDefaultBranch and Format-RepositoryUpdateResult (WinuX Git module). Used by
# Update-Repositories, Initialize-Repository and Invoke-StartupRepositoryUpdate; repo_scope_groups
# also by Bootstrap. repo_entry, repo_resolve_url and repo_url_shallow read the repository lines of
# repositories.conf (the end of this file).
#
# repo_update NAME DIR [INCLUDE-DEFAULT 0|1] [QUIET 0|1] leaves its result in global variables:
#
#   REPO_NAME, REPO_DIR, REPO_BRANCH
#   REPO_OUTCOME          Updated, UpToDate, NoUpstream (branch not on origin), FetchFailed,
#                         Conflict (no fast-forward possible, or it would overwrite an ignored
#                         file; nothing changed), Detached, Busy (merge, rebase, cherry-pick,
#                         revert, bisect or unresolved conflicts: nothing touched),
#                         NotARepository (DIR is not the top of a working tree: nothing touched),
#                         StashFailed, StashConflict (stash kept, its name in REPO_STASH_NAME),
#                         StashMissing (another git command took the stash)
#   REPO_DEFAULT_BRANCH, REPO_DEFAULT_OUTCOME   (empty when the step did not run) Current,
#                         Updated, UpToDate, Missing (no local branch), Diverged, Failed, Unresolved
#   REPO_STASH_NAME       set while local changes are kept in a stash
#
# The default branch is REPO_DEFAULT_CONFIGURED when the caller sets it, otherwise origin/HEAD.
# With QUIET 1 nothing is logged and git's output is dropped; repo_format_result then gives the
# caller one line. Written to run under bash 3.2 too, like the rest of lib/.
# shellcheck disable=SC2034 # the REPO_* results are read by the commands that source this file

REPO_DEFAULT_CONFIGURED=${REPO_DEFAULT_CONFIGURED:-}

# git in REPO_DIR; quiet drops its output. Usage: repo__git ARGS...
repo__git() {
	if [ "${REPO__QUIET:-0}" -eq 1 ]; then
		git -C "$REPO_DIR" "$@" >/dev/null 2>&1
	else
		git -C "$REPO_DIR" "$@"
	fi
}

repo__say() { # FUNCTION MESSAGE - log only when not quiet
	[ "${REPO__QUIET:-0}" -eq 1 ] && return 0
	"$1" "$2"
}

# Re-applies exactly the stash COMMIT (staged changes staged again) and drops it only after a
# clean restore. Sets REPO_RESTORE to Restored, Missing (no such stash any more) or Conflict (the
# stash is kept). Usage: repo_restore_stash COMMIT
repo_restore_stash() {
	local commit=$1 position
	REPO_RESTORE=Missing
	git -C "$REPO_DIR" stash list --format=%H 2>/dev/null | grep -qx "$commit" || return 0
	if ! repo__git stash apply --index "$commit"; then
		# --index refuses without touching anything when the staged part cannot be rebuilt; a
		# clean tree afterwards proves it, and only then is a plain apply safe. A dirty tree
		# means the apply started and conflicted: leave it, the stash is kept.
		if [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ] || ! repo__git stash apply "$commit"; then
			REPO_RESTORE=Conflict
			return 0
		fi
	fi
	# Its position may have moved since the lookup; found again by commit, never by position.
	position=$(git -C "$REPO_DIR" stash list --format=%H 2>/dev/null | awk -v c="$commit" '$0 == c { print NR - 1; exit }')
	[ -n "$position" ] && repo__git stash drop "stash@{$position}"
	REPO_RESTORE=Restored
}

# The default branch of REPO_DIR: REPO_DEFAULT_CONFIGURED, else origin/HEAD; empty when neither
# names one. Usage: repo_default_branch
repo_default_branch() {
	local head
	if [ -n "$REPO_DEFAULT_CONFIGURED" ]; then
		printf '%s' "$REPO_DEFAULT_CONFIGURED"
		return 0
	fi
	head=$(git -C "$REPO_DIR" symbolic-ref --quiet --short refs/remotes/origin/HEAD 2>/dev/null) || return 0
	printf '%s' "${head#origin/}"
}

# Fast-forwards DEFAULT without checking it out (git fetch origin DEFAULT:DEFAULT refuses anything
# but a fast-forward and never touches the working tree, index or stash). Sets
# REPO_DEFAULT_OUTCOME. Usage: repo_update_default_branch DEFAULT CURRENT
repo_update_default_branch() {
	local default=$1 current=$2 before after
	if [ "$default" = "$current" ]; then
		REPO_DEFAULT_OUTCOME=Current
		return 0
	fi
	if ! git -C "$REPO_DIR" show-ref --verify --quiet "refs/heads/$default"; then
		REPO_DEFAULT_OUTCOME=Missing
		repo__say log_warning "Default branch [$default] has no local branch - skipped"
		return 0
	fi
	before=$(git -C "$REPO_DIR" rev-parse --verify --quiet "refs/heads/$default")
	repo__say log_step "Fast-forwarding default branch [$default]"
	if ! repo__git fetch origin "$default:$default"; then
		# A rejected fast-forward and a failed fetch exit alike; the refs tell them apart.
		REPO_DEFAULT_OUTCOME=Failed
		if git -C "$REPO_DIR" rev-parse --verify --quiet "refs/remotes/origin/$default" >/dev/null; then
			git -C "$REPO_DIR" merge-base --is-ancestor "refs/heads/$default" "refs/remotes/origin/$default"
			[ $? -eq 1 ] && REPO_DEFAULT_OUTCOME=Diverged
		fi
		if [ "$REPO_DEFAULT_OUTCOME" = Diverged ]; then
			repo__say log_warning "Default branch [$default] has local commits origin does not - left untouched"
		else
			repo__say log_error "Failed to fetch default branch [$default]"
		fi
		return 0
	fi
	after=$(git -C "$REPO_DIR" rev-parse --verify --quiet "refs/heads/$default")
	if [ "$before" = "$after" ]; then
		REPO_DEFAULT_OUTCOME=UpToDate
		repo__say log_success "Default branch [$default] is already up to date!"
	else
		REPO_DEFAULT_OUTCOME=Updated
		repo__say log_success "Default branch [$default] fast-forwarded"
	fi
}

# Usage: repo_update NAME DIR [INCLUDE-DEFAULT 0|1] [QUIET 0|1]
repo_update() {
	REPO_NAME=$1
	REPO_DIR=$2
	REPO__QUIET=${4:-0}
	local include_default=${3:-0}
	REPO_BRANCH=''
	REPO_OUTCOME=''
	REPO_DEFAULT_BRANCH=''
	REPO_DEFAULT_OUTCOME=''
	REPO_STASH_NAME=''
	local stash_commit='' operation='' git_dir marker
	repo__say log_step "Checking status of [$REPO_NAME]"

	# 1. The path must be the top of its own working tree, or every command below would act on
	# whatever repository encloses it.
	if [ "$(git -C "$REPO_DIR" rev-parse --is-inside-work-tree 2>/dev/null)" != true ] ||
		[ -n "$(git -C "$REPO_DIR" rev-parse --show-prefix 2>/dev/null)" ]; then
		REPO_OUTCOME=NotARepository
		repo__say log_error "[$REPO_DIR] is not the top of a git repository - nothing was touched"
		return 0
	fi

	# 2. Work in progress that a stash or a fast-forward could destroy.
	git_dir=$(git -C "$REPO_DIR" rev-parse --absolute-git-dir 2>/dev/null)
	for marker in "MERGE_HEAD:a merge" "CHERRY_PICK_HEAD:a cherry-pick" "REVERT_HEAD:a revert" \
		"rebase-merge:a rebase" "rebase-apply:a rebase or am" "BISECT_LOG:a bisect"; do
		if [ -e "$git_dir/${marker%%:*}" ]; then
			operation=${marker#*:}
			break
		fi
	done
	[ -z "$operation" ] && [ -n "$(git -C "$REPO_DIR" ls-files --unmerged 2>/dev/null)" ] && operation="unresolved conflicts"
	if [ -n "$operation" ]; then
		REPO_OUTCOME=Busy
		repo__say log_warning "[$REPO_NAME] has $operation in progress - nothing was touched"
		return 0
	fi

	REPO_BRANCH=$(git -C "$REPO_DIR" rev-parse --abbrev-ref HEAD 2>/dev/null)
	repo__say log_step "Current branch => [$REPO_BRANCH]"

	if [ "$REPO_BRANCH" = HEAD ]; then
		# 3. Detached HEAD: no branch to pull into, and moving HEAD would lose the position.
		REPO_OUTCOME=Detached
		repo__say log_warning "[$REPO_NAME] has no branch checked out (detached HEAD) - nothing to pull"
	else
		# 4. Stash, tracked by its commit, with an ephemeral identity (works before a global one).
		if [ -n "$(git -C "$REPO_DIR" status --porcelain 2>/dev/null)" ]; then
			local stash_name stash_before stash_after push_status
			stash_name="${REPO_BRANCH}_$(date +%Y-%m-%d_%H-%M-%S)"
			repo__say log_warning "Local changes detected. Creating stash..."
			stash_before=$(git -C "$REPO_DIR" rev-parse --verify --quiet refs/stash)
			repo__git -c user.name=Foundation -c user.email=foundation@localhost stash push --include-untracked -m "$stash_name"
			push_status=$?
			stash_after=$(git -C "$REPO_DIR" rev-parse --verify --quiet refs/stash)
			[ -n "$stash_after" ] && [ "$stash_after" != "$stash_before" ] && stash_commit=$stash_after
			if [ "$push_status" -ne 0 ]; then
				# A push can fail after it created the stash: whatever it took is given back now.
				REPO_OUTCOME=StashFailed
				if [ -n "$stash_commit" ]; then
					repo_restore_stash "$stash_commit"
					[ "$REPO_RESTORE" = Restored ] || REPO_STASH_NAME=$stash_name
				fi
				repo__say log_error "Failed to stash changes in [$REPO_NAME]. Skipping update."
				[ -n "$REPO_STASH_NAME" ] && repo__say log_warning "Part of the changes are kept in stash => [$stash_name]"
				return 0
			fi
			if [ -n "$stash_commit" ]; then
				REPO_STASH_NAME=$stash_name
				repo__say log_success "Changes stashed as [$stash_name]"
			else
				# Nothing git can stash (a submodule's new commits): nothing to restore later.
				repo__say log_step "Nothing stashable among the local changes - continuing"
			fi
		fi

		# 5. Fetch, then fast-forward without ever overwriting an ignored file.
		local fetch_status behind
		repo__say log_step "Updating [$REPO_NAME] on branch [$REPO_BRANCH]"
		repo__git fetch origin "$REPO_BRANCH"
		fetch_status=$?
		if ! git -C "$REPO_DIR" rev-parse --verify --quiet "refs/remotes/origin/$REPO_BRANCH" >/dev/null; then
			REPO_OUTCOME=NoUpstream
			repo__say log_warning "Branch [$REPO_BRANCH] is not on origin - nothing to pull"
		elif [ "$fetch_status" -ne 0 ]; then
			REPO_OUTCOME=FetchFailed
			repo__say log_error "Failed to fetch [$REPO_BRANCH] from origin - nothing was pulled"
		else
			behind=$(git -C "$REPO_DIR" rev-list "HEAD..origin/$REPO_BRANCH" --count 2>/dev/null)
			if [ "$behind" = 0 ]; then
				REPO_OUTCOME=UpToDate
				repo__say log_success "Repository is already up to date!"
			elif repo__git merge --ff-only --no-overwrite-ignore "origin/$REPO_BRANCH"; then
				# Not `git pull`: its merge silently replaces an ignored local file at a path the
				# incoming commits start tracking; a refused --ff-only merge changes nothing.
				REPO_OUTCOME=Updated
				repo__say log_success "Updated repository"
			else
				REPO_OUTCOME=Conflict
				repo__say log_error "Could not fast-forward [$REPO_BRANCH] - it has local commits origin does not, or the update would overwrite an ignored file. Nothing was changed."
			fi
		fi
	fi

	# 6. The default branch, fetched into directly and never checked out.
	if [ "$include_default" -eq 1 ]; then
		REPO_DEFAULT_BRANCH=$(repo_default_branch)
		if [ -z "$REPO_DEFAULT_BRANCH" ] && repo__git remote set-head origin --auto; then
			# Not created by `git clone`: origin is asked once and its answer recorded locally.
			REPO_DEFAULT_BRANCH=$(repo_default_branch)
		fi
		if [ -z "$REPO_DEFAULT_BRANCH" ]; then
			REPO_DEFAULT_OUTCOME=Unresolved
			repo__say log_warning "Default branch of [$REPO_NAME] could not be determined - set default-branch in repositories.conf or run [git remote set-head origin --auto]"
		else
			repo_update_default_branch "$REPO_DEFAULT_BRANCH" "$REPO_BRANCH"
		fi
	fi

	# 7. Give back exactly this run's stash.
	if [ -n "$stash_commit" ]; then
		repo__say log_warning "Attempting to restore stashed changes..."
		repo_restore_stash "$stash_commit"
		case $REPO_RESTORE in
			Restored)
				REPO_STASH_NAME=''
				repo__say log_success "Restored stashed changes!"
				;;
			Missing)
				REPO_OUTCOME=StashMissing
				repo__say log_error "The stash [$REPO_STASH_NAME] was taken by another git command before it could be restored - check the working tree and [git stash list]"
				;;
			*)
				REPO_OUTCOME=StashConflict
				repo__say log_error "Conflicts occurred while restoring stashed changes in [$REPO_NAME]"
				repo__say log_warning "Changes are preserved in stash: $REPO_STASH_NAME - resolve with [git stash list] and [git stash apply]"
				;;
		esac
	fi
	return 0
}

# A result for a repository repo_update did not run on (cloned, not cloned, not configured).
# Usage: repo_result NAME OUTCOME
repo_result() {
	REPO_NAME=$1
	REPO_OUTCOME=$2
	REPO_BRANCH=''
	REPO_DEFAULT_BRANCH=''
	REPO_DEFAULT_OUTCOME=''
	REPO_STASH_NAME=''
}

# One summary line for the current REPO_* result: sets REPO_LINE, REPO_LEVEL (Success|Warning)
# and REPO_CATEGORY (Updated, UpToDate, Skipped, Attention). Usage: repo_format_result
repo_format_result() {
	local text default_text=''
	case $REPO_OUTCOME in
		Updated) text=updated ;;
		UpToDate) text="up to date" ;;
		Cloned) text=cloned ;;
		NoUpstream) text="not on origin, nothing to pull" ;;
		FetchFailed) text="could not fetch from origin" ;;
		Conflict) text="could not fast-forward, nothing changed - resolve manually" ;;
		Detached) text="detached HEAD, nothing to pull" ;;
		Busy) text="operation in progress, nothing touched" ;;
		NotARepository) text="not the top of a git repository, nothing touched" ;;
		StashFailed) text="local changes could not be stashed - skipped" ;;
		StashConflict) text="local changes could not be restored cleanly and are kept in stash [$REPO_STASH_NAME]" ;;
		StashMissing) text="its stash was taken by another git command - check the working tree and git stash list" ;;
		NotCloned) text="not cloned on this machine - skipped" ;;
		NotConfigured) text="no local path on this machine - skipped" ;;
		*) text=failed ;;
	esac
	case $REPO_OUTCOME in
		Updated | Cloned) REPO_CATEGORY=Updated ;;
		UpToDate) REPO_CATEGORY=UpToDate ;;
		NotCloned | NotConfigured | NoUpstream | Detached) REPO_CATEGORY=Skipped ;;
		*) REPO_CATEGORY=Attention ;;
	esac
	case $REPO_DEFAULT_OUTCOME in
		Updated) default_text="$REPO_DEFAULT_BRANCH fast-forwarded" ;;
		UpToDate) default_text="$REPO_DEFAULT_BRANCH up to date" ;;
		Missing) default_text="no local $REPO_DEFAULT_BRANCH" ;;
		Diverged) default_text="$REPO_DEFAULT_BRANCH has local commits, left untouched" ;;
		Failed) default_text="$REPO_DEFAULT_BRANCH could not be fetched" ;;
		Unresolved) default_text="default branch unknown" ;;
	esac
	case $REPO_DEFAULT_OUTCOME in Diverged | Failed | Unresolved) REPO_CATEGORY=Attention ;; esac
	if [ -n "$REPO_BRANCH" ]; then
		REPO_LINE="[$REPO_NAME] $REPO_BRANCH - $text"
	else
		REPO_LINE="[$REPO_NAME] $text"
	fi
	[ -n "$default_text" ] && REPO_LINE="$REPO_LINE, $default_text"
	REPO_LEVEL=Success
	[ "$REPO_CATEGORY" = Attention ] && REPO_LEVEL=Warning
	return 0
}

# The repositories.conf groups a scope names (the startup-scope of repositories.conf, the
# repository-scope of bootstrap.conf), one per line as written in FILE. Group names only, as on
# Windows: when any NAME is no group (a repository's name included) it logs the unknown names with
# the configured groups and fails without printing any, so the caller updates nothing instead of
# half the scope. Needs lib/config.sh. Usage: repo_scope_groups FILE SETTING NAME...
repo_scope_groups() {
	local file=$1 setting=$2 word group names configured groups=() unknown=()
	shift 2
	for word in "$@"; do
		if [ -n "$file" ] && group=$(conf_section_name "$file" "$word"); then
			groups+=("$group")
		else
			unknown+=("$word")
		fi
	done
	if [ ${#unknown[@]} -gt 0 ]; then
		names=$(printf '%s, ' "${unknown[@]}")
		configured=''
		[ -n "$file" ] && configured=$(conf_sections "$file" | awk 'NR > 1 { printf ", " } { printf "%s", $0 }')
		log_error "Unknown repository group [${names%, }] in $setting - nothing updated. Configured groups => [$configured]"
		return 1
	fi
	[ ${#groups[@]} -eq 0 ] || printf '%s\n' "${groups[@]}"
}

# One repository line of repositories.conf (`NAME PATH-OR-URL [DIR] [shallow]`) split into
# REPO_ENTRY_NAME, REPO_ENTRY_SOURCE, REPO_ENTRY_DIR (as written, unexpanded; empty when the line
# has none) and REPO_ENTRY_SHALLOW (1 when the last word is `shallow`: cloned --depth 1, the
# Windows Obsidian rule as a setting). Usage: repo_entry LINE
repo_entry() {
	local rest last
	read -r REPO_ENTRY_NAME REPO_ENTRY_SOURCE rest <<<"$1"
	REPO_ENTRY_SHALLOW=0
	last=${rest##*[[:space:]]}
	if [ -n "$rest" ] && foundation_ieq "$last" shallow; then
		REPO_ENTRY_SHALLOW=1
		rest=${rest%"$last"}
		rest=${rest%"${rest##*[![:space:]]}"}
	fi
	REPO_ENTRY_DIR=$rest
}

# The clone URL of a repository source: a full URL (http(s)://, git@, ssh://, git://, file://) as
# is, a path appended to BASE. Usage: repo_resolve_url SOURCE BASE
repo_resolve_url() {
	case $1 in
		http://* | https://* | git@* | ssh://* | git://* | file://*) printf '%s' "$1" ;;
		*) printf '%s%s' "$2" "$1" ;;
	esac
}

# A URL compared without case, a user name (https://MyUser@host), a trailing slash or `.git`.
# Usage: repo__url_key URL
repo__url_key() {
	local key rest
	key=$(foundation_lower "${1%/}")
	case $key in *://*@*)
		rest=${key#*://}
		key=${key%%://*}://${rest#*@}
		;;
	esac
	printf '%s' "${key%.git}"
}

# Does a repository line of FILE marked `shallow` lead to URL? Compared as repo__url_key does.
# Needs lib/config.sh. Usage: repo_url_shallow FILE URL
repo_url_shallow() {
	local file=$1 base group line url
	url=$(repo__url_key "$2")
	base=$(conf_value "$file" base) || base=https://github.com
	while IFS= read -r group; do
		while IFS= read -r line; do
			[ -n "$line" ] || continue
			repo_entry "$line"
			[ "$REPO_ENTRY_SHALLOW" -eq 1 ] || continue
			[ "$(repo__url_key "$(repo_resolve_url "$REPO_ENTRY_SOURCE" "$base")")" = "$url" ] && return 0
		done < <(conf_section "$file" "$group")
	done < <(conf_sections "$file")
	return 1
}
