# The Custom Area

This folder is the **fork-owned** half of the Unix module tree, the twin of
WinuX's [`Windows/PowerShell/Modules/Custom`](https://github.com/IvanPavlak/WinuX/blob/master/Windows/PowerShell/Modules/Custom/README.md). A fork's own commands - the ones not (yet) part of the
upstream Unix half - live here, one module folder each, so upstream pulls never conflict with them
and graduating a command upstream is a move.

Upstream ships only this README; a fork creates the module folders.

## Layout

```
Unix/modules/
├── Workflow/                 # engine module - upstream-owned, never edit in a fork
└── Custom/                   # fork area
    └── Workflow/             # a Custom module, named after the engine module it extends
        ├── module.conf       # its manifest: description, command, function and helper lines
        ├── bin/              # its executables
        └── functions.sh      # optional shell functions
```

Each Custom module has:

- its `module.conf` and `bin`, exactly as an engine module;
- its page `docs/unix/custom/<module>.md` (lowercase), in the same man-style entry format as
  `docs/unix/modules/<Module>.md`;
- one suite per command, `Unix/tests/modules/Custom/<Module>/<Command>.bats` (it loads
  `../../../helpers`).

## How loading works

- The shell rc and `lib/foundation.sh` put every Custom module's `bin` on PATH and source its
  `functions.sh`, like an engine module's.
- **The engine wins on a name clash:** the engine's bins come first on PATH and
  `foundation_command_path` looks there first, so a Custom command with an engine command's name never
  runs. `commands.bats` fails on such a clash.
- `List-Functions` lists a Custom module as `Custom/<Module>`, and `List-Functions
  --list-discrepancies` and `commands.bats` check it against its manifest, page and suites like
  any module.

## Graduating a command upstream

Move `bin/<Command>` into the engine module's `bin`, its `command` line into that module's
`module.conf`, its page entry into `docs/unix/modules/<Module>.md` and its suite into
`Unix/tests/modules/<Module>/` (the suite then loads `../../helpers`). Remove the Custom module
once it is empty.
