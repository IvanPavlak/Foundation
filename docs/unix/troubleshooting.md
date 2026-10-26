# Troubleshooting on a Mac

Common problems of Foundation on a Mac, by area, each with its fix. Every command also writes a
session log (`Get-LogPath` prints the newest, `Get-LogPath --errors` the error log), and a
`Bootstrap` run keeps a transcript in `~/Desktop/BootstrapLog_<yyyy-MM-dd_HH-mm-ss>.log`: start
there when a message scrolled away.

## Bootstrap and Homebrew

### "bash 3.2.57 is too old for Foundation"

**Problem:** A command stops with `bash 3.2.57 is too old for Foundation (needs 4.4+)`.

**Solution:** Every module command needs bash 4.4+, which the HomebrewBash step installs; only
`Unix/bootstrap.sh` and `bootstrap-first-run` run on the stock bash. Run `brew install bash` (or
`Bootstrap --only HomebrewBash`), then open a new terminal so Homebrew's `bin` comes first on PATH.

### bootstrap.sh stops at the Command Line Tools

**Problem:** `Unix/bootstrap.sh` opens the Command Line Tools installer and exits.

**Solution:** By design: git, clang and the rest of the toolchain come with them and nothing can
continue without. Finish the installer, then run `Unix/bootstrap.sh` again.

### brew bundle refuses a third-party tap

**Problem:** The Packages step (or `brew bundle` by hand) refuses an entry from a third-party tap
until it is trusted.

**Solution:** Homebrew 7 keeps the trust list in `$XDG_CONFIG_HOME/homebrew/trust.json` when that
variable is set (the shared rc sets it) and in `~/.homebrew/trust.json` otherwise. The Packages
step trusts every `trust TYPE NAME` line of `bootstrap.conf`'s `[Packages]` section in both (the
base file trusts AeroSpace's cask), so `brew` works the same from the bootstrap and from a
terminal. For a tap of your own, add its line to `[Packages]` of `bootstrap.local.conf` (copy the
base section's lines too: an overlay section replaces the base one whole), then rerun
`Bootstrap --only Packages`.

### An App Store app was skipped

**Problem:** The Packages step warns `App Store app <id> skipped - sign in to the App Store app`.

**Solution:** `brew bundle` installs only App Store apps the Apple Account already got, so the
step runs `mas get` for each `mas` line first. That needs an Apple Account signed in to the App
Store app itself (iCloud is not enough), which no script can do; an app that cannot be got is left
out (`HOMEBREW_BUNDLE_MAS_SKIP`) and the rest still installs. Sign in through App Store > Sign In,
then run `Bootstrap --only Packages`.

### A download or disk image mount failed

**Problem:** `brew bundle` fails on a cask with a failed download or `hdiutil: Resource busy`.

**Solution:** The Packages step already retries with one more `brew bundle` pass, which installs
only what is still missing. When the retry fails too, run `Bootstrap --only Packages` again later.

### A cask's kernel extension or an unverified app is blocked

**Problem:** An app installed by a cask does not start (VeraCrypt without macFUSE, or DBeaver,
whose signer Homebrew could not verify).

**Solution:** Still manual, once per Mac: approve the kernel extension under System Settings >
Privacy & Security (the Permissions step of `--with-initial-setup` opens that pane), and use
"Open Anyway" there for the unverified app.

### Steps were skipped for lack of administrator rights

**Problem:** Bootstrap warns `No administrator rights - the steps that need them are skipped` and
exits with status 1 although no step failed.

**Solution:** The password is asked once, and only when an enabled step needs root (Power,
Spotlight, Firewall, SoftwareUpdate, Rosetta, DotnetSdks, RenameMachine; Packages and AiArtifacts
for their root parts). A refused or cancelled prompt skips those steps. Rerun `Bootstrap` (or
`Bootstrap --only` the skipped steps) from an administrator account and answer the prompt.

### InitializeConfiguration, RenameMachine or Permissions did not run

**Problem:** A plain `Bootstrap` run lists these steps as off although `bootstrap.conf` turns them on.

**Solution:** They run only with `--with-initial-setup` (or when `--only` names them):
`Bootstrap --only Permissions` reopens the permission panes, `Bootstrap --only InitializeConfiguration`
asks the identity and paths again.

### RepositoryUpdate fails: a scope name is no group

**Problem:** The RepositoryUpdate step reports a `repository-scope` name that is no
`repositories.conf` group, updates nothing and fails.

**Solution:** The scope takes group names only (or `All`). Put the repositories to update in a group
of their own in `repositories.local.conf` and name that group.

### The Obsidian vault was not found

**Problem:** The ObsidianSettings step warns `Obsidian vault not found`.

**Solution:** The vault is not cloned yet (cloning into a folder that already holds `.obsidian`
would fail, so the step waits). Clone it (the RepositoryUpdate step, or `Update-Repositories`),
then run `Bootstrap --only ObsidianSettings`.

### Git asks for a password and GitHub rejects it

**Problem:** `git push`, `git pull` or the Obsidian Git plugin asks for a password, and GitHub
answers that password authentication is not supported.

**Solution:** Git authenticates through the GitHub CLI: run `gh auth login` once. The helper comes
from `Git/Unix/gitconfig.local`, which chezmoi links to `~/.gitconfig.local`; check the link with
`readlink ~/.gitconfig.local` (see [Git credentials](README.md#git-credentials)).

### A new command is "not found" or its Bootstrap step fails to start

**Problem:** A command under `Unix/modules/<Module>/bin` is on disk, but the shell answers
`command not found` (or `permission denied` by path), and the Bootstrap step that runs it fails.

**Solution:** The file was committed from Windows, which records it as mode `100644`, so the Mac
checkout has no execute bit. Run `chmod +x` on it and `git update-index --chmod=+x` on the same
path, then commit the mode change. The `commands` suite (`Run-Tests commands`) fails on any command
git does not track as executable.

## chezmoi

### A Mac Keeps Its Old Machine Type After machines.conf Changes

**Problem:** The machine type in `Unix/config/machines.conf` (or its `.local.conf` overlay) was
changed, but `chezmoi apply` still links the old type's files, for example
`~/.config/fastfetch/config.jsonc` to `config_Laptop.jsonc` on a Work Mac. A
`chezmoi: warning: config file template has changed, run chezmoi init to regenerate config file`
line may appear as well.

**Cause:** `chezmoi init` asks for the machine type once and saves the answer as `machineType` in
`~/.config/chezmoi/chezmoi.toml`. Every later `chezmoi init` reuses that answer, so the `host` line
is only the default for the first question. The warning only means the template changed since the
last init, and a plain `chezmoi init` keeps the saved type.

**Solution:** Ask both questions again, answer the new type, then apply:

```bash
chezmoi init --prompt
chezmoi apply
```

`chezmoi data` shows the `machineType` in effect.

### chezmoi applied nothing: a backup failed

**Problem:** `Unix/bootstrap.sh` or Bootstrap's Dotfiles step stops before `chezmoi apply` after a
`Backup of <path> failed` line.

**Solution:** A real file or folder sat where a link goes and could not be copied into
`Backups/Unix/SymbolicLinks/Dotfiles.<path>/`; nothing is applied over an original without a
backup. Free disk space or fix the permissions the message names, then rerun. `Unix/bootstrap.sh
--dry-run` lists what would be backed up. See [Backups on a Mac](backups.md).

### A machine type warning names a type that does not exist

**Problem:** Every command warns once that the machine type is no `type` line of `machines.conf`.

**Solution:** The type came from `FOUNDATION_MACHINE_TYPE`, a `host` line or `MACHINE_TYPE` (the
warning names which) and has a typo, or its `type` line is missing. Fix the source, or add
`type MyType` to `machines.local.conf`; `Test-ConfigurationSchema` lists every such problem. See
[Machine type](README.md#machine-type).

## Workspaces

The workspace problems (AeroSpace not answering, the Accessibility and Automation permissions,
layout verification, browser windows, WezTerm tabs) are on
[macOS Workspaces: Troubleshooting](macos-workspaces.md#troubleshooting).

### A Templated Workspace Opens Nothing

**Problem:** `w MyRepo` prints `workspaces.conf [MyRepo]: <problem>` (an unknown template, a
variable without a value, an unknown placeholder, an ambiguous override) and
`Workspace [MyRepo] not opened`.

**Solution:** The workspace is a `template NAME` section of `workspaces.conf` and its template a
section of `workspace-templates.conf`. Nothing is expanded at load: a workspace that cannot be
expanded opens nothing, on purpose. Fix what the message names (`set` lines for variables,
`replace` / `drop` / `add` lines for overrides, `:ID` for an action id), then check with
`Test-ConfigurationSchema`, which lists the same problems. See
[workspace-templates.conf](configuration.md#workspace-templatesconf).

### Project tabs open in a new window

**Problem:** `Open-ProjectTerminals` (or a workspace) opens the project tabs in a new WezTerm window
instead of the one the command was typed in.

**Solution:** The tabs join the window by its WezTerm window id, which the command has only when it
runs in a WezTerm pane. An app started from WezTerm (VS Code, the Claude app) inherits
`WEZTERM_PANE`, so the variable counts only when that pane's tty is the command's own terminal.
Run the command in a WezTerm tab.

## Shell

### A leftover zsh fills RAM and swap

**Problem:** macOS runs out of application memory with little open. `ps -axo pid,ppid,rss,command
-m` shows a `-zsh` at the top whose parent is another `-zsh` with no terminal (`??`) and parent
PID 1, and the kernel log has `memorystatus: killing zsh [PID] due to low-swap`.

**Solution:** That is a completion worker of zsh-autocomplete left behind by a closed terminal:
the plugin forks a worker and a helper zsh on a pseudo-terminal of its own for every key, and once
the completion runs long nothing stops them. The shared rc wraps the worker with a hard limit
(`Unix/shell/autocomplete-guard.zsh`): a worker still running after 10 seconds is killed with its
helper. A shell started before the guard existed still has the unguarded worker - open a new
terminal. To catch one still running, `sample PID 3` shows what it is doing.

## AI

The deployment itself (paths, steps, verification) is on [AI on a Mac](ai.md).

### An Artifact Is Not Deployed

**Problem:** A skill, rules item, prompt or agent sits under `AI/` but `Deploy-AiArtifacts` does not
link it, or links another one of the same name.

**Solution:** `List-AiArtifacts --list-discrepancies` names what is missing. The usual causes:

1. Its source folder is not read: only `own`, `foundation`, `example` and the `[sections]` of
   `ai-artifacts.conf` are (WinuX's `winux` folder never is on a Mac). Move the item into `own`.
2. Another source carries the same name: `own` wins, then the first source by name, with a
   `Duplicate ...` warning. Rename one, or `exclude KIND/SOURCE/NAME` the one you do not want.
3. An `exclude` line names it.
4. No harness of the `deploy` line takes that kind, or the item has none of the files the
   destination names (`codex.toml` for Codex agents, for instance): add the variant to the item.
5. A rules item: only the `use rules NAME` line's item is linked, and the last such line wins.

### A Mod Does Not Appear In Claude Code

**Problem:** `Deploy-AiArtifacts` ran, but a new Claude Code session shows no band, pane or status entry
from the mod.

**Solution:**

1. Confirm the link, the settings key and that the CLI accepts the mod:

    ```bash
    ls -l ~/.claude/mods
    python3 -c 'import json,os; print(json.load(open(os.path.expanduser("~/.claude/settings.json")))["env"]["CLAUDE_CODE_PLUGIN_DIRS"])'
    claude plugin validate ~/.claude/mods/my-mod
    ```

2. Claude Code reads `CLAUDE_CODE_PLUGIN_DIRS` when a session starts: close and reopen the session
   (and quit and reopen the desktop app for its Code tab).
3. If the key is missing although `Deploy-AiArtifacts` set it, something rewrote `settings.json`
   without it (a manual edit or another tool). Run `Deploy-AiArtifacts --kind mods` again; it only
   rewrites that one key.

### A Marketplace Plugin Is Installed But Draws Nothing

**Problem:** `claude plugin install <plugin>@<marketplace>` reports the plugin installed and
enabled (and `Deploy-AiMarketplaces` reports it installed), yet a new session shows nothing from it.

**Solution:** Claude Code 2.1.286 loads hooks modules only when `CLAUDE_CODE_ENABLE_FUNCTION_HOOKS`
is `1`, read from the `env` block of `~/.claude/settings.json`; a plugin cannot set it for itself.
Check `claude --version`, then add the line to the marketplace's section of
`ai-marketplaces.local.conf` and run `Deploy-AiMarketplaces` (or `Bootstrap --only AiMarketplaces`):

```
[my-marketplace]
repository  MyOrg/MyMarketplace
plugins     my-plugin
env         CLAUDE_CODE_ENABLE_FUNCTION_HOOKS 1
```

Start a new session, or run `/reload-plugins` in an open one. Claude Code 2.1.287 and later ignore
the variable, so the line can go once every copy on the Mac is that new.

### A Marketplace Plugin Ignores Its Options

**Problem:** The options under `pluginConfigs.<plugin>@<marketplace>` are set, yet the plugin draws
with its defaults; `Deploy-AiMarketplaces` may warn that the plugin `is installed from its
marketplace and also loaded from` a folder.

**Solution:** A folder holding the same plugin is listed in `env.CLAUDE_CODE_PLUGIN_DIRS`, usually
a development clone added by hand, so Claude Code loads it twice and the folder copy reads
`pluginConfigs.<plugin>` instead. Remove that entry from the `env` block of
`~/.claude/settings.json`, start a new session, and load a clone only for development with
`claude --plugin-dir <clone>`. An option that is still ignored may have the wrong type: an `option`
value is JSON when it parses, so write `true`, not `"true"` (a string).

### "Claude Code CLI (claude) not found on PATH" Or "claude plugin validate failed"

**Problem:** `Deploy-AiArtifacts` warns that mods are deployed but cannot be used yet.

**Solution:** The links and the settings key are in place; the warning is about the CLI only.
Install the Claude Code CLI (`brew install --cask claude-code`, or its line in `Brewfile.local`) or
update it: an older CLI that predates the mod API rejects a mod it cannot load. When the CLI is
current and validation still fails, run `claude plugin validate <mod folder>` to see what it
refuses, and fix the mod upstream.

### settings.json Could Not Be Parsed

**Problem:** `Deploy-AiArtifacts` or `Deploy-AiMarketplaces` reports `Could not parse ~/.claude/settings.json - left untouched`.

**Solution:** The file is not valid JSON, usually a trailing comma or a comment added by hand. Fix
it (Claude Code refuses an invalid settings file too), then run the command again. A file it cannot
read is never overwritten, so nothing was lost.

### The managed settings were not linked

**Problem:** `Deploy-AiArtifacts` reports `SKIPPED /Library/Application Support/ClaudeCode/managed-settings.json`.

**Solution:** That path is root-owned and linked through sudo (the `+managed-settings` hook of the
`claude-code` harness). Run `Deploy-AiArtifacts` (or `Bootstrap --only AiArtifacts`) from an
administrator account and answer the password prompt. When the line says its backup failed, a file
there could not be copied into
`Backups/Unix/SymbolicLinks/AiArtifacts.rules.<Name>.managed-settings.json/`: fix what the error
names and rerun.

### An MCP Server Is Listed but Its Tools Are Missing

**Problem:** `Deploy-AiMcpServers` reports the server added or already configured and `claude mcp list` lists it, yet a new session has none of its tools, or the list says it needs authentication.

**Solution:** The configuration carries the server, not its credentials. An OAuth server needs the sign-in once per machine and app, because the tokens stay in the keychain: `/mcp` in Claude Code, `codex mcp login <name>` for Codex. A `bearer-token-env` server needs that variable exported where the app starts (your shell profile, then a new terminal; restart the desktop app). The same gotchas on Windows, and why a hand-added option of a Codex table is replaced, are on WinuX's [Troubleshooting](https://ivanpavlak.github.io/WinuX/#/reference/troubleshooting?id=ai-mcp-server-issues).
