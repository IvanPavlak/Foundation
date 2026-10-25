# Test fixture config

A small, generic stand-in for `Unix/config`, used by the bats suites instead of the real files:
`setup_foundation` points `FOUNDATION_CONFIG_DIR` here, and `copy_fixture_config` / `stub_config` give a
test a writable copy. The suites assert the values written here, never the personal values of
`Unix/config`, so editing your own workspaces, layouts or browser groups never breaks a test.

Names are placeholders (`Sample`, `Docs`, `*.example` URLs). The suites add their own sections
on top of a copy (`Demo`, `TestGroup`, `Launch`, ...), so keep those names out of the fixture.
Whether the real `Unix/config` is consistent is `Test-ConfigurationSchema`'s job, not the suites'.
