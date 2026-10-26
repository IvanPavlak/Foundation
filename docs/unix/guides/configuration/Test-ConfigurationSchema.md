# Test-ConfigurationSchema

Checks that the `Unix/config` files agree with each other - workspaces, templates, layouts, zone
sets, projects, browser groups and machine types - and reports every broken reference.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

Test-ConfigurationSchema has no settings of its own: it reads these lines (base and overlay
together) to check them against each other.

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `default-workspace NAME` | `Default` | Must name a section |
| [`workspaces.conf`](../../configuration.md#workspacesconf) | `[Workspace]` action lines, `+A,B` and `%SET` scopes | the base workspaces | Each action is a command, an `Open-<App>` of `apps.conf` or `Return`; `Open-Project`, `Open-Browser`, `Set-WorkspaceWindowLayout` and scopes name what exists (a `%SET` scope a `type` line or a `layouts/<Set>/` folder) |
| [`workspace-templates.conf`](../../configuration.md#workspace-templatesconf) | `[Template]`, `var`, `:ID` | none | Checked through each workspace that uses it (known template, every placeholder has a value, `replace`/`drop`/`add` keys match, no cycle); a template no workspace uses is reported |
| [`layouts/<Type>/<Workspace>_<Type>.conf`](../../configuration.md#files) | `[Workspace]`, `layout`, window lines, `project` | the `Test` set | One section named after the file; zone sets and zones exist; apps are tokens or roles; variant projects exist |
| [`zones.conf`](../../configuration.md#zonesconf) | `ZONESET COLUMN...`, `alias` | `Zero` to `Nine` | The zone sets and zones layouts may use |
| [`projects.conf`](../../configuration.md#projectsconf) | `action`, `tab`, `run`, `docker` | `[Dotfiles]` and `[ExampleProject]` | Actions are commands; tab keys name a path key; run keys name a tab key (a `run KEY` whose key is only a `path` is reported: Run-Project types commands only into tabs, so it runs nothing); docker names a `docker.conf` stack or a path key |
| [`browser-groups.conf`](../../configuration.md#browser-groupsconf) | `[Group]`, `Name URL` | the example groups | The names `Open-Browser` and `dnd.conf` may use: a group path, its last segment or a URL label |
| [`machines.conf`](../../configuration.md#files) | `type`, `host`, `default`, `small-display`, `layout-override`, `dev-root` | `type Test`, `default Test` | The valid machine types every `@TYPE` prefix and `layouts/<Type>/` set must be; the layout sets a machine uses; the dev root must be a folder |
| [`apps.conf`](../../configuration.md#files) | `app` tokens, `role` lines | the shipped apps | What an `Open-<App>` action and a layout window may name |
| [`docker.conf`](../../configuration.md#dockerconf) | `stack NAME FILE` | `PostgreSQL` | What a project `docker` line may name |
| [`dnd.conf`](../../configuration.md#files), [`pdfs.conf`](../../configuration.md#files) | `pdf`, `browser`; `[Group]` | none | A campaign's PDF and browser groups exist |
| [`vscode-workspaces.conf`](../../configuration.md#files) | `default WORKSPACE NAME`, `directory` | the workspaces `directory` | The workspace exists and `NAME.code-workspace` is in the directory |
| [`ai-artifacts.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `deploy`, `exclude`, `use` | `use rules CoreAiRules` | Every `deploy` name is a section of `ai-harnesses.conf`; `exclude` entries are `KIND/NAME` or `KIND/SOURCE/NAME`; `use` lines are `KIND NAME` |
| [`ai-harnesses.conf`](../../configuration.md#ai-artifactsconf-and-ai-harnessesconf) | `[Harness]` destination lines | the inactive catalogue | Every line is `KIND PLACEMENT FILES [+HOOK...] PATH` with a known kind, placement and hook |
| [`git.conf`](../../configuration.md#files) | `name`, `email` | none | A note (not a problem) when neither these lines nor the global git config hold the identity |

`apps.conf`, `docker.conf`, `pdfs.conf`, `zones.conf` and `browser-groups.conf` are read only as
the targets of those references; their own lines are not checked. Every other file
(`backups.conf`, `translate.conf`, `spinners.conf`, `bootstrap.conf`, ...) is checked only for its
`@TYPE` prefixes, as the Windows twin checks only framework keys and section shapes: a bad line
there shows up when its command runs.

## Decisions

1. Should a problem fail the run?
    - Options: `--strict` exits 1 when there is any problem (tests, Bootstrap); `--quiet` prints only the problems.
    - Default: every problem is a warning and the exit status is 0, so the shell keeps working with a degraded configuration.
    - More detail: [`Test-ConfigurationSchema` in the Configuration module reference](../../modules/Configuration.md#test-configurationschema)
2. Which machine types are valid?
    - Options: one `type NAME` line per type in `machines.local.conf`; every `host`, `default`, `small-display` and `layout-override` type, every `@TYPE` prefix of any file and every `layouts/<Type>/` folder must be one of them.
    - Default: `type Test` only.
    - More detail: [Files](../../configuration.md#files)
3. Which layout sets must hold every layout a workspace names?
    - Options: the sets `machines.conf` maps a host, the default and the small display to, each through its `layout-override`; a set no machine uses (a fork's `Test`) need not hold every layout.
    - Default: without `machines.conf`, every set.
    - More detail: [Files](../../configuration.md#files)
4. Is an unset git identity a problem?
    - Options: set `name` and `email` in `git.local.conf` (Initialize-Configuration asks for them), or in the global git config.
    - Default: a note only - not counted, so `--strict` passes, and left out by `--quiet`, since a fresh clone has no identity until its first Bootstrap run.
    - More detail: [`Test-ConfigurationSchema` in the Configuration module reference](../../modules/Configuration.md#test-configurationschema)

## Where to Put Values

Nothing is written. Fix a reported problem in the overlay of the file it names
(`Unix/config/NAME.local.conf`), or in the layout file it names under `Unix/config/layouts/`.

## Steps Overview

1. Run the check
2. Fix what it reports

## Step 1: Run the check

```bash
Test-ConfigurationSchema --quiet
```

## Step 2: Fix what it reports

Each warning names the file and section, for example a workspace naming a project that has no
section: add it to `projects.local.conf`.

```conf
[MyProject]
path ROOT $DEV/MyProject
action Open-VSCode MyProject
```

## Verification

```bash
Test-ConfigurationSchema
Test-ConfigurationSchema --strict --quiet; echo "exit $?"
```

## Complete Example

A consistent set of overlays: the workspace's project, browser group and layout all exist, and
the layout's machine type is a `type` line.

`Unix/config/machines.local.conf`:

```conf
type Work
default Work
```

`Unix/config/git.local.conf` (no git identity note):

```conf
name My Name
email me@example.com
```

`Unix/config/projects.local.conf`:

```conf
[MyProject]
path ROOT $DEV/MyProject
action Open-VSCode MyProject
```

`Unix/config/browser-groups.local.conf`:

```conf
[MyGroup]
MyRepo https://github.com/MyUser/MyRepo
```

`Unix/config/workspaces.local.conf`:

```conf
[MyProject]
Open-Project MyProject
Open-Browser MyGroup
Set-WorkspaceWindowLayout MyProject
```

`Unix/config/layouts/Work/MyProject_Work.conf`:

```conf
[MyProject]
layout 1 Five
1 Left    Code
1 Right   Browser   *MyRepo*
```

## Related

- [`Test-ConfigurationSchema` in the Configuration module reference](../../modules/Configuration.md#test-configurationschema)
- [Configuration configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
