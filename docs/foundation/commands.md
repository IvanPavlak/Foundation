<!-- reference: commands unix -->

# Unix Commands

Every command of the Unix half is a bash executable in `Unix/modules/<Module>/bin`, named exactly
like its Windows function and filed under the module of its Windows twin, so it runs from zsh, bash or any other shell and from scripts. `<Command> --help`
prints the same header this page summarises. Windows-style flags are accepted next to the Unix
spelling, case- and dash-insensitively like PowerShell parameters (`w Dotfiles -TimeoutSeconds
45`, `kill-all -includecurrent` and `Kill-All --include-current` all work), and a
PowerShell-style abbreviation takes the one flag it starts, as the Windows binder does
(`w Example -Along` is `--alongside`; a prefix several flags share, `-Include` with both
`--include-current` and `--include-default-branch`, stops the command as ambiguous; the Unix
`--` spelling is never abbreviated). `-v` / `--verbose` turns on debug output everywhere. The aliases are defined in
`Unix/shell/shellrc.sh`.

The PowerShell switches a command does not take never reach it as a value. `-WhatIf` is the dry
run of a command that documents `--dry-run` (Bootstrap and its steps, Set-SystemDefaults,
Clear-OldLogs, Clear-OldBackups, ...) and stops every other command before it does anything, as
on Windows, where only a few functions support it; `-Confirm`, `-Debug` and `-ErrorAction` stop a
command the same way. The commands that close, move, rename, restart, upgrade or write -
Kill-All, Terminate-WindowsTerminalTabs, Close-ProjectTerminals, Rename-Machine, Restart-Machine,
Upgrade-All, Set-SystemDefaults, Move-Windows, Reset-Windows, Focus-VirtualDesktop,
Set-WorkspaceWindowLayout, Docker-Cleanup, DockerWizard, Open-Docker, Open-Terminal, Open-Obsidian,
Open-SecureBrowser, Add-BrowserGroup, Initialize-Repository - refuse any flag they do not
document instead of taking it for a name, a pattern or a desktop, so a typo never runs them. So
does every command that collects names (workspaces, projects, groups, folders, stacks, machines,
patterns): `--udpate` is an error, never a workspace called `--udpate`.

Name lists take the PowerShell comma form: `cw Server,Client`, `Upgrade-All Homebrew,AppStore`
and `Open-Browser AI, GitHub` (which reaches bash as `AI,` `GitHub`) each name two, as
`[string[]]` parameters bind on Windows. A Windows parameter name that only stands in front of the
names (`-Workspace`, `-Project`, `-Groups`, `-TestName`, ...) is accepted and ignored; each
command's header lists its own under `Windows-style names:`, which also makes the flag match in
any case (`Run-Tests -testname layout`). PowerShell's prefix abbreviations (`-Along` for
`-Alongside`) are not accepted.

`--help` prints the header without doing anything, in the pass-through wrappers too (DotnetRun,
DotnetBuildAndRun, NpmInstallAndStart, GitPull, Open-ClaudeDesktop): a leading `--help` is
theirs, and `DotnetRun -- --help` hands it to the wrapped tool.

Command names are case-insensitive too (`kill-all`, `reload-profile`). Every shell function a
module manifest lists (`Reload-Profile`, `Cd-Desktop`, `Show-TerminalGreeting`) gets a lowercase
alias, and a not-found handler retries any other command under its case-insensitive match in the
module folders, then as an alias in another case (`GSW` runs `gsw`). That matters on Linux; macOS
already resolves executables case-insensitively (so `W` finds the system's `/usr/bin/w` before
the handler is asked). The Windows names the Unix half spells differently are aliases:
`Preview-LoadingSpinners` (`Loading-Spinner --preview`) and `Create-CondaEnvironments`
(`Install-CondaEnvironments`).

Every menu is one shared Resolve-Selection port (`lib/foundation.sh`), drawn on stderr and read
from the terminal (never stdin): answer by number or name, several separated by spaces or commas
where a menu takes several. A menu with a default shows it as `(default: NAME)` and Enter picks it;
a Yes/No confirmation (Restart-Machine) draws its question in red and Enter means No; the
browser-group menu is a tree numbered `1`, `1.2`, `1.2.1` that takes an index path or a name.
Without a terminal a menu fails and nothing it would have chosen runs. A name given on the command
line goes through the same matching without showing the menu, as `-InputObject` does on Windows:
a menu number (`w 2`, `Open-Browser 1.2`), a name in any case, or an entry the menu adds itself
(`Send-WakeOnLan None`) names that entry.

A command that acts on several things and fails on some of them says so: Center-Windows,
Resize-Windows and Reset-Windows end with a warning and exit status 1 instead of their success
line, and Open-Workspace names its failed actions in the closing warning (its exit status stays
0, like Kill-All with survivors).

## Modules

A module is a folder of `Unix/modules` with a `module.conf` manifest (the `.psd1` analog: its
`command`, `function` and `helper` lines), a `bin` of executables, and optionally a
`functions.sh` of shell functions (commands that must run in the calling shell). The shell rc
puts every module's `bin` on PATH and sources its `functions.sh`; `Reload-Profile` lists each
module it reloaded. `List-Functions --list-discrepancies` checks every manifest against its
folder and its page.

A fork's own commands live in the [Custom area](custom/README.md), `Unix/modules/Custom/<Module>`,
with the same layout and their pages in `docs/foundation/custom`. The engine wins on a name clash.

| Module | Contents |
| --- | --- |
| [AI](modules/AI.md) | Deploys the AI agent rules, skills, Claude Code mods and plugin marketplaces, lists the skills the repository carries and vendors skills and mods from upstream. |
| [Application](modules/Application.md) | Launches and focuses applications and browser groups. |
| [Bootstrap](modules/Bootstrap.md) | Provisions a Mac: the Bootstrap runner and its steps - the first-run identity and paths, dotfiles, the Firefox profile, system defaults, power settings, Dock pins, login items, dotnet-ef, Conda environments and the NuGet config. |
| [Configuration](modules/Configuration.md) | Adds workspaces, projects, browser groups, layouts and links to the Unix config files and checks them. |
| [Git](modules/Git.md) | Git shorthands and repository cloning and updating. |
| [Helper](modules/Helper.md) | General helpers: search, translation, the command reference, the colour palette, countdowns, backups, project runs and the .NET/npm shorthands. |
| [System](modules/System.md) | Machine-wide actions: closing everything, terminal tabs, Wake-on-LAN and reachability, upgrades, drives, theme and wallpaper, languages and keyboard layouts, dated folders, special folders, installed apps, .NET SDKs, machine name, restart, the terminal greeting and the shell profile and its start-up time. |
| [Logging](modules/Logging.md) | Finds, pins and prunes the session and error logs every Foundation command writes. |
| [Tests](modules/Tests.md) | Runs the Unix test suites and the shellcheck lint. |
| [Window](modules/Window.md) | Desktops (AeroSpace workspaces), window lookup and inspection, moving, centering and resizing windows, workspace layouts and their drawings. |
| [Workflow](modules/Workflow.md) | Workspaces, projects, their terminals, Docker containers and EF Core migrations. |
