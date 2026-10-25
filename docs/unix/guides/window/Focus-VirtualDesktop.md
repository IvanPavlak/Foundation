# Focus-VirtualDesktop

Switches to a desktop, the AeroSpace workspace of that number that `alt-NUMBER` shows, and parks
the focus on the terminal when one is there.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`apps.conf`](../../configuration.md#files) | `role Terminal MEMBER...` | `role Terminal WezTerm` | Which app's window gets the focus after the switch: the first window of a `Terminal` member on that desktop, as Windows locks the focus onto Windows Terminal; without one there, AeroSpace's last-focused window of the desktop keeps it |

## Decisions

1. Which terminal should a desktop switch focus?
    - Options: the members of the `role Terminal` line of `apps.conf`, each an `app` token (`WezTerm`, or another terminal app a fork adds as an `app` line).
    - Default: `WezTerm`, the orchestration terminal.
    - More detail: [`apps.conf`](../../configuration.md#files)

## Where to Put Values

`Unix/config/apps.local.conf`, created when missing. Its lines are added after the base ones, and
for a `role` line the last one wins, so a `role Terminal` line there replaces the base members;
`-LINE` takes a base line back; `@TYPE` limits a line to machine types.

## Steps Overview

1. Name the terminal
2. Check the configuration

## Step 1: Name the terminal

The role's members are `app` tokens; a terminal that is not one yet gets an `app` line first.

```conf
app MyTerminal  com.example.myterminal
role Terminal   MyTerminal
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

Nothing is printed when the configuration is consistent.

## Verification

```bash
grep -h '^role Terminal' Unix/config/apps.conf Unix/config/apps.local.conf
Get-WindowHandle --process-name Terminal
```

## Complete Example

`Unix/config/apps.local.conf`:

```conf
app MyTerminal  com.example.myterminal
role Terminal   MyTerminal
```

## Related

- [`Focus-VirtualDesktop` in the Window module reference](../../modules/Window.md#focus-virtualdesktop)
- [Window configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
