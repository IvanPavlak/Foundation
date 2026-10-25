# AI Module Configuration Guides

The AI module deploys the AI skills, mods, rules, prompts and agents into the AI apps of the Mac,
installs the Claude Code plugin marketplaces, adds the MCP servers to Claude Code and Codex, lists
the artifacts and vendors them from upstream; see [the module reference](../../modules/AI.md).

## Configurable Commands

| Command | Configuration files | Guide |
| ------- | ------------------- | ----- |
| `Deploy-AiArtifacts` | `ai-artifacts.conf`, `ai-harnesses.conf` | [Deploy-AiArtifacts](Deploy-AiArtifacts.md) |
| `Deploy-AiMarketplaces` | `ai-marketplaces.conf` | [Deploy-AiMarketplaces](Deploy-AiMarketplaces.md) |
| `Deploy-AiMcpServers` | `ai-mcp-servers.conf` | [Deploy-AiMcpServers](Deploy-AiMcpServers.md) |
| `List-AiArtifacts` | `ai-artifacts.conf`, `ai-harnesses.conf` | [List-AiArtifacts](List-AiArtifacts.md) |
| `Update-AiArtifacts` | `ai-artifacts.conf` | [Update-AiArtifacts](Update-AiArtifacts.md) |

## Commands With No Configuration

None: every AI command reads its configuration file.

## Related

- [All configuration guides](../README.md)
- [Configuration](../../configuration.md)
