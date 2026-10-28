# Foundation Docs Overview

Internal maintenance reference for Foundation's documentation, the counterpart of WinuX's [Docs Overview](https://ivanpavlak.github.io/WinuX/#/winux/docs_overview). Everything under `docs/foundation/`, the decision records of `docs/foundation/adr/` included, is Foundation's room: no other project and no fork writes there. The docs landing above it (`docs/README.md`, `docs/_sidebar.md`) and the docsify shell (`docs/index.html`) are hallway files: Foundation ships a landing that lists itself, and a fork of several upstreams writes its own, one line per project.

## Navigation

The Foundation pages have their own sidebar, [`docs/foundation/_sidebar.md`](_sidebar.md): docsify loads the `_sidebar.md` of a page's folder, falling back to the parent folder's, so every page under `/foundation/` shows it. Its first entry leads back to the other project's docs (`/winux/README.md`); the root landing links `foundation/README.md`. `Unix/tests/guides.bats` checks that the Foundation sidebar lists every module page, every guide index and the configurator page, and `Unix/tests/doclinks.bats` that every link under `docs/foundation` resolves, that the Foundation sidebar links only pages under `/foundation/` and the WinuX docs, that the root landing links the Foundation overview and that `docs/index.html` names no project.

## Structure

```
docs/foundation/
├── _sidebar.md                             # The Foundation sidebar (every page under /foundation/)
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
├── fork-model.md                           # Overlays, payloads, Custom area, rooms and hallway, Merge-Upstreams
├── roadmap.md                              # The 0.1.0 to 1.0.0 roadmap and what is not scheduled
└── adr/                                    # Decision records (listed in the Foundation sidebar)
```

## Maintenance

### When a Unix page or module is added or removed

1. Add or remove its entry in `docs/foundation/_sidebar.md` (a module page and its guide index both)
2. Update the structure above

### When a Unix command is added, renamed or removed

1. Its entry on `docs/foundation/modules/<Module>.md` (alphabetical) and the `command` line of `Unix/modules/<Module>/module.conf`
2. Its guide under `docs/foundation/guides/<module>/` and the row in that folder's `README.md`
3. Its suite `Unix/tests/modules/<Module>/<Command>.bats`

### When Unix/Brewfile changes

1. Update `software-list.md` (`Unix/tests/docpages.bats` compares its table with the Brewfile)
