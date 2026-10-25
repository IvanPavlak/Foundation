# Window layouts

One folder per layout set (machine type: `Work`, `Laptop`, ...) and one file per workspace,
`<Type>/<Workspace>_<Type>.conf` - the Windows `Layouts/<Type>/<Workspace>_<Type>.psd1` files.
Converted 2026-09-25; hand-maintained from here on. Read by Set-WorkspaceWindowLayout, drawn by
Visualize-Layouts, created by Add-WindowLayout.

Each file holds the workspace's `[Workspace]` section:

```
layout DESKTOP ZONESET        the zone set desktop DESKTOP uses (config/zones.conf)
monitor NAME                  following lines target that monitor (default Primary; only
                              Primary is placed on macOS yet)
DESKTOP ZONE APP [TITLE...]   one window: app token (config/apps.conf, or a role such as
                              Browser/Terminal) goes into ZONE of DESKTOP; TITLE is an exact,
                              wildcard (*x*) or regex pattern and may contain spaces
project A[,B...]              the lines after it, up to the next project line, are a project
                              variant: when the open is for A or B, its layout lines change those
                              desktops' zone sets and its window lines replace every base window
                              on the same desktop and monitor (ProjectOverrides on Windows)
```

Several windows of one app: each entry claims one window; an entry without a TITLE takes only
windows no titled entry of the same app asks for; several entries in the one zone of a
single-zone desktop are stacked with the last entry in front.

`#|` lines under the header are the drawing `Visualize-Layouts --update` writes. Desktops are
AeroSpace workspaces 1..9 (alt-1 .. alt-9). A `<Workspace>_<Type>.local.conf` next to a file
(not committed) replaces its section.
