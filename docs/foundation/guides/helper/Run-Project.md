# Run-Project

Brings up a project's Docker containers, opens its terminal tabs and types each tab's `run`
command into it (alias `rp`); without a project it shows a menu of the runnable ones.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`projects.conf`](../../configuration.md#projectsconf) | `[Project]` | `[Dotfiles]`, the repository itself, and the showcase `[ExampleProject]` | A project Run-Project can run; the menu lists those with `run` lines, in file order (base first). Windows orders this menu by its own RunnableProjectMappings list; the Mac has the one project order |
| [`projects.conf`](../../configuration.md#projectsconf) | `path KEY DIR` | `ROOT $DOTFILES_ROOT`, `DOCS $DOTFILES_ROOT/docs` | Named folders: a tab's directory, or a folder holding the project's own compose file |
| [`projects.conf`](../../configuration.md#projectsconf) | `tab KEY [DIR]` | `tab ROOT`, `tab DOCS` | The tabs that open, titled `<Project>.<KEY>`, in path `KEY` or `DIR` (`DEFAULT` is the home folder) |
| [`projects.conf`](../../configuration.md#projectsconf) | `run KEY COMMAND...` | `run DOCS npx docsify-cli serve` | What is typed into tab `KEY`; a project with one is runnable |
| [`projects.conf`](../../configuration.md#projectsconf) | `docker TARGET` | none | Containers brought up first: a `docker.conf` stack or a path key with its own compose file; of several stacks (database providers) only the one `--database-provider` or the menu picks starts |
| [`projects.conf`](../../configuration.md#projectsconf) | `step Docker on\|off` (before the first section) | on | Whether the Docker step runs when neither `--skip Docker` nor `--include Docker` is given |
| [`docker.conf`](../../configuration.md#dockerconf) | `stack NAME FILE` | `stack PostgreSQL docker-compose.postgresql.yml` | A shared Compose stack a `docker` line can name; a relative `FILE` is under the `directory` of `docker.conf` (`Docker`) |
| [`docker.conf`](../../configuration.md#dockerconf) | `timeout start SECONDS` | `180` | How long to wait for Docker Desktop's daemon when it has to be started |

## Decisions

1. Which projects should be runnable?
    - Options: a `[Project]` section with at least one `run` line; `Run-Project MyProject` or `rp MyProject`, several names run one after another.
    - Default: `[Dotfiles]`, which serves the docs, and `[ExampleProject]`, which starts the PostgreSQL stack and runs its API and UI.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
2. Which tabs should open, and what runs in each?
    - Options: one `tab KEY` line per tab and a `run KEY COMMAND` line for each tab that should start something (`dnr`, `nir`, `npm run dev`); a tab without `run` opens as a plain shell, and a `run` key without a `tab` line runs nothing.
    - Default: no tabs; the project is reported as having none to open.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
3. Does the project need containers first?
    - Options: `docker PostgreSQL` (a stack of `docker.conf`), `docker ROOT` (a path key whose folder holds a compose file), several lines, or none. Two or more stacks are alternatives (PostgreSQL or Oracle): one starts per run, picked with `--database-provider NAME` or the menu.
    - Default: none; nothing Docker-related happens.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
4. Should the Docker step run by default?
    - Options: `step Docker on` or `step Docker off` before the first section; `--skip Docker` and `--include Docker` override it per call, `--skip` winning (with a warning) when both are given. Any other step name stops the run before anything starts.
    - Default: on.
    - More detail: [`projects.conf`](../../configuration.md#projectsconf)
5. Does a shared stack or a slow machine need configuring?
    - Options: `stack NAME FILE` for another shared stack; `timeout start SECONDS` for the wait on Docker Desktop.
    - Default: the PostgreSQL stack and 180 seconds.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)

## Where to Put Values

`Unix/config/projects.local.conf` and `Unix/config/docker.local.conf`, created when missing. A
`[MyProject]` section in `projects.local.conf` adds the project; a section named like a base one
(`[Dotfiles]`) replaces it whole, so copy every line you keep. `Add-Project` writes such a section
for you. The `step` line goes before the first section, and the last one wins. `docker.conf` has
no sections: `stack` and `timeout` lines are added after the base ones; for a stack and for a timeout
the last line with the name wins (an overlay stack replaces the base stack of that name), and
`-LINE` takes a base line back.

## Steps Overview

1. Add the tabs and run commands
2. Add the Docker targets
3. Check the configuration

## Step 1: Add the tabs and run commands

```conf
[MyProject]
path ROOT $DEV/MyProject
path API $DEV/MyProject/src/MyProject.Api
path UI $DEV/MyProject-ui
tab API
tab UI
run API dnr
run UI nir
```

The same `tab` lines are what [Open-Project](../workflow/Open-Project.md)'s
`Open-ProjectTerminals` action opens. Running the project again closes its open tabs first, and
from one of its own tabs reuses that tab (its `run` command is typed in after Run-Project ends),
so a rerun never stacks a second set of servers.

## Step 2: Add the Docker targets

```conf
[MyProject]
docker PostgreSQL
docker ROOT
```

`docker PostgreSQL` names the shared stack of `docker.conf`; `docker ROOT` runs
`docker compose up -d` in the folder of path `ROOT`. Add the lines to the section of Step 1. When
Docker or one of these targets cannot be started, the project is skipped with an error and no tab
opens.

## Step 3: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a `tab` key without a `path`, a `run` key without a `tab` line (it would run nothing),
and a `docker` line that is neither a stack nor a path key.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n -A10 '^\[MyProject\]' Unix/config/projects.local.conf
grep -n '^stack\|^timeout' Unix/config/docker.conf Unix/config/docker.local.conf
```

## Complete Example

`Unix/config/projects.local.conf`:

```conf
step Docker on

[MyProject]
path ROOT $DEV/MyProject
path API $DEV/MyProject/src/MyProject.Api
path UI $DEV/MyProject-ui
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
tab API
tab UI
run API dnr
run UI nir
docker PostgreSQL
```

`Unix/config/docker.local.conf`:

```conf
stack Redis   docker-compose.redis.yml
timeout start 300
```

## Related

- [`Run-Project` in the Helper module reference](../../modules/Helper.md#run-project)
- [Helper configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
