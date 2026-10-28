# Open-Docker

Starts Docker Desktop without a window and returns at once, as on Windows (a Docker Desktop that
already runs is a warning); `--stop` stops the running containers and quits Docker Desktop. The
daemon wait (`timeout start`) belongs to the commands that need the daemon: see
[Start-Containers](../workflow/Start-Containers.md).

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`docker.conf`](../../configuration.md#dockerconf) | `timeout stop SECONDS` | `60` | How long `Open-Docker --stop` waits for Docker Desktop to quit before it kills it |

## Decisions

1. How long may Docker Desktop take to quit before it is killed?
    - Options: `timeout stop SECONDS`; it is read only by `Open-Docker --stop` and Kill-All's Docker step (Start-Containers and Docker-Cleanup never quit Docker Desktop).
    - Default: 60 seconds, also without a `timeout stop` line.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)

## Where to Put Values

`Unix/config/docker.local.conf`, created when missing. The file has no sections: its lines are
added after the base ones and the last `timeout stop` line for this machine
type wins, so an overlay line overrides the base value. `@TYPE` limits a line to machine types.
The same file holds the `stack` and `cleanup` lines of Start-Containers and Docker-Cleanup.

## Steps Overview

1. Set the quit timeout
2. Check the configuration

## Step 1: Set the quit timeout

```conf
timeout stop 90
```

## Step 2: Check the configuration

```bash
grep -n 'timeout stop' Unix/config/docker.conf Unix/config/docker.local.conf
```

The last line for this machine type is the one in effect.

## Verification

```bash
cat Unix/config/docker.local.conf
docker info --format '{{.ServerVersion}}'
```

## Complete Example

`Unix/config/docker.local.conf`:

```conf
timeout stop 90
@Laptop timeout stop 120
```

## Related

- [`Open-Docker` in the Application module reference](../../modules/Application.md#open-docker)
- [Application configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
