# Backups on a Mac

Every Foundation command that overwrites or displaces an existing file first copies it into one
backup sink at the repository root, the Unix namespace of the sink WinuX uses on Windows:

```
<repo>/Backups/Unix/<Category>/<Key>/<yyyy-MM-dd_HH-mm-ss>/
```

One folder per key, one timestamped folder per replacement (a second backup of the same key within
one second gets a `-2` suffix), so every version ever displaced sits side by side with the newest
last. The sink is gitignored: the copies hold this machine's data and possibly secrets.

All backups are taken by one bash primitive, `backup_item CATEGORY KEY PATH` in
`Unix/lib/backup.sh` (the Backup-RepositoryItem of Windows), and pruned by one command,
[Clear-OldBackups](modules/Helper.md#clear-oldbackups). `FOUNDATION_BACKUP_ROOT` names another sink
(the test suites' seam); a few commands take `--backup-root DIR` for one run, as their Windows
`-BackupRoot`.

## What lands where

| Category | Key | Written by | When |
| -------- | --- | ---------- | ---- |
| `SymbolicLinks` | `Dotfiles.<home path>` (dots for slashes, leading dots dropped, e.g. `Dotfiles.config.btop.themes`) | `Unix/bootstrap.sh`, Bootstrap's Dotfiles step | A **real** file or folder sits where a chezmoi link goes; nothing is applied when a copy fails. A link already there is replaced without a backup: it carries no content of its own. |
| `SymbolicLinks` | `Obsidian` | Bootstrap's ObsidianSettings step | The vault's own `.obsidian` folder is a real folder where the link to the `settings` folder of `obsidian.conf` goes; it is kept when the copy fails. |
| `SymbolicLinks` | `Firefox.<profile>.user.js` | [Deploy-FirefoxProfile](modules/Bootstrap.md#deploy-firefoxprofile) | A real `user.js` sits in the profile. |
| `SymbolicLinks` | `VSCodeProfiles.<profile>.<item>` | [Deploy-VSCodeProfiles](modules/Application.md#deploy-vscodeprofiles) | A real file or folder sits where a profile link (settings, keybindings, snippets) goes. |
| `SymbolicLinks` | `VSCodeProfiles.Extensions.<id>` | [Deploy-VSCodeProfiles](modules/Application.md#deploy-vscodeprofiles) | A real folder sits in VS Code's extensions folder where a local extension's link goes. |
| `SymbolicLinks` | `AiArtifacts.<kind>.<item>`, `AiArtifacts.<kind>.<item>.<file>` | [Deploy-AiArtifacts](modules/AI.md#deploy-aiartifacts) | A real file or folder sits where an artifact link or copy goes (`AiArtifacts.skills.tdd`), or where a `file` destination goes (`AiArtifacts.rules.CoreAiRules.RULES.md` for `~/.claude/CLAUDE.md`; Claude Code's managed-settings path is copied as the user, removed through sudo); that item is skipped when the copy fails. |
| `VSCodeProfiles` | `storage.json` | [Deploy-VSCodeProfiles](modules/Application.md#deploy-vscodeprofiles) | Before VS Code's profile list is rewritten to register a profile. |
| `Config` | `<file>.local`, the overlay's path under `Unix/config` with dots for slashes and `.conf` dropped (`workspaces.local`, `projects.local`, `browser-groups.local`) | [Add-Workspace](modules/Configuration.md#add-workspace), [Add-Project](modules/Configuration.md#add-project), [Add-BrowserGroup](modules/Configuration.md#add-browsergroup), [Add-WindowLayout](modules/Configuration.md#add-windowlayout) (its `simple-layouts` line) | Before every write to an existing `.local.conf` overlay; a missing overlay is created with a header instead. The base file is never written. |
| `Config` | `git.local`, `machines.local` | [Initialize-Configuration](modules/Bootstrap.md#initialize-configuration) | Before its first write of a run to an existing overlay (the identity, the `host` and `dev-root` lines); nothing is written when the copy fails. |
| `Config` | `WindowLayouts.<Type>.<Workspace>` | [Visualize-Layouts](modules/Window.md#visualize-layouts) `--update` | Before rewriting the drawing in `Unix/config/layouts/<Type>/<Workspace>_<Type>.conf`. |
| `Config` | `obsidian.json` | [Enable-ObsidianCli](modules/Application.md#enable-obsidiancli) | Before switching the CLI on in `~/Library/Application Support/obsidian/obsidian.json`. |
| `System` | `NuGetConfig` | [Configure-NuGetConfig](modules/Bootstrap.md#configure-nugetconfig) | Before overwriting an existing real NuGet config (default `~/.nuget/NuGet/NuGet.Config`). |
| `System` | `DockLayout` | [Set-DockPins](modules/Bootstrap.md#set-dockpins) | Before `clear on` empties the Dock: `com.apple.dock.plist` (`defaults export com.apple.dock`); the Dock is left as it is when this fails. |

`Unix/tests/docpages.bats` checks that every category and every fixed key prefix a `backup_item`
call under `Unix/` uses appears in this table, so a new writer cannot land without its row.

## The contract: skip, never destroy

If a backup cannot be taken, the write it protects **does not happen**: a link is skipped and the
existing file left alone, a configuration write aborts before touching the file. `backup_item`
removes a partly copied folder before it reports the failure, so the sink never holds a half-taken
backup that looks like a good restore point.

## Retention

[Clear-OldBackups](modules/Helper.md#clear-oldbackups) applies three independent limits from
`Unix/config/backups.conf` (the `Backups.Retention` of Windows), each disabled by `0`, and
`Invoke-LogMaintenance` runs it with the log sweep once its interval has passed:

| Line | Shipped default | What it does |
| ---- | --------------- | ------------ |
| `max-age-days` | `0` (never) | Delete backups older than this many days. |
| `max-backups-per-key` | `10` | Keep at most this many backups per key, newest retained. Also enforced right after every backup. |
| `max-total-size-mb` | `500` | Cap the whole sink's size; oldest backups removed first. |

Whatever the limits, **the newest backup of every key is never deleted**, and only folders named
`yyyy-MM-dd_HH-mm-ss` count as backups: a manual copy in a key folder is never removed.
`Clear-OldBackups --dry-run` lists what would go.

## Restoring a backup

Find what you are looking for, newest last:

```bash
find "$(Get-RepositoryPath)/Backups/Unix" -mindepth 3 -maxdepth 3 -type d | sort
```

For a file a link displaced, remove the link first, then copy the file back:

```bash
rm ~/.config/btop/themes
cp -pR "$(Get-RepositoryPath)/Backups/Unix/SymbolicLinks/Dotfiles.config.btop.themes/<timestamp>/themes" ~/.config/btop/
```

A link chezmoi manages comes back on the next `chezmoi apply`; to keep your own file for good,
take the dotfile out of chezmoi's management first (see [Dotfiles with chezmoi](bootstrap.md#dotfiles-with-chezmoi)).

For a configuration overlay, copy straight over the current one:

```bash
cp "$(Get-RepositoryPath)/Backups/Unix/Config/workspaces.local/<timestamp>/workspaces.local.conf" \
    "$(Get-RepositoryPath config)/workspaces.local.conf"
```

For the Dock: `defaults import com.apple.dock <backup>/com.apple.dock.plist; killall Dock`.

## The AI-assistant convention

An assistant editing `Unix/config` (the [FoundationConfigurator](foundation-configurator.md) protocol, or any
other agent) follows the same policy as the code: before its **first** write to a file in a
session, it copies the file to `Backups/Unix/Config/<key>/<yyyy-MM-dd_HH-mm-ss>/`, with the key
built as above (`Brewfile.local` for `Unix/Brewfile.local`).

## Related

- [Bootstrap a Mac](bootstrap.md) - which steps back up what on a first run
- [Troubleshooting](troubleshooting.md) - recovery recipes
- [Backups on Windows](https://ivanpavlak.github.io/WinuX/#/reference/backups) - the same sink and contract in WinuX
