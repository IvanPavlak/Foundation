# Foundation

Foundation, the macOS counterpart of WinuX (the Unix half): the same one-command workflow as
Windows (`w Dotfiles`, `cw`, `Kill-All`, `b`, `t`, `rp`, the git aliases) on a Mac, built from
bash executables, plain config files and free tools. Linux is a design constraint (every platform
call sits in a driver), not yet a target.

| Windows piece                          | macOS piece                                                      |
| -------------------------------------- | ---------------------------------------------------------------- |
| PowerShell modules + profile           | modules in `Unix/modules` (bash executables + manifest), sourced libraries in `Unix/lib` |
| `Configuration(.local).psd1`           | small per-domain files in `Unix/config` (see [Configuration](configuration.md)) |
| Virtual desktops + FancyZones          | [AeroSpace](https://nikitabobko.github.io/AeroSpace/) workspaces 1..9, tiled |
| Windows Terminal (`wt`)                | [WezTerm](https://wezterm.org/) (`wezterm cli`)                  |
| WinGet / Scoop / Chocolatey            | Homebrew: `Unix/Brewfile` (the runtime, like the base `WinGetApps.csv`), `Unix/Brewfile.local` (your apps, like `WinGetApps.local.csv`) |
| SymbolicLinkMaker                      | [chezmoi](https://www.chezmoi.io): link templates in `Unix/home` (see [Bootstrap a Mac](bootstrap.md#dotfiles-with-chezmoi)) |
| Bootstrap module                       | `Unix/bootstrap.sh` (first run), then `Bootstrap`                |

WezTerm (and Ghostty, for casual use) follow the Windows Terminal settings: a new window starts
on the Desktop (`startingDirectory`), WezTerm keeps 9999 lines of scrollback (`historySize`), and a
mouse selection in WezTerm is not copied to the clipboard until Cmd+C (`copyOnSelect false`).
WezTerm's keys port the Windows Terminal actions: Shift+Enter sends ESC CR (a newline without
submitting, in Claude Code and other TUIs), Cmd+W closes the focused pane only (`closePane`) and
Cmd+Shift+W the whole tab, and Cmd+Shift+X moves the focused pane into a new window (`moveTab`,
Alt+X on Windows). The **Conda** entry of WezTerm's launcher (right-click the `+` of the tab bar)
is the Conda profile: conda's shell hook, the base environment, the Conda fastfetch panel
(`FastFetch/Unix/config_Conda.jsonc`), then an interactive zsh in the home folder; the Windows
profile's Solarized Dark colours are not ported. A shell started inside an activated environment
gets conda's shell function back from the rc, so `conda activate` keeps working there.

Command reference: [Unix Commands](commands.md). Workspace details: [macOS Workspaces](macos-workspaces.md). Configuring by
interview: [FoundationConfigurator](foundation-configurator.md). What gets installed: [Software on a Mac](software-list.md). The
AI layers: [AI on a Mac](ai.md). Backups: [Backups on a Mac](backups.md). When something fails:
[Troubleshooting on a Mac](troubleshooting.md).

## Getting started on a Mac

### Before you start

- **macOS.** Foundation is built and tested on a current macOS (27) on Apple silicon. AeroSpace,
  the tiling window manager it relies on, needs macOS 13 Ventura or later. An Intel Mac is not
  tested, though the first run finds Homebrew under `/opt/homebrew` or `/usr/local`; the Rosetta
  step (off by default) only matters on Apple silicon.
- **An administrator account.** Homebrew, the permission panes and the steps that need root
  (power, firewall, software update, renaming the Mac) ask for its password once per run.
- **One Mission Control Space.** AeroSpace only sees the windows of the current Space; its
  workspaces replace extra Spaces.
- **An Apple Account in the App Store app**, only when a Brewfile has `mas` lines (App Store
  apps): signing in there cannot be scripted.
- **Internet access** for Homebrew, chezmoi and the casks. The Command Line Tools (git included)
  come from `xcode-select --install` below.

Cloning variants:

- **A private fork**: `git clone https://github.com/MyUser/MyFork.git ~/Development/GitHub/MyFork` (then run
  `~/Development/GitHub/MyFork/Unix/bootstrap.sh`; the folder can be anywhere).
  Until the GitHub CLI is installed (`gh`, a line of `Brewfile.local`) and `gh auth login` has run,
  git asks for a username and password: give a personal access token as the password. Afterwards
  git authenticates through `gh` (see [Git credentials](#git-credentials)).
- **A branch**: `git clone -b my-branch ...`.
- **A Mac that already has the clone**: `bootstrap.sh` neither clones nor pulls, so update it first
  with `git -C ~/Development/GitHub/Foundation pull --ff-only`, then run it (or `Bootstrap`) again.

### First run

```bash
xcode-select --install
git clone https://github.com/IvanPavlak/Foundation.git ~/Development/GitHub/Foundation
~/Development/GitHub/Foundation/Unix/bootstrap.sh --dry-run
~/Development/GitHub/Foundation/Unix/bootstrap.sh
```

`bootstrap.sh` runs on the stock macOS bash 3.2 and only links the dotfiles: it checks the
Command Line Tools, installs chezmoi into `~/.local/bin` when it is missing, runs `chezmoi init`
(it asks the machine type and whether to provision now, once per Mac), copies every real file a
link would replace into `Backups/Unix/SymbolicLinks/Dotfiles.<path>/` and runs `chezmoi apply`.
`--dry-run` changes nothing and shows `chezmoi diff` once chezmoi is set up. On the first apply,
when you answered yes, chezmoi installs Homebrew and Homebrew bash and hands over to
`Bootstrap --with-initial-setup`: `brew bundle`, the machine-type check, the
permission panes, the system settings, theme, Dock and login items, AeroSpace, and the AI
artifacts, plugin marketplaces and MCP servers once a fork turns those steps on (`step AiArtifacts on`,
`step AiMarketplaces on` and `step AiMcpServers on` in `bootstrap.local.conf`; the base ships them off). Every module executable needs bash 4.4+ and says so (with the
install hint) when started by an older one.

Afterwards `Bootstrap` is the command to rerun, with every step switchable per machine, the
power, firewall and update steps included: see [Bootstrap a Mac](bootstrap.md).

Bootstrap's Packages step handles what used to stop `brew bundle` on a fresh Mac: it trusts the
third-party taps, gets the App Store apps first (skipping, with a warning, one it cannot get) and
retries a failed download once. Still manual, once per Mac: approving a kernel extension a cask
installs (macFUSE, for VeraCrypt) and "Open Anyway" for an app whose signer Homebrew could not
verify (DBeaver). The messages and fixes are under
[Troubleshooting: Bootstrap and Homebrew](troubleshooting.md#bootstrap-and-homebrew); what the
step installs is on [Software on a Mac](software-list.md).

### One-time permissions (TCC)

macOS does not let a script grant these; Bootstrap's Permissions step (part of `--with-initial-setup`)
opens the right pane and waits.

- **AeroSpace - Accessibility.** Until it is granted `w` reports that AeroSpace did not answer.
  AeroSpace asks again after an update that changes its signature.
- **WezTerm - Accessibility.** Needed by Center-Windows, Resize-Windows and `Reset-Windows
  --center`, which set window frames through the Accessibility API (reading a frame - the frame
  check of Set-WorkspaceWindowLayout, Resize-Windows, Get-ActiveWindowInfo - goes through the
  window server's window list and needs no permission). AeroSpace's own permission does not cover scripts run from the terminal. Add WezTerm with `+`,
  then quit and reopen it; until then those commands say "The terminal may not control windows".
  Also listed under troubleshooting.
- **The terminal - Automation (System Events).** Asked once, on the first `Set-SystemDefaults`
  (theme), `Set-SystemTheme` or `Set-LoginItems` run.
- **The terminal - Automation (Safari, Chrome, Brave, Edge).** Asked once per browser, the first
  time Open-Browser or Close-Project scripts it (a group opened in Safari, the tabs read to tell a
  group is open, a project's tabs closed). Refused, Safari opens no group and the rest fall back to
  whole windows, with a warning naming the pane.

Keep a single Mission Control Space: AeroSpace only sees windows on the current Space.

### Git credentials

Git authenticates to GitHub through the GitHub CLI, as on Windows: run `gh auth login` once. The
shared `Git/.gitconfig` names the Windows `gh.exe` and includes `~/.gitconfig.local` last; on
Unix that file is chezmoi's link to `Git/Unix/gitconfig.local` and switches the helper to the
Unix `gh` (with a Homebrew fallback path, because GUI apps such as Obsidian start without
Homebrew on PATH). Without it every git client, including the Obsidian Git plugin, asks for a
password and GitHub rejects it as unsupported.

The same file registers the `ours` merge driver that `.gitattributes` names (`merge=ours`: a
merge from upstream keeps the fork's copy of a listed payload). Git never takes a driver from a
cloned repository; Windows' installer sets it with `git config --global merge.ours.driver true`,
the Mac gets it from `Git/Unix/gitconfig.local`, because `~/.gitconfig` is a link to the tracked
`Git/.gitconfig` and a global write would edit the repository.

## Kept simpler than on Windows

- Environment variables: no configured list as `AutoEnvironmentVariables` on Windows; PATH comes
  from the shell rc and `brew shellenv`, and a machine's own exports go in `~/.shellrc.local`.
- Shell start: no configuration check (the Windows Schema stage; one Test-ConfigurationSchema run
  takes about 16 s, see [Unix Configuration](configuration.md#files)) and no in-session table of
  stage times (`$WinuXStartupTimings`): `FOUNDATION_STARTUP_TRACE` records them for
  Measure-ShellStartup, and a clock read per stage would cost every start.
- Nerd Font: a Brewfile cask (`font-jetbrains-mono-nerd-font`, the font the WezTerm and Ghostty
  configs name), no font menu as `Configure-NerdFont` has.
- Version pins: the Brewfile has no version column as the Windows app lists do, so the pins live
  in `package-pins.conf` (`brew FORMULA` lines), which Upgrade-All reconciles with `brew pin` and
  `brew unpin` before it upgrades, the Sync-AppPins of Windows. Homebrew pins the installed version;
  it cannot install an arbitrary one.
- Node: Windows installs Node LTS (`OpenJS.NodeJS.LTS`) next to mise; on the Mac mise alone
  provides it (`brew "mise"` in a `Brewfile.local`): a `[PersonalSteps]` line of `bootstrap.local.conf`,
  `mise use --global node@lts`, sets the global version, a project's `mise.toml` pins its own, and
  the shell rc puts mise's shims folder on PATH (no process at shell start). Bun is the Homebrew
  `bun` formula.
- Create-Executable: not ported. Every Foundation command already is an executable in
  `Unix/modules/*/bin`; a standalone copy would need `Unix/lib` inlined into it.
- Notepad++ launcher: not ported. Notepad++ has no macOS build; VS Code and Obsidian take its
  place (the Test workspace opens Obsidian).
- GCC toolchain (Install-GccToolchain, MSYS2): not ported. clang and gcc come with the Command
  Line Tools, which the first step of `Unix/bootstrap.sh` checks.
- Configure-PostgreSqlPasswords: not ported. PostgreSQL runs only as the Docker stack
  (`stack PostgreSQL` of `docker.conf`), and its password is the compose file's. Port it if a
  native `postgresql@N` formula is ever added.
- Wallpaper picker: not ported. Set-Wallpaper takes the picture from `wallpapers.conf`; System
  Settings covers a manual pick.
- Special folders: Set-SpecialFolders moves Downloads and Screenshots only. Windows also relocates
  Desktop, Documents and the other known folders; none is used here, and linking Desktop or
  Documents is risky while iCloud Drive syncs them.
- Always-on-top terminal: not bound. Stable WezTerm (20240203, checked 2026-10-23) has no
  always-on-top action, only `wezterm@nightly` does, and the orchestration terminal stays on the
  stable release. Bind it when a stable release ships it.

## Machine type

`Unix/config/machines.conf` lists the valid machine types (`type` lines, the `ValidMachineTypes`
of Windows) and maps `scutil --get LocalHostName` to one of them, the `HostnameToMachineType` of
Windows. The type is resolved in this order:

1. `FOUNDATION_MACHINE_TYPE`, an override for one shell
2. the `host` line of `machines.conf` matching this Mac's name
3. `MACHINE_TYPE`, when the environment exports it (`~/.shellrc.local` holds per-machine exports)
4. the `default` line of `machines.conf`, else Test

A type that is no `type` line (a typo such as `FOUNDATION_MACHINE_TYPE=work2`) is still used, with
a warning naming where it came from, once per command (once per `w` run), as Windows'
DetermineMachineType rejects an unknown type; an `@TYPE` prefix naming no type is logged at the
verbose level (`-v`), and Test-ConfigurationSchema reports both. The type picks the Oh My Posh
theme (the `prompt-theme` line of `theme.conf`, `{MachineType}` replaced) and the layout set; a
primary display at most `small-display-width` points wide (default 3000, the MacBook's own panel)
uses the `small-display` set of `machines.conf`, when one is configured.

## Shell startup

Every interactive zsh (and bash on Linux) sources `Unix/shell/shellrc.sh` through `~/.zshrc`, the
port of the Windows profile. First, in every shell: `DOTFILES_ROOT`, the shared logging, PATH
(every module's `bin`, the Custom area's first, then `~/.local/bin` and mise's shims; `~/.zshrc`
runs `brew shellenv` before). Then, interactive shells only, these stages in order:

| Stage | What it does |
| ----- | ------------ |
| LineEditing | Reads `shell.conf` (the PSReadLine settings) and the prompt theme; sets `LANG=en_US.UTF-8` when macOS left it empty; the zsh or bash history (`history-size`, `history-file`); the edit mode (`emacs`, `vi`, or `windows` with PSReadLine's Windows-mode keys); the `key` handlers, `history-no-duplicates`, `history-save-style`, `completion-ignore-case` and the prediction list (zsh); the completion system with zsh's own defaults. Nothing without a `shell.conf` line (the base ships none) |
| Aliases | `w`, `cw`, `rp` and the other short names of the Windows profile; an `Open-<App>` alias for every `apps.conf` token without a command of its own |
| Prompt | Oh My Posh with the machine type's theme (`prompt-theme` of `theme.conf`; `OH_MY_POSH_THEME` wins); a warning with the install hint when it is missing |
| Plugins | zsh-syntax-highlighting when installed (the prediction plugins zsh-autosuggestions and zsh-autocomplete are not loaded until the line editing is ported) |
| Icons | `ls`, `ll`, `la` through `eza --icons` when eza is installed (the Terminal-Icons analog), in the `list-color` colours of `theme.conf` (`EZA_COLORS`) |
| Greeting | Show-TerminalGreeting: clear, the fastfetch panel, onefetch inside a repository (`greeting.conf`) |
| RepositoryUpdate | Invoke-StartupRepositoryUpdate when it is due (off unless `repositories.conf` says `startup on`) |

Between Plugins and Icons the modules' shell functions load (each `functions.sh`, e.g.
Reload-Profile), and `~/.shellrc.local` is sourced right before the Greeting: this machine's own
exports and aliases, never committed. `FOUNDATION_STARTUP_SKIP` leaves stages out for one shell
(names separated by commas or spaces, or `All`):

```bash
FOUNDATION_STARTUP_SKIP=Greeting,RepositoryUpdate zsh
```

[Measure-ShellStartup](modules/System.md#measure-shellstartup) times each stage.

## Checking the current state

```bash
Bootstrap --only MachineType --dry-run   # this Mac's host name and machine type (and the missing host line, if any)
chezmoi data | grep machineType          # the machine type chezmoi links dotfiles for
Visualize-Layouts MyWorkspace            # a workspace's layout; its title names the layout set in use
Bootstrap --list                         # every step with its default and its state on this Mac
Test-ConfigurationSchema                 # the Unix config files checked against each other
Get-LogPath                              # the newest session log (--errors: the error log)
Get-RepositoryPath                       # the repository root the commands use
```

## Layout of the Unix half

```
Unix/
├── modules/<Module>/ module.conf manifest, bin/ of Verb-Noun executables, optional functions.sh
│   └── Custom/<Module>/  the fork-owned Custom area, laid out the same - see docs/foundation/custom
├── lib/             sourced bash: foundation.sh (core), config, steps, repository, apps, layout, project, state, terminal, testrun (Run-Tests),
│   └── drivers/     aerospace.sh, wezterm.sh, inputsource.sh (+ .swift) - the only files that call those tools
├── config/          workspaces, layouts/<Type>/<Workspace>_<Type>, projects, browser-groups, apps, zones, machines, kill-all
├── shell/           shellrc.sh, the shared interactive rc (zsh on macOS, bash on Linux), aliases;
│                    zshrc, bashrc, bash_profile, the files ~/.zshrc and friends link to under chezmoi;
│                    autocomplete-guard.zsh, the time limit on zsh-autocomplete's worker (not sourced now)
├── home/            chezmoi source state (.chezmoiroot): one link template per dotfile, the config
│                    template and the first-apply script - see docs/foundation/bootstrap.md
├── tests/           bats suites (run: Run-Tests)
├── logs/            session and error logs of every command (gitignored, Pinned/ kept)
├── Brewfile         the runtime the Unix half needs (do not add your own apps here)
├── Brewfile.local   this machine's packages, bundled after Brewfile
└── bootstrap.sh
```

Rules: every app or process that outlives a command is started through `foundation_launch`, which drops the `FOUNDATION_*` variables (an app started by `w` would otherwise hand that open's session log and state to every command run from it); no `aerospace` / `wezterm` invocation outside `lib/drivers` (checked by the tests); no
file under `Windows/` refers to `Unix/`; shared assets (Oh-My-Posh, WezTerm, Git, Btop,
FastFetch, LazyGit, LazyDocker, Wallpapers) stay top-level and are linked by chezmoi. A file that
must differ per OS gets a `Unix/` sibling that chezmoi links instead, leaving the Windows file
untouched: `FastFetch/Unix/config_<Type>.jsonc` and `Btop/Unix/btop.conf` (btop rewrites its
config with platform-specific keys, so the Mac keeps its own; the themes stay shared).

## Menus

Every command that is started without its main argument shows the same numbered menu, a port
of Windows' Resolve-Selection (`foundation_resolve_selection` in `Unix/lib/foundation.sh`): pick by number
or name, several at once separated by spaces or commas where the command allows it; invalid
entries are listed and asked again. Titles, prompts and what an empty Enter does (default
workspace, plain browser window, cancel, or "a selection is required") follow each Windows
function. A name passed as an argument is matched the same way without the menu
(`foundation_resolve_items`, the `-InputObject` path of Resolve-Selection): a menu number, a name
in any case, or an entry the menu adds itself, such as None of Send-WakeOnLan.

## Tests

```bash
Run-Tests
```

`Run-Tests` is the Windows `Run-Tests` analog: every bats suite in parallel workers with a live
test counter, shellcheck and `shfmt` over the files CI checks alongside, then one verdict line
and the full output in `Unix/tests/Results/` (gitignored). `Run-Tests layout` runs one suite,
`--filter REGEX` single tests, `--quick` leaves out the integration tier (real git and nested
runs), `--changed` runs only what the uncommitted and branch changes can affect, and the worker
count is learned per machine (see [Tests](modules/Tests.md)); plain `bats -r Unix/tests` works
too, serially. The suites cover
the pattern rules, the config readers against a generic fixture config
(`Unix/tests/fixtures/config`, never your `Unix/config`), and the
commands-versus-docs completeness check (the Test-ManifestCompleteness analog). CI runs them on
macOS (`.github/workflows/foundation.yml`), the only Unix Foundation runs on, through `Run-Tests
--audit-since` (the full suite, plus a warning for every failing suite `--changed` would have
missed), together with shellcheck over the list `Run-Tests --lint-files` prints and shfmt; the job
reports as the `Unix Tests` check, can be re-run by hand (`workflow_dispatch`), and keeps the run log
as the `unix-run-log` artifact. It runs on every pull request and on pushes to `master`. The job is
skipped in a private repository, so a private fork never spends Actions minutes on it and
`Run-Tests` on the Mac is the gate; a fork keeps the workflow byte-identical to Foundation's, so a
merge from Foundation never conflicts on it. The lint settings live in `Unix/.shellcheckrc` and `Unix/.editorconfig`, which the recommended VS
Code extensions (`timonwong.shellcheck`, `mkhl.shfmt`) read too.
