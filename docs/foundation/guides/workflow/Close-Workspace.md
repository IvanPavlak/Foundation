# Close-Workspace

Closes everything a workspace opened and nothing else, from the record `w` keeps (alias `cw`).

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Close-Workspace
Close-Workspace MyWorkspace
cw MyWorkspace
cw 'MyWorkspace (alongside, desktop 6)'
cw MyWorkspace --dry-run
cw --all
```

A workspace open twice (plain, then `w MyWorkspace --alongside`) has one record per instance: the
menu labels each, a full label closes that instance, a bare name closes both.

## Related

- [`Close-Workspace` in the Workflow module reference](../../modules/Workflow.md#close-workspace)
- [Workflow configuration guides](README.md)
