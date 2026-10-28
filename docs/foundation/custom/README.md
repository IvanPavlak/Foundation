<!-- reference: guide -->

# Custom Area

The Custom area holds a fork's own Unix commands, the ones that are not (yet) part of the upstream
Unix half. It is the twin of the Windows [Custom area](https://ivanpavlak.github.io/WinuX/#/custom/README): one module folder
per engine module it extends, under `Unix/modules/Custom/<Module>`, so upstream pulls never
conflict with it. Upstream ships the area empty.

| Part | Where |
| --- | --- |
| Commands | `Unix/modules/Custom/<Module>/bin`, with its `module.conf` manifest and an optional `functions.sh` |
| Reference | `docs/foundation/custom/<module>.md` (lowercase), one man-style entry per command, as the [module pages](../commands.md) |
| Suites | `Unix/tests/modules/Custom/<Module>/<Command>.bats` |

A Custom module is loaded like an engine module: its `bin` goes on PATH and its `functions.sh` is
sourced. The engine wins on a name clash (its bins come first on PATH), and the completeness test
fails on one. `List-Functions` lists Custom modules as `Custom/<Module>`, and
`List-Functions --list-discrepancies` checks them against their manifests and pages.

How a fork lays the area out and how a command graduates upstream: `Unix/modules/Custom/README.md`.

## Modules

None yet. A fork lists its Custom modules here, one row each, linking its `docs/unix/custom/<module>.md` page:

```markdown
| Module | Contents |
| --- | --- |
| [Workflow](workflow.md) | My own workflow commands. |
```
