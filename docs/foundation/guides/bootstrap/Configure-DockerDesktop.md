# Configure-DockerDesktop

Sets where Docker Desktop installs its command-line tools: `/usr/local/bin` (system) or
`~/.docker/bin` (user). In user mode Docker Desktop puts `~/.docker/bin` on PATH by writing a block
into the shell profiles at every start, and `~/.bash_profile` is a link into this repository, so
system mode keeps installers out of the tracked files.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`docker.conf`](../../configuration.md#dockerconf) | `cli-install system\|user` | none: Docker Desktop keeps its own choice | The mode written into Docker Desktop's settings (`DockerBinInstallPath` of `settings-store.json`) |
| [`docker.conf`](../../configuration.md#dockerconf) | `timeout stop SECONDS` | `60` | How long a running Docker Desktop may take to quit before the change, as for `Open-Docker --stop` |

## Decisions

1. Where should Docker Desktop install its tools?
    - Options: `cli-install system` (links in `/usr/local/bin`; Docker Desktop asks for the administrator password once, and leaves the shell profiles alone) or `cli-install user` (`~/.docker/bin`, no password; Docker Desktop writes its PATH block into `~/.zprofile` and `~/.bash_profile` at every start).
    - Default: no line, Docker Desktop's own setting (Settings > Advanced) stays.
    - More detail: [`docker.conf`](../../configuration.md#dockerconf)
2. Should Bootstrap run it?
    - Options: `step DockerDesktop on` in `bootstrap.local.conf`, per machine type with `@TYPE`.
    - Default: off; run `Configure-DockerDesktop` by hand.
    - More detail: [Bootstrap](Bootstrap.md)

## Where to Put Values

`Unix/config/docker.local.conf`, created when missing. Its lines go before any section and are read
after the base ones, so its `cli-install` line wins; an `@TYPE` prefix limits it to one machine
type.

Docker Desktop writes its settings file only once it has started, so on a new Mac the step warns
and changes nothing until Docker Desktop ran once (`Open-Docker`); run it again then. While Docker
Desktop runs it holds the file in memory, so a running Docker Desktop is stopped first (its
containers too) and started again afterwards. The file is backed up into
`Backups/Unix/System/DockerDesktop/` before the write.

## Steps Overview

1. Choose the mode
2. Check the configuration

## Step 1: Choose the mode

```conf
cli-install system
```

In system mode Docker Desktop asks for the administrator password when it starts next, to link its
tools into `/usr/local/bin`; nothing is written into the shell profiles from then on. A block it
wrote before stays where it is: remove it from `~/.zprofile` by hand, and restore
`Unix/shell/bash_profile` from git.

## Step 2: Check the configuration

```bash
Configure-DockerDesktop --dry-run
```

It says which mode would be written and whether Docker Desktop would be restarted, and changes
nothing.

## Verification

```bash
Configure-DockerDesktop --dry-run
Bootstrap --only DockerDesktop --dry-run
command -v docker
grep -n "added by Docker Desktop" ~/.zprofile ~/.bash_profile
```

In system mode `command -v docker` prints `/usr/local/bin/docker`, and after a restart of Docker
Desktop the last command finds nothing.

## Complete Example

`Unix/config/docker.local.conf`:

```conf
cli-install system
@Laptop cli-install user
```

## Related

- [`Configure-DockerDesktop` in the Bootstrap module reference](../../modules/Bootstrap.md#configure-dockerdesktop)
- [Open-Docker](../application/Open-Docker.md), which starts and stops Docker Desktop
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
