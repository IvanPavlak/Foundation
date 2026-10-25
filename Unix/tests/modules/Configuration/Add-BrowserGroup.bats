#!/usr/bin/env bats
# Add-BrowserGroup: labelled and plain URLs, a non-URL argument fails.

load ../../helpers

setup() {
	setup_foundation
	export FOUNDATION_LOGGING=off FOUNDATION_BACKUP_ROOT=$BATS_TEST_TMPDIR/sink
	copy_fixture_config
	cmd=$UNIX_DIR/modules/Configuration/bin/Add-BrowserGroup
}

@test "labelled and plain URLs become the group's lines" {
	run "${BASH:-bash}" "$cmd" Test.Group GitHub=https://github.com https://example.com
	[ "$status" -eq 0 ]
	[ "$(conf_section "$FOUNDATION_CONFIG_DIR/browser-groups.conf" Test.Group | paste -sd'|' -)" = "GitHub https://github.com|https://example.com" ]
}

@test "a second name that is not a URL fails" {
	run "${BASH:-bash}" "$cmd" Group notaurl
	[ "$status" -ne 0 ]
}
