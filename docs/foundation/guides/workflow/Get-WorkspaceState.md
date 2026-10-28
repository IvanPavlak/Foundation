# Get-WorkspaceState

Shows the ownership record of each open workspace, exactly what `cw` would close.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Get-WorkspaceState
Get-WorkspaceState MyWorkspace
Get-WorkspaceState --raw
```

A window the app recreated or restarted is shown live under its new id (`(ID, now NEW-ID)`), as
`cw` finds it.

## Related

- [`Get-WorkspaceState` in the Workflow module reference](../../modules/Workflow.md#get-workspacestate)
- [Workflow configuration guides](README.md)
