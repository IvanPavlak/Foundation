# macOS Workspaces

`w Dotfiles` on a Mac does what it does on Windows: opens Claude Desktop, the Dotfiles project (VS
Code plus its `Dotfiles.ROOT` WezTerm tab in the terminal you typed `w` in), one Firefox window
per browser group, waits for every window of the layout, tiles desktop 1 as Code | WezTerm
(67.25/32.75), desktop 2 as Claude | Firefox, desktop 3 as Firefox | Firefox (50/50), and lands on
desktop 1. `cw` closes exactly what it opened. See [Configuration](configuration.md) for the files
and [Unix Commands](commands.md) for every command.

> [!NOTE]
> AeroSpace workspaces "1".."9" are not Mission Control Spaces (macOS has no public API to create
> Spaces or move windows between them). Switch with `alt-1..9`, not trackpad swipes, and keep a
> single Space.

## What happens, in order

1. **Open-Workspace** resolves the workspace: a `template` line stamps out its template of
   `workspace-templates.conf` (a template error opens nothing of that workspace). It settles the
   open's projects before anything launches - the projects you typed, else the project menu for
   an `Open-Project` without a project, else the ones its `Open-Project` lines name - and keeps
   the `+A,B` lines those projects select. Then it starts AeroSpace if needed, records the windows
   and WezTerm panes that exist, and runs the lines. Unknown actions (Open-DBeaver without an app
   entry, Send-WakeOnLan, ...) are reported and skipped.
2. **Launchers** skip what is already open: an app with a window, a VS Code folder whose name is
   already a whole window-title segment, a project tab title already present. Project tabs start without the fastfetch
   panel; it is drawn once the layout has placed the terminal window.
3. **Set-WorkspaceWindowLayout** applies the layout's `project` variants for the open's projects,
   then lets every layout entry claim one window (new windows before pre-existing ones; an entry
   without a title leaves the windows titled entries of the same app ask for, and the only
   untitled entry of an app then takes every remaining window of it; titles must hold for a
   second because browsers retitle while loading).
4. **Per desktop** the AeroSpace driver focuses the workspace, parks stray windows on workspace
   `P`, moves the layout windows in left zone first, flattens the tree, repairs the order with a
   focus walk and sizes the columns (equal shares: balance; otherwise `resize width` in points
   from the zone set's shares). Windows sharing one zone (a whole desktop, a column or a top or
   bottom half) are stacked in an accordion, the last entry in front. The desktop is then read
   back: every window on its desktop and within 50 points of its zone (one read of the window
   server's window list, by window id, so same-titled windows are told apart); a misplaced window has the desktop arranged again, up
   to two more times, and then the open ends Partial with Expected / Actual per window.
5. The workspace's `Focus-VirtualDesktop` line runs, the deferred panels are drawn, and the
   ownership record (new windows and panes plus the windows the layout adopted, minus the `keep`
   apps such as the terminal) is written for `cw`.

## Keyboard

Bindings live in `Unix/aerospace/aerospace.toml`:

| Keys | Action |
| --- | --- |
| `alt-1` .. `alt-9`, `alt-0` | go to desktop 1..9, `alt-0` is desktop 10 |
| `alt-p` | go to the parking workspace |
| `alt-tab` | back and forth between the last two workspaces |
| `alt-h/j/k/l` | focus left/down/up/right (cycles a stacked zone) |
| `alt-shift-1..9`, `alt-shift-0`, `alt-shift-p` | move the focused window to that workspace |
| `alt-shift-h/j/k/l` | move the focused window within the workspace |
| `alt-minus` / `alt-equal` | shrink / grow |
| `alt-shift-f` | toggle the focused window between floating and tiling (a window Center-Windows, Resize-Windows or Center-Terminal floated goes back into the tiling) |
| `alt-shift-;` then `r` | service mode: flatten the current workspace |

## Verifying a run

```bash
Get-WindowHandle
aerospace list-workspaces --all
wezterm cli list --format json
cat ~/.local/state/foundation/open-workspaces
```

## Not ported yet

- Secondary monitors (their entries are skipped with a warning).

`w WORKSPACE --alongside` opens a second workspace next to the first, as on Windows: it runs in
a new WezTerm window, lands on the desktops right of the first workspace's, places only the
windows it created, and a later plain `w` of the first workspace leaves it alone. `cw` closes
either one without touching the other. The same workspace may be opened alongside itself: the
second instance is recorded apart (`NAME#2` in `open-workspaces`), and the `cw` menu labels each
(`MyWorkspace (plain, desktop 1)`, `MyWorkspace (alongside, desktop 6)`); `cw MyWorkspace` closes
both, a full label one. macOS runs most apps once, so an app that already has a
window (Slack, VS Code for the same folder) keeps it where it is.

Rerunning a workspace is safe: apps, VS Code folders and project tabs that are already open
are skipped, and so is a browser group whose window from the earlier run still exists.

Unlike Windows, a failed layout does not rerun itself in a fresh terminal: there is no
`ReRun-LastCommand` on the Unix half, because every command already runs in its own process and a
fresh terminal would add nothing a plain rerun does not. Rerun the workspace instead.

## The PowerShell port (removed)

The first macOS port (`Unix/PowerShell`, driven through one-shot `pwsh` calls) was replaced by
the bash commands and removed on 2026-09-26; the Unix half needs no PowerShell. Its design
record and hard-won gotchas (`Backlog/MacOS/0_MacOS Port of the Workspace Orchestration.md`) and the
code stay in git history.

## Troubleshooting

- **"bash 3.2.57 is too old"** - `brew install bash`, then a new terminal.
- **"AeroSpace did not answer"** - grant Accessibility to AeroSpace, or start it once by hand.
- **"The terminal may not control windows"** (Center-Windows, Resize-Windows) - add WezTerm under System Settings > Privacy &
  Security > Accessibility, then quit (Cmd+Q) and reopen WezTerm; a permission applies only to
  processes started after it was granted.
- **"Layout verification failed"** - a window kept a frame other than its zone's through three
  arrangements, often an app whose minimum width is larger than the zone; the Expected / Actual
  lines name it. Widen the zone (zones.conf) or move the app to another zone: a Chrome window is
  at least 500 points wide, so four columns on a 1512-point display cannot hold it.
- **A browser window is never found** - Firefox titles a window after its active tab; the layout
  title must match the group's first URL (`*Google Gemini*` for `AI`). When no window matches,
  Set-WorkspaceWindowLayout switches the browser windows to their first tab before it waits
  (Cmd+1, which needs the terminal's Accessibility permission), so a window left on another tab
  is found again.
- **Windows share a desktop with unrelated ones** - parking is off (`parking-workspace ""` in
  `zones.conf`) or AeroSpace is not using the repo config (`aerospace config --config-path`).
- **A window covers its whole desktop despite the layout** - it is in macOS native full screen
  (its own Space, which AeroSpace does not tile). Claude Desktop restores that from its last
  session. The layout pass takes windows out of native full screen before placing them.
- **Chrome (or Brave, Edge) never opens a window** - started from its binary inside a terminal,
  a Chromium browser is refused access to its own profile folder by macOS and aborts
  (`SingletonLock: Operation not permitted` in `$TMPDIR/foundation-browser-launch.err`). Its
  `browser` line in `apps.conf` needs `launch=open`, which starts it through LaunchServices.
- **"The terminal may not control Safari" (or Chrome, Brave, Edge)** - the browser scripting
  driver was refused Automation: allow the terminal for that browser under System Settings >
  Privacy & Security > Automation (`tccutil reset AppleEvents` makes macOS ask again). Until then
  Safari opens no group and Close-Project closes whole matching windows instead of tabs.
- **Tab titles get replaced by the running program** - `~/.config/wezterm/wezterm.lua` must be the
  repo file (it carries the `format-tab-title` handler).
- **`c` drops the fastfetch logo in WezTerm instead of shrinking the font** - the same file also
  carries the `user-var-changed` handler that answers the greeting's font steps; without it no step
  changes the window and the panel loses its logo. When the font shrinks, every tab of that window
  shrinks with it (WezTerm sizes fonts per window); the next `c` resets it, as does Cmd+0.
- **`code` not found** - in VS Code run *Shell Command: Install 'code' command in PATH*.
- **A command run from VS Code's terminal (or another app started from WezTerm) ignores the WezTerm
  tab** - by design: such an app inherits `WEZTERM_PANE`, so the variable only counts when that
  pane's tty is the command's own terminal. Project tabs open in a new window and no WezTerm tab is
  spared or closed as "this tab". Run the command in a WezTerm tab to target it.
- **A few output lines come out torn while `w` runs** (`... in VSCode!]...`, `(1 URL(s)) (1 URL(s))`,
  a missing blank line) - AeroSpace resizes the terminal while the open prints (a new window tiles
  next to it, then the layout moves it), and WezTerm re-wraps its text at each resize. The
  messages are correct; the session log (`Unix/logs/Session_*_Open-Workspace.log`) has them intact.
  Running `w` from a terminal on a desktop the workspace does not tile avoids it.
