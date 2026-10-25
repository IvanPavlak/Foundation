# Third-Party Licenses

Foundation is released under the [MIT License](LICENSE). It bundles one third-party file and builds
on the tools listed below. Each retains its own license; this file collects the required notices.

If you add or remove vendored third-party content, update this file accordingly.

---

## btop theme "dusklight"

- **Path in this repository:** `Btop/themes/dusklight.theme`
- **Upstream:** https://github.com/aristocratos/btop (`themes/dusklight.theme`)
- **Author:** Drazil100, distributed with btop by Jakob P. Liljenberg (aristocratos)
- **License:** Apache License 2.0 - https://github.com/aristocratos/btop/blob/main/LICENSE

The theme file is redistributed unmodified from an earlier btop revision (upstream has since fixed
a typo in one comment line). It is a colour scheme only; btop itself is installed from Homebrew.

---

## Installed, not vendored

Foundation ships configuration for these tools, never the tools themselves; they are installed from
their upstreams (Homebrew, the chezmoi installer) during bootstrap. Listed as a courtesy
acknowledgement.

| Tool | Upstream | License |
| --- | --- | --- |
| AeroSpace | https://github.com/nikitabobko/AeroSpace | MIT |
| WezTerm | https://github.com/wezterm/wezterm | MIT |
| chezmoi | https://github.com/twpayne/chezmoi | MIT |
| Homebrew | https://github.com/Homebrew/brew | BSD-2-Clause |
| bats-core | https://github.com/bats-core/bats-core | MIT |
| ShellCheck | https://github.com/koalaman/shellcheck | GPL-3.0 (run as a tool, not linked) |
| shfmt | https://github.com/mvdan/sh | BSD-3-Clause |
| Oh My Posh (the shipped theme file `Oh-My-Posh/WinuX_Test.omp.json` configures it) | https://github.com/JanDeDobbeleer/oh-my-posh | MIT |

Fonts are not bundled: the terminal configs name JetBrains Mono Nerd Font (SIL OFL 1.1), which a
fork installs from Homebrew (`cask "font-jetbrains-mono-nerd-font"`).
