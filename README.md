<h1 align="center">Foundation</h1>

<p align="center"><strong>The macOS counterpart of WinuX</strong></p>

<p align="center">
A bash-based dotfiles system that turns a fresh Mac into a keyboard-driven, fully configured
environment - the same one-command workflow as <a href="https://github.com/IvanPavlak/WinuX">WinuX</a> on Windows.
</p>

---

Foundation is for people who keep a dotfiles repository and want their Mac to open whole
workspaces, tile them and keep every machine in step from one command. It is built from bash
executables, small plain-text config files and free tools: AeroSpace for tiling and desktops,
WezTerm for the orchestrated terminal, chezmoi for the dotfile links, Homebrew for packages.

> [!NOTE]
> Foundation is in its 0.x series: it works end to end on the maintainer's Macs, but any release may
> still rename or remove a command, flag or config line, with a migration note in the changelog.
> See the [roadmap](docs/unix/roadmap.md).

## What it does

- **One-command bootstrap** - `Unix/bootstrap.sh` links the dotfiles with chezmoi, then
  `Bootstrap` installs the Brewfile and applies every step you turned on, each switchable per
  machine and safe to rerun.
- **Workspaces** - `w MyProject` opens a project's terminals, editor, browser groups and apps and
  places every window on its AeroSpace workspace; `cw` closes it again, `Kill-All` clears the
  screen.
- **Multi-machine** - one repository for every Mac: machine types pick each one's layouts, apps
  and settings with `@TYPE` lines.
- **Repository orchestration** - clone and update all your repositories with one command.
- **System settings** - macOS defaults, power, Dock, login items, theme and wallpaper from config
  files.
- **AI artifacts** - skills, mods and rules linked into Claude Code, Codex and Gemini CLI, plugin
  marketplaces and MCP servers, all opt-in.
- **Empty by default** - the base config files ship only what a generic clone needs; your values go
  in `.local.conf` overlays next to them.
- **Tested and documented** - one bats suite per command, shellcheck and shfmt in CI, and a
  man-style reference and configuration guide for every command.

## Quick start

On a Mac with an administrator account:

```bash
xcode-select --install
git clone https://github.com/IvanPavlak/Foundation.git ~/Development/GitHub/Foundation
~/Development/GitHub/Foundation/Unix/bootstrap.sh --dry-run
~/Development/GitHub/Foundation/Unix/bootstrap.sh
```

Read [`Unix/bootstrap.sh`](Unix/bootstrap.sh) before running it, and start on a test user or a
virtual machine. To keep your own values in git, fork the repository first: see the
[Fork Model](docs/unix/fork-model.md).

## Documentation

**The documentation is the single source of truth** - getting started, configuration, every module,
and a man-style reference for every command.

Read it at [ivanpavlak.github.io/Foundation](https://ivanpavlak.github.io/Foundation/), browse it
under [`docs/unix/`](docs/unix/README.md), or serve it locally:

```bash
npx docsify-cli serve docs
```

## Foundation and WinuX

Foundation mirrors WinuX's repository layout path for path, so one fork can hold both halves:
WinuX for Windows and the shared files, Foundation for `Unix/` and the macOS paths. Command names
follow WinuX (`Open-Workspace`, `Kill-All`, `Update-Repositories`), so the same muscle memory works
on both. The two diverge until Foundation is as established as WinuX, then merge.

## License

Foundation is released under the [MIT License](LICENSE). Third-party components keep their own
licenses: see [THIRD-PARTY-LICENSES.md](THIRD-PARTY-LICENSES.md).

## Contributing

Contributions of all kinds are welcome - code, docs, tests, bug reports and ideas. Please read
[CONTRIBUTING.md](CONTRIBUTING.md) and the [Code of Conduct](CODE_OF_CONDUCT.md) first. For security
issues, follow [SECURITY.md](SECURITY.md).

---

## Supporters

Foundation is free and open-source. If it saves you time, please consider supporting it.

<p align="center">
  <a href="https://ko-fi.com/ivanpavlak"><img src="https://img.shields.io/badge/Ko--fi-Support%20Foundation-FF5E5B?style=for-the-badge&logo=ko-fi&logoColor=white" alt="Ko-fi"/></a>
  <a href="https://github.com/sponsors/IvanPavlak"><img src="https://img.shields.io/badge/GitHub%20Sponsors-Sponsor-EA4AAA?style=for-the-badge&logo=githubsponsors&logoColor=white" alt="GitHub Sponsors"/></a>
</p>

---

## Disclaimer

AI was used throughout this project and is ingrained in it - but everything has been tested by hand
on the maintainer's Macs. Regardless, use it at your own discretion. Known problems and their
workarounds live in [Troubleshooting on a Mac](docs/unix/troubleshooting.md).
