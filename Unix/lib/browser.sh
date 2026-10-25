# shellcheck shell=bash
# Browser groups (config/browser-groups.conf) - Find-BrowserGroup and Collect-BrowserUrls.

# Prints the group's display name on the first line, then its URLs in file order.
# Lookup: exact dotted section path, then the last segment of any section, then a named URL.
# Reads the effective file (conf_effective): the .local overlay and @TYPE lines apply.
# Usage: browser_group_urls NAME
browser_group_urls() {
	local file
	file=$(conf_path browser-groups.conf) || return 1
	awk -v want="$(foundation_lower "$1")" '
		/^[[:space:]]*(#|$)/ { next }
		/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
			s = $0; sub(/^[[:space:]]*\[/, "", s); sub(/\][[:space:]]*$/, "", s)
			nsec++; secname[nsec] = s; section = nsec; next
		}
		{
			n++; line_sec[n] = section
			if (NF >= 2) { line_name[n] = $1; line_url[n] = $2 } else { line_name[n] = ""; line_url[n] = $1 }
		}
		END {
			target = ""
			for (i = 1; i <= nsec; i++) if (tolower(secname[i]) == want) { target = secname[i]; break }
			if (target == "") {
				for (i = 1; i <= nsec; i++) {
					k = split(secname[i], seg, ".")
					if (tolower(seg[k]) == want) { target = secname[i]; break }
				}
			}
			if (target != "") {
				print target
				t = tolower(target)
				for (j = 1; j <= n; j++) {
					s = tolower(secname[line_sec[j]])
					if (s == t || index(s, t ".") == 1) print line_url[j]
				}
				exit 0
			}
			for (j = 1; j <= n; j++) if (tolower(line_name[j]) == want) { print line_name[j]; print line_url[j]; exit 0 }
			exit 1
		}' < <(conf_effective "$file")
}

# The entry of PROJECT in the [Swagger] group (Resolve-SwaggerBrowserGroup): prints
# "NAME<TAB>URL" for the named line whose name equals the project, case-insensitive.
browser_swagger_entry() {
	local file
	file=$(conf_path browser-groups.conf) || return 1
	awk -v want="$(foundation_lower "$1")" '
		/^[[:space:]]*\[[^]]+\][[:space:]]*$/ { s = tolower($0); inside = (s ~ /^[[:space:]]*\[swagger\][[:space:]]*$/); next }
		inside && NF >= 2 && tolower($1) == want { printf "%s\t%s\n", $1, $2; found = 1; exit }
		END { exit found ? 0 : 1 }' < <(conf_effective "$file")
}

# The group tree for the Open-Browser menu (foundation_resolve_tree_selection), the -GroupsConfig
# menu of Windows: every section as its dotted path, each followed by its named URLs (a leaf
# "PATH.NAME<TAB>NAME", which Open-Browser opens alone) and then its nested sections, depth first
# in file order, so a nested section listed further down the file still sits under its parent. A
# nested section whose parent has no section of its own gets that parent as a node.
# Reads the effective file. Usage: browser_menu_nodes
browser_menu_nodes() {
	local file
	file=$(conf_path browser-groups.conf) || return 0
	awk '
		/^[[:space:]]*(#|$)/ { next }
		/^[[:space:]]*\[[^]]+\][[:space:]]*$/ {
			s = $0; sub(/^[[:space:]]*\[/, "", s); sub(/\][[:space:]]*$/, "", s)
			add(s); section = s; next
		}
		NF >= 2 && section != "" { leaves[section] = leaves[section] $1 "\n" }
		function add(path,   parent) {
			if (path in known) return
			parent = path; sub(/\.[^.]*$/, "", parent)
			if (parent != path) add(parent)
			known[path] = 1; order[++n] = path
			if (parent != path) kids[parent] = kids[parent] path "\n"
		}
		function walk(path,   k, i, list, name) {
			print path
			k = split(leaves[path], list, "\n")
			for (i = 1; i < k; i++) { name = list[i]; gsub(/\./, "_", name); printf "%s.%s\t%s\n", path, name, list[i] }
			k = split(kids[path], list, "\n")
			for (i = 1; i < k; i++) walk(list[i])
		}
		END { for (i = 1; i <= n; i++) if (index(order[i], ".") == 0) walk(order[i]) }' < <(conf_effective "$file")
}

# Top-level group names, for menus and "available" hints.
browser_top_groups() {
	local file
	file=$(conf_path browser-groups.conf) || return 0
	conf_sections "$file" | grep -v '\.'
}

# QUERY encoded for a URL's query string, as HttpUtility.UrlEncode does on Windows: letters,
# digits and `-_.~` stay, a space becomes `+`, every other byte (`+`, `&`, `?`, `=`, `/`, UTF-8)
# becomes `%XX`, so `c++` searches for c++. Usage: browser_url_encode QUERY
browser_url_encode() {
	printf '%s' "$1" | LC_ALL=C od -An -v -tx1 | awk '
		BEGIN { for (i = 32; i < 127; i++) chr[sprintf("%02x", i)] = sprintf("%c", i) }
		{
			for (i = 1; i <= NF; i++) {
				h = tolower($i)
				if (h == "20") out = out "+"
				else if ((h in chr) && chr[h] ~ /[A-Za-z0-9._~-]/) out = out chr[h]
				else out = out "%" toupper(h)
			}
		}
		END { printf "%s", out }'
}

# "HOST<TAB>PORT" of URL: the port written in it, else 443 for https and 80 for http; an IPv6
# literal loses its brackets. Fails for a URL without a host. Usage: browser_url_host_port URL
browser_url_host_port() {
	local rest=$1 scheme='' host port=''
	case $rest in *://*)
		scheme=$(foundation_lower "${rest%%://*}")
		rest=${rest#*://}
		;;
	esac
	rest=${rest%%[/?#]*}
	rest=${rest##*@}
	case $rest in
		\[*\]*)
			host=${rest#\[}
			host=${host%%\]*}
			case $rest in *\]:*) port=${rest##*\]:} ;; esac
			;;
		*:*)
			host=${rest%%:*}
			port=${rest#*:}
			;;
		*) host=$rest ;;
	esac
	[ -n "$host" ] || return 1
	if [ -z "$port" ]; then
		case $scheme in http) port=80 ;; *) port=443 ;; esac
	fi
	printf '%s\t%s\n' "$host" "$port"
}

# Does URL point at this machine (host localhost or 127.0.0.1, the Get-SwaggerCloseTitlePatterns
# rule of Windows)? Usage: browser_url_is_localhost URL
browser_url_is_localhost() {
	local host
	host=$(browser_url_host_port "$1") || return 1
	host=$(foundation_lower "${host%%$'\t'*}")
	[ "$host" = localhost ] || [ "$host" = 127.0.0.1 ]
}
