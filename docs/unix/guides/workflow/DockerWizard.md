# DockerWizard

Starts Docker Desktop, waits for the daemon and brings up a Compose file or a project folder's
(`docker compose up -d`), or stops Docker Desktop with `--stop`.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`docker.conf`](../../configuration.md#dockerconf) | `timeout start SECONDS` | `180` | How long to wait for the daemon after starting Docker Desktop |
| [`docker.conf`](../../configuration.md#dockerconf) | `timeout stop SECONDS` | `60` | How long `DockerWizard --stop` waits for Docker Desktop to quit before it kills it |

The Compose file itself is a flag, not configuration: configured stacks are what
[Start-Containers](Start-Containers.md) starts.

## Decisions

1. How long may Docker Desktop take to start?
    - Options: `timeout start SECONDS`; a slower machine gets a longer wait with `@TYPE` (`@Laptop timeout start 300`).
    - Default: 180 seconds, also without a line.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)
2. How long may Docker Desktop take to quit before it is killed?
    - Options: `timeout stop SECONDS`.
    - Default: 60 seconds, also without a line.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)

## Where to Put Values

`Unix/config/docker.local.conf`, created when missing. `docker.conf` has no sections: the overlay's
lines are added after the base ones, and the last `timeout start` or `timeout stop` line for this
machine type wins. `@TYPE` limits a line to machine types.

## Steps Overview

1. Set the timeouts
2. Check the configuration

## Step 1: Set the timeouts

```conf
timeout start 240
timeout stop 90
```

## Step 2: Check the configuration

```bash
grep -n 'timeout' Unix/config/docker.conf Unix/config/docker.local.conf
```

The last line for this machine type is the one in effect.

## Verification

```bash
cat Unix/config/docker.local.conf
DockerWizard --compose-project-path $DEV/MyProject
```

## Complete Example

`Unix/config/docker.local.conf`:

```conf
timeout start 240
@Laptop timeout start 300
timeout stop 90
```

## Related

- [`DockerWizard` in the Workflow module reference](../../modules/Workflow.md#dockerwizard)
- [Start-Containers](Start-Containers.md)
- [Workflow configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
