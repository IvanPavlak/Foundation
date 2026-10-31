# AI Module Configuration Guides

The AI module deploys the AI skills, mods, rules, prompts and agents into the AI apps of the Mac,
installs the Claude Code plugin marketplaces, adds the MCP servers to Claude Code and Codex, lists
the artifacts, vendors them from upstream, and checks and initializes the AI profile of the Mac; see [the module reference](../../modules/AI.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Deploy-AiArtifacts` | `ai-artifacts.conf`, `ai-harnesses.conf`, `ai-profiles.conf`, `repositories.conf` | [Deploy-AiArtifacts](Deploy-AiArtifacts.md) |
| `Deploy-AiMarketplaces` | `ai-marketplaces.conf`, `ai-profiles.conf` | [Deploy-AiMarketplaces](Deploy-AiMarketplaces.md) |
| `Deploy-AiMcpServers` | `ai-mcp-servers.conf`, `ai-profiles.conf` | [Deploy-AiMcpServers](Deploy-AiMcpServers.md) |
| `Initialize-AiProfile` | `ai-profiles.conf`, `ai-mcp-servers.conf` | [Initialize-AiProfile](Initialize-AiProfile.md) |
| `List-AiArtifacts` | `ai-artifacts.conf`, `ai-harnesses.conf`, `ai-profiles.conf`, `repositories.conf` | [List-AiArtifacts](List-AiArtifacts.md) |
| `Test-AiProfile` | `ai-profiles.conf`, `ai-artifacts.conf`, `ai-harnesses.conf`, `ai-mcp-servers.conf` | [Test-AiProfile](Test-AiProfile.md) |
| `Update-AiArtifacts` | `ai-artifacts.conf`, `ai-profiles.conf` | [Update-AiArtifacts](Update-AiArtifacts.md) |

## Commands With No Configuration

None: every AI command reads its configuration file.

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
