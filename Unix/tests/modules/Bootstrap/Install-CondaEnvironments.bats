#!/usr/bin/env bats
# Install-CondaEnvironments against a stand-in for conda (its environments come from
# $CONDA_ENVS, a create or update fails when $CONDA_FAIL is set and prints $CONDA_FAIL) with
# environment files in the test folder: only missing environments are created and named after
# their file, env lines select files, update-base is opt-in, a Terms of Service refusal gets the
# hint, --list and --dry-run create nothing, a missing folder is skipped, no conda is skipped with
# a warning (hide_tool keeps the real conda out of reach).

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	envs=$BATS_TEST_TMPDIR/envs
	mkdir -p "$envs"
	printf 'name: One\n' >"$envs/One.yml"
	printf 'name: Two\n' >"$envs/Two.yml"
	export CONDA_ENVS=''
	stub_tool conda 'case "$1 $2" in "env list") printf "# conda environments:\n#\nbase                 /opt/conda\n%s\n" "$CONDA_ENVS" ;; *) [ -z "$CONDA_FAIL" ] || { echo "$CONDA_FAIL"; exit 1; } ;; esac'
	[ "$(command -v conda)" = "$BATS_TEST_TMPDIR/tools/conda" ] || {
		echo "stub guard: conda resolves to $(command -v conda)" >&2
		return 1
	}
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Install-CondaEnvironments
}

conf() { printf '%s\n' "$@" >"$FOUNDATION_CONFIG_DIR/conda-environments.conf"; }
changes() { grep -E '^conda (env create|update)' "$BATS_TEST_TMPDIR/tool.log" 2>/dev/null || true; }

@test "without env lines every file is created, an existing environment is left alone" {
	conf "directory $envs"
	CONDA_ENVS='one                  /opt/conda/envs/one' run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(changes)" = "conda env create -n Two -f $envs/Two.yml" ]
}

@test "env lines select the files, a missing file is skipped with a warning" {
	conf "directory $envs" "env Two.yml" "env Missing"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ "$(changes)" = "conda env create -n Two -f $envs/Two.yml" ]
	[[ $output == *"No environment file, skipped"* ]]
}

@test "a directory relative to the repository root and an @TYPE env line" {
	mkdir -p "$BATS_TEST_TMPDIR/root/Envs"
	cp "$envs/One.yml" "$envs/Two.yml" "$BATS_TEST_TMPDIR/root/Envs/"
	conf "directory Envs" "env One" "@Work env Two"
	DOTFILES_ROOT=$BATS_TEST_TMPDIR/root CONF_MACHINE_TYPE=Laptop run "${BASH:-bash}" "$cmd"
	[ "$(changes)" = "conda env create -n One -f $BATS_TEST_TMPDIR/root/Envs/One.yml" ]
}

@test "update-base on updates base first, off (the default) does not" {
	conf "directory $envs" "env One"
	run "${BASH:-bash}" "$cmd"
	[ "$(changes)" = "conda env create -n One -f $envs/One.yml" ]
	rm -f "$BATS_TEST_TMPDIR/tool.log"
	conf "directory $envs" "env One" "update-base on"
	run "${BASH:-bash}" "$cmd"
	[ "$(changes)" = $'conda update -n base -c defaults conda -y\nconda env create -n One -f '"$envs/One.yml" ]
}

@test "a refused Terms of Service fails the run with the accept command" {
	conf "directory $envs" "env One"
	CONDA_FAIL='CondaToSNonInteractiveError: Terms of Service have not been accepted' run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[[ $output == *"conda tos accept"* ]]
}

@test "--list and --dry-run create nothing" {
	conf "directory $envs" "update-base on"
	CONDA_ENVS='One                  /opt/conda/envs/One' run "${BASH:-bash}" "$cmd" --list
	[[ $output == *"One"*"exists"* ]]
	[[ $output == *"Two"*"missing"* ]]
	run "${BASH:-bash}" "$cmd" --dry-run
	[[ $output == *"conda update -n base -c defaults conda -y"* ]]
	[[ $output == *"conda env create -n Two -f $envs/Two.yml"* ]]
	[ -z "$(changes)" ]
}

@test "a missing folder is skipped with nothing created, a missing config and an unknown argument are errors" {
	conf "directory $BATS_TEST_TMPDIR/nowhere" "env One"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[ -z "$(changes)" ]
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	rm -f "$FOUNDATION_CONFIG_DIR/conda-environments.conf"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
}

@test "no conda is skipped with a warning, not a failure, and nothing is created" {
	conf "directory $envs"
	hide_tool conda
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"conda is not installed"* ]]
	[ ! -e "$BATS_TEST_TMPDIR/tool.log" ]
}
