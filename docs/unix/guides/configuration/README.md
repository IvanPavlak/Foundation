# Configuration Module Configuration Guides

The writers that add workspaces, projects, browser groups, layouts and dotfile links to the Unix
configuration, and the check that the files agree, with a link to
[the module reference](../../modules/Configuration.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Add-BrowserGroup` | `browser-groups.conf` | [Add-BrowserGroup](Add-BrowserGroup.md) |
| `Add-Project` | `projects.conf` | [Add-Project](Add-Project.md) |
| `Add-WindowLayout` | `layouts/<Type>/`, `machines.conf` | [Add-WindowLayout](Add-WindowLayout.md) |
| `Add-Workspace` | `workspaces.conf`, `workspace-templates.conf` | [Add-Workspace](Add-Workspace.md) |
| `Test-ConfigurationSchema` | `workspaces.conf`, `workspace-templates.conf`, `layouts/<Type>/`, `zones.conf`, `projects.conf`, `browser-groups.conf`, `machines.conf`, and the files they refer to | [Test-ConfigurationSchema](Test-ConfigurationSchema.md) |

## Commands With No Configuration

[Add-SymbolicLink](Add-SymbolicLink.md)

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
