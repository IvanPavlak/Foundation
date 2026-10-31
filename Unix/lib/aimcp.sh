# shellcheck shell=bash
# What Test-AiProfile and Initialize-AiProfile need to know about the MCP servers of the active AI
# profile (lib/aiprofile.sh): which of them sign in with OAuth. Deploy-AiMcpServers reads
# ai-mcp-servers.conf itself. Needs lib/config.sh and lib/aiprofile.sh. Written to run under bash
# 3.2 too.

# The OAuth servers of the active profile, one per line: the remote servers of
# ai-mcp-servers.conf (a url line and neither bearer-token-env nor an Authorization header) the
# profile's `mcp` lines name (no mcp line: every server), for this machine type.
# Usage: ai_profile_oauth_servers
ai_profile_oauth_servers() {
	local file section lines line key rest listed='' url remote
	file=$(conf_path ai-mcp-servers.conf) || return 0
	if [ -n "${AI_PROFILE:-}" ] && ai_profile_has mcp; then
		listed=$'\n'$(ai_profile_words mcp | tr '[:upper:]' '[:lower:]')$'\n'
		[ "$listed" != $'\n\n' ] || return 0
	fi
	while IFS= read -r section; do
		[ -n "$section" ] || continue
		if [ -n "$listed" ]; then
			case $listed in *$'\n'"$(foundation_lower "$section")"$'\n'*) ;; *) continue ;; esac
		fi
		lines=$(conf_section "$file" "$section") || continue
		url='' remote=1
		while IFS= read -r line; do
			read -r key rest <<<"$line"
			case $(foundation_lower "$key") in
				url) url=$rest ;;
				bearer-token-env) remote=0 ;;
				header)
					read -r key _ <<<"$rest"
					foundation_ieq "$key" Authorization && remote=0
					;;
				machine)
					local types
					types=" $(printf '%s' "$rest" | tr ',/' '  ' | tr '[:upper:]' '[:lower:]') "
					case $types in
						*" all "* | *" $(foundation_lower "${CONF_MACHINE_TYPE:-$(foundation_machine_type)}") "*) ;;
						*) remote=0 ;;
					esac
					;;
			esac
		done <<<"$lines"
		[ -n "$url" ] && [ "$remote" -eq 1 ] && printf '%s\n' "$section"
	done < <(conf_sections "$file")
	return 0
}
