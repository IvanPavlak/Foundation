# Start-Containers

Brings up (or stops) the Docker Compose stacks of `docker.conf` without running a project, and
prints their published ports.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`docker.conf`](../../configuration.md#dockerconf) | `directory PATH` | `Docker` | The folder relative stack files resolve under (DockerDirectory): relative to the repository root, `~` and `$VARIABLES` expand |
| [`docker.conf`](../../configuration.md#dockerconf) | `stack NAME FILE` | `stack PostgreSQL docker-compose.postgresql.yml` | A stack Start-Containers can start; a relative `FILE` is under the `directory` line's folder (`Docker` of the repository without one). One stack starts without a menu, several show one, sorted by name |
| [`docker.conf`](../../configuration.md#dockerconf) | `timeout start SECONDS` | `180` | How long to wait for the daemon after starting Docker Desktop |

## Decisions

1. Which Compose stacks should Start-Containers offer?
    - Options: one `stack NAME FILE` line per stack; `FILE` relative to the `directory` folder (`Docker/` in the repository without a line), or an absolute path (`~`, `$DEV` and `$DOTFILES_ROOT` expand). The same stacks are what a project's `docker NAME` line in `projects.conf` names for Run-Project.
    - Default: only `PostgreSQL`, so it starts without a menu.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)
2. How long may Docker Desktop take to start?
    - Options: `timeout start SECONDS`.
    - Default: 180 seconds.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)

## Where to Put Values

`Unix/config/docker.local.conf`, created when missing. `docker.conf` has no sections: the overlay's
`stack` lines are added after the base ones, and `timeout start` there wins. A stack with the name
of a base one replaces it (the last line of a name is the one used, names compare
case-insensitively) and the menu lists the name once; `-LINE` takes a base stack back entirely, and
`@TYPE` limits a stack to machine types. `timeout stop` is not read here: Start-Containers leaves
Docker Desktop running, and only `Open-Docker --stop` and Kill-All's Docker step quit it.
The menu sorts the stacks by name (case-insensitively, as Windows), whatever their order in the
files, and a stack whose compose file is missing fails before Docker Desktop is started.

## Steps Overview

1. Add the stack
2. Check the configuration

## Step 1: Add the stack

```conf
stack MyStack    $DEV/MyProject/docker-compose.yml
```

To point the base stack at another file, add a line with its name; it overrides the base line:

```conf
stack PostgreSQL   $DEV/MyProject/docker-compose.postgresql.yml
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports a `docker` line of `projects.conf` that names neither a stack nor a path key; a missing
Compose file is reported by Start-Containers itself.

## Verification

```bash
Test-ConfigurationSchema --quiet
grep -n '^-\?stack' Unix/config/docker.conf Unix/config/docker.local.conf
```

## Complete Example

`Unix/config/docker.local.conf`:

```conf
stack MyStack    $DEV/MyProject/docker-compose.yml
@Work stack MyWorkStack    docker-compose.mywork.yml
timeout start 240
```

## Related

- [`Start-Containers` in the Workflow module reference](../../modules/Workflow.md#start-containers)
- [Docker-Cleanup](Docker-Cleanup.md)
- [Workflow configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
