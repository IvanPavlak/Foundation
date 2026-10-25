# Deploy-AiMarketplaces

Registers the Claude Code plugin marketplaces of `ai-marketplaces.conf`, writes the variables and
options their plugins need into `~/.claude/settings.json` and installs the plugins, or with
`--check` reports the current state.

> [!NOTE]
> Every value on this page belongs in the `.local.conf` overlay of its file
> (`Unix/config/NAME.local.conf`), never in the base `NAME.conf` a generic clone ships. See
> [Base and overlay](../../configuration.md#base-and-overlay).

## Configuration Keys

| File | Line | Default (base) | What it controls |
| ---- | ---- | -------------- | ---------------- |
| [`ai-marketplaces.conf`](../../configuration.md#files) | `[Marketplace]` | none, a commented example only | One marketplace, named as Claude Code knows it; its plugins install as `<plugin>@<Marketplace>` |
| [`ai-marketplaces.conf`](../../configuration.md#files) | `repository OWNER/NAME` | none (required) | The GitHub repository carrying the marketplace |
| [`ai-marketplaces.conf`](../../configuration.md#files) | `plugins PLUGIN...` | none: the marketplace is only registered | The plugins to install from it |
| [`ai-marketplaces.conf`](../../configuration.md#files) | `env NAME VALUE` | none | A variable written to the `env` block of the settings; a later section wins the same name |
| [`ai-marketplaces.conf`](../../configuration.md#files) | `option PLUGIN KEY VALUE` | none | One option of a plugin, in `pluginConfigs.<plugin>@<Marketplace>.options` (the option lines replace that key whole); VALUE is JSON when it parses |
| [`ai-marketplaces.conf`](../../configuration.md#files) | `config PLUGIN CHILD VALUE` | none | Any other key of the plugin's entry |
| [`ai-marketplaces.conf`](../../configuration.md#files) | `[plugin:NAME]` | none | Options (`option KEY VALUE`, `config CHILD VALUE`) of a plugin no marketplace installs, such as a vendored mod, under `pluginConfigs.<NAME>` |

## Decisions

1. Which plugin marketplaces should Claude Code know, and which of their plugins should be installed?
    - Options: one `[Marketplace]` section per marketplace with `repository` and `plugins`. A plugin installed here must not also be a vendored mod: Claude Code would load it twice.
    - Default: none; the command warns that there is nothing to deploy.
    - More detail: [AI on a Mac](../../ai.md#marketplaces)
2. Does a plugin need a variable in Claude Code's environment?
    - Options: `env NAME VALUE` lines (`env CLAUDE_CODE_ENABLE_FUNCTION_HOOKS 1` for a hooks module on Claude Code 2.1.286).
    - Default: none.
    - More detail: [Troubleshooting: AI](../../troubleshooting.md#ai)
3. Which options should each plugin get?
    - Options: `option PLUGIN KEY VALUE` lines, `config PLUGIN CHILD VALUE` for other keys, a `[plugin:NAME]` section for a plugin no marketplace installs.
    - Default: the plugin's own defaults.
    - More detail: [AI on a Mac](../../ai.md#marketplaces)

## Where to Put Values

`Unix/config/ai-marketplaces.local.conf`, created when missing. A section there adds a marketplace;
one with the name of a base section replaces it whole.

## Steps Overview

1. Add the marketplace section
2. Check the configuration

## Step 1: Add the marketplace section

```conf
[my-marketplace]
repository  MyOrg/MyMarketplace
plugins     my-plugin
option      my-plugin theme dark
```

## Step 2: Check the configuration

```bash
Test-ConfigurationSchema --quiet
Deploy-AiMarketplaces --check
```

## Verification

```bash
Deploy-AiMarketplaces --check
claude plugin marketplace list
claude plugin list
```

## Complete Example

`Unix/config/ai-marketplaces.local.conf`:

```conf
[my-marketplace]
repository  MyOrg/MyMarketplace
plugins     my-plugin
env         CLAUDE_CODE_ENABLE_FUNCTION_HOOKS 1
option      my-plugin theme dark
option      my-plugin pulse true
config      my-plugin enabled true

[plugin:my-mod]
option      theme light
```

## Related

- [`Deploy-AiMarketplaces` in the AI module reference](../../modules/AI.md#deploy-aimarketplaces)
- [AI configuration guides](README.md)
- [macOS Configurator](../../macos-configurator.md)
