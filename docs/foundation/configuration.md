# Unix Configuration

The Unix half reads small per-domain files in `Unix/config` instead of one configuration hub.
They are the second copy of the Windows data (converted from `Configuration(.local).psd1` and
the layout files on 2026-09-25, hand-maintained since) until WinuX adopts one OS-agnostic format.
To fill them in by interview, run the [FoundationConfigurator](foundation-configurator.md) (`/foundation-configurator`).

## Shared format

- `#` starts a comment line; blank lines are ignored.
- `[Name]` opens a section; names compare case-insensitively.
- Other lines are whitespace-separated fields; a trailing free-text field (a title pattern, a
  command) may contain spaces.
- `NAME.local.conf` next to `NAME.conf` replaces same-named sections and adds lines before the
  first section - the `Configuration.local.psd1` idea, per file. A generic repository keeps
  these overlays out of git; a personal fork may commit them, as Dotfiles does.
- A data line of any file may start with `@TYPE` (or `@Laptop,Work`): it applies only on those
  machine types of `machines.conf` (its `type` lines), and every other machine skips it. Every reader applies the
  filter, so it works for every line kind, `step` lines included (`@Laptop step Power on`); a
  line without the prefix applies everywhere. Sections are not filtered as a whole: prefix their
  lines. A prefix naming no `type` line applies nowhere: Test-ConfigurationSchema reports it, and
  a command run with `-v` logs it as it reads the file.
- A workspace line (in `workspaces.conf` and `workspace-templates.conf`) may also start with a
  project scope, after any `@TYPE`: `+A,B LINE` runs only when one of those projects is among the
  open's projects, `+!A,B LINE` only when none of them is. It is the `Project` scope of Windows;
  machine variation stays with `@TYPE` lines.
- Before a project scope, a workspace line may start with a layout-set scope: `%A,B LINE` runs
  only when the layout set this machine applies (`layout-override`, else `small-display`, else the
  machine type; see `machines.conf`) is one of them. It is the `LayoutMachine` of Windows: where
  `@TYPE` follows the machine type, `%` follows the layout actually applied, so a window count can
  match it (`%Work Open-Browser --no-menu --instances 2`). Test-ConfigurationSchema reports a set
  that is no `type` line and no `layouts/<Set>/` folder.
- A workspace line ending in a lone `&` runs in the background (`Open-DBeaver &`): Open-Workspace
  starts it and goes on with the next action, and waits for every background action before the next
  `Set-WorkspaceWindowLayout`, `Focus-VirtualDesktop`, `Terminate-WindowsTerminalTabs` or `Return`
  and at the end of the workspace, so the layout still sees every window. Only commands that just
  start apps, terminal tabs or containers may: `Open-Application` and every `Open-<App>`,
  `Open-Project`, `Open-ProjectTerminals`, `Open-VSCode`, `Open-VSCodeWorkspace`, `Open-Obsidian`,
  `Open-ClaudeDesktop`, `Open-Docker`, `Open-Acrobat` and `Start-Containers`. The browser openers
  stay in place: each takes the window that appears after its own launch. Any other command marked
  `&` runs in place with a warning, and Test-ConfigurationSchema reports it. A background action
  cannot ask anything (a menu fails it), its output appears when it is waited for, and its failure
  is reported like any other. WinuX has no equivalent; workspaces without `&` open as before.
- Before the first section, a line `-LINE` removes every earlier line equal to `LINE` (case and
  whitespace runs ignored), so an overlay can take back a line of the base file, as the `-<id>`
  rows of the Windows `.local.csv` overlays do: `-item /Applications/Tailscale.app hidden` in
  `login-items.local.conf`. It takes `@TYPE` like any line. Sections need no removal: an overlay
  section replaces the base one whole.
- Where lines before the first section are keyed by a name - a `KEY value` setting, the `app`,
  `browser` and `role` lines of `apps.conf` by token, the folder names of `vscode-folders.conf`,
  the `stack` and `timeout` lines of `docker.conf`, the styles of `spinners.conf`, the
  `onefetch-color` indices of `greeting.conf` - the last line of that name for this machine type
  wins, so an overlay line overrides the base line of the same name without `-LINE`; a menu lists
  each name once.
- Paths may use `~` and `$VARIABLES`; `$DOTFILES_ROOT` is always set, and `$DEV` is the dev root
  (the `{Dev}` of Windows): the `dev-root` line of `machines.conf` for this machine type, else
  the folder that holds this clone (`$DEV/MyRepo`), whatever `DEV` the environment holds.

## Base and overlay

Every base file holds only what a generic clone needs; a fork's own values live in its
`NAME.local.conf` overlays (Dotfiles commits them, a generic clone keeps them out of git), the
`Configuration.psd1` / `Configuration.local.psd1` split of Windows. Every line kind of every file
takes `@TYPE`. What the base files ship:

| File | The base file ships | A fork's overlay adds |
| --- | --- | --- |
| `machines.conf` | `type Test`, `default Test`, `small-display-width 3000` | its `type` lines, `host`, `default`, `small-display`, `layout-override`, `dev-root` (Initialize-Configuration writes `host` and `@TYPE dev-root` on a fresh clone) |
| `git.conf` | comments only | `name`, `email`: the git identity Initialize-Configuration writes and the GitIdentity step sets; `status-arguments` for GitStatus (without one `gs` runs `git status --short`, the WinuX base) |
| `layouts/` | the `Test` set (Default, Empty, Example, Fullscreen, SecureBrowser, Test) | its own sets (`Work/`, `Laptop/`), one file per workspace |
| `workspaces.conf` | `default-workspace Default`, the layout settings, `benchmark off` with `benchmark-display table` and history 10, Example, Test (its Mac apps), Fullscreen, Empty (closes no tab), Default (closes every tab, the calling one last), SecureBrowser - WinuX's base values | its workspaces, its benchmark lines (Dotfiles: off, history 50, and Empty and Default closing only the calling tab, as its Windows overlay) |
| `workspace-templates.conf` | a commented example | its templates (Dotfiles: `Project`, `Notes`) |
| `projects.conf` | `[Dotfiles]`, the repository itself, with a ROOT tab and a DOCS tab running the docs server (WinuX's base self project), and the showcase `[ExampleProject]` (API and UI tabs, the PostgreSQL stack) | its projects (Dotfiles: one ROOT tab serving the docs, as its Windows overlay) |
| `browser-groups.conf` | example groups the base workspaces open (Google, AI, Email, Calendar, News, YouTube) | every group it uses, the example names included |
| `repositories.conf` | `base https://github.com`, the update schedule, `[Private]` with the repository itself | its `base`, `startup on`, its groups |
| `vscode-folders.conf`, `vscode-workspaces.conf` | the repository folder and `ExampleProject`, the workspaces `directory` | its folders, its `default` lines |
| `dock.conf`, `login-items.conf` | `clear off` and WezTerm; AeroSpace | `clear on` and its pins; its login items (`-item` takes one back) |
| `theme.conf`, `wallpapers.conf` | the SetWallpaper step, the shipped `WinuX_Test` prompt, no `list-color` line (eza's own colours); `Black.jpg` / `White.png` for Test and Default | its `theme`, `prompt-theme` and `list-color` lines (Dotfiles: the user in orange, the date in red); its `[Dark]` / `[Light]` |
| `kill-all.conf` | every step, keep Terminal, Finder and AeroSpace, quit Code | its `step`, `keep` and `quit` lines |
| `obsidian.conf` | an example vault `directory`, a commented `settings` example | its vault, its `settings` folder |
| `system-defaults.conf`, `power.conf`, `bootstrap.conf` | the generic groups, steps and values | whole sections it changes (an empty one turns a group off), its `step` lines |
| `docker.conf`, `conda-environments.conf` | the PostgreSQL stack, timeouts, cleanup actions; the macOS folder | its stacks; its `env` lines |
| `special-folders.conf` | the line kinds and a commented example, no folder | its `folder` lines (Dotfiles: Downloads and Screenshots on the Desktop) |
| `language.conf` | the line kinds and a commented example, no entries | its display languages, locales, keyboard layouts and sets, and its defaults |
| `ai-artifacts.conf` | `use rules CoreAiRules` (the example rules) and commented source examples; no `deploy` line, no source | its `deploy` lines, sources, `exclude` and `use` lines (Dotfiles: Claude Code, Codex and Gemini CLI, a local skills repository as a checkout and a manifest source, its own rules) |
| `ai-profiles.conf` | the line kinds and a commented example; no profile, so profiles are off | its `host`, `default`, `shared` and `default-owner` lines and one `[Profile]` section each (Dotfiles: `Personal` by default, `Work` for one named host) |
| `ai-harnesses.conf` | the inactive catalogue: `claude-code`, `codex`, `gemini-cli`, `copilot` | a section of its own for another app, or one replacing a base harness |
| `ai-marketplaces.conf`, `wake-on-lan.conf`, `pdfs.conf`, `dnd.conf` | a commented example, no entries | its marketplaces and `[plugin:NAME]` sections, machines, PDF groups and campaigns |
| `package-pins.conf` | the line kind and a commented example, no pin | its `brew FORMULA` lines |
| `ai-mcp-servers.conf` | the line kinds and a commented example; no `deploy` line, no server | its `deploy` line and servers (Dotfiles: Linear, Supermemory, Appllama, Mobbin, Awwwards and Playwright into Claude Code and Codex, which its AI profiles pick from) |
| `greeting.conf` | the clear and fastfetch settings, onefetch off with no arguments, separator or colors (WinuX's base), no `image-logo` (every machine type shows the text logo of its fastfetch config) | its `@TYPE image-logo` lines; `onefetch on` with its arguments, separator and colors |
| `spinners.conf` | the 19 styles of WinuX's base verbatim, plus Bounce | styles it changes |
| `shell.conf` | the line kinds and a commented example, no setting: zsh keeps its own keys and history options | its line-editing values (Dotfiles: WinuX's effective PSReadLine block - `history-size 32767`, `edit-mode windows`, prefix search on the arrows, no duplicates, incremental saving, case-insensitive Tab, the prediction list in its own colours) |
| `apps.conf`, `zones.conf`, `window.conf`, `list-functions.conf`, `backups.conf`, `logging.conf`, `dotnet.conf`, `translate.conf`, `vscode-profiles.conf` | sensible defaults | what it changes |

Writers (Add-Workspace, Add-Project, Add-BrowserGroup and the
[FoundationConfigurator](foundation-configurator.md)) write to the overlay; Add-WindowLayout creates a new
layout file in the set (and the set folder when it is missing, as on Windows).

## Files

| File | Windows source | Read by |
| --- | --- | --- |
| `window.conf` | `CenterTerminalSizing`, `ResizeWindowsPercent`, `BrowserGroupMatching.Matching.ProblemLoadingPagePattern` (`problem-page-title`, a plain text matched case-insensitively) | Center-Terminal (and Kill-All's CenterTerminal step through it), Resize-Windows, Open-ProjectSwagger, Close-Project |
| `workspaces.conf` | `WorkspaceActions`, `DefaultWorkspace`, `SimpleLayoutWorkspaces`, `WorkspaceBenchmark` | Open-Workspace |
| `workspace-templates.conf` | `WorkspaceTemplates` | Open-Workspace, Add-Workspace, Test-ConfigurationSchema |
| `layouts/<Type>/<Workspace>_<Type>.conf` | `Layouts/<Type>/<Workspace>_<Type>.psd1` | Set-WorkspaceWindowLayout, Visualize-Layouts |
| `zones.conf` | `FancyZones/custom-layouts.json`, `ZoneNameMappings` | Set-WorkspaceWindowLayout, Visualize-Layouts |
| `projects.conf` | `ProjectActions`, `ProjectTerminals`, `RunnableProjectMappings` | Open-Project, Open-ProjectTerminals, Run-Project |
| `vscode-folders.conf` | `VSCodeProjects` | Open-VSCode |
| `vscode-workspaces.conf` | `Projects.Self.VSCodeWorkspaces`, `DefaultVSCodeWorkspaces` | Open-VSCodeWorkspace, Open-Workspace |
| `special-folders.conf` | `SpecialFolders` | Set-SpecialFolders (Bootstrap's SpecialFolders step) |
| `language.conf` | `DisplayLanguages`, `Locales`, `KeyboardLayouts`, `KeyboardLayoutSets`, `DefaultDisplayLanguage`, `DefaultLocale`, `DefaultKeyboardLayoutSet` | Display-SystemLanguageSettings, Set-DisplayLanguage, Set-Locale, Set-KeyboardLayouts |
| `vscode-profiles.conf` | `VSCodeProfiles` | Deploy-VSCodeProfiles (Bootstrap's VSCodeProfiles step), Export-VSCodeProfile |
| `browser-groups.conf` | `BrowserGroups` | Open-Browser, Invoke-Browser |
| `ai-artifacts.conf` | `AiArtifacts` | Deploy-AiArtifacts (Bootstrap's AiArtifacts step), Update-AiArtifacts, List-AiArtifacts, Test-ConfigurationSchema |
| `ai-harnesses.conf` | WinuX's `AiHarnesses` | Deploy-AiArtifacts, List-AiArtifacts, Test-AiProfile, Test-ConfigurationSchema |
| `ai-profiles.conf` | `AiProfiles` | Deploy-AiArtifacts, Deploy-AiMcpServers, Deploy-AiMarketplaces, List-AiArtifacts, Update-AiArtifacts, Test-AiProfile, Initialize-AiProfile, Test-ConfigurationSchema |
| `ai-marketplaces.conf` | `AiMarketplaces.Marketplaces`, `AiMarketplaces.PluginConfigs` (a `[plugin:NAME]` section for a plugin no marketplace lists) | Deploy-AiMarketplaces (Bootstrap's AiMarketplaces step) |
| `ai-mcp-servers.conf` | `AiMcpServers.Deploy` (`deploy`), `AiMcpServers.Servers` (one section per server; `machine` for `Machine`) | Deploy-AiMcpServers (Bootstrap's AiMcpServers step), Test-AiProfile, Initialize-AiProfile |
| `backups.conf` | `Backups.Retention` | Clear-OldBackups, every backup |
| `apps.conf` | `Universal.Browsers` (and the former MacOSApplicationMap of the removed PowerShell port) | every launcher, the drivers, Kill-All |
| `logging.conf` | `Logging.DefaultLevel` (`level`), `Logging.Colors` (`color STYLE COLOR`), `Logging.FileLogging` (`directory`, `error-file`, the retention), `Logging.Maintenance` (`maintenance`, `maintenance-interval-hours`) | every command (console level and colours, session and error logs), Clear-OldLogs, Get-LogPath, Protect-Log, Invoke-LogMaintenance |
| `list-functions.conf` | `ListFunctionsColors`, `ShowFunctionDetailsColors`, `FunctionDiscrepancyExclusions` | List-Functions |
| `machines.conf` | `ValidMachineTypes`, `HostnameToMachineType`, `DefaultMachineType`, `SmallDisplayMachineType`, `LayoutMachineTypeOverrides`, `BasePaths.<Type>.Dev` | machine type, layout set, the dev root `$DEV` of every path; Initialize-Configuration writes it |
| `git.conf` | `GitConfig.UserName`, `GitConfig.UserEmail`, `GitStatusArguments` | Bootstrap's GitIdentity step; Initialize-Configuration writes it; Test-ConfigurationSchema notes an unset one; GitStatus (`status-arguments`) |
| `dnd.conf` | `CampaignResources` | Open-DnD |
| `obsidian.conf` | `Obsidian.Vault`, `Obsidian.DefaultWorkspace`, `MachineSpecificPaths.ObsidianDirectory`, the Obsidian link of `SymbolicLinks` | Open-Obsidian, git-obsidian, Bootstrap's ObsidianSettings step |
| `pdfs.conf` | `AcrobatPdfGroups`, the PDF paths of `MachineSpecificPaths` | Open-Acrobat |
| `docker.conf` | `DockerComposeFiles`, `DockerTimeouts`, `DockerCleanupActions`, `DockerCleanupStartMode`, `PathTemplates.DockerDirectory`; `cli-install` is Foundation's own | Start-Containers, Open-Docker, DockerWizard, Docker-Cleanup, Run-Project, Kill-All, Configure-DockerDesktop |
| `wake-on-lan.conf` | `WakeOnLanConfig`, `DefaultWakeOnLanMachine` | Send-WakeOnLan, Test-MachineOnline |
| `theme.conf` | `Themes`, `SystemTheme.Steps`, the Oh My Posh theme of the profile, the Terminal-Icons colours of the listing (`list-color KEY COLOR`: KEY `directory`, `file`, `executable`, `symlink`, `symlink-path`, `user`, `user-other`, `group`, `group-other`, `date`, `size`, `size-unit`, `header`, `punctuation` or a two-letter key of `man eza_colors`; COLOR as in [shell.conf](#shellconf); a key without a line keeps eza's colour) | Set-SystemTheme, the shell rc (`prompt-theme`, and `list-color` as `EZA_COLORS` for the `ls`, `ll`, `la` and `l` aliases, through foundation-shell-settings), Test-ConfigurationSchema |
| `shell.conf` | `PSReadLine` (`MaximumHistoryCount`, `HistorySavePath`, `EditMode`, `KeyHandlers`, `HistoryNoDuplicates`, `PredictionSource`, `PredictionViewStyle`) | the LineEditing stage of the shell rc, through foundation-shell-settings; Test-ConfigurationSchema |
| `system-defaults.conf` | `ExplorerOptions`, `TaskbarSettings`, `VisualEffects` | Set-SystemDefaults |
| `power.conf` | `PowerPlans`, `PowerButtonActions` | Set-PowerSettings |
| `dock.conf` | `TaskbarConfiguration` | Set-DockPins |
| `login-items.conf` | (Windows Startup apps) | Set-LoginItems |
| `dotnet.conf` | `DotnetEFVersion`, `MachineSpecificPaths.NuGetConfig`, `DotnetProjectsSearchPath`, the .NET 6 SDK of `WinGetApps.local.csv` | Install-DotnetEf, Install-DotnetSdks (`sdk-channel`), Configure-NuGetConfig, Determine-DotnetDependencies |
| `npm.conf` | `PathTemplates.NpmConfig`, `NpmRegistries` | Configure-NpmConfig |
| `conda-environments.conf` | `BootstrapConfig.DataFiles.CondaEnvironments` | Install-CondaEnvironments |
| `package-pins.conf` | the `Version` column of `WinGetApps.csv`, `ScoopApps.csv` and `ChocolateyApps.csv` | Upgrade-All |
| `bootstrap.conf` | `BootstrapConfig.Steps`, `BootstrapConfig.RepositoryUpdateScope`, `BootstrapConfig.PersonalSteps` | Bootstrap |
| `Unix/home/` (not in `config/`: chezmoi's link templates) | `SymbolicLinks` | chezmoi, Bootstrap's Dotfiles step, `Unix/bootstrap.sh`, Add-SymbolicLink - see [Dotfiles with chezmoi](bootstrap.md#dotfiles-with-chezmoi) |
| `wallpapers.conf` | `WallpaperDarkSettings`, `WallpaperLightSettings` | Set-Wallpaper |
| `spinners.conf` | `LoadingSpinners`, `DefaultSpinner` | the loading spinner of long waits, Loading-Spinner |
| `translate.conf` | `DefaultTranslateLanguages` | Invoke-GoogleTranslate |
| `repositories.conf` | `RepositoryGroups`, `Universal.GitHub.Base`, `RepositoryUpdate` | Update-Repositories, Invoke-StartupRepositoryUpdate |
| `greeting.conf` | `TerminalGreeting`, `Universal.FastFetchImageLogo` | Show-TerminalGreeting (`c`), Invoke-Clear (`clear`), Invoke-Fastfetch (`fastfetch*`, `image-logo`), Invoke-Onefetch (`onefetch*`), Open-ProjectTerminals (`onefetch-in-project-terminals`) |
| `kill-all.conf` | `KillAll.Steps`, `VisibleWindowExclusions`, `TerminateProcessNames` | Kill-All, Open-Workspace |
| `upstream.conf` | WinuX's own manifest, `Windows/PowerShell/Upstream.conf` (same format) | Merge-Upstreams |

Each file's header documents its line kinds. The essentials:

The Windows profile checks the configuration at every shell start (the Schema stage runs
Test-ConfigurationSchema). The Unix shell rc does not: one Test-ConfigurationSchema run reads every
file and its references and takes about 16 s on the Mac (measured 2026-10-24), too long for a
shell start even when only a changed file triggers it. Run it by hand after an edit
(`Test-ConfigurationSchema --quiet`); the test suites and the FoundationConfigurator run it too.

### workspaces.conf

```
default-workspace Default

[Dotfiles]
Open-ClaudeDesktop
Open-Project Dotfiles
Open-Browser DotfilesRepository AI YouTube
Set-WorkspaceWindowLayout Dotfiles
Focus-VirtualDesktop 1
```

A line is a Foundation command (any module) with its arguments, or `Open-<App>` for any `app` of
`apps.conf`; `Return` stops the open there. `{Workspace}` is the workspace's own name.
`{SelectedProjects}` expands to the open's projects: `w NAME X` (or `--project X`), else the
project menu Open-Workspace shows up front for an `Open-Project` without a project (Enter skips
that `Open-Project`), else the projects the workspace's `Open-Project` lines name. The same
projects choose the `+A,B` / `+!A,B` lines that run and the layout's project variants, and fill
an `Open-Project` that names no project; one that names its project keeps it, and every
`Open-Project` keeps its own flags (`--run-app`), as on Windows.

### workspace-templates.conf

```
[Project]
var Repository {Workspace}Repository
Open-ClaudeDesktop
:project Open-Project {Workspace}
Open-Browser {Repository} AI YouTube
Set-WorkspaceWindowLayout {Workspace}
Focus-VirtualDesktop 1
```

The `WorkspaceTemplates` of Windows: one section per template, `var NAME [DEFAULT...]` lines and
action lines. A default may use `{Workspace}` and other variables (a cycle is an error); a `var`
without a default must be set by every workspace that uses the template. `:ID` names an action
for the workspace's `replace`, `drop` and `add` lines - needed only when the template has the
same action twice. `Workspace`, `SelectedProjects` and `ProjectName` are reserved. A template
cannot use another template; a `workspace-templates.local.conf` section replaces the template
whole. A workspace section stamps a template out under its own name, so the layout file, the
Close-Workspace record, the benchmarks and the Obsidian workspace stay per workspace:

```
[Dotfiles]
template Project

[MyProject]
template Project
replace Open-Browser Open-Browser {Repository} AI Docs YouTube
add after Open-Project Open-Obsidian --workspace {Workspace}

[Research]
template Notes
set Groups Google YouTube
drop Terminate-WindowsTerminalTabs
```

| Line | Meaning |
| --- | --- |
| `template NAME` | the template to stamp out |
| `set NAME VALUE...` | a variable value; declares the variable when the template does not |
| `replace KEY LINE` | swaps action KEY (an `:ID`, else an action name that must be unique) for LINE |
| `drop KEY` | removes action KEY |
| `add LINE` | adds LINE just before the template's first `Set-WorkspaceWindowLayout` (the end when there is none) |
| `add before KEY LINE`, `add after KEY LINE` | adds LINE next to action KEY |

They apply in that order (`replace` and `drop` before `add`, each in the order written), then the
variables are substituted over the final list, so a dropped action never asks for its
placeholders. `@TYPE` lines are filtered first, in the template and in the workspace alike, so
a `replace`, `drop` or `add` anchored on a machine-specific template line needs the same `@TYPE`
prefix (`@Laptop replace lap ...`) - on another machine the line it names does not exist. A workspace with a `template` line takes no other lines. `w NAME --variable VALUE`
(or `-Variable VALUE`) sets a variable for one open and is not forwarded to the actions. Anything
wrong - an unknown template, an unknown `{X}`, a variable without a value, a key that matches no
action or several - makes the workspace open nothing: Open-Workspace names the problem and moves
on, and Test-ConfigurationSchema reports it beforehand.

### layouts/Work/Dotfiles_Work.conf

```
[Dotfiles]
layout 1 Five
layout 2 Five
layout 3 One
1 Left   Code
1 Right  Terminal
2 Left   Claude   Claude
2 Right  Browser  *Google Gemini*
```

One file per workspace and layout set, as on Windows; it holds that workspace's one section
(Test-ConfigurationSchema checks the name matches). Every repository ships the `Test` set
(Default, Empty, Example, Fullscreen, SecureBrowser, Test); a fork adds its own sets (`Work/`, `Laptop/`). A
layout a workspace names must exist in every set a machine uses - the sets `machines.conf` maps
a host, the default or the small display to. `layout DESKTOP ZONESET`, then
`DESKTOP ZONE APP [TITLE]`. APP is an `apps.conf` token or a role
(`Terminal` = WezTerm, `Browser` = any browser); TITLE follows the Windows rules (a plain word is
a substring, `*x*` a wildcard, anything else a regex, case-insensitive; a leading `(?i)` is
accepted, and a value POSIX regex rejects, such as `Notepad++`, is matched as plain text). An app
pattern always matches its exact name, regex characters included. `monitor Secondary` switches following
lines to another monitor; only Primary is placed yet (secondary monitors are deferred until a Mac runs
with two or more displays - see Backlog/MacOS/deferred_SecondMonitor.md).

Several windows of one app: each entry claims one window, a window is never handed to two
entries, and an entry without a TITLE takes only windows no titled entry of the same app asks
for. The only untitled entry of an app takes every such window (as on Windows); several untitled
entries of one app take one window each. Several windows in one zone - a whole desktop, a column,
or a top or bottom half - are stacked (an AeroSpace accordion) with the last entry in front.

Project variants (the `ProjectOverrides` of Windows) live in the same file, after the base lines:

```
[Client]
layout 1 One
1 Left   Browser
1 Right  Code
project MyProject
layout 2 One
2 Left   Code     MyProject
2 Right  Code     MyProjectApi
```

A `project A,B` line opens a variant that lasts until the next `project` line. When the open is
for one of those projects, the variant's `layout D ZONESET` lines change those desktops' zone
sets, and its window lines replace every base window on the same desktop and monitor (a desktop
the base does not use is added). Several selected projects apply in the order given, so on the
same desktop the later one wins. A variant naming a project `projects.conf` does not have is
reported (by Set-WorkspaceWindowLayout and Test-ConfigurationSchema) and skipped.
Visualize-Layouts draws each variant under its base layout.

### zones.conf

```
Five    Left:67.25 Right:32.75
Six     Left:50 Top-Right+Bottom-Right:50
```

Column shares of the monitor's work area. `TOP+BOTTOM:PERCENT` is a column split into two
50/50 rows (a vertical AeroSpace container). Every FancyZones layout of the repository (Zero to
Nine) is defined this way.

### Spacing (aerospace.toml)

```
gaps.inner.horizontal = 3
gaps.outer.left =       0
```

The space between windows and around them is AeroSpace's gaps in `Unix/aerospace/aerospace.toml`,
the counterpart of the `spacing` of the FancyZones layouts on Windows. The base file ships 3 points
between windows and none at the screen edges, where a gap would only take space from every
window. Set-WorkspaceWindowLayout reads the gaps from the file AeroSpace loads (any TOML
spelling, a per-monitor list's `monitor.main` value) and sizes and verifies the zones with them:
the outer gaps come off the work area, and each window gives up half the inner gap on every side
that faces another window. Any values work, different ones per side included; 0 puts the
windows edge to edge. The file is shared by every machine (there is no overlay), and the gaps are
points, so a Retina display draws each as 2 pixels.

### projects.conf

```
[MyProject]
path API $DEV/MyProject/src/MyProject.Api
path UI $DEV/MyProject-ui
action Open-VSCode MyProject
action Open-ProjectTerminals MyProject
tab API
tab UI
run API dnr
run UI nir
```

`{ProjectName}` in an `action` line is the project's name (`action Open-VSCode {ProjectName}`),
as on Windows. Tabs are titled `<Project>.<KEY>`; `tab KEY DIR` overrides the path and `DEFAULT` is `$HOME`.
The Windows name-only tab (`@{ Key = "Name" }`, a plain tab titled `<Project>.Name`) is
`tab Name ~`; a `tab KEY` with neither a `DIR` nor a `path KEY` line is skipped with a warning and
reported by Test-ConfigurationSchema, so a mistyped key is caught.
`docker TARGET` names containers Run-Project brings up first: a `docker.conf` stack
(`docker PostgreSQL`, the DatabaseProviders case) or a path key whose directory holds the
project's own compose file (`docker ROOT`, the UsesDocker case). `step Docker off` before the
first section turns that step off by default. A `run KEY` without a `tab KEY` line runs nothing,
as on Windows; Test-ConfigurationSchema reports it.

### docker.conf

```
stack PostgreSQL   docker-compose.postgresql.yml
timeout start 180
timeout stop 60
cleanup-start ask
cleanup Delete all volumes :: docker volume ls -q | xargs docker volume rm :: Are you sure?
cleanup-description Delete all volumes :: Removes every volume, with the data in it.
cleanup-preview Delete all volumes :: docker volume ls --format '{{.Name}} ({{.Driver}})'
```

A relative stack file resolves under the `directory PATH` folder (the `DockerDirectory` of Windows; relative to the repository root, `Docker` without a line); the last `stack` line of
a name wins, so an overlay line replaces the base stack of that name. `timeout start SECONDS`
bounds every wait for the daemon to come up - Start-Containers, Docker-Cleanup and Run-Project;
Open-Docker returns without waiting, as on Windows (180 without a line); `timeout stop SECONDS` is how
long `Open-Docker --stop`, `DockerWizard --stop` and Kill-All's Docker step wait for Docker
Desktop to quit (through `docker desktop stop`) before killing it (60 without a line).
`cli-install system|user` is where Docker Desktop installs its command-line tools, written by
Configure-DockerDesktop (step DockerDesktop): system links them into `/usr/local/bin`, user into
`~/.docker/bin`, which Docker Desktop then adds to PATH by writing into the shell profiles at every
start; the base ships no line, so Docker Desktop keeps its own choice. `cleanup` entries are
`LABEL :: COMMAND [:: CONFIRMATION]`; Docker-Cleanup's menu adds All, and selected entries run in
the order of these lines, so keep stops and container deletes before images and volumes.
`cleanup-description LABEL :: TEXT` and `cleanup-preview LABEL :: COMMAND` are optional: the
preview lists what the action would stop or remove, and an empty list skips the action. When any
entry left to run has a `CONFIRMATION`, one confirmation covers the whole run (an entry's own
message when it is the only one left) and needs an explicit "yes"; a run whose entries have none
starts without a prompt. All runs every configured `cleanup` line. `cleanup-start` is what happens when the daemon is down: `ask` (the default,
also for an empty or unknown value; Enter means yes), `always` or `never`. A `docker.local.conf`
adds its `cleanup` lines after the base ones (Windows replaces the list whole); take a base one
back with `-LINE`.

### browser-groups.conf

Sections nest by dots (`[GitHub.Personal]`), a line is `URL` or `Name URL`, and a group opens its
own URLs plus every nested group's. Lookup: exact path, then the last segment, then a named URL.
The first URL decides the window title that layouts match.

### repositories.conf

```
base https://MyUser@github.com

[Private]
MyRepo    /MyUser/MyRepo.git    $DEV/MyRepo
```

A relative path is appended to `base`; a full URL (`http(s)://`, `git@`, `ssh://`, `git://`, or `file://` for a local mirror) is used as is.
A repository line may end in `shallow` (`MyNotes  /MyUser/MyNotes.git  $DEV/MyNotes  shallow`):
it is cloned `--depth 1`, a clone that keeps its `.git` and can still commit and push, by
Update-Repositories and by Initialize-Repository for the same URL - the setting form of the
Windows rule that clones the Obsidian repository shallow because of its large history.

Top-level lines before the first group set the repository update (the `RepositoryUpdate`
section of Windows; `@TYPE` lines per machine type):

```
include-default-branch on
startup on
startup-schedule daily
startup-day-start-hour 6
@Test startup-scope Private
```

`include-default-branch` makes Update-Repositories also fast-forward each default branch
(`default-branch NAME` names one for every repository, otherwise `origin/HEAD` does); `startup`
turns on the automatic update (Invoke-StartupRepositoryUpdate: the groups of `startup-scope`,
group names only, as on Windows - a name that is no group, a repository's included, updates
nothing - never cloning; without a `startup-scope` line for this machine type it takes the
`repository-scope` of `bootstrap.conf`, then All, as Windows falls back from
`RepositoryUpdate.Startup.Scope` to `BootstrapConfig.RepositoryUpdateScope`). All are off by default. `startup-schedule daily` (the default) runs it once a
day: the first shell after the day starts at `startup-day-start-hour` (0-23, default 6, any other value 6; so a shell
opened past midnight still counts as the day before), or, when a shell was already open, its
first prompt after that hour - a Mac woken from sleep updates at the first command you run.
`startup-schedule interval` runs it at most once per `startup-interval-hours` (whole hours, default 24),
checked only when a shell starts.

### git.conf

```
name My Name
email you@example.com
status-arguments --short
@Work status-arguments -v -v -u
```

`name` and `email` are the git identity (Initialize-Configuration writes them, Bootstrap's
GitIdentity step sets an unset global one). `status-arguments` is what GitStatus (`gs`) passes to
`git status` when it is called without arguments - the `GitStatusArguments` of Windows: `--short`
without a line, a bare `status-arguments` line runs a plain `git status`, and arguments given on
the call replace the configured ones. The base ships no line; all of them go in `git.local.conf`.

### upstream.conf

```
name        foundation
url         https://github.com/IvanPavlak/Foundation.git
tag-prefix  foundation
changelog   Unix/CHANGELOG.md
own         Unix/
own         docs/foundation/
mirror      LICENSE
```

Foundation's upstream manifest, read by Merge-Upstreams from the commit it merges (never from the
working tree). `name` is the project's name and the name of its remote in a fork; `url` its
repository (the remote whose fetch URL matches it is used, under any name); `tag-prefix` the
prefix of its release tags (`foundation/v0.2.0`); `changelog` the changelog whose newest
`## [x.y.z]` names the merge in the suggested commit message. `own PATH` is a path only Foundation
ships (a PATH ending in `/` covers everything under it, any other PATH is one file); `mirror PATH`
is a file every upstream ships byte-identical, by contract (WinuX's manifest lists the same ones).
Unlike the other files it is not per machine and not layered: no `@TYPE` lines and no
`upstream.local.conf` overlay. A fork's own choices (`root-owner`, `take`) go in
`Git/upstreams.local.conf`. See [Fork Model](fork-model.md).

### special-folders.conf

```
folder Downloads    ~/Desktop
folder Screenshots  ~/Pictures/Screenshots
```

Set-SpecialFolders turns `~/Downloads` into a link to the Downloads folder given (its contents move
there first; a clashing name is kept as `NAME (Downloads)`; the deny-delete rule macOS puts on
`~/Downloads` is removed from the emptied folder) and writes the screenshot folder, creating it
when missing. The base file ships no line. To undo the Downloads link:
`rm ~/Downloads && mkdir ~/Downloads && chmod +a "group:everyone deny delete" ~/Downloads`.

### system-defaults.conf

```
[Dock]
defaults com.apple.dock autohide -bool true
@Laptop defaults com.apple.dock tilesize -int 40
restart Dock

[Screenshots]
defaults com.apple.screencapture type -string png
restart SystemUIServer
```

One group per section (`Set-SystemDefaults Dock`, `--skip Dock`). `defaults` and `currenthost`
write a preference (`defaults write`, `defaults -currentHost write`), `delete` removes one,
`mkdir` creates a folder, `command` runs another Foundation command, `restart` names the processes
restarted once at the end, `note` prints a reminder. TYPE is `-bool` (or `-boolean`), `-int` (or
`-integer`), `-float`, `-string`, `-date`, `-data`, `-array`, `-array-add`, `-dict` or `-dict-add`;
a `-string` value may contain spaces and expands `~`; `-array` and `-dict` values split on spaces; a key with spaces goes in double quotes
(`defaults com.apple.print.PrintingPrefs "Quit When Finished" -bool true`). An empty `[Dock]` in `system-defaults.local.conf`
turns the group off on that machine. The keys and what each needs to take effect are listed in
`Backlog/MacOS/Research/MacOSDefaultsInventory.md`.

### power.conf

```
[AC]
displaysleep 30
sleep 0

[Battery]
displaysleep 5
@Laptop sleep 15
```

`[AC]`, `[Battery]` and `[All]` hold `KEY VALUE` lines for `pmset -c`, `-b` and `-a`; timers are
in minutes, 0 means never. Set-PowerSettings checks each key against `pmset -g cap` and skips the
ones this Mac does not offer (`lidwake` on Apple silicon MacBooks), and changes only keys whose
value differs.

### dock.conf and login-items.conf

```
clear on
pin /Applications/WezTerm.app
pin /Applications/Visual Studio Code.app
folder ~/Downloads --view fan --display stack
```

```
item /Applications/Tailscale.app hidden
```

`clear on` makes the Dock hold exactly the `pin`, `spacer` and `folder` lines in order (a list with
a `spacer` is rebuilt on every run, as spacers cannot be compared), backing the Dock up into
`Backups/Unix/System/DockLayout/` before it empties it; `clear off`, or no `clear`
line, only adds what is missing. Login items are only ever added; `hidden` starts the app without a
window. A path may contain spaces in both files.

### bootstrap.conf

```
step UpgradeAll on
step DockPins off
repository-scope All
@Laptop repository-scope Private Work

[Packages]
trust cask some-org/tap/some-app

[Firewall]
globalstate on
stealthmode on

[SoftwareUpdate]
defaults /Library/Preferences/com.apple.SoftwareUpdate AutomaticDownload -bool true

[PersonalSteps]
Set-DockPins
@Work Install-DotnetEf
```

`step NAME on|off` lines go before the first section and override a step's built-in default;
`Bootstrap --list` shows every step. `repository-scope All|GROUP...` (also before the first
section; the last line for this machine type wins) names the `repositories.conf` groups the
RepositoryUpdate step updates, the `RepositoryUpdateScope` of Windows; All, or no line, updates
every repository. Group names only: a name that is no group (a repository's included) is
reported with the configured groups, nothing is updated and the step fails. It is also the
startup update's scope when `repositories.conf` has no `startup-scope` for this machine type. `[Packages]` holds `trust TYPE NAME` (a third-party tap
entry to `brew trust`) and optional `brewfile PATH` lines (default `Unix/Brewfile`, then
`Unix/Brewfile.local`). `[Spotlight]` holds `index VOLUME on|off`, `[Firewall]` the
`socketfilterfw` switches `globalstate`, `stealthmode`, `allowsigned`, `allowsignedapp`, and
`[SoftwareUpdate]` `defaults DOMAIN KEY TYPE VALUE` lines written with sudo. `[PersonalSteps]`
holds a fork's own steps (`BootstrapConfig.PersonalSteps`), one `COMMAND [ARG...]` per line, run
in order by the PersonalSteps step: a Foundation command or any command on PATH, split into words with
no shell (no quoting, pipes or `&&`); an unknown command is skipped with a warning and a failing
line fails the step without stopping the others. A section of
`bootstrap.local.conf` replaces the same section here.

### shell.conf

The `PSReadLine` block of WinuX's `Configuration.psd1`, for zsh's line editor. The base ships no
setting: Foundation enforces no line-editing behaviour, and a kind without a line keeps the
shell's own default (history in `~/.zsh_history`, 4096 lines, emacs keys, zsh's Tab). A fork sets
what it wants in `shell.local.conf`; the last line of a kind wins, `key` lines merge per key.

| Line | Windows key | Effect |
| --- | --- | --- |
| `history-size N` | `MaximumHistoryCount` | `HISTSIZE` and `SAVEHIST` (bash: `HISTSIZE`, `HISTFILESIZE`) |
| `history-file PATH` | `HistorySavePath` | `HISTFILE`; `~` and `$VARIABLES` expand |
| `edit-mode emacs\|vi\|windows` | `EditMode` | `bindkey -e` / `-v`; `windows` is emacs plus, under the `key` lines, the Windows-mode keys Foundation ports: Tab and Shift+Tab cycle through the completions in place (the first match goes in at once, no list, no bell: `AUTO_LIST` and `LIST_BEEP` off), Home, End, Delete, Ctrl+Left and Ctrl+Right |
| `key KEY FUNCTION` | `KeyHandlers` | `bindkey` for every sequence a terminal sends for KEY |
| `history-no-duplicates on\|off` | `HistoryNoDuplicates` | `HIST_FIND_NO_DUPS`: repeats are skipped when recalling, the file keeps every line |
| `history-save-style incrementally\|at-exit\|nothing` | `HistorySaveStyle` | `incrementally`: each line is written as it runs (`INC_APPEND_HISTORY`, no live sharing, so a new tab sees every line and an open tab's Up does not); `at-exit`: zsh's default; `nothing`: `SAVEHIST=0`. Except `nothing`, a line equal to the one just before it is not written (`HIST_IGNORE_DUPS`), as PSReadLine does |
| `completion-ignore-case on\|off` | (PowerShell always) | `on`: Tab matches in any case (`matcher-list 'm:{a-zA-Z}={A-Za-z}'`) |
| `prediction-source none\|history` | `PredictionSource` | with `prediction-view list`: the prediction list below |
| `prediction-view inline\|list` | `PredictionViewStyle` | `list`: the prediction list; `inline` is read and checked, not ported |
| `prediction-list-marker TEXT` | (PSReadLine's `>`) | what starts each row of the list |
| `color-list-prediction COLOR` | `Colors.ListPrediction` | the rows (default yellow) |
| `color-list-prediction-selected COLOR` | `Colors.ListPredictionSelected` | the selected row's background (default 238, dark grey) |
| `color-emphasis COLOR` | `Colors.Emphasis` | the typed text inside the rows (default 14, bright cyan) |

KEY is a PSReadLine key name, in any case: `UpArrow`, `DownArrow`, `LeftArrow`, `RightArrow`,
`Home`, `End`, `Insert`, `Delete`, `PageUp`, `PageDown`, `Tab`, `Shift+Tab`, `Enter`, `Escape`,
`Backspace`, `Ctrl+Backspace`, `Ctrl+Delete`, `Ctrl+Spacebar`, `Ctrl+`, `Shift+` or `Alt+` an arrow
(`Ctrl+` or `Shift+` Home and End too), `F1` to `F12`, `Ctrl+` a letter and `Alt+` a letter. A KEY
starting with `^` is a bindkey sequence as it is (`^X^E`). FUNCTION is a PSReadLine function name
(`HistorySearchBackward`, `HistorySearchForward`, `PreviousHistory`, `NextHistory`,
`ReverseSearchHistory`, `Complete`, `MenuComplete`, `TabCompleteNext`, `TabCompletePrevious`,
`AcceptLine`, `BeginningOfLine`, `EndOfLine`, `BackwardWord`, `ForwardWord`, `BackwardKillWord`,
`KillLine`, `Undo`, `ClearScreen` and more: the table is in `Unix/lib/lineediting.sh`) or a zle
widget name such as `up-line-or-beginning-search`. `-` in its place drops the key, a `windows`
binding included, so the key keeps zsh's default: the `$null` of WinuX's `KeyHandlers`.

```
edit-mode              windows
key UpArrow            HistorySearchBackward
key DownArrow          HistorySearchForward
history-no-duplicates  on
history-save-style     incrementally
completion-ignore-case on
prediction-source      history
prediction-view        list
```

**The prediction list** (`prediction-source history` with `prediction-view list`,
`Unix/shell/prediction-list.zsh`): from the first character, the history lines that contain the
typed text (in any case, not fuzzy, newest first, each line once) show below the line, at most 10
rows under a `<n/N>` header, each `> line` with `[History]` on the right and every place the typed
text occurs highlighted. While it shows, Up and Down move in it and the line follows the selected
row (Down enters at the top, Up at the bottom, past either end the line is the typed text again);
otherwise they keep their own binding (the prefix search of `key UpArrow HistorySearchBackward`).
Enter runs the line, Right keeps it, Tab completes and closes the list, and a line recalled with
Up opens none. It reads this shell's history only: lines another open tab runs appear in a new
tab. COLOR is one of `black`, `red`, `green`, `yellow`, `blue`, `magenta`, `cyan`, `white`,
`default`, a number 0-255 or `#RRGGBB`.

Everything but `history-size`, `history-file` and `edit-mode emacs|vi` is zsh only. A line the
shell cannot use is skipped without a word; Test-ConfigurationSchema names it.

### package-pins.conf

```
brew node
@Work brew postgresql@16
```

One `brew FORMULA` line per Homebrew formula Upgrade-All must leave where it is, the `Version`
column of the Windows app lists. Before `brew upgrade` Upgrade-All makes Homebrew's own pins match
the file, in both directions, as Sync-AppPins does on Windows: an installed formula with a line is
pinned (`brew pin`), and a formula named by a bundled Brewfile (the `brewfile` lines of
`bootstrap.conf`, else `Unix/Brewfile` and `Unix/Brewfile.local`) that is pinned without a line is
unpinned, so taking a line back releases the formula. A pin on a formula no Brewfile names was made
by hand and stays. A line for a formula that is not installed yet is reported and pinned by the
first Upgrade-All after it is. When the pins cannot be read or set, the Homebrew upgrade is
skipped and the run fails.

Homebrew pins the installed version: it cannot install an arbitrary one as winget can, and casks
cannot be pinned. The first field names the package manager, so a manager that can pin joins with a
line kind of its own. The base ships no pin; `-brew FORMULA` in the overlay takes a base line back.

### dotnet.conf and conda-environments.conf

```
ef-version 8.*
sdk-channel 6.0
nuget-template NuGet/nuget.config
nuget-config ~/.nuget/NuGet/NuGet.Config
projects-search-path $DEV
```

```
directory Conda/Environments/macOS
env MyEnvironment
update-base off
```

An empty `ef-version` installs the latest dotnet-ef. Each `sdk-channel` is a .NET SDK channel no Homebrew cask ships, which Install-DotnetSdks (the Bootstrap step DotnetSdks) installs next to the cask SDKs. The NuGet template holds `[Username]` and
`[Token]` placeholders that Configure-NuGetConfig fills in from the terminal. A relative
`nuget-template` or `nuget-config` starts at the repository root.
`projects-search-path` is where Determine-DotnetDependencies looks for projects (default
the dev root, `$DEV`). Each `env` line names a `.yml` file in the `directory` (relative paths
start at the repository root); without `env` lines every file there is created. The Windows
exports in `Conda/Environments` carry win-64 builds, so the macOS copies live in
`Conda/Environments/macOS` and use `conda-forge` with `nodefaults`. conda 26 still checks the Terms of Service of the defaults channels it is
configured with, even for such a file, so a fresh Mac needs `conda tos accept` once; a refused
run prints the full command. `update-base on` updates conda from the defaults channel.

### npm.conf

```
npmrc ~/.npmrc
registry https://npm.pkg.github.com/
registry https://npm.pkg.github.com/ @my-org
```

Each `registry URL [SCOPE]` line is a private registry Configure-NpmConfig writes a GitHub token
for into the `npmrc` (default `~/.npmrc`; a relative path starts at the repository root): the
`//HOST/PATH/:_authToken` line and, with a SCOPE, the `SCOPE:registry=URL` line that sends the
scope's packages there. A URL is the same registry with or without its trailing slash, and the
last line of a URL wins, so an overlay line adds a scope to the base registry. The base ships
GitHub Packages without a scope; the token is typed at the command's prompt, never stored here.

### ai-artifacts.conf and ai-harnesses.conf

```
deploy claude-code codex
@Work deploy claude-code
exclude skills/tdd rules/example/CoreAiRules
use rules CoreAiRules

[mattpocock]
repository  OWNER/skills
ref         main
skills      skills/engineering skills/productivity
skip        .git tests

[myskills]
checkout    $DEV/MySkills
skills      skills
manifest    $DEV/MySkills/third-party/manifest.tsv
```

```
[my-app]
skills   each  .                  ~/.my-app/skills
rules    file  my-app.md,RULES.md ~/.my-app/INSTRUCTIONS.md
agents   copy  AGENT.md           ~/Library/Application Support/MyApp/agents
```

`ai-artifacts.conf` before its first section: `root PATH` (the artifacts root, default `AI` of the
repository), `deploy HARNESS...` (the last for the machine type wins; none deploys nothing),
`exclude KIND/NAME` or `KIND/SOURCE/NAME` (any number), `use KIND NAME` (the item a `file`
destination of that kind links; the last per kind wins). Each `[section]` is a vendored source:
`repository OWNER/NAME`, `ref REF` (default `main`), one `KIND PATH...` line per kind it feeds (none:
`skills skills`), `exclude ITEM...`, `skip NAME...` (default `.git .github tests design docs`).
A section with a `checkout PATH` line is a checkout source instead: the items under its kind
folders (`KIND FOLDER...` relative to PATH, `skills skills` without one) are linked from that
repository in place. A `manifest FILE` line makes it a manifest source: the rows of that file (the
format is on [AI on a Mac](ai.md#manifest-sources)) are linked from their pinned clones in the
cache. One section can be both; a section with neither (or with a `repository` line) is vendored.

Each section of `ai-harnesses.conf` is an app, one `KIND PLACEMENT FILES [+HOOK...] PATH` line per
destination: `each`, `copy` or `file`; the files to take from an item, the first it has (`.` for
the folder); the hooks `+claude-plugin-dirs` and `+managed-settings`; the path, spaces allowed. The
mechanism, the base catalogue and the sources each folder was checked against are on
[AI on a Mac](ai.md). Test-ConfigurationSchema reports a `deploy` name that is no section, a
malformed destination line, an unknown hook and a malformed `exclude` or `use` line.

### ai-profiles.conf

```
host My-Work-Mac Work
default Personal
default-owner Personal
shared github.com/myuser/dotfiles

[Personal]
rules         Personal
plan          Max 00000000-0000-0000-0000-000000000000
unattended    on
default-policy branch
policy        autonomous github.com/myuser/myproject
policy        readonly github.com/myuser/archive-*

[Work]
rules         Work
plan          Team 11111111-1111-1111-1111-111111111111
mcp
exclude       skills/my-personal-skill
owns          github.com/my-org/*
default-policy draft
```

Before the first section: `host NAME PROFILE` (the profile of the Mac whose local hostname is NAME,
compared without case), `default PROFILE`, `shared PATTERN...` and `default-owner PROFILE`. Each
`[Profile]` section: `rules NAME` (wins over `use rules`), `plan NAME UUID...`, `deploy
HARNESS...` (wins over the `deploy` line of `ai-artifacts.conf`), `include KIND/NAME...` (a kind
named deploys only those items), `exclude KIND/NAME...`, `mcp NAME...` and `marketplaces NAME...`
(no line: all; a bare line: none), `unattended on|off` (default off), `owns PATTERN...`,
`policy LEVEL PATTERN...` (repeatable, the last matching line wins), `autonomous PATTERN...` (a
synonym of `policy autonomous`), `default-policy LEVEL` (default `branch`),
`merge-without-checks PATTERN...` and `env NAME...`; the levels are `autonomous`, `branch`,
`draft`, `readonly` and `blocked` ([Repository policies](ai.md#repository-policies)). A PATTERN is a shell glob on the `origin` remote
normalised to `host/owner/name`. With no section, profiles are off and every AI command behaves as
without the file. `FOUNDATION_AI_PROFILE` overrides the host and default lines for one shell. The
mechanism is on [AI on a Mac](ai.md#profiles); Test-ConfigurationSchema reports a `host`, `default`
or `default-owner` line naming no profile, an unknown line kind, a malformed `plan` UUID, a
`deploy`, `mcp` or `marketplaces` name that is no section of its file, and a `policy` or
`default-policy` line naming no level.

## State

`$XDG_STATE_HOME/foundation` (default `~/.local/state/foundation`) holds `open-workspaces`, the ownership
record Close-Workspace uses, `WorkspaceBenchmark.csv` (one row per workspace open with its early-move mode, its mode - Plain or Alongside - and the layout's attempts, older files gaining the newer columns on the next write, read by Get-WorkspaceBenchmark, written only with `benchmark on`; `benchmark`, `benchmark-display`, `benchmark-history`, `layout-early-move` and `layout-stable-ms` are set at the top of `workspaces.conf`), `WorkspaceOpenMeasurements.csv` (the runs of Measure-WorkspaceOpen with their layout attempts, its sessions listed by `Measure-WorkspaceOpen --list-sessions`), `browser-groups` (the window each group opened, so a rerun skips
it), `terminal-windows` (the WezTerm window each `Open-Terminal --window-id NAME` opened), `current-layout` and `ai-mcp-servers.state` (the MCP servers Deploy-AiMcpServers registered per app under an AI profile, so it removes only those). Nothing there is configuration. The pinned clones of the AI manifest sources live in `$XDG_DATA_HOME/foundation/ai-manifests` (default `~/.local/share/foundation/ai-manifests`), outside every repository.
