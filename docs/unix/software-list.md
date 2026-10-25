# Software on a Mac

What Foundation installs on a Mac and how a machine adds its own. Packages come from Homebrew
Brewfiles, the counterpart of the WinGet, Scoop and Chocolatey app lists of Windows: the base
`Unix/Brewfile` (like the base `WinGetApps.csv`) holds only the runtime Foundation needs, and
`Unix/Brewfile.local` (like `WinGetApps.local.csv`) holds this machine's own apps.

Bootstrap's Packages step bundles both, in that order (`brew bundle --file ...`), after the
Homebrew and HomebrewBash steps have installed Homebrew and the bash every command needs. The
Command Line Tools (git, clang, make) are not a package: `Unix/bootstrap.sh` checks for them first.

## The base Brewfile

Everything here is needed for Foundation to work end to end; do not add your own apps to it.
`Unix/tests/docpages.bats` checks that this table and `Unix/Brewfile` list the same entries.

| Entry | Kind | Why it is needed |
| ----- | ---- | ---------------- |
| `nikitabobko/tap` | tap | AeroSpace's tap, which carries the `aerospace` cask; trusted by the Packages step (`trust` line of `bootstrap.conf`) |
| `bash` | brew | Every command in `Unix/modules` needs bash 4.4+; macOS ships 3.2 |
| `jq` | brew | JSON for the WezTerm driver, `foundation.sh` and Invoke-GoogleTranslate |
| `fzf` | brew | Fuzzy finder for the shell; no Foundation command uses it yet |
| `chezmoi` | brew | The dotfile links of `Unix/home` (Bootstrap's Dotfiles step); `Unix/bootstrap.sh` puts a copy in `~/.local/bin` before Homebrew exists |
| `dockutil` | brew | The Dock pins of Set-DockPins |
| `aerospace` | cask | Tiling and desktops, the FancyZones and virtual desktop analog |
| `wezterm` | cask | The orchestrated terminal (`wezterm cli`), the Windows Terminal analog |
| `shellcheck` | brew | Lint of the Unix half (Run-Tests, CI) |
| `shfmt` | brew | Format check of the Unix half (Run-Tests, CI) |
| `bats-core` | brew | Test runner of the Unix suites (Run-Tests, CI) |

Casks cannot be version-pinned; a formula can be held with `brew pin FORMULA`, which Upgrade-All
lists and skips.

## Your own packages: Brewfile.local

Add a machine's apps to `Unix/Brewfile.local`, one Brewfile line each, with a comment saying what
uses it:

```ruby
brew "oh-my-posh"                 # prompt theme (Oh-My-Posh/, loaded by shellrc.sh)
cask "visual-studio-code"         # Open-VSCode, Deploy-VSCodeProfiles
mas "Some App", id: 123456789     # an App Store app, by its numeric id
```

Then run `Bootstrap --only Packages` (or `brew bundle --file Unix/Brewfile.local`). The optional
tools the shell rc and the commands use when present (Oh My Posh, fastfetch, onefetch, eza, the
zsh plugins, the GitHub CLI `gh`, the Claude Code CLI `claude-code`) belong here: each is guarded,
so a Mac without them still works, with a warning or a plainer shell.

- **App Store apps** (`mas` lines) need an Apple Account signed in to the App Store app; the
  Packages step runs `mas get` for each one first and skips, with a warning, an app it cannot get.
- **Third-party taps** need trust before `brew bundle` loads them: add a `trust TYPE NAME` line
  (`trust cask some-org/tap/some-app`) to the `[Packages]` section of `bootstrap.local.conf`.
- **Removing a base package** from a machine: point the Packages step at your own Brewfiles with
  `brewfile PATH` lines in `[Packages]` of `bootstrap.local.conf` (they replace the default
  `Unix/Brewfile`, `Unix/Brewfile.local`; an overlay section replaces the base one whole, so copy
  its `trust` line too). Leaving out an entry of the base Brewfile leaves out a part of Foundation:
  the table above says which.
- **Removing a package you installed**: delete its line and run `brew uninstall NAME`; the Packages
  step never removes what is not listed.

The [macOS Configurator](macos-configurator.md) edits `Brewfile.local` by interview, and
[Bootstrap](guides/bootstrap/Bootstrap.md) documents the `[Packages]` lines.

## Apps not on the Mac

Foundation installs the base Brewfile only. Which apps of WinuX's lists a fork's Macs do without,
and why, is the fork's own record: keep it with the fork's other pages (the Custom area page of a
fork of both WinuX and Foundation), not in the shared Foundation pages.
