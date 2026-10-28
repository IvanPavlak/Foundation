# Set-PowerSettings

Applies the sleep and power settings of `power.conf` with `pmset`, per power source, changing only
the keys whose value differs.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`power.conf`](../../configuration.md#powerconf) | `[All]` `KEY VALUE` | `displaysleep 5`, `sleep 10` | Settings for every power source (`pmset -a`) |
| [`power.conf`](../../configuration.md#powerconf) | `[AC]` `KEY VALUE` | `womp 1` (wake for network access) | Settings on the charger (`pmset -c`) |
| [`power.conf`](../../configuration.md#powerconf) | `[Battery]` `KEY VALUE` | `powernap 0`, `lessbright 1` | Settings on battery (`pmset -b`); skipped on a Mac without a battery |

## Decisions

1. How long until the display and the Mac sleep?
    - Options: `displaysleep MINUTES` and `sleep MINUTES` (0 means never) in `[All]`, or different values in `[AC]` and `[Battery]`.
    - Default: display after 5 minutes, the Mac after 10, on every source.
    - More detail: [`power.conf`](../../configuration.md#powerconf)
2. Which other pmset switches should be set?
    - Options: any key `pmset -g cap` lists on this Mac (`womp`, `powernap`, `lessbright`, ...), 1 or 0 for switches; a key the Mac does not offer is skipped with a warning.
    - Default: wake for network access on the charger, no Power Nap and a slightly dimmed display on battery.
    - More detail: [`power.conf`](../../configuration.md#powerconf)
3. Should the values differ per machine type?
    - Options: an `@TYPE` prefix on a line (`@Laptop sleep 15`).
    - Default: every line applies everywhere.
    - More detail: [Shared format](../../configuration.md#shared-format)
4. Should Bootstrap apply them?
    - Options: `step Power on` in `bootstrap.local.conf` (it needs the administrator password), per machine type with `@TYPE`.
    - Default: off; run `Set-PowerSettings` by hand.
    - More detail: [Bootstrap](Bootstrap.md)

## Where to Put Values

`Unix/config/power.local.conf`, created when missing. A `[AC]`, `[Battery]` or `[All]` section
there replaces the base one whole, so copy every line you keep; an empty section turns that
source's settings off on this Mac. `@TYPE` limits a line to one machine type.

## Steps Overview

1. Set the timers and switches per source
2. Check the configuration

## Step 1: Set the timers and switches per source

```conf
[AC]
displaysleep 30
sleep 0
womp 1

[Battery]
displaysleep 5
@Laptop sleep 15
```

The sections apply in the order AC, Battery, All, so a key in `[All]` overrides the same key of
the other two.

## Step 2: Check the configuration

```bash
Set-PowerSettings --list
```

It shows each key with its configured and current value per source, warns about unsupported keys
and changes nothing.

## Verification

```bash
Set-PowerSettings --list
Set-PowerSettings --dry-run
Bootstrap --only Power --dry-run
Test-ConfigurationSchema --quiet
```

## Complete Example

`Unix/config/power.local.conf`:

```conf
[AC]
displaysleep 30
sleep 0
womp 1

[Battery]
displaysleep 5
@Laptop sleep 15
powernap 0

[All]
lessbright 1
```

## Related

- [`Set-PowerSettings` in the Bootstrap module reference](../../modules/Bootstrap.md#set-powersettings)
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
