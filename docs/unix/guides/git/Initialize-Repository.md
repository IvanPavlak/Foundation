# Initialize-Repository

Clones a repository into a folder, or updates the folder safely (stash, fast-forward only) when it
already is a checkout; a URL that `repositories.conf` marks `shallow` is cloned `--depth 1`.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `NAME PATH-OR-URL [DIR] shallow` | no line is `shallow` | A clone of the same URL (case, a user name, a trailing slash and `.git` ignored) is made `--depth 1` and keeps its `.git` - the Windows rule for the Obsidian repository, as a setting |
| [`repositories.conf`](../../configuration.md#repositoriesconf) | `base URL` | `https://github.com` | The prefix a relative path of such a line gets before the URLs are compared |

## Decisions

1. Which repositories should be cloned without their history?
    - Options: end their `repositories.conf` line in `shallow` (a vault or another repository with a large history); Update-Repositories reads the same word, so both commands clone it alike. `--archive` instead drops the `.git` folder altogether.
    - Default: every clone takes the full history.
    - More detail: [`repositories.conf`](../../configuration.md#repositoriesconf)

## Where to Put Values

`Unix/config/repositories.local.conf`: a `[Group]` there replaces the base group of the same name
whole, so the `shallow` word goes on the overlay's own repository line. `@TYPE` limits a line to
machine types.

## Steps Overview

1. Mark the repository `shallow`
2. Check the configuration

## Step 1: Mark the repository `shallow`

```conf
[Private]
MyNotes   /MyUser/MyNotes.git   $DEV/MyNotes   shallow
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
```

It reports an `@TYPE` prefix that is not a machine type; the repository lines themselves are not
checked.

## Verification

```bash
Test-ConfigurationSchema --quiet
cat Unix/config/repositories.local.conf
```

## Complete Example

`Unix/config/repositories.local.conf`:

```conf
base https://MyUser@github.com

[Private]
Dotfiles   /MyUser/Dotfiles.git   $DOTFILES_ROOT
MyNotes    /MyUser/MyNotes.git    $DEV/MyNotes   shallow
```

Then `Initialize-Repository https://MyUser@github.com/MyUser/MyNotes.git $DEV/MyNotes` clones it
shallow, and so does `Update-Repositories MyNotes` while the folder is missing.

## Related

- [`Initialize-Repository` in the Git module reference](../../modules/Git.md#initialize-repository)
- [Git configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
