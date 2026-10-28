# 0001 - Imperative-only AeroSpace placement

- **Status:** Accepted, 2026-09-27
- **Scope:** the Unix half (macOS), workspace window placement
- **Supersedes:** the "Tiling" standing decision of `Backlog/MacOS/Map.md` (hybrid: declarative `on-window-detected` rules plus a thin imperative pass)

## Context

On macOS the workspace layouts run on AeroSpace, a tiling window manager. AeroSpace offers two ways to
put a window on a workspace: declarative `on-window-detected` rules in `aerospace.toml`, which fire as
a window appears, and its CLI (`move-node-to-workspace`, `layout`, `resize`, ...), which a script
drives. AeroSpace's own documentation recommends the rules for placement, and the map charted in
September 2026 chose a hybrid: rules place the windows, a small scripted pass does what rules cannot.

Building the port showed two things the charting could not see:

- A rule says "app X always goes to workspace N". The WinuX workspaces put the same app on different
  desktops: Claude is desktop 3 in the Dotfiles workspace and desktop 1 in the AI workspace, VS Code
  and the terminal move between desktops per workspace too. One static rule set places each app in
  exactly one of those, wrongly for every other workspace. Generating a rule file per workspace and
  reloading AeroSpace in the middle of every `w` would make placement depend on a config reload
  racing the apps that are starting.
- The rule-like behaviour - moving each window to its desktop the moment it appears - was built
  behind a setting (`layout-early-move`) and measured with `Measure-WorkspaceOpen` in a full-factorial
  run on the Dotfiles workspace (every run placed every window): it gained nothing (10.6 s with it,
  10.4 s without, at the 1000 ms title wait; 10.1 s either way at 500 ms). The measured win was the
  title-stability wait (`layout-stable-ms` 500 instead of 1000, about 0.5 s per open).

## Decision

Per-workspace placement is imperative only: `Set-WorkspaceWindowLayout` claims each layout window as
it appears and moves, tiles and sizes it through the AeroSpace CLI, driven by `Unix/config/layouts`.
`aerospace.toml` carries no `on-window-detected` placement rules. A small static rule set is allowed
only for behaviour that never varies by workspace (for example floating a dialog window), and only
once a concrete problem needs it.

## Alternatives considered

- **Hybrid rules plus imperative pass** (the charted plan): wrong for any app that lives on different
  desktops in different workspaces, which is most of them.
- **Generated rule file per workspace, reloaded on each open:** fragile (reload timing against starting
  apps) and duplicates the layout files in a second format.
- **Early move by default** (the rule-like imperative variant): no measured gain; kept as the
  `layout-early-move` setting, off.

## Consequences

- A layout change stays a one-file edit in `Unix/config/layouts/<Type>.conf`, drawn by
  `Visualize-Layouts` and checked by `Test-ConfigurationSchema`.
- The missing `on-window-detected` section in `aerospace.toml` is deliberate.
- Any new placement idea is judged the same way: behind a setting, measured with
  `Measure-WorkspaceOpen` before it becomes the default.
- Windows opened outside a workspace open are not placed automatically; `w <Workspace>` (or
  `Reset-Windows`) arranges them.
