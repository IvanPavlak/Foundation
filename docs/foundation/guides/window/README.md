# Window Module Configuration Guides

Desktops (AeroSpace workspaces), window lookup, moving, centering and resizing windows, and the
workspace layouts and their drawings; see [the module reference](../../modules/Window.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Center-Terminal` | `window.conf`, `machines.conf` | [Center-Terminal](Center-Terminal.md) |
| `Center-Windows` | `window.conf`, `machines.conf` (through Center-Terminal only) | [Center-Windows](Center-Windows.md) |
| `Focus-VirtualDesktop` | `apps.conf` (the `Terminal` role) | [Focus-VirtualDesktop](Focus-VirtualDesktop.md) |
| `Move-Windows` | `window.conf`, `machines.conf` (loaded, not used) | [Move-Windows](Move-Windows.md) |
| `Reset-Windows` | `window.conf`, `machines.conf` (loaded, not used) | [Reset-Windows](Reset-Windows.md) |
| `Resize-Windows` | `window.conf`, `machines.conf` | [Resize-Windows](Resize-Windows.md) |
| `Set-WorkspaceWindowLayout` | `layouts/<Type>/`, `zones.conf`, `machines.conf`, `workspaces.conf`, `projects.conf` | [Set-WorkspaceWindowLayout](Set-WorkspaceWindowLayout.md) |
| `Visualize-Layouts` | `layouts/<Type>/`, `zones.conf`, `machines.conf`, `workspaces.conf`, `projects.conf`, `apps.conf` (the apps a layout may name) | [Visualize-Layouts](Visualize-Layouts.md) |

## Commands With No Configuration

[Get-ActiveWindowInfo](Get-ActiveWindowInfo.md),
[Get-WindowHandle](Get-WindowHandle.md)

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
