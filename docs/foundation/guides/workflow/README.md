# Workflow Module Configuration Guides

Workspaces, projects, their terminals, Docker containers and EF Core migrations; see
[the module reference](../../modules/Workflow.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Close-Project` | `projects.conf`, `vscode-folders.conf`, `browser-groups.conf` | [Close-Project](Close-Project.md) |
| `Docker-Cleanup` | `docker.conf` | [Docker-Cleanup](Docker-Cleanup.md) |
| `DockerWizard` | `docker.conf` | [DockerWizard](DockerWizard.md) |
| `Get-WorkspaceBenchmark` | `workspaces.conf` | [Get-WorkspaceBenchmark](Get-WorkspaceBenchmark.md) |
| `Measure-WorkspaceOpen` | `workspaces.conf`, `workspace-templates.conf` | [Measure-WorkspaceOpen](Measure-WorkspaceOpen.md) |
| `Open-DnD` | `dnd.conf` | [Open-DnD](Open-DnD.md) |
| `Open-Project` | `projects.conf` | [Open-Project](Open-Project.md) |
| `Open-ProjectSwagger` | `browser-groups.conf` | [Open-ProjectSwagger](Open-ProjectSwagger.md) |
| `Open-ProjectTerminals` | `projects.conf`, `greeting.conf` | [Open-ProjectTerminals](Open-ProjectTerminals.md) |
| `Open-Workspace` | `workspaces.conf`, `workspace-templates.conf`, `projects.conf`, `vscode-workspaces.conf`, `kill-all.conf`, `machines.conf`, `zones.conf` | [Open-Workspace](Open-Workspace.md) |
| `Start-Containers` | `docker.conf` | [Start-Containers](Start-Containers.md) |

## Commands With No Configuration

[Close-ProjectTerminals](Close-ProjectTerminals.md), [Close-Workspace](Close-Workspace.md),
[EfCoreMigrationWizard](EfCoreMigrationWizard.md), [Focus-TerminalTab](Focus-TerminalTab.md),
[Get-WorkspaceState](Get-WorkspaceState.md)

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
