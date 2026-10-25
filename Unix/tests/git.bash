# Throwaway repositories for the Git command suites: a bare `origin` and a clone with one commit
# on master, under $BATS_TEST_TMPDIR. Git runs with an empty global and system config and an
# identity set for the suite only, so the user's configuration and repositories are never read or
# written. Load after helpers; call git_sandbox in setup, then work in "$REPO".

git_sandbox() {
	export HOME=$BATS_TEST_TMPDIR/home
	mkdir -p "$HOME"
	export GIT_CONFIG_GLOBAL=$BATS_TEST_TMPDIR/gitconfig GIT_CONFIG_NOSYSTEM=1
	printf '[init]\n\tdefaultBranch = master\n[user]\n\tname = Test\n\temail = test@example.invalid\n' >"$GIT_CONFIG_GLOBAL"
	ORIGIN=$BATS_TEST_TMPDIR/origin.git
	REPO=$BATS_TEST_TMPDIR/repo
	git init -q --bare "$ORIGIN"
	git clone -q "$ORIGIN" "$REPO" 2>/dev/null
	echo one >"$REPO/file.txt"
	git -C "$REPO" add file.txt
	git -C "$REPO" commit -qm "First commit"
	git -C "$REPO" push -q origin master 2>/dev/null
	export FOUNDATION_LOGGING=off
	bin=$UNIX_DIR/modules/Git/bin
}

# A file:// URL named NAME.git that leads to the sandbox origin (a link), so a repository entry
# prints as [NAME] - commands name a repository from its URL. Usage: origin_url NAME
origin_url() {
	mkdir -p "$BATS_TEST_TMPDIR/remotes"
	[ -e "$BATS_TEST_TMPDIR/remotes/$1.git" ] || ln -s "$ORIGIN" "$BATS_TEST_TMPDIR/remotes/$1.git"
	printf 'file://%s/remotes/%s.git' "$BATS_TEST_TMPDIR" "$1"
}
