---
name: document
description: Write or update the documentation of a Foundation command (the macOS half under Unix/) from its code - the man-style entry on its module page and its configuration guide - and keep the module manifest and indexes in step. Use when the user says "document", adds, renames, removes or changes a command under Unix/modules/<Module>/bin, or asks to bring a module page or guide in line with the code.
argument-hint: "Command name or module (e.g., 'Open-Browser' or 'Workflow')"
---

# Document a Foundation command

The docs under `docs/unix/` are the single source of truth for Foundation's commands, and the test suites check them against the code. Write from the code, never from memory.

## 1. Read the command

- The executable `Unix/modules/<Module>/bin/<Command>`: its header (every comment line after the shebang) is what `<Command> --help` prints, and its body is what the docs must match. The header can lag: when it disagrees with the code, fix the header first.
- The libraries it loads (`foundation_load ...`, `Unix/lib/<name>.sh`): the `Unix/config` files they read (`conf_path NAME.conf`) and the line kinds they accept.
- The module manifest `Unix/modules/<Module>/module.conf`: a documented command has a `command` line.

## 2. The module page entry

On `docs/unix/modules/<Module>.md`, one entry per command, alphabetical:

- `## [Command](https://github.com/<owner>/<repo>/blob/master/Unix/modules/<Module>/bin/<Command>)`
- right under it, a contiguous bullet block: `- **Description:**` first, then `- **Usage:**` (the header's usage line), then `- **Alias:**` when the shared rc defines one; omit a bullet that does not apply
- optional prose, tables and a `**See also:**` line after a blank line

## 3. The configuration guide

Every `command` line has exactly one guide, `docs/unix/guides/<module>/<Command>.md`, listed in that folder's `README.md`. Follow `docs/unix/guides/README.md` exactly: the FULL template when the command (or a library it loads, the shared ones excepted) reads a `Unix/config` file, with every such file in its `## Configuration Keys` table; the STUB template otherwise. Generic example values only (`MyProject`, `My-Mac`, `$DEV/MyRepo`), never a value from a `.local.conf` file.

## 4. Keep the rest in step

- Added, renamed or removed command: the `command` line of `module.conf`, the guide file and its index row, and the bats suite `Unix/tests/modules/<Module>/<Command>.bats` (one per command).
- A changed config file or line kind: `docs/unix/configuration.md` and the guide of every command that reads it.
- Links are relative and checked; anchors follow docsify (lower case, punctuation dropped, spaces become hyphens).
- No em-dashes anywhere: a plain hyphen.

## 5. Hand over the checks

Do not run the suites yourself. Give the user the commands that check what changed: the command's own suite, and the documentation gates (`commands.bats`, `guides.bats`, `doclinks.bats`, `docpages.bats`) through the repository's test runner.
