# Roadmap

Where Foundation is headed from its first release to a stable 1.0.0. Before 1.0.0 no compatibility
rules apply, as in WinuX before its 1.0.0: any release may rename or remove a command, flag, config
line kind or Bootstrap step, with a migration note in the changelog. The contract baseline is
written when 1.0.0 is cut, and WinuX's ladder binds from then on.

| Version | Theme | Done when |
| --- | --- | --- |
| 0.1.0 | Extraction | Foundation is its own repository with green CI and its docs site up, and a fork of WinuX merges it as a second upstream |
| 0.2.0 | Proven standalone | A fresh macOS user or virtual machine bootstraps from a plain clone and passes the end-to-end check below; what breaks is fixed and the getting-started docs are written from that run |
| 0.3.0 | Fork model proven | Several real Foundation releases merged into a fork of both upstreams with `Merge-Upstreams` and no hand fixes; a check of the mirrored files against a pinned WinuX commit; a first outside-forker pass over the docs |
| 0.4.0 | Daily-use improvements | Better Mac-native options found in use (closest equivalent first, better options later), each landing in WinuX too where it applies |
| 0.5.0 | Cross-half parity | A parity table against WinuX 1.x on this page, every gap closed or recorded as out of scope, and the rule that a change to one half lands in both |
| 0.6.0 - 0.8.x | Contract review | Every command name, flag, config line kind and Bootstrap step reviewed once; the Windows-style names get a final keep-or-rename decision; every rename lands now, with migration notes |
| 0.9.x | Release candidates | Contract frozen, fixes only; CI on the two current macOS versions; the security policy and private vulnerability reporting live; docs complete |
| 1.0.0 | Stable | The contract baseline is written and WinuX's ladder applies (deprecate in a MINOR, remove only in a MAJOR); 0.9.x ran without a contract change; a fresh install works on two macOS versions; forks have merged several releases cleanly |

## End-to-end check (0.2.0)

In a fresh macOS user or virtual machine: clone Foundation, run `Unix/bootstrap.sh --dry-run`, then
`Unix/bootstrap.sh`; the machine type is `Test`; `Bootstrap --with-initial-setup` installs the
Brewfile and links the dotfiles; AeroSpace and WezTerm run; `w Example` opens; `Run-Tests` is
green; `List-Functions --list-discrepancies` reports nothing; the docs site renders with no broken
link.

## Not scheduled

- **Several displays.** Workspace layouts place windows on the primary display only; the
  `monitor Secondary` placement of WinuX needs a Mac with two displays to build and test.
- **Linux.** Every platform call sits in a driver so a Linux driver can be added; there is no
  window manager, driver or package list for it yet.
