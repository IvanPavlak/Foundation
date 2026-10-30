#!/usr/bin/env bats
# Configure-NuGetConfig with a template and a config in the test folder (HOME and the backup
# sink point there too) and the answers fed through FOUNDATION_TTY: matching package sources change
# nothing, a mismatch or --override asks and writes the filled-in template with owner-only
# permissions, the old file is backed up first with its tokens redacted, empty answers and a
# token with whitespace are asked again, --dry-run asks and writes nothing.

load ../../helpers

setup() {
	setup_foundation
	copy_fixture_config
	export HOME=$BATS_TEST_TMPDIR/home
	export FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/backups
	mkdir -p "$HOME"
	template=$BATS_TEST_TMPDIR/nuget.config
	target=$BATS_TEST_TMPDIR/home/.nuget/NuGet/NuGet.Config
	cat >"$template" <<'EOF'
<configuration>
  <packageSources>
    <add key="nuget.org" value="https://api.nuget.org/v3/index.json" protocolVersion="3" />
    <add key="MyFeed" value="https://nuget.pkg.github.com/MyOrg/index.json" />
  </packageSources>
  <packageSourceCredentials>
    <MyFeed>
      <add key="Username" value="[Username]" />
      <add key="ClearTextPassword" value="[Token]" />
    </MyFeed>
  </packageSourceCredentials>
</configuration>
EOF
	printf '%s\n' "nuget-template $template" "nuget-config $target" >"$FOUNDATION_CONFIG_DIR/dotnet.conf"
	answers=$BATS_TEST_TMPDIR/answers
	printf 'my-user\nghp_A&B<C\n' >"$answers"
	export FOUNDATION_TTY=$answers
	cmd=$UNIX_DIR/modules/Bootstrap/bin/Configure-NuGetConfig
}

existing() { # SOURCES...
	mkdir -p "$(dirname "$target")"
	{
		printf '<configuration>\n  <packageSources>\n'
		printf '    %s\n' "$@"
		printf '  </packageSources>\n</configuration>\n'
	} >"$target"
}

@test "a missing config is written with the answers filled in and owner-only permissions" {
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qF 'value="my-user"' "$target"
	grep -qF 'value="ghp_A&amp;B&lt;C"' "$target"
	! grep -qF '[Token]' "$target" || false
	[ "$(stat -f %Lp "$target" 2>/dev/null || stat -c %a "$target")" = 600 ]
	[ ! -e "$FOUNDATION_BACKUP_ROOT" ]
}

@test "a relative nuget-config starts at the repository root, not the current folder" {
	export DOTFILES_ROOT=$BATS_TEST_TMPDIR/repo
	mkdir -p "$DOTFILES_ROOT" "$BATS_TEST_TMPDIR/elsewhere"
	printf '%s\n' "nuget-template $template" "nuget-config out/NuGet.Config" >"$FOUNDATION_CONFIG_DIR/dotnet.conf"
	cd "$BATS_TEST_TMPDIR/elsewhere"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	grep -qF 'value="my-user"' "$DOTFILES_ROOT/out/NuGet.Config"
	[ ! -e "$BATS_TEST_TMPDIR/elsewhere/out" ]
}

@test "matching package sources change nothing and ask nothing" {
	existing '<add key="nuget.org" value="https://api.nuget.org/v3/index.json" />' '<add key="MyFeed" value="https://nuget.pkg.github.com/MyOrg/index.json" />'
	before=$(cat "$target")
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/no-tty run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"package sources match"* ]]
	[ "$(cat "$target")" = "$before" ]
}

@test "a missing, changed or extra source reconfigures after backing up the old file" {
	existing '<add key="nuget.org" value="https://example.invalid/v3/index.json" />' '<add key="Other" value="https://other.invalid" />'
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"[MyFeed] is missing"* ]]
	[[ $output == *"[nuget.org] has a different URL"* ]]
	[[ $output == *"[Other] exists in the actual config"* ]]
	grep -qF 'value="my-user"' "$target"
	grep -rqF 'https://other.invalid' "$FOUNDATION_BACKUP_ROOT/System/NuGetConfig"
}

@test "--override rewrites a matching config, empty answers are asked again" {
	existing '<add key="nuget.org" value="https://api.nuget.org/v3/index.json" />' '<add key="MyFeed" value="https://nuget.pkg.github.com/MyOrg/index.json" />'
	printf '\n  \nmy-user\n\nsecret\n' >"$answers"
	run "${BASH:-bash}" "$cmd" --override
	[ "$status" -eq 0 ]
	[[ $output == *"cannot be empty"* ]]
	grep -qF 'value="secret"' "$target"
}

@test "--dry-run asks nothing and writes nothing" {
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/no-tty run "${BASH:-bash}" "$cmd" --dry-run
	[ "$status" -eq 0 ]
	[[ $output == *"ask for the GitHub username and token, write $target"* ]]
	[ ! -e "$target" ]
}

@test "no terminal, no answer, a missing template and an unknown argument are errors" {
	FOUNDATION_TTY=$BATS_TEST_TMPDIR/no-tty run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -e "$target" ]
	printf 'my-user\n' >"$answers"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
	[ ! -e "$target" ]
	run "${BASH:-bash}" "$cmd" --bogus
	[ "$status" -ne 0 ]
	rm -f "$template"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -ne 0 ]
}

@test "--backup-root puts the backup of the old file under that folder" {
	existing '<add key="Other" value="https://other.invalid" />'
	run "${BASH:-bash}" "$cmd" -BackupRoot "$BATS_TEST_TMPDIR/elsewhere"
	[ "$status" -eq 0 ]
	grep -rqF 'https://other.invalid' "$BATS_TEST_TMPDIR/elsewhere/System/NuGetConfig"
	[ ! -d "$FOUNDATION_BACKUP_ROOT/System/NuGetConfig" ]
}

@test "the backup keeps the sources but no token: ClearTextPassword and Password are redacted" {
	mkdir -p "$(dirname "$target")"
	printf '%s\n' '<configuration>' '  <packageSources>' '    <add key="Other" value="https://other.invalid" />' '  </packageSources>' \
		'  <packageSourceCredentials>' '    <Other>' '      <add key="ClearTextPassword" value="old-token" />' '      <add value="old-password" key="Password" />' \
		'    </Other>' '  </packageSourceCredentials>' '</configuration>' >"$target"
	export TMPDIR=$BATS_TEST_TMPDIR/tmp
	mkdir -p "$TMPDIR"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	backup=$(find "$FOUNDATION_BACKUP_ROOT/System/NuGetConfig" -type f -name NuGet.Config)
	grep -qF 'https://other.invalid' "$backup"
	grep -qF '<add key="ClearTextPassword" value="REDACTED" />' "$backup"
	grep -qF '<add value="REDACTED" key="Password" />' "$backup"
	! grep -rqE 'old-token|old-password|ghp_A' "$FOUNDATION_BACKUP_ROOT" || false
	[ -z "$(ls -A "$TMPDIR")" ]
}

@test "a token with whitespace (a pasted command) is asked again, the username is not checked" {
	printf 'My User\nConfigure-NuGetConfig --override\nsecret\n' >"$answers"
	run "${BASH:-bash}" "$cmd"
	[ "$status" -eq 0 ]
	[[ $output == *"no spaces"* ]]
	grep -qF 'value="My User"' "$target"
	grep -qF 'value="secret"' "$target"
	! grep -qF 'Configure-NuGetConfig' "$target" || false
}
