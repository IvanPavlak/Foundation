# Contributing to Foundation

Thank you for contributing! Foundation is the macOS counterpart of
[WinuX](https://github.com/IvanPavlak/WinuX): a dotfiles system that turns a fresh Mac into a
fully configured, keyboard-driven environment from one command. Contributions of all kinds are
welcome - code, documentation, tests, bug reports and ideas. By participating you agree to our
[Code of Conduct](../CODE_OF_CONDUCT.md).

> **Security:** Foundation runs installers and `sudo` steps on your Mac. If you believe you have
> found a security vulnerability, do **not** open a public issue - follow [SECURITY.md](SECURITY.md)
> instead.

---

## Core principle - configure through `Unix/config`, never hardcode

> **Every value a user might want to change lives in a `Unix/config` file. Commands never embed
> paths, hostnames, usernames or emails.**

- The base `NAME.conf` files ship generic values only; personal values go in the `.local.conf`
  overlays, which Foundation's `.gitignore` ignores.
- Use `$DEV`, `$HOME` and `$DOTFILES_ROOT` in paths, never a literal home folder.
- New behaviour a user might want to toggle, name or relocate gets a line kind in the file of its
  concern, documented in that file's header, on the Configuration page and in the guide of every
  command that reads it.

---

## Contribution quality bar

- **Open an issue or Discussion first** for anything non-trivial, so the approach is agreed before
  you write code.
- **Keep changes minimal and focused** - one logical change per pull request; reuse the libraries
  in `Unix/lib` instead of duplicating logic.
- **Tests are required** for behaviour changes; the `Unix Tests` check must be green.
- **Docs and manifests stay complete** (see below).
- **Explain your reasoning** in the pull request.

> Pull requests that are unexplained, untested, or appear to be raw AI output submitted without a
> reviewed approach will be closed. Use AI tools - but every change must be understood, minimal and
> tested by a human who stands behind it.

---

## Development environment

| Requirement | Notes |
| --- | --- |
| macOS 13 or later | AeroSpace needs Ventura or later; Foundation is developed on a current macOS on Apple silicon. |
| Command Line Tools | `xcode-select --install` (git, make, clang). |
| Homebrew bash 4.4+ | Every command needs it; `brew install bash`. macOS ships 3.2. |
| bats-core, shellcheck, shfmt | `brew install bats-core shellcheck shfmt` (all in the base `Unix/Brewfile`). |

1. **Fork** the repository and clone your fork:

    ```bash
    git clone https://github.com/<your-username>/Foundation.git
    ```

2. **Add the upstream remote**:

    ```bash
    git remote add upstream https://github.com/IvanPavlak/Foundation.git
    ```

> **Do not test changes by bootstrapping your daily-driver Mac.** Bootstrap changes system
> settings, links dotfiles over your own (backing them up first) and installs packages. Test risky
> changes on a separate macOS user or in a virtual machine, with the `Test` machine type.

---

## Running the tests

```bash
Run-Tests                      # every suite, shellcheck and shfmt, as CI runs them
Run-Tests Merge-Upstreams      # the suites whose path contains the pattern
Run-Tests --changed            # only what your branch's changes can affect
Run-Tests --changed --quick    # the same, without the integration tier (real git, real processes)
```

`--changed` and `--quick` are for the edit-test loop and never replace the full run, which is what
CI runs and what must be green before you open a pull request. The full output of a run lands in
`Unix/tests/Results/TestRun_<timestamp>.log` (gitignored).

### How to add tests

1. Every command has `Unix/tests/modules/<Module>/<Command>.bats` (`tests/commands.bats` checks it).
2. Start with `load helpers` and `setup_foundation`: the suites read the generic fixture config in
   `Unix/tests/fixtures/config`, never your `Unix/config`.
3. Test behaviour, side effects, branching and edge cases - not message wording.
4. Never reach the real machine: stand in for a tool with `stub_tool`, take one away with
   `hide_tool`, and use the throwaway repositories of `tests/git.bash` for git. A suite whose value
   is real I/O carries `# bats file_tags=integration`.

---

## Coding conventions

The full set is [`AI/Instructions/ShellConventions.md`](../AI/Instructions/ShellConventions.md). In
short:

- Commands are `#!/usr/bin/env bash` executables named `Verb-Noun`, tracked as `100755`, whose
  header comment is their `--help` and their docs entry. Files sourced into a shell are POSIX sh;
  `Unix/bootstrap.sh` stays bash 3.2.
- Tabs, case branches indented (`shfmt`, styled by `Unix/.editorconfig`); `shellcheck -S warning`
  clean.
- `aerospace`, `wezterm` and the other platform tools are called only from their driver in
  `Unix/lib/drivers/`.
- No em-dash (U+2014) anywhere; use `-`.

---

## Documentation is part of the change

The docsify docs under `docs/foundation/` are the single source of truth. A change to a command updates,
in the same pull request:

- its entry on `docs/foundation/modules/<Module>.md` (one man-style entry per command, alphabetical) and
  the `command` line of its `module.conf`;
- its guide `docs/foundation/guides/<module>/<Command>.md` and that folder's `README.md` index;
- `docs/foundation/_sidebar.md` and `docs/foundation/docs_overview.md` when a page is added or removed.

Then check:

```bash
Run-Tests commands guides doclinks
List-Functions --list-discrepancies
```

Use generic values in docs (`MyProject`, `MyRepo`, `My-Mac`) - never real identifiers. Preview the
site with `npx docsify-cli serve docs`.

---

## Develop in your fork's Custom area first

Commands Foundation does not ship start in your fork's Custom area:
`Unix/modules/Custom/<Module>/bin` with its own `module.conf`, `docs/foundation/custom/<module>.md`, and
`Unix/tests/modules/Custom/<Module>/`. Upstream never writes those paths. When a command is stable,
tested and documented, graduate it with a focused pull request; the checklist is in
`Unix/modules/Custom/README.md`.

---

## Commit messages

- Imperative mood, sentence case: `Add Merge-Upstreams and upstream.conf`.
- No trailing period, no Conventional-Commits prefixes (`feat:`, `fix:`), no scope tags.
- One logical change per commit.

---

## Branch and pull-request workflow

1. Sync with upstream: `git switch master` and `git pull upstream master`.
2. Branch off `master`: `git switch -c add-my-command`.
3. Make focused commits, run `Run-Tests`, update docs and manifests.
4. Add a changelog entry under `## [Unreleased]` in `Unix/CHANGELOG.md`. Before 1.0.0 a rename or
   removal needs a migration note; from 1.0.0 on it is deprecated first (see
   [VERSIONING.md](VERSIONING.md)).
5. Push to your fork and open a pull request against `IvanPavlak/Foundation:master`; fill in the
   template and reference the issue it closes.

### Review and merge

The maintainer reviews and authorizes every contributor merge; merges to `master` need a green
`Unix Tests` check and maintainer review. This is a personal project maintained in spare time -
expect review comments and iteration.

---

## Recognition

Code and non-code contributions (docs, ideas, bug reports, testing) all count and are appreciated.
Financial supporters are credited in the root README "Supporters" section.
