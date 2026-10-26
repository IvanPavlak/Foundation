# Configuration Guides

One page per command: which `Unix/config` files and line kinds it reads, the decisions they encode
and how to set them, the Unix twin of the per-function guides of the Windows half. Every `command`
line of every `module.conf` (the Custom area's included) has exactly one guide, in the folder of its
module, named after the command: `guides/<module>/<Command>.md`, and `guides/custom/<module>/` for
the Custom area. Each folder has a `README.md` index. `tests/guides.bats` enforces all of it.

| Module | Guides |
| ------ | ------ |
| AI | [ai/](ai/README.md) |
| Application | [application/](application/README.md) |
| Bootstrap | [bootstrap/](bootstrap/README.md) |
| Configuration | [configuration/](configuration/README.md) |
| Git | [git/](git/README.md) |
| Helper | [helper/](helper/README.md) |
| Logging | [logging/](logging/README.md) |
| System | [system/](system/README.md) |
| Tests | [tests/](tests/README.md) |
| Window | [window/](window/README.md) |
| Workflow | [workflow/](workflow/README.md) |

The file formats themselves (`@TYPE` lines, sections, `.local.conf` overlays, `$DEV`) are on
[Configuration](../configuration.md); a guide links there instead of repeating them. The
[FoundationConfigurator](../foundation-configurator.md) reads a guide's `## Configuration Keys` and
`## Decisions` when it configures that command.

## Rules for writing a guide

- **FULL or STUB.** A command is configurable when its executable, or a library it loads, reads a
  `Unix/config` file (`conf_path NAME.conf`). The shared libraries every command loads (`config`,
  `apps`, `logfile`, `log`, `backup`, `spinner`, the drivers) do not count. A configurable command
  gets the FULL template and its Configuration Keys table names at least every such file; any
  other command gets the STUB template, unless it is configured through a shared file after all
  (the Logging commands and `logging.conf`): then it is FULL and lists that file. `tests/guides.bats`
  computes the files and checks the table.
- **Read the code, not only the help.** The line kinds, defaults and effects come from the
  executable and its libraries; the usage header can lag.
- **Generic values only.** A guide is a public page: `MyProject`, `MyRepo`, `Work`, `Laptop`,
  `My-Mac`, `you@example.com`, `~/Development/GitHub/MyRepo` or `$DEV/MyRepo`. Never a real host,
  repository, address, account or path from a `.local.conf` file.
- **Relative links** (`../../configuration.md#projectsconf`, `../../modules/Workflow.md#open-project`),
  checked by `tests/doclinks.bats`. Anchors follow docsify: lower case, punctuation dropped, spaces
  become hyphens (`### projects.conf` is `#projectsconf`).
- **No counts** of commands or guides: they rot on every add and remove.

## FULL template

The headings are fixed and in this order; the configurator parses `## Configuration Keys` and
`## Decisions`. Each Decisions item is a numbered question with exactly three sub-bullets:
`Options:`, `Default:`, `More detail:`.

`````markdown
# Command-Name

One sentence: what the command does, enough to know whether this is the right page.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`projects.conf`](../../configuration.md#projectsconf) | `path KEY DIR` | none | The folder a project key names |

## Decisions

1. The question, phrased as it would be asked out loud?
    - Options: the acceptable answers.
    - Default: what happens when the reader does nothing.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)

## Where to Put Values

Which overlay file (`Unix/config/NAME.local.conf`, created when missing), and how it combines with
the base: lines before the first section are added, a `[Section]` replaces the base one whole,
`-LINE` takes a base line back, `@TYPE` limits a line to machine types.

## Steps Overview

1. Add the `path` line
2. Check the configuration

## Step 1: Add the `path` line

What it controls, then a fenced `conf` fragment with generic values.

## Step 2: Check the configuration

`Test-ConfigurationSchema --quiet` and what to look for.

## Verification

Read-only commands only (a `--dry-run`, `--list`, `--check`, `Test-ConfigurationSchema`, `cat`).
Nothing here may change state.

## Complete Example

The overlay file(s) covering every line kind on the page, generic values.

## Related

- [`Command-Name` in the Module module reference](../../modules/Module.md#command-name)
- [Module configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
`````

## STUB template

For a command that reads nothing. The sentence under `## Configuration Keys` is verbatim
mandatory: it makes stubs greppable and the stub-to-full upgrade checkable.

`````markdown
# Command-Name

One sentence: what the command does.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Command-Name
Command-Name --flag VALUE
```

## Related

- [`Command-Name` in the Module module reference](../../modules/Module.md#command-name)
- [Module configuration guides](README.md)
`````

## Module index template

`guides/<module>/README.md`, one per folder; every guide of the folder appears in it.

`````markdown
# Module Module Configuration Guides

One sentence on what the module covers, and a link to
[the module reference](../../modules/Module.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Open-Project` | `projects.conf` | [Open-Project](Open-Project.md) |

## Commands With No Configuration

[Close-Workspace](Close-Workspace.md), [Focus-TerminalTab](Focus-TerminalTab.md)

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
`````

Custom-area guides sit one level deeper (`guides/custom/<module>/`), so their links take one more
`../` and point at the Custom page (`../../../custom/<module>.md#command-name`).
