# Bootstrap a Mac

`Bootstrap` is the macOS twin of the Windows [Bootstrap](https://ivanpavlak.github.io/WinuX/#/winux/modules/bootstrap): one command that provisions the machine in a fixed order, where every step is idempotent and can be switched on or off per machine. Rerunning it converges the Mac on what the repository says.

On a fresh Mac, `Unix/bootstrap.sh` does the first run on the stock bash 3.2: it installs chezmoi when needed, backs up the real files the dotfile links replace and runs `chezmoi init` and `chezmoi apply`, whose first apply installs Homebrew and Homebrew bash and runs `Bootstrap --with-initial-setup` (see [Getting started on a Mac](README.md#getting-started-on-a-mac)). Its first step, Initialize-Configuration, asks for the git identity, this Mac's name and machine type (chezmoi's answer is the default) and the dev root, and writes them into `git.local.conf` and `machines.local.conf`; a fork that committed its overlays is asked only what they lack. After that, `Bootstrap` is the command to rerun.

```bash
Bootstrap --list
Bootstrap --dry-run
Bootstrap
Bootstrap --only Packages,DockPins
Bootstrap --with-initial-setup
```

## Steps

In execution order. **Default** is the built-in state before any configuration; *initial* steps run only with `--with-initial-setup`, *sudo* steps need administrator rights and are skipped without them, *sudo-optional* steps share the password prompt but also run without it, *interactive* steps ask on the terminal.

| Step | Default | Kind | What it does | Windows analog |
|---|---|---|---|---|
| InitializeConfiguration | on | initial, interactive | Initialize-Configuration: the git identity (`git.local.conf`), this Mac's `host` line and its machine type's `dev-root` (`machines.local.conf`), asking only for what is not set; defaults without a terminal. The steps after it are resolved again, so the `@TYPE step` lines of the machine type it recorded govern the rest of the run | Initialize-Configuration |
| RenameMachine | on | initial, sudo | Rename-Machine | RenameMachine |
| Homebrew | on | | installs Homebrew when missing; a dry run names the installer without downloading it | package manager install |
| HomebrewBash | on | | Homebrew bash (bash 4.4+) | - |
| Packages | on | sudo-optional | trusts the `[Packages]` taps, gets App Store apps once, `brew bundle` per Brewfile, one retry; pkg installers use the one password prompt | WinGetApps, ScoopApps, ChocolateyApps |
| Dotfiles | on | | `chezmoi init --source Unix` + `chezmoi apply`; a real file or folder a link replaces is copied into `Backups/Unix/SymbolicLinks/` first and a failed copy applies nothing (the dry run lists the copies); reports links the old stow layer left; skipped under `CHEZMOI=1` | SymbolicLinks |
| GitIdentity | on | | sets an unset global `user.name` / `user.email` from `git.local.conf`, else from `Git/.gitconfig`; run alone (`Bootstrap --only GitIdentity`) it also replaces a set one that differs from `git.local.conf`, with a warning naming both, so a changed identity reaches git | git identity guarantee; Install-Git |
| MachineType | on | | reports this host's machine type from `machines.conf` | - |
| Permissions | on | initial, interactive | opens the Accessibility pane, then Privacy & Security for a kernel extension to approve (macFUSE), then the Automation pane (Safari and Chrome tab scripting), and waits for Enter each time; after Packages, so the apps exist | - |
| RepositoryUpdate | off | | Update-Repositories over the `repository-scope` of `bootstrap.conf`: `--all` for All (the default), the named groups otherwise. Group names only, as on Windows: a name that is no `repositories.conf` group (a repository's included) is reported with the configured groups, nothing is updated and the step fails | RepositoryUpdate, RepositoryUpdateScope |
| ObsidianSettings | on | | links the Obsidian vault's `.obsidian` to the `settings` folder of `obsidian.conf` (a real folder goes into `Backups/Unix/SymbolicLinks/Obsidian` first); nothing without a `settings` line, a vault not cloned yet is skipped with a warning (it comes with RepositoryUpdate, so the link follows on the next run) | SymbolicLinks (Obsidian) |
| SystemDefaults | on | | Set-SystemDefaults | ExplorerOptions, TaskbarSettings, VisualEffects |
| SpecialFolders | on | | Set-SpecialFolders: Downloads and the screenshot folder from `special-folders.conf`; nothing without a line | SpecialFolders |
| Power | off | sudo | Set-PowerSettings | PowerPlan, PowerButtonActions |
| Spotlight | off | sudo | `[Spotlight]`: `mdutil -i` per volume | - |
| Firewall | off | sudo | `[Firewall]`: `socketfilterfw` switches | - |
| SoftwareUpdate | off | sudo | `[SoftwareUpdate]`: machine-wide `defaults write` lines | - |
| Rosetta | off | sudo | installs Rosetta 2 on Apple silicon; you agree to its licence | - |
| SystemTheme | on | | Set-SystemTheme --auto | SystemTheme |
| Locale | on | | Set-Locale with `default-locale` of `language.conf`; nothing without one | Locale |
| DisplayLanguage | on | | Set-DisplayLanguage with `default-display-language`; takes effect after logging out | DisplayLanguage |
| KeyboardLayouts | on | | Set-KeyboardLayouts with `default-keyboard-set`. After the language steps, when any of the three ran, Display-SystemLanguageSettings reads back what they applied | KeyboardLayouts, Display-SystemLanguageSettings |
| DockPins | on | | Set-DockPins | Taskbar |
| LoginItems | on | | Set-LoginItems | - |
| FirefoxProfile | off | | Deploy-FirefoxProfile | Firefox `user.js` links |
| VSCodeProfiles | off | | Deploy-VSCodeProfiles: links the local extensions and the `vscode-profiles.conf` profiles into VS Code and installs their extensions | VSCodeProfiles |
| AiArtifacts | off | sudo-optional | Deploy-AiArtifacts: the skills, mods, rules, prompts and agents into the harnesses of the `deploy` line of `ai-artifacts.conf` (see [AI on a Mac](ai.md)) | CoreAiRules, AiSkills, AiMods |
| AiMarketplaces | off | | Deploy-AiMarketplaces | AiMarketplaces |
| AiMcpServers | off | | Deploy-AiMcpServers: the servers of `ai-mcp-servers.conf` into Claude Code and Codex (see [AI on a Mac](ai.md#mcp-servers)) | AiMcpServers |
| ObsidianCli | off | | Enable-ObsidianCli --create-if-missing | ObsidianCli |
| DotnetEf | on | | Install-DotnetEf | DotnetEf |
| DotnetSdks | off | sudo | Install-DotnetSdks: the `sdk-channel` lines of `dotnet.conf` (a .NET SDK no cask ships, such as 6.0) | the .NET 6 SDK of `WinGetApps.local.csv` |
| CondaEnvironments | on | | Install-CondaEnvironments | CondaEnvironments |
| NuGetConfig | off | interactive | Configure-NuGetConfig | NuGetConfig |
| NpmConfig | off | interactive | Configure-NpmConfig: the GitHub token of the `npm.conf` registries into `~/.npmrc` | NpmConfig |
| DockerDesktop | off | | Configure-DockerDesktop: where Docker Desktop installs its tools, the `cli-install` line of `docker.conf` (system mode keeps it from writing into the shell profiles) | - |
| UpgradeAll | off | | Upgrade-All (Homebrew and the App Store; `mas upgrade` asks for the password when an App Store app is outdated) | UpgradeAll |
| PersonalSteps | on | | the `[PersonalSteps]` lines of `bootstrap.conf`, a fork's own commands, in order; the base ships none | PersonalSteps |
| AeroSpace | on | | starts AeroSpace and checks its config | - |
| Logout | off | interactive | asks to log out so keyboard and trackpad settings apply; when off, prints a reminder | Restart-Machine |

The defaults follow the Windows rule: a step is on when it is idempotent or does nothing on an empty configuration, and off when it acts at once, prompts, or needs root.

## Choosing steps

Lowest to highest, as on Windows:

1. the built-in default above
2. `step NAME on|off` lines of `Unix/config/bootstrap.conf`, then of `bootstrap.local.conf`; a line prefixed `@TYPE` applies on that machine type only (`@Laptop step Power on`), as the per-machine-type step values do on Windows
3. `--include STEP...`
4. `--skip STEP...`, which wins; a step in both lists is skipped with a warning

`--only STEP...` runs just the named steps, whatever their state, and is the way to rerun a failed one. Names compare case-insensitively and lists may be comma-separated (`--skip Power,UpgradeAll`). The values of the inline steps live in the same file; see [bootstrap.conf](configuration.md#bootstrapconf).

## Administrator rights

When an enabled step needs root, the password is asked once, before the first step (or right after InitializeConfiguration, when a step that its recorded machine type turned on needs root), and kept fresh in the background until the run ends; Packages counts, because pkg-based casks run their installers with sudo. Nothing is asked when no such step runs, and never in a dry run. A refused password skips the *sudo* steps; the rest still runs, the summary lists what was skipped, and the exit status is 1 even when no step failed, so a script sees the run as incomplete (rerun the skipped steps with `Bootstrap --only ...` once the password is at hand).

## Dry run and summary

`--dry-run` passes each command its own dry run (`--dry-run` or `--check`), prints the inline commands it would run, never asks for the password and changes nothing. Commands without a dry run of their own (Rename-Machine, Set-SystemTheme, Set-Locale, Set-DisplayLanguage, Set-KeyboardLayouts, Update-Repositories, Upgrade-All) are only named.

A failed step does not stop the run. The summary lists the steps that ran and the ones that failed, with the `Bootstrap --only ...` line that reruns them, and the exit status is 1. The whole run, including every command it starts, goes into one session log under `Unix/logs`; a run that is not a dry run also keeps a transcript of the console, the output of brew, defaults and the other tools included, in `~/Desktop/BootstrapLog_<yyyy-MM-dd_HH-mm-ss>.log` (as the Windows Bootstrap's Start-Logging does), and ends with `Log file location =>` and `Total duration =>`. `Unix/bootstrap.sh` opens a session log of its own (`Session_<timestamp>_bootstrap.sh.log`) that chezmoi's first apply, `bootstrap-first-run` and the Bootstrap it starts write into, so a failed first run leaves its trace there.

## Dotfiles with chezmoi

The dotfile links are [chezmoi](https://www.chezmoi.io)'s (GNU stow did this before). `Unix/.chezmoiroot` names `Unix/home` as chezmoi's source state, so every chezmoi file stays under `Unix/`:

- one `symlink_*.tmpl` per dotfile, rendering to a path inside the repository (`{{ .chezmoi.workingTree }}/...`), so `~/.zshrc`, `~/.gitconfig`, `~/.config/aerospace/aerospace.toml`, `~/.ssh/config` and the rest stay links and editing them edits the repository. `.chezmoiignore` skips `~/.ssh/config` when the repository has no `.ssh/config` (a clone that does not ship one), and the terminal overrides `~/.config/wezterm/wezterm.local.lua` and `~/.config/ghostty/config.local` when the repository has no `WezTerm/wezterm.local.lua` or `Unix/ghostty/config.local`, so no link points at nothing. The fastfetch config follows the machine type (`FastFetch/Unix/config_<Type>.jsonc`), with the shipped Test file as the fallback.
- `.chezmoi.toml.tmpl`, rendered by `chezmoi init`: it records the source folder and asks twice, once per machine: the machine type (the default is what `machines.conf` says for this host) and whether to run `Bootstrap --with-initial-setup` after the first apply. Both answers are kept in `~/.config/chezmoi/chezmoi.toml`, and a later `chezmoi init` reuses them without asking, so a `host` line changed afterwards does not reach chezmoi: `chezmoi init --prompt` asks again (see [Troubleshooting](troubleshooting.md#a-mac-keeps-its-old-machine-type-after-machinesconf-changes)).
- `.chezmoiscripts/run_once_after_bootstrap.sh.tmpl`: on that first apply it runs `bootstrap-first-run`, which installs Homebrew and Homebrew bash when they are missing and hands over to `Bootstrap --with-initial-setup` (`bootstrap-first-run --help` only prints its usage, and any other argument is refused, so typing it never provisions by accident). chezmoi sets `CHEZMOI=1`, so the Dotfiles step leaves the links to chezmoi. Answering no at `chezmoi init` renders the script empty, and chezmoi skips it.

The shell rc files the links point at live in `Unix/shell/` (`zshrc`, `bashrc`, `bash_profile`), the git overrides in `Git/Unix/gitconfig.local` (the GitHub credential helper and the `merge=ours` driver). Because `~/.zshrc` is a link into the repository, an installer that appends to it edits the tracked `Unix/shell/zshrc`: move what it adds to `~/.shellrc.local`, which the shared rc sources and git never sees. Docker Desktop's completion lines are not needed at all - the shared rc puts `~/.docker/completions` on `fpath` before the completion system starts, and their extra `compinit` would run a second, uncached one. `Add-SymbolicLink HOME-PATH TARGET` adds a link template. chezmoi replaces a real file at a link's place without asking on the first apply; `bootstrap.sh` and Bootstrap's Dotfiles step copy such files into `Backups/Unix/SymbolicLinks/` first and apply nothing when a copy fails, a bare `chezmoi apply` does not back up. To look at what chezmoi would do (`chezmoi init` writes only chezmoi's own config, `~/.config/chezmoi/chezmoi.toml`; the rest changes nothing):

```bash
chezmoi init --source ~/Development/GitHub/Foundation/Unix
chezmoi data
chezmoi diff
chezmoi apply --dry-run --verbose
```

## Still manual

macOS keeps some decisions with the person at the keyboard: privacy permissions (Accessibility, Automation, Full Disk Access), Gatekeeper exceptions, FileVault, signing in to the App Store, approving a kernel extension, and agreeing to Rosetta's licence. The steps that touch these open the right place or stop with the pane to open.
