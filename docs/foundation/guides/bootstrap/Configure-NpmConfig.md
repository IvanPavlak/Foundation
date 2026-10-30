# Configure-NpmConfig

Writes a GitHub personal access token, asked on the terminal, into the user npmrc for the private
npm registries of `npm.conf`, so `npm install` of a private scoped package authenticates.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`npm.conf`](../../configuration.md#npmconf) | `npmrc PATH` | `~/.npmrc` | The npmrc the token goes into; `~` and `$VARIABLES` expand, and a relative path starts at the repository root |
| [`npm.conf`](../../configuration.md#npmconf) | `registry URL [SCOPE]` | `https://npm.pkg.github.com/`, no scope | A registry to write the token for; with a SCOPE (`@my-org`) its packages are sent there too. The last line of a URL wins |

## Decisions

1. Which registries need a token?
    - Options: one `registry URL` line per private registry; GitHub Packages is `https://npm.pkg.github.com/`.
    - Default: GitHub Packages.
    - More detail: [`npm.conf`](../../configuration.md#npmconf)
2. Should the npmrc also route a scope to the registry?
    - Options: a SCOPE after the URL (`registry https://npm.pkg.github.com/ @my-org`) when your projects do not ship their own `.npmrc` with `@my-org:registry=...`; none otherwise.
    - Default: no scope.
    - More detail: [`npm.conf`](../../configuration.md#npmconf)
3. Where is the npmrc?
    - Options: any path npm reads as its user config; `~/.npmrc` is npm's own default.
    - Default: `~/.npmrc`.
    - More detail: [`npm.conf`](../../configuration.md#npmconf)
4. Should Bootstrap run it?
    - Options: `step NpmConfig on` in `bootstrap.local.conf` (it asks on the terminal, so it is off by default), per machine type with `@TYPE`.
    - Default: off; run `Configure-NpmConfig` by hand.
    - More detail: [Bootstrap](Bootstrap.md)

## Where to Put Values

`Unix/config/npm.local.conf`, created when missing. Its lines go before any section and are read
after the base ones, so its `npmrc` wins and its `registry` line of a base URL replaces that line;
an `@TYPE` prefix limits a line to one machine type. The token is never stored in configuration:
it is asked when a registry needs it.

Use a classic personal access token with only `read:packages` (the one Configure-NuGetConfig asks
for works), not the GitHub CLI's `gh auth token`: that token carries `repo` and is replaced when
you sign in again. The command writes the token into the npmrc itself, never through `npm config
set`, which puts it on a command line and into npm's debug log.

## Steps Overview

1. Name the registries
2. Check the configuration

## Step 1: Name the registries

```conf
registry https://npm.pkg.github.com/ @my-org
```

A registry counts as configured when its `_authToken` line has a value and, with a scope, the
scope line points at it; a rerun then asks nothing. `--override` asks again and rewrites every
registry. An existing npmrc is backed up into `Backups/Unix/System/NpmConfig/` first, with every
credential value (`_authToken`, `_auth`, `_password`) replaced by `<redacted>`, so the copy keeps
the other settings but no token.

## Step 2: Check the configuration

```bash
Configure-NpmConfig --dry-run
```

It names each registry that would be written and the npmrc, and asks nothing.

## Verification

```bash
Configure-NpmConfig --dry-run
Bootstrap --only NpmConfig --dry-run
npm whoami --registry https://npm.pkg.github.com/
```

## Complete Example

`Unix/config/npm.local.conf`:

```conf
registry https://npm.pkg.github.com/ @my-org
@Work registry https://registry.example.com/npm/
```

## Related

- [`Configure-NpmConfig` in the Bootstrap module reference](../../modules/Bootstrap.md#configure-npmconfig)
- [Configure-NuGetConfig](Configure-NuGetConfig.md), the same token for NuGet
- [Bootstrap configuration guides](README.md)
- [FoundationConfigurator](../../foundation-configurator.md)
