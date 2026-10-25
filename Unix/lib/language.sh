# shellcheck shell=bash
# Display language, locale and keyboard layout sets - the DisplayLanguages, Locales,
# KeyboardLayouts and KeyboardLayoutSets of Windows, read from Unix/config/language.conf by
# Display-SystemLanguageSettings, Set-DisplayLanguage, Set-Locale and Set-KeyboardLayouts. Needs
# lib/config.sh.

# The entries of KIND (display-language, locale, keyboard-layout, keyboard-set) as NAME<TAB>VALUE
# lines in the order the names first appear; a later line for the same name (case-insensitive)
# replaces the value, so the overlay can change a base entry. VALUE is the rest of the line (the
# layouts of a set, space-separated). Usage: lang_entries KIND
lang_entries() {
	local file
	file=$(conf_path language.conf) || return 0
	conf_lines "$file" | awk -v k="$1" '
		tolower($1) == k && NF >= 3 {
			key = tolower($2)
			if (!(key in value)) order[++n] = key
			name[key] = $2
			rest = $0; sub(/^[[:space:]]*[^[:space:]]+[[:space:]]+[^[:space:]]+[[:space:]]+/, "", rest)
			value[key] = rest
		}
		END { for (i = 1; i <= n; i++) printf "%s\t%s\n", name[order[i]], value[order[i]] }
	'
}

# The entry NAME of KIND (case-insensitive) as NAME<TAB>VALUE, NAME as configured; fails when
# there is none. Usage: lang_entry KIND NAME
lang_entry() {
	lang_entries "$1" | awk -F'\t' -v n="$(foundation_lower "$2")" 'tolower($1) == n { print; found = 1; exit } END { exit !found }'
}

# The default-KIND name (default-display-language, default-locale, default-keyboard-set); empty
# when it is not set. Usage: lang_default KIND
lang_default() {
	local file
	file=$(conf_path language.conf) || return 0
	conf_value "$file" "default-$1" 2>/dev/null || true
}

# The display languages macOS uses, in order (AppleLanguages), one per line.
lang_current_languages() {
	defaults read -g AppleLanguages 2>/dev/null | tr -d ' \t"(),' | grep .
}

# The AppleLocale value (en_US@rg=hrzzzz); empty when unset.
lang_current_locale() {
	defaults read -g AppleLocale 2>/dev/null || true
}

# The region of an AppleLocale value, uppercase: the @rg= override when there is one (hrzzzz is
# HR), the country of the locale otherwise (en_US is US). Usage: lang_locale_region LOCALE
lang_locale_region() {
	local locale=$1 region
	case $locale in
		*@rg=*)
			region=${locale#*@rg=}
			region=${region%%[;@]*}
			region=${region:0:2}
			;;
		*_*)
			region=${locale#*_}
			region=${region%%[@.]*}
			;;
		*) region='' ;;
	esac
	printf '%s' "$region" | tr '[:lower:]' '[:upper:]'
}

# The region of a configured locale CODE, uppercase (hr-HR is HR). Usage: lang_code_region CODE
lang_code_region() {
	local code=${1//_/-}
	case $code in *-*) code=${code##*-} ;; *) code='' ;; esac
	printf '%s' "$code" | tr '[:lower:]' '[:upper:]'
}

# The language part of an AppleLocale value (en_US@rg=hrzzzz is en_US).
# Usage: lang_locale_language LOCALE
lang_locale_language() {
	printf '%s' "${1%%@*}"
}

# An AppleLocale value for language LANGUAGE (en_US or en-US) with formats of REGION (HR): the
# language alone when its own country is that region, LANGUAGE@rg=<region>zzzz otherwise, as
# System Settings writes it. Usage: lang_build_locale LANGUAGE REGION
lang_build_locale() {
	local language=${1//-/_} region country
	region=$(printf '%s' "$2" | tr '[:upper:]' '[:lower:]')
	country=''
	case $language in *_*) country=$(printf '%s' "${language#*_}" | tr '[:upper:]' '[:lower:]') ;; esac
	if [ -z "$region" ] || [ "$country" = "$region" ]; then
		printf '%s' "$language"
	else
		printf '%s@rg=%szzzz' "$language" "$region"
	fi
}

# The entry of KIND to apply, as NAME<TAB>VALUE: NAME when it is given (fails when language.conf
# has no such entry), otherwise a menu of the entries TITLE heads, where Enter picks the
# default-KIND entry. Fails when the menu cannot be shown or nothing is picked.
# Usage: lang_choose KIND TITLE [NAME]
lang_choose() {
	local kind=$1 title=$2 name=${3:-} default options=() entry_name _value choice
	if [ -n "$name" ]; then
		lang_entry "$kind" "$name" || {
			log_error "No $kind [$name] in language.conf"
			return 1
		}
		return 0
	fi
	while IFS=$'\t' read -r entry_name _value; do options+=("$entry_name"); done < <(lang_entries "$kind")
	default=$(lang_default "$kind")
	choice=$(foundation_resolve_selection "$title" "Select one or press [Enter] for the default => ${default:-none}" 1 0 "${options[@]}") || return 1
	[ -n "$choice" ] || choice=$default
	[ -n "$choice" ] || {
		log_error "Nothing selected and no default-$kind in language.conf"
		return 1
	}
	lang_entry "$kind" "$choice" || {
		log_error "No $kind [$choice] in language.conf (default-$kind)"
		return 1
	}
}
