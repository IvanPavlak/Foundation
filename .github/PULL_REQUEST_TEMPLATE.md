<!--
Thanks for contributing to Foundation! Please read CONTRIBUTING.md first.
Non-trivial changes should start as an issue or Discussion so the approach can be agreed.
The maintainer reviews and authorizes all merges, so a complete PR speeds up review.
-->

## Description

<!-- What does this PR do, and why? Explain your reasoning. -->

## Related issue

Closes #

## Type of change

- [ ] Bug fix
- [ ] New command, flag or config line kind
- [ ] Rename or removal of a command, flag, config line kind or Bootstrap step (with a migration note in `CHANGELOG.md`; from 1.0.0 on, a deprecation first - see VERSIONING.md)
- [ ] Documentation only
- [ ] Tests only
- [ ] Refactor / chore (no behavior change)

## Quality bar

- [ ] The change is **minimal and focused** (one logical change; reuses `Unix/lib` instead of duplicating it).
- [ ] I **understand and have tested** this change myself (not unreviewed AI output).
- [ ] No machine-specific values (paths, hostnames, usernames, emails) are hardcoded in commands or base config files.
- [ ] Platform tools (`aerospace`, `wezterm`, browser scripting) are called only from `Unix/lib/drivers/`.

## Tests

<!-- Paste the exact Run-Tests command(s) you ran and the result. -->

```bash
Run-Tests ...
```

- [ ] I added/updated the suite `Unix/tests/modules/<Module>/<Command>.bats`.
- [ ] `Run-Tests` passes locally (shellcheck and shfmt included) and the `Unix Tests` check is green.
- [ ] Tests cover behavior, side effects and branching, not just output text.
- [ ] N/A - no testable behavior changed.

## Documentation & manifests

- [ ] I updated `docs/unix/modules/<Module>.md` and the module's `module.conf` for any added/renamed/removed/changed command.
- [ ] I added/updated its guide under `docs/unix/guides/<module>/` and that folder's `README.md`.
- [ ] I updated `docs/unix/configuration.md` and the file's header for a new or changed config line kind.
- [ ] I updated `docs/unix/_sidebar.md` and `docs/unix/docs_overview.md` if a page was added/removed.
- [ ] `List-Functions --list-discrepancies` reports nothing.
- [ ] N/A - no command or config changed.

## Tested on

- macOS version: <!-- sw_vers -productVersion -->
- Machine type(s): <!-- Test / custom -->

## Checklist

- [ ] My commit messages follow the project style (imperative, sentence case, no trailing period, no Conventional-Commits prefix).
- [ ] My branch is up to date with `master`.
- [ ] I read and agree to the [Code of Conduct](../CODE_OF_CONDUCT.md).
- [ ] This PR contains no secrets or personal data (tokens, real paths/hostnames/emails).
