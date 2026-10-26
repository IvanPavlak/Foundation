# Foundation Docs Overview

Internal maintenance reference for Foundation's documentation, the counterpart of WinuX's [Docs Overview](https://ivanpavlak.github.io/WinuX/#/docs_overview). Everything under `docs/unix/`, the decision records of `docs/unix/adr/` included, is Foundation's. In a fork that holds both WinuX and Foundation, the pages outside `docs/unix/` are WinuX's: they stay byte-identical to it and never mention Foundation.

## Navigation

The Unix pages have their own sidebar, [`docs/unix/_sidebar.md`](_sidebar.md): docsify loads the `_sidebar.md` of a page's folder, falling back to the parent folder's, so every page under `/unix/` shows it. In Foundation the root `docs/_sidebar.md` lists the same entries. In a fork of both upstreams it is WinuX's and carries no Unix entry; the way in from the shared docs is then the fork-owned Custom Area page (`docs/custom/README.md`, protected by `merge=ours`), which links here. `Unix/tests/guides.bats` checks that the Unix sidebar lists every module page, every guide index and the configurator page, and `Unix/tests/doclinks.bats` that every link under `docs/unix` resolves and, in a fork of both, that the shared sidebar has no Unix or Decisions entry.

## Structure

```
docs/unix/
├── _sidebar.md                             # The Foundation sidebar (every page under /unix/)
├── README.md                               # Overview, before you start, shell startup, current state
├── docs_overview.md                        # This page
├── commands.md, modules/, guides/          # Command reference and one configuration guide per command
├── custom/                                 # The Unix custom area pages
├── configuration.md                        # The Unix/config files, base and overlay
├── bootstrap.md                            # Bootstrap a Mac: steps, chezmoi
├── macos-workspaces.md                     # Workspaces on AeroSpace, their troubleshooting
├── foundation-configurator.md              # AI-assisted interview that configures Foundation
├── ai.md                                   # macOS paths and checks of the AI layers
├── software-list.md                        # The base Unix/Brewfile and Brewfile.local
├── backups.md                              # Backups/Unix: writers, retention, restore
├── troubleshooting.md                      # Bootstrap, Homebrew, chezmoi, workspaces, AI on a Mac
├── fork-model.md                           # Overlays, payloads, Custom area, Merge-Upstream, the two-upstream fork
├── roadmap.md                              # The 0.1.0 to 1.0.0 roadmap and what is not scheduled
└── adr/                                    # Decision records (listed in the Foundation sidebar)
```

## Maintenance

### When a Unix page or module is added or removed

1. Add or remove its entry in `docs/unix/_sidebar.md` (a module page and its guide index both)
2. Update the structure above

### When a Unix command is added, renamed or removed

1. Its entry on `docs/unix/modules/<Module>.md` (alphabetical) and the `command` line of `Unix/modules/<Module>/module.conf`
2. Its guide under `docs/unix/guides/<module>/` and the row in that folder's `README.md`
3. Its suite `Unix/tests/modules/<Module>/<Command>.bats`

### When Unix/Brewfile changes

1. Update `unix/software-list.md` (`Unix/tests/docpages.bats` compares its table with the Brewfile)
