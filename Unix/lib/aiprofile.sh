# shellcheck shell=bash
# AI profiles (docs/foundation/ai.md#profiles): the one profile this machine runs and what it names,
# read from Unix/config/ai-profiles.conf and its overlay. Used by Deploy-AiArtifacts,
# Deploy-AiMcpServers, Deploy-AiMarketplaces, List-AiArtifacts, Update-AiArtifacts, Test-AiProfile
# and Initialize-AiProfile. Needs lib/config.sh.
#
# A profile is a [section] of ai-profiles.conf; with no section, profiles are off and every AI
# command behaves as it does without this file. The profile is picked once per command by
# ai_profile_load: FOUNDATION_AI_PROFILE, then the last `host NAME PROFILE` line naming this host
# (foundation_hostname), then the last `default PROFILE` line. Every line may start with @TYPE.
# Written to run under bash 3.2 too, like the rest of lib/ (read -a never expands a glob, so a
# pattern such as github.com/my-org/* stays as written).
# shellcheck disable=SC2034 # the AI_PROFILE* results are read by the commands that source this file

# Path of ai-profiles.conf (fails when there is none).
aiprof__conf() { conf_path ai-profiles.conf; }

# The profiles: the [sections] of ai-profiles.conf, one per line; nothing when profiles are off.
ai_profiles() {
	local file
	file=$(aiprof__conf) || return 0
	conf_sections "$file"
}

# Picks this machine's profile. Sets AI_PROFILE (as its section spells it), AI_PROFILE_HOW
# (override, hostname or default) and AI_PROFILE_ERROR. Returns 0 with a profile, 1 when profiles
# are off (AI_PROFILE empty), 2 when the name picked is no profile or nothing picks one
# (AI_PROFILE_ERROR says which; AI_PROFILE is then empty too). Call it directly, not in $(...), so
# the variables reach the caller. Usage: ai_profile_load
ai_profile_load() {
	local file name='' how='' line key first second host section
	AI_PROFILE='' AI_PROFILE_HOW='' AI_PROFILE_ERROR=''
	file=$(aiprof__conf) || return 1
	[ -n "$(conf_sections "$file")" ] || return 1
	if [ -n "${FOUNDATION_AI_PROFILE:-}" ]; then
		name=$FOUNDATION_AI_PROFILE
		how=override
	else
		host=$(foundation_hostname)
		local fallback=''
		while IFS= read -r line; do
			read -r key first second _ <<<"$line"
			if foundation_ieq "$key" host && [ -n "$second" ] && foundation_ieq "$first" "$host"; then
				name=$second
				how=hostname
			elif foundation_ieq "$key" default && [ -n "$first" ]; then
				fallback=$first
			fi
		done < <(conf_lines "$file")
		if [ -z "$name" ] && [ -n "$fallback" ]; then
			name=$fallback
			how=default
		fi
	fi
	if [ -z "$name" ]; then
		AI_PROFILE_ERROR="no host line names this Mac ($(foundation_hostname)) and there is no default line in ai-profiles.conf"
		return 2
	fi
	if ! section=$(conf_section_name "$file" "$name"); then
		AI_PROFILE_ERROR="the $how picks profile [$name], which is no section of ai-profiles.conf ($(conf_sections "$file" | paste -sd' ' -))"
		AI_PROFILE_HOW=$how
		return 2
	fi
	AI_PROFILE=$section
	AI_PROFILE_HOW=$how
	return 0
}

# Every line of PROFILE (default the active one) whose first word is KEY: the rest of each line,
# one per line. Usage: ai__profile_rest KEY [PROFILE]
ai__profile_rest() {
	local file line key rest profile=${2:-${AI_PROFILE:-}}
	[ -n "$profile" ] || return 0
	file=$(aiprof__conf) || return 0
	while IFS= read -r line; do
		read -r key rest <<<"$line"
		foundation_ieq "$key" "$1" && printf '%s\n' "$rest"
	done < <(conf_section "$file" "$profile")
	return 0
}

# The words of every KEY line of PROFILE (default the active one), one per line, in file order.
# Usage: ai_profile_words KEY [PROFILE]
ai_profile_words() {
	local rest words
	while IFS= read -r rest; do
		read -r -a words <<<"$rest"
		[ ${#words[@]} -eq 0 ] || printf '%s\n' "${words[@]}"
	done < <(ai__profile_rest "$@")
}

# Does PROFILE (default the active one) carry a KEY line (a bare `mcp` line counts: it names none)?
# Usage: ai_profile_has KEY [PROFILE]
ai_profile_has() {
	local file line key profile=${2:-${AI_PROFILE:-}}
	[ -n "$profile" ] || return 1
	file=$(aiprof__conf) || return 1
	while IFS= read -r line; do
		read -r key _ <<<"$line"
		foundation_ieq "$key" "$1" && return 0
	done < <(conf_section "$file" "$profile")
	return 1
}

# The rest of the last KEY line of PROFILE (default the active one); fails without one.
# Usage: ai_profile_value KEY [PROFILE]
ai_profile_value() {
	local value found=1 rest
	while IFS= read -r rest; do
		value=$rest
		found=0
	done < <(ai__profile_rest "$@")
	[ "$found" -eq 0 ] || return 1
	printf '%s' "$value"
}

# The words of every KEY line before the first section (shared, default-owner, ...), one per line.
# Usage: ai_profiles_top_words KEY
ai_profiles_top_words() {
	local file line key rest words
	file=$(aiprof__conf) || return 0
	while IFS= read -r line; do
		read -r key rest <<<"$line"
		foundation_ieq "$key" "$1" || continue
		read -r -a words <<<"$rest"
		[ ${#words[@]} -eq 0 ] || printf '%s\n' "${words[@]}"
	done < <(conf_lines "$file")
}

# The default owner: the last `default-owner PROFILE` line; empty without one.
ai_profiles_default_owner() {
	local file value
	file=$(aiprof__conf) || return 0
	value=$(conf_value "$file" default-owner 2>/dev/null) || return 0
	read -r value _ <<<"$value"
	printf '%s' "$value"
}

# The Plan of PROFILE (default the active one): its display name on the first line, then each org
# UUID on a line of its own; nothing without a plan line (the last one wins).
# Usage: ai_profile_plan [PROFILE]
ai_profile_plan() {
	local value words
	value=$(ai_profile_value plan "${1:-}") || return 0
	read -r -a words <<<"$value"
	[ ${#words[@]} -eq 0 ] || printf '%s\n' "${words[@]}"
}

# Is unattended on for PROFILE (default the active one)? `unattended on` (or yes, true, 1); off
# without the line. Usage: ai_profile_unattended [PROFILE]
ai_profile_unattended() {
	local value
	value=$(ai_profile_value unattended "${1:-}") || return 1
	read -r value _ <<<"$value"
	case $(foundation_lower "$value") in on | yes | true | 1) return 0 ;; esac
	return 1
}

# The ai-profile.conf the deploy writes next to the managed settings copy (the ownership guard
# and the rules item's hooks read it): the active profile, the default owner, unattended, the Plan,
# the shared patterns, every profile's `owns` patterns and the active profile's `autonomous` ones.
# Usage: ai_profile_conf_text
ai_profile_conf_text() {
	local owner plan pattern profile
	[ -n "${AI_PROFILE:-}" ] || return 1
	printf '# Written by Deploy-AiArtifacts from the AI profile configuration; do not edit.\n'
	printf 'profile %s\n' "$AI_PROFILE"
	owner=$(ai_profiles_default_owner)
	# Spelled as its section, since the guard compares profile names exactly.
	[ -z "$owner" ] || owner=$(conf_section_name "$(aiprof__conf)" "$owner") || owner=$(ai_profiles_default_owner)
	[ -z "$owner" ] || printf 'default-owner %s\n' "$owner"
	if ai_profile_unattended; then printf 'unattended on\n'; else printf 'unattended off\n'; fi
	plan=$(ai_profile_plan | paste -sd' ' -)
	[ -z "$plan" ] || printf 'plan %s\n' "$plan"
	while IFS= read -r pattern; do
		[ -n "$pattern" ] && printf 'shared %s\n' "$pattern"
	done < <(ai_profiles_top_words shared)
	while IFS= read -r profile; do
		[ -n "$profile" ] || continue
		while IFS= read -r pattern; do
			[ -n "$pattern" ] && printf 'owns %s %s\n' "$profile" "$pattern"
		done < <(ai_profile_words owns "$profile")
	done < <(ai_profiles)
	while IFS= read -r pattern; do
		[ -n "$pattern" ] && printf 'autonomous %s\n' "$pattern"
	done < <(ai_profile_words autonomous)
	return 0
}

# The organization Claude Code is signed in to: UUID<TAB>NAME from the oauthAccount block of
# ${CLAUDE_CONFIG_DIR:-~}/.claude.json (organizationUuid, organizationName; undocumented, read
# only). Fails when there is none, or no python3. Usage: ai_logged_in_org
ai_logged_in_org() {
	command -v python3 >/dev/null 2>&1 || return 1
	python3 - "${CLAUDE_CONFIG_DIR:-$HOME}/.claude.json" <<'PY'
import json, sys
try:
    with open(sys.argv[1], encoding="utf-8") as handle:
        account = json.load(handle).get("oauthAccount") or {}
except (OSError, ValueError, AttributeError):
    sys.exit(1)
uuid = account.get("organizationUuid") if isinstance(account, dict) else None
if not isinstance(uuid, str) or not uuid:
    sys.exit(1)
name = account.get("organizationName")
print(f"{uuid}\t{name if isinstance(name, str) else ''}")
PY
}

# The managed settings copy rendered from a rules item's managed-settings.json, on stdout: the
# token {ManagedDir} becomes DIR (forward slashes); with a profile active, forceLoginOrgUUID is set
# from its Plan (one UUID as a string, several as an array) and the ownership guard is appended to
# hooks.UserPromptSubmit and hooks.PreToolUse (matcher *) as bash "DIR/ai-ownership-guard.sh"
# EVENT. Without a profile only the token changes. Fails (python3 missing, a file that does not
# parse, a plan line without a valid UUID) with the reason on stderr; the deploy then leaves the
# deployed copy as it is. Usage: ai_render_managed_settings SOURCE DIR
ai_render_managed_settings() {
	local uuids='' planned=''
	command -v python3 >/dev/null 2>&1 || {
		printf 'python3 is required to render the managed settings\n' >&2
		return 1
	}
	if [ -n "${AI_PROFILE:-}" ]; then
		uuids=$(ai_profile_plan | sed 1d | paste -sd' ' -)
		[ -z "$(ai_profile_plan)" ] || planned=1
	fi
	python3 - "$1" "$2" "${AI_PROFILE:+1}" "$uuids" "$planned" <<'PY'
import json, re, sys

source, directory, profiled, uuids = sys.argv[1], sys.argv[2].replace("\\", "/").rstrip("/"), sys.argv[3] == "1", sys.argv[4].split()
planned = sys.argv[5] == "1"
# A plan line that names no valid UUID fails closed: a copy without the pin would let any Plan sign
# in, so the deployed copy is left as it is instead.
if profiled and planned:
    shape = re.compile(r"^[0-9A-Fa-f]{8}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{4}-[0-9A-Fa-f]{12}$")
    bad = [uuid for uuid in uuids if not shape.match(uuid)]
    if bad or not uuids:
        print(f"The AI profile's plan line names no valid org UUID ({' '.join(bad) or 'none'}); the managed settings would carry no Plan pin", file=sys.stderr)
        sys.exit(1)
    uuids = [uuid.lower() for uuid in uuids]
try:
    with open(source, encoding="utf-8") as handle:
        text = handle.read()
except OSError as error:
    print(f"{source} cannot be read: {error}", file=sys.stderr)
    sys.exit(1)
# The token sits inside JSON strings: the folder is escaped as a string body would be.
text = text.replace("{ManagedDir}", json.dumps(directory)[1:-1])
try:
    document = json.loads(text) if text.strip() else {}
except ValueError as error:
    print(f"{source} does not parse: {error}", file=sys.stderr)
    sys.exit(1)
if not isinstance(document, dict):
    print(f"The top level of {source} is not a JSON object", file=sys.stderr)
    sys.exit(1)
if profiled:
    if uuids:
        document["forceLoginOrgUUID"] = uuids[0] if len(uuids) == 1 else uuids
    hooks = document.get("hooks")
    if not isinstance(hooks, dict):
        hooks = {}
    guard = f'bash "{directory}/ai-ownership-guard.sh"'
    for event, entry in (
        ("UserPromptSubmit", {"hooks": [{"type": "command", "command": f"{guard} UserPromptSubmit"}]}),
        ("PreToolUse", {"matcher": "*", "hooks": [{"type": "command", "command": f"{guard} PreToolUse"}]}),
    ):
        entries = hooks.get(event)
        if not isinstance(entries, list):
            entries = []
        if entry not in entries:
            entries.append(entry)
        hooks[event] = entries
    document["hooks"] = hooks
sys.stdout.write(json.dumps(document, indent="\t", ensure_ascii=False) + "\n")
PY
}
