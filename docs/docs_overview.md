# Docs Overview

Internal maintenance reference for the documentation site. Every real page is under `docs/unix/`,
the path it keeps in a fork that holds both WinuX and Foundation, so the two trees merge path for
path. Its own maintenance reference is the [Foundation docs overview](unix/docs_overview.md).

## Structure

```
docs/
├── index.html          # docsify shell: name, plugins, homepage unix/README.md
├── README.md           # Pointer into unix/ for readers browsing the repository
├── _sidebar.md         # Root sidebar (same entries as unix/_sidebar.md)
├── docs_overview.md    # This page
├── .nojekyll           # GitHub Pages serves the folder as is
└── unix/               # Every page: overview, commands, modules, guides, configuration, bootstrap,
                        # workspaces, AI, software, backups, troubleshooting, fork model, roadmap,
                        # the Custom area pages and the decision records (adr/)
```

## Maintenance

- A page added or removed under `docs/unix/` updates `docs/unix/_sidebar.md`,
  `docs/unix/docs_overview.md` and the same entry in `docs/_sidebar.md`.
- A command added, renamed or removed: see the Foundation docs overview.
- Links are checked by `Unix/tests/doclinks.bats`; serve the site locally with
  `npx docsify-cli serve docs`.
