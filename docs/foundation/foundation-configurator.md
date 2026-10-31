# FoundationConfigurator

The macOS twin of [WinuXConfigurator](https://ivanpavlak.github.io/WinuX/#/winux/configuration/winux-configurator). Point an AI assistant at this document and it interviews you, one decision at a time, and writes the answers into the Unix config files under `Unix/config`. Everything, nothing, or any subset you name: a whole file, one entry, or a task such as "add a repository and a workspace for MyProject" or "choose what Bootstrap does on this Mac".

The Windows session walks per-function guides and writes one `Configuration.local.psd1`. The Unix half has neither: it reads [small per-domain files](configuration.md), each documenting its own line kinds in its header, and the files refer to each other (a workspace names a project, browser groups and a layout; a layout names zone sets and apps). This document is the map through those files, and the decisions for each one live here rather than in separate guides.

## How to Start

Foundation ships the document as one of its product skills, `AI/Skills/foundation/foundation-configurator/`, linked into every harness the Mac deploys into by `Deploy-AiArtifacts` (the bootstrap's AiArtifacts step; a fork leaves it out with `exclude skills/foundation/foundation-configurator`). The skill resolves the checkout from its own symbolic link, so it works from any project:

- Claude Code: `/foundation-configurator`
- Codex CLI: `$foundation-configurator`
- Gemini CLI: listed by `gemini skills list`

It is also model-invoked, so "configure Foundation on this Mac with me" or "add a workspace for MyProject" reaches it without naming it. Without the skill deployed, open a session in the checkout and say:

> Read docs/foundation/foundation-configurator.md and configure the Unix half with me.

## What the Assistant Needs

| Capability | Required | What it is used for |
| ---------- | -------- | ------------------- |
| Read files from disk | Yes | `Unix/config/*`, their headers, this document |
| Ask questions in a conversation and read the answers | Yes | The interview itself |
| Write files to disk | No | Editing the config files directly. Without it, the assistant prints each fragment and you paste it in |
| Run shell commands | No | The read-only verification commands. Without it (or when you prefer to run them), the assistant prints them and you report the output |

## Ground Rules (for the AI assistant)

1. **Write only under `Unix/config` and to `Unix/Brewfile.local`, plus the backups of rule 6.** Never edit a file under `Windows/`, `Unix/lib`, `Unix/modules`, or anything else. The base file (`NAME.conf`) is the generic part every clone ships; a fork's own values go in its `NAME.local.conf` overlay, which a personal fork commits (Dotfiles does) and a generic clone keeps out of git. Write to the overlay - the `Add-*` writers do too - and edit a base file only to change what every clone ships (rule 2).

2. **Know what an overlay does before you write one.** `NAME.local.conf` (kept out of git in a generic repository, committed in a personal fork such as Dotfiles) **replaces** a same-named section of `NAME.conf` wholesale and adds new sections; lines before its first section are added to the base file's. Writing a one-line `[Default]` into `workspaces.local.conf` discards every other action of the base `[Default]`. To change one line of a section the overlay does not hold yet, copy the whole section from the base file into the overlay first, then change it there. A line before the first section can be taken back with `-LINE` in the overlay (`-item /Applications/X.app hidden`), and any line can be limited to machine types with `@TYPE`. Files with no sections at all (`dock`, `login-items`, `dotnet`, `conda-environments`, and the `step` and `repository-scope` lines of `bootstrap`) are all such lines: a list line in the overlay (`pin`, `item`, `env`, `sdk-channel`, `step`) adds to the base list, and for a single-value line (`clear`, `ef-version`, `directory`, `update-base`, `repository-scope`) the last line for this machine type wins.

3. **Never invent a machine-specific value. Ask.** Hostnames, repository URLs and owners, clone directories, bundle ids, URLs, title patterns, which desktop and zone a window goes in: all of it is knowledge only the user has. If the user does not know, leave it out and say so. The one exception is a value you can read rather than guess, and confirm: a bundle id from `osascript -e 'id of app "Name"'`, a remote URL from `git -C DIR remote get-url origin`, a host name from `scutil --get LocalHostName`. Show the value and ask before using it.

4. **No git, no deletions, no state-changing commands.** No `commit`, `push`, `pull`, `clone`, `reset`, `checkout --`, branch deletion, or force anything. No `rm`, no `mv`. Do not run commands that act on the machine: `Update-Repositories` clones and pulls, `Open-Workspace` launches apps, `deploy-*` and `chezmoi apply` create links, `Visualize-Layouts --update` rewrites layout files, and `Bootstrap`, `Set-SystemDefaults`, `Set-PowerSettings`, `Set-DockPins`, `Set-LoginItems`, `Install-DotnetEf`, `Install-DotnetSdks`, `Install-CondaEnvironments` and `Configure-NuGetConfig` change the Mac. Their `--list` and `--dry-run` forms are read-only and fine to run. Hand those to the user in a fenced `bash` block, one command per block, and let them run it.

5. **One question at a time, and every question has three exits.** An answer, "use the default" (state what it is, take it, move on), or "skip" (write nothing for it). Never batch questions, never treat silence as consent.

6. **Back up before the first write to each file, then show every write.** Before you first change a file in this session, copy it to `Backups/Unix/Config/<key>/<yyyy-MM-dd_HH-mm-ss>/<file name>`, where `<key>` is its path under `Unix/config` without `.conf`, slashes turned into dots (`workspaces`, `repositories`, `layouts.Work.MyProject_Work`) - the sink the `Add-*` writers use ([Backups on a Mac](backups.md)). A file you create needs no backup. After every write, show the exact lines and the exact file.

7. **Match the file's own format.** Each file's header comment is its specification; read it before writing. Keep the column alignment of the neighbouring lines, put a new section after the last section with one blank line before it, and never reorder or reformat what is already there.

8. **A checkout that also holds WinuX is configured on both halves.** When `<RepoRoot>/Windows/PowerShell/Configuration.psd1` exists next to `Unix/config`, the checkout is a fork of both upstreams ([Fork Model](fork-model.md)), the user runs the same configuration on Windows, and every entry you write that the Windows half reads too is written into `Windows/PowerShell/Configuration.local.psd1` (a layout into `Windows/PowerShell/Modules/Window/Layouts/<Type>/<Workspace>_<Type>.psd1`) in the same session, so the two halves never drift. Rule 1 yields to this rule for exactly those files. Those writes follow the [WinuXConfigurator](https://ivanpavlak.github.io/WinuX/#/winux/configuration/winux-configurator) protocol (`docs/configuration/winux-configurator.md` in the checkout, with the per-function guides under `docs/configuration/guides/`): never the base `Configuration.psd1`; a hashtable key merges per key and an array key replaces wholesale, so read the base array first; a backup of `Configuration.local.psd1` under `Backups/Windows/Config/Configuration.local/` before the first write; the guide's `## Where to Put Values` for the destination. Reuse the Unix answers and ask only what Windows cannot share - the FancyZones layout and zone per monitor, an executable path, a Windows-only value. Say which halves the session writes before the first question, show a counterpart write like any other write, and print the Windows checks (`Reload-PowerShellProfile`, `$global:Configuration.<Key>`) for the user's next Windows session when you cannot run them. What has no counterpart (AeroSpace, chezmoi, Homebrew, the Dock, a Mac-only application) stays on the Mac: say so and move on. A checkout without `Windows/` is Foundation alone: write nothing there and never create the folder.

    | Unix file | Windows counterpart |
    | --------- | ------------------- |
    | `repositories.conf` | `Universal.GitHub`, `RepositoryGroups` |
    | `browser-groups.conf` | `Universal.BrowserGroups` |
    | `projects.conf` | `PathTemplates.Projects.<Name>`, `ProjectActions`, `ProjectTerminals`, `RunnableProjectMappings` |
    | `vscode-folders.conf` | `VSCodeProjects` |
    | the `default` lines of `vscode-workspaces.conf` | `DefaultVSCodeWorkspaces` |
    | `workspaces.conf`, `workspace-templates.conf` | `WorkspaceActions`, `WorkspaceTemplates` |
    | `layouts/<Type>/<Workspace>_<Type>.conf` | `Modules/Window/Layouts/<Type>/<Workspace>_<Type>.psd1`, one per Windows machine type |
    | `machines.conf` | `HostnameToMachineType`, `BasePaths` |
    | `wake-on-lan.conf`, `pdfs.conf`, `dnd.conf`, `obsidian.conf` | `WakeOnLanConfig`, `AcrobatPdfGroups`, `CampaignResources`, `Obsidian` |
    | `Unix/Brewfile.local` | the app-list overlays (`*.local.csv`), for a package Windows has a winget, Scoop or Chocolatey id for |

    The full map, every Unix file with its Windows source, is the Files table of [Unix Configuration](configuration.md#files).

## Session Protocol

### Step 0: Prerequisites

1. **Find the repository.** `Get-RepositoryPath` prints it; otherwise resolve the skill's symbolic link. Confirm `Unix/config/workspaces.conf` exists under it.
2. **First run.** Run `Initialize-Configuration --dry-run`. When it would write anything (a fresh clone: no git identity, no `host` line for this Mac, no dev root), hand over `Initialize-Configuration` for the user to run - it asks for the identity, the Mac's name and machine type and the dev root, and writes `git.local.conf` and `machines.local.conf` - and continue once it has. Do not ask those questions again yourself.
3. **Establish the machine type and layout set.** Ask for (or read, rule 3) `scutil --get LocalHostName` and look it up in `Unix/config/machines.conf` (`host` lines, then `default`, then `layout-override`; a primary display at most `small-display-width` points wide uses the `small-display` set). The layout set decides which `Unix/config/layouts/<Type>/` folder a new layout goes into. List the sets that exist (`ls Unix/config/layouts`): `Test-ConfigurationSchema` requires every layout a workspace names to exist in every set.
4. **Read what exists.** For each file in scope, read it (and its `.local.conf` if present) before the first question. You are adding to it, never replacing it.
5. **Find the other half.** Check whether `<RepoRoot>/Windows/PowerShell/Configuration.psd1` exists. If it does, the session writes both halves (rule 8): read `Windows/PowerShell/Configuration.local.psd1` as well, and tell the user so before the first question.

### Step 1: Mode

| Mode | What it means |
| ---- | ------------- |
| **Everything** | Walk every file in the [walk order](#walk-order) |
| **By file** | The user names files (`repositories`, `browser-groups`, ...). Walk only those |
| **Task** | The user names an outcome ("add MyProject end to end", "add a repository"). Run the matching [task](#tasks) |
| **Review only** | Ask nothing, write nothing. Read the files, run `Test-ConfigurationSchema --quiet`, and report what is configured, what is missing, and what is broken |

### Step 2: Interview, write as you go

For each file in scope, ask the decisions of its [configuration guides](guides/README.md): find the guides whose `## Configuration Keys` table names the file (`grep -l '`NAME.conf`' docs/foundation/guides/*/*.md docs/foundation/guides/custom/*/*.md`), read each guide's `## Configuration Keys` and `## Decisions`, and ask those questions in order, once each when two guides share one; the Options and Default lines are what you offer. The [per-file notes](#decisions-per-file) below add what the guides leave to the walk (what to look up first, which answers depend on earlier files) and take precedence on those points. Write after each entry (a repository, a project, a group), not at the end of the file, so an interrupted session keeps what was answered. When an answer is already set from an earlier step, say so and do not ask again.

### Step 3: Verify per file

After each file, run (or print, rule 4) the read-only checks:

```bash
Test-ConfigurationSchema --quiet
```

It prints nothing when every reference resolves. Add the file's own check from its decision list. `Test-ConfigurationSchema` checks only the `@TYPE` prefixes of the provisioning files, so for them the real check is that file's own (a `--list` or `--dry-run`). Fix a reported problem before moving on, or tell the user what is left broken.

### Step 4: Finish

1. Summarise what was set, what was skipped, and what is still empty.
2. Hand the user the commands that act on what was configured (rule 4): the clone, the workspace open, the drawing update, the `Bootstrap --only STEP` that applies a provisioning file.
3. Do not hand over `Run-Tests` for a config change: the suites run against the fixture config in `Unix/tests/fixtures/config`, never `Unix/config`. `Test-ConfigurationSchema --strict` (step 3) is the check for the committed files.
4. In a checkout that holds both halves (rule 8), list the counterpart entries written into `Configuration.local.psd1` and the Windows layout files, and the checks to run there.

## Walk Order

Files that others refer to come first, so a reference is never written before its target.

| # | File | Why here |
| - | ---- | -------- |
| 1 | `machines.conf` | Machine type and layout set; everything per-machine resolves through it |
| 2 | `repositories.conf` | Where checkouts live; projects point at those directories |
| 3 | `apps.conf` | App tokens that workspaces (`Open-<App>`), layouts and Kill-All name |
| 4 | `browser-groups.conf` | Groups that workspaces open and layouts match by title |
| 5 | `projects.conf` | Projects that workspaces open |
| 6 | `vscode-folders.conf`, `vscode-workspaces.conf` | What `Open-VSCode` opens for a project |
| 7 | `zones.conf`, `layouts/<Type>/` | Zone sets, then where each window of a workspace goes |
| 8 | `workspace-templates.conf`, `workspaces.conf` | Ties everything above together; a template stamps out sibling workspaces |
| 9 | `bootstrap.conf`, then `Unix/Brewfile.local` with its `package-pins.conf` (the formulae Upgrade-All keeps where they are), and the files of the steps it turns on: `system-defaults.conf`, `power.conf`, `dock.conf`, `login-items.conf`, `dotnet.conf`, `conda-environments.conf` | Provisioning: which [Bootstrap](bootstrap.md) steps run on this Mac, then what each one sets |
| 10 | The rest | Ask the Decisions of the guides that name each file (its header comment as a fallback): `obsidian`, `git` (`status-arguments`; the identity is Step 0's), `docker`, `theme`, `wallpapers`, `language`, `special-folders`, `greeting`, `kill-all`, `window`, `wake-on-lan`, `pdfs`, `dnd`, `ai-artifacts` (which harnesses this Mac deploys into, the vendored sources, `exclude` and `use` lines), `ai-profiles` (the profiles, their Plans and the repository policy of each: levels, the default level, no-CI merges; a Mac with both halves keeps it in step with `AiProfiles` of the Windows configuration), `ai-harnesses` (only an app the catalogue lacks), `ai-marketplaces`, `ai-mcp-servers` (the apps and the servers; never a token, only the variable holding it), `vscode-profiles`, `backups`, `logging`, `spinners`, `translate` |

## Decisions per file

The guides carry each command's questions; these notes are the walk-level additions for the files above.

### machines.conf

1. **Is this Mac mapped?** Initialize-Configuration (Step 0) writes this Mac's `host` line and its `dev-root`. If `host <LocalHostName>` is still missing, ask which type it is (one of the `type` lines, such as `Work` or `Laptop`, or a new one, which needs its own `type` line). Default: leave it unmapped and it resolves to `default`.
2. **Several Macs?** Their `host` lines go in `machines.local.conf`, with a `type` line for every new machine type (the base file ships only `Test`).

### repositories.conf

Line: `NAME PATH-OR-URL DIR [shallow]` under a `[Group]`. Relative paths append to `base`.

1. **Group.** Which existing group (the menu of `Update-Repositories`), or a new one. Default: `Private`.
2. **Name.** The token `Update-Repositories NAME` takes. Default: the repository name.
3. **Source.** `/Owner/Repo.git` under `base` (show the `base` line), or a full URL for another host. If a checkout already exists, read its remote (rule 3) and confirm.
4. **Directory.** Where it is cloned. Default: `$DEV/<Name>`, the dev root (`machines.conf` `dev-root`, else the folder holding this clone) that the existing entries use; write paths under the dev root as `$DEV/...`, never spelled out.
5. **History.** Full clone, or `shallow` (`--depth 1`, still able to commit and push) for a repository with a large history such as a notes vault. Default: full.

Check: `grep -n NAME Unix/config/repositories.conf`; the user runs `Update-Repositories NAME` (clones when missing, pulls otherwise).

### apps.conf

Line: `app TOKEN BUNDLE-ID [BINARY]`.

1. **Which apps does the workspace or layout need that have no `app` line?** For each: the token (short, PascalCase, what layouts will name), and its bundle id (read with `osascript`, rule 3).
2. **Binary.** Only when a launcher must pass arguments to a running instance (browsers). Default: omit.

### browser-groups.conf

Section `[Group]` (dots nest: `[GitHub.MyProject]`); lines `URL` or `Name URL`.

1. **Group name.** Convention for a project's repository page: `[GitHub.<Project>]`, or a named line `<Project>Repository URL` inside `[GitHub]`/`[GitHub.Personal]` so `Open-Browser <Project>Repository` opens just that page. Read how sibling projects did it and offer the same shape.
2. **URLs, in order.** The first URL decides the window title a layout matches (Firefox titles a window after its active tab). Note it for the layout step.

Check: the group name appears once (`grep -n -i '^\[.*NAME' Unix/config/browser-groups.conf`).

### projects.conf

Section `[Project]`; lines `path KEY DIR`, `action ...`, `tab KEY [DIR]`, `run KEY COMMAND`, `docker TARGET`.

1. **Root.** `path ROOT DIR`. Default: the `DIR` from `repositories.conf`.
2. **More paths?** API, UI, DOCS... Default: none.
3. **Actions.** Default: `action Open-VSCode <Project>` and `action Open-ProjectTerminals <Project>`.
4. **Terminal tabs.** Default: `tab ROOT`. Each tab is titled `<Project>.<KEY>`.
5. **Run commands.** What `Run-Project` types into which tab (`run ROOT npm run dev`). Default: none.
6. **Docker.** A `docker.conf` stack or a path key with its own compose file. Default: none.

### vscode-folders.conf, vscode-workspaces.conf

1. **Does `Open-VSCode <Project>` need an entry?** Read both headers; ask only when the project's folder differs from its `path ROOT` or it has a `.code-workspace`. Default: skip.

### zones.conf and layouts

A layout is `Unix/config/layouts/<Type>/<Workspace>_<Type>.conf` holding one `[Workspace]` section: `layout DESKTOP ZONESET` lines, then `DESKTOP ZONE APP [TITLE]` lines. Zone sets come from `zones.conf` (`Visualize-Layouts --display-available-layouts` draws them all, read-only).

1. **Model on an existing workspace?** Offer the closest existing layout (a project workspace usually mirrors `Dotfiles` or `WinuX`) and show it. Default: yes, the closest one.
2. **Per desktop: the zone set, then which window goes in each zone** (an `apps.conf` token or a role: `Terminal`, `Browser`), and its title pattern (a plain word is a substring, `*x*` a wildcard, anything else a regex). A browser window's pattern matches the first URL of its group.
3. **Which layout sets?** Every set in `Unix/config/layouts/` must get a file, or `Test-ConfigurationSchema` reports the workspace. Default: the same layout in every set, adjusted only where the user says the screen differs.
4. **Project variants?** Only for a workspace opened for different projects (`w Client MyProject`): which desktops look different for which project. Each becomes a `project A,B` block after the base lines whose `layout` and window lines replace that desktop's. Default: none.

Check: `Visualize-Layouts NAME` draws it (read-only). The user runs `Visualize-Layouts NAME --update` to store the drawing in the file.

### workspaces.conf

Section `[Workspace]`, one action per line, run top to bottom - or a template instance (`template NAME` plus `set`, `replace`, `drop` and `add` lines) of `workspace-templates.conf`.

1. **From a template?** Read `workspace-templates.conf` and its `.local.conf` (a fork's templates live in the overlay) and show each template with its variables. A project workspace usually fits `Project` (Claude, the project, its `<Workspace>Repository` group, the layout): then it is `template Project` plus a `set` for a variable that differs and a `replace`, `drop` or `add` for an action that differs. Default: the template the closest sibling uses. `Add-Workspace NAME --template Project --set Repository=Group` writes it.
2. **Actions, in order** (a plain workspace only). Show the closest existing workspace and ask what differs. A line only some projects need gets a `+A,B` scope (`+!A,B` for all but those).
3. **Default workspace?** Only if the user wants a bare `w` to open it. Default: no change.

Check: `Test-ConfigurationSchema --quiet` (the template resolves, every action resolves, the layout exists in every set). The user runs `w <Workspace>` and then `cw`.

### bootstrap.conf

`step NAME on|off` and `repository-scope` lines before the first section; sections `[Packages]`, `[Spotlight]`, `[Firewall]`, `[SoftwareUpdate]` hold the inline steps' values and `[PersonalSteps]` the fork's own commands. `bootstrap.local.conf` is layered on top: its `step` lines win, its sections replace whole sections. Show `Bootstrap --list` (every step, its default and its current state) before the first question.

1. **Every machine or one type?** The fork's choices go in `bootstrap.local.conf` (rule 2); a choice for one machine type only gets an `@TYPE` prefix (`@Laptop step Power on`). Default: every machine of the fork.
2. **Which off-by-default steps to turn on**, one at a time, with what each does (the step table of [Bootstrap a Mac](bootstrap.md#steps)): RepositoryUpdate, Power, Spotlight, Firewall, SoftwareUpdate, Rosetta, FirefoxProfile, VSCodeProfiles, the three AI steps (AiArtifacts, AiMarketplaces, AiMcpServers), AiProfileInit (the AI profile's sign-ins through Initialize-AiProfile, which waits at the terminal; only with an AI profile), ObsidianCli, DotnetSdks, NuGetConfig, NpmConfig, DockerDesktop (with its `cli-install` line of `docker.conf`, see [Configure-DockerDesktop](guides/bootstrap/Configure-DockerDesktop.md)), UpgradeAll, Logout. Say which need the administrator password (*sudo*) and which ask on the terminal. InitializeConfiguration, RenameMachine and Permissions are not asked: they run only with `--with-initial-setup`, whatever their `step` line says. Default: leave off.
3. **Which on-by-default steps to turn off.** Default: none.
4. **Repository scope** (when RepositoryUpdate is on): `All`, or `repositories.conf` group names, read from its `[Group]` sections first. Group names only: a repository's name fails the step, so a set of repositories becomes a group of its own. Default: `All`.
5. **Firewall** (when on): `globalstate`, `stealthmode`, `allowsigned`, `allowsignedapp`, each on or off. Default: the base file's lines.
6. **Software update** (when on): which `defaults DOMAIN KEY TYPE VALUE` lines (automatic check, download, security installs, macOS and App Store installs). Default: the base file's lines.
7. **Spotlight** (when on): `index VOLUME on|off` per volume. Default: `index / on`.
8. **Packages:** an extra `trust` entry only when a Brewfile adds a cask from a third-party tap; another `brewfile` only when the user keeps one elsewhere. The packages themselves go in `Unix/Brewfile.local` ([below](#brewfilelocal)). Default: nothing.
9. **Personal steps:** anything the fork runs on every provisioning that no step covers, one `COMMAND [ARG...]` line each, in order. Lines are split into words with no shell, so a pipe, `&&` or a quoted argument becomes a script of the user's own that the line names. Default: none.

Check: `Bootstrap --list` shows the new states (the RUNS column confirms a `step` line took effect); `Bootstrap --dry-run` prints what a run would do.

### Brewfile.local

This machine's packages on top of `Unix/Brewfile`, the `WinGetApps.local.csv` of Windows. There is no writer command for it (Windows' Save-AppCsvOverlay is not ported): you edit it, with the backup of rule 6 under the key `Brewfile.local`.

1. **Which apps and tools?** One per question, by name. Look the package up before writing it: `brew info --cask NAME` or `brew info NAME` (read-only) gives the exact token and says whether it is a cask or a formula; one that does not exist is said so and written nowhere.
2. **Where in the file?** Under the `# --- Group ---` heading it belongs to, in the file's column layout, each line with a comment saying what it is for (`cask "rustdesk"  # remote desktop`). An app the user wants listed but not installed is a commented line (`#cask "NAME"`).

Check: the user runs `brew bundle check --file Unix/Brewfile.local` (it lists what is not installed yet) and installs with `brew bundle --file Unix/Brewfile.local`.

### system-defaults.conf

`[Group]` sections of `defaults`, `currenthost`, `delete`, `mkdir`, `command`, `restart` and `note` lines; an empty `[Group]` in `system-defaults.local.conf` turns a group off. Show `Set-SystemDefaults --list` first.

1. **Per group, keep, change or turn off?** Walk the groups in file order (Dock, Finder, Keyboard, Trackpad, Screenshots, HotCorners, MenuBar, Windows, Appearance, Apps, Theme). A changed group goes into the overlay whole, copied from the base and then edited (rule 2). For a change, show the current line and ask the new value; add only a key the user names or one found for them in the key inventory, `Backlog/MacOS/Research/MacOSDefaultsInventory.md` (rule 3). Default: keep.
2. **Only on one machine type?** Prefix the line with `@TYPE`. Default: everywhere.
3. **A group of the user's own?** A new `[Group]` after the last one, with the `restart` or `note` line its keys need to show. Default: none.

Check: `Set-SystemDefaults --dry-run`.

### power.conf

`[All]`, `[AC]`, `[Battery]` sections of `KEY VALUE` pmset lines (minutes, 0 = never; 1/0 switches). Set-PowerSettings applies `[AC]`, then `[Battery]`, then `[All]`, so a key that differs per source must leave `[All]`, or `[All]` overrides it on both. `[Battery]` is skipped on a Mac without one.

1. **Display sleep and system sleep**, the same on both sources (`[All]`) or per source (the key moves out of `[All]` into both `[AC]` and `[Battery]`). Default: the base file's values.
2. **Wake for network access on the charger** (`womp 1`, needed for Send-WakeOnLan). Default: on.
3. **Battery extras** (Power Nap, dimming). Default: the base file's lines.

Check: `Set-PowerSettings --list` (configured against current per source; a key this Mac does not support is flagged).

### dock.conf and login-items.conf

`dock.conf`: `clear on|off`, then `pin PATH`, `spacer`, `folder PATH [options]` in Dock order. `login-items.conf`: `item PATH [hidden]`, only ever added.

1. **Exact Dock or additive?** `clear on` removes every pin not listed (Set-DockPins backs the Dock up into `Backups/Unix/System/DockLayout/` first). Default: the file's current setting.
2. **Apps, in order**, as `/Applications/<Name>.app` paths (check each exists, rule 3). The overlay's pins follow the base ones; a base pin the user does not want is taken back with `-pin PATH`. A `spacer` with `clear on` rebuilds the Dock on every run: say so before writing one. Then folders on the right, with their view options. Default: the current list.
3. **Login items:** which apps start at login, and which of them hidden. A base item the user does not want is taken back with `-item PATH [hidden]`; one macOS already starts stays until the user removes it in System Settings > General > Login Items. Default: the current list.

Check: `Set-DockPins --list` and `Set-LoginItems --list`.

### dotnet.conf and conda-environments.conf

`dotnet.conf` holds the lines of four commands: `ef-version` (Install-DotnetEf, step DotnetEf), `sdk-channel` (Install-DotnetSdks, step DotnetSdks), `nuget-template` and `nuget-config` (Configure-NuGetConfig, step NuGetConfig), and `projects-search-path` (Determine-DotnetDependencies, no step). `conda-environments.conf` holds `directory`, `env` and `update-base` (Install-CondaEnvironments, step CondaEnvironments).

1. **dotnet-ef version** (`ef-version`): a version such as `8.0.11`, a wildcard such as `8.*` matching the projects' EF Core, or empty for the latest. It applies only when dotnet-ef is not installed yet. Default: empty.
2. **Older SDKs** (only when the DotnetSdks step is on): one `sdk-channel CHANNEL` line for each SDK a project needs that no Homebrew `dotnet-sdk` cask ships (`sdk-channel 6.0`). The current SDKs belong in a Brewfile instead. Default: none.
3. **NuGet** (only when the NuGetConfig step is on): the template and destination paths. The GitHub username and token are typed at the step's own prompt, never stored here. Default: the base paths.
4. **Project search path** (`projects-search-path`): where Determine-DotnetDependencies looks for projects, written under the dev root as `$DEV/...`. Default: no line, the dev root.
5. **Conda environment folder** (`directory`): a folder of macOS exports (`osx-arm64` or `noarch`, conda-forge); a Windows export does not build. Default: `Conda/Environments/macOS`.
6. **Conda environments:** which files of that folder to create (`env NAME`, or no `env` line for all of them), and whether to update base first (`update-base`, which needs the defaults channel's Terms of Service accepted). Default: the current lines, `update-base off`.

Check: `Install-DotnetEf --dry-run`, `Install-DotnetSdks --dry-run`, `Configure-NuGetConfig --dry-run`, `Install-CondaEnvironments --list`.

### npm.conf

`npm.conf` holds the lines of Configure-NpmConfig (step NpmConfig): `npmrc` and one `registry URL [SCOPE]` line per private registry.

1. **Registries** (only when the NpmConfig step is on): which private registries need a token (the base ships GitHub Packages, `https://npm.pkg.github.com/`), and whether to route a scope there (`registry https://npm.pkg.github.com/ @my-org`), needed only when the projects do not ship their own `.npmrc` with that scope line. The token is typed at the step's own prompt, never stored here. Default: the base registry, no scope.
2. **npmrc** (`npmrc`): where the token goes. Default: `~/.npmrc`.

Check: `Configure-NpmConfig --dry-run`.

## Tasks

### New project end to end

The common case: a repository becomes a one-command workspace. Ask the project name once and reuse it everywhere. Walk, writing each before the next:

1. `repositories.conf`: the repository line.
2. `browser-groups.conf`: the project's repository page (and anything else its workspace opens that has no group yet).
3. `projects.conf`: the project section.
4. `layouts/<Type>/<Project>_<Type>.conf`: one per layout set.
5. `workspaces.conf`: the workspace section.
6. Verify: `Test-ConfigurationSchema --quiet`, `Visualize-Layouts <Project>`. Hand over: `Update-Repositories <Project>`, `w <Project>`, `cw`.

### Provision this Mac

Choose what `Bootstrap` does here, then what each chosen step sets. Walk `bootstrap.conf` first, then only the files of the steps that end up on, in the walk order. Verify each with its check. Hand over `Bootstrap --dry-run`, then `Bootstrap` (or `Bootstrap --only STEP` for one step); `--with-initial-setup` only on a fresh Mac.

### Add a repository / browser group / project / workspace / layout

Run that file's decisions only. Adding a workspace whose project, groups or layout do not exist yet becomes the end-to-end task; say so and ask before widening scope.

## If the Session Is Interrupted

The files are the record, not the conversation. Re-read them, run `Test-ConfigurationSchema --quiet` (a half-finished task shows as a broken reference: a workspace naming a missing layout, a project with no repository), and resume at the first file in the walk order that is incomplete.

## Related

- [Unix Configuration](configuration.md) - every file and its format
- [Configuration guides](guides/README.md) - one page per command: the files it reads and the decisions this session asks
- [macOS Workspaces](macos-workspaces.md) - how `w` and `cw` use workspaces, layouts and zones
- [Bootstrap a Mac](bootstrap.md) - the steps `bootstrap.conf` switches and what each runs
- [Configuration module](modules/Configuration.md) - `Add-Workspace`, `Add-Project`, `Add-BrowserGroup`, `Add-WindowLayout` and `Test-ConfigurationSchema`, the writers this session mirrors
- [WinuXConfigurator](https://ivanpavlak.github.io/WinuX/#/winux/configuration/winux-configurator) - the Windows session
- [AI Skills](https://ivanpavlak.github.io/WinuX/#/winux/ai/skills) - how skills are linked into every harness
