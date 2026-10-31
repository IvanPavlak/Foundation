# shellcheck shell=bash
# Workspace definitions of config/workspaces.conf: templates and project scopes - the
# Resolve-WorkspaceTemplate and Resolve-WorkspaceActions of Windows. Needs lib/config.sh.
#
# A workspace section is either a plain action list or a template instance:
#
#   [Dotfiles]                      [MyProject]
#   template Project                template Project
#                                   set Repository MyProject
#
# A template is a section of config/workspace-templates.conf: `var NAME [DEFAULT...]` lines and
# action lines, each optionally named `:ID` (a stable handle for replace, drop and add):
#
#   [Project]
#   var Repository {Workspace}Repository
#   :project Open-Project {Workspace}
#   Open-Browser {Repository} AI YouTube
#   Set-WorkspaceWindowLayout {Workspace}
#
# An instance takes only these lines, applied in this order:
#   template NAME                   the template it stamps out under its own name
#   set NAME VALUE...               a variable value (declares it when the template does not)
#   replace KEY LINE                swaps the whole action KEY (an :ID, else a unique action name)
#   drop KEY                        removes the action KEY
#   add [before|after KEY] LINE     inserts LINE; bare, just before the template's first
#                                   Set-WorkspaceWindowLayout (the end when there is none)
# @TYPE lines are filtered before anything else, in the template and the instance alike, so a
# replace, drop or add anchored on a machine-specific template line carries the same @TYPE.
# Variables are substituted last, over the final list: {Workspace} is built in (plain workspaces
# get it too), defaults may use it and other variables (a cycle is an error), the command line
# beats `set`, `set` beats the default. In an instance, an unknown {X} or a variable without a
# value is an error, and the workspace resolves to nothing - Open-Workspace opens nothing for it.
#
# Any workspace line (plain, template or added) may start with a project scope, after the @TYPE
# machine prefix and the :ID: `+A,B LINE` runs only when one of A, B is among the open's projects,
# `+!A,B LINE` only when none of them is (the Project scope of Windows; machine variation stays
# with @TYPE lines). Project names compare case-insensitively.
#
# A line may also start with a layout-set scope, before any project scope: `%Laptop LINE` (or
# `%Laptop,Work LINE`) runs only when the layout set this machine applies (layout_type: the
# layout-override, else the small-display set, else the machine type) is one of them - the
# LayoutMachine of Windows, so an action can follow the layout actually applied where @TYPE follows
# the machine type: `%Work Open-Browser --no-menu --instances 2`.
#
# The pure helpers run under bash 3.2 too (no associative arrays), like the rest of lib/.

# Names a template cannot declare: the engine tokens Open-Workspace resolves later.
workspace__reserved=' workspace selectedprojects projectname '
workspace__token_re='\{([A-Za-z][A-Za-z0-9_]*)\}'

# Path of the template file, fails when there is none.
workspace_templates_file() {
	conf_path workspace-templates.conf
}

# Is the section NAME of FILE a template instance? Usage: workspace_is_templated FILE NAME
workspace_is_templated() {
	conf_section "$1" "$2" 2>/dev/null | grep -qE '^template([[:space:]]|$)'
}

# The action word of a line, past an optional +scope. Usage: workspace_action_name LINE
workspace_action_name() {
	local line=$1
	case $line in %*) line=$(foundation_trim "${line#*[[:space:]]}") ;; esac
	case $line in +*) line=${line#*[[:space:]]} ;; esac
	line=$(foundation_trim "$line")
	printf '%s' "${line%%[[:space:]]*}"
}

workspace__error() {
	local message=$1 existing
	for existing in ${WORKSPACE_ERRORS[@]+"${WORKSPACE_ERRORS[@]}"}; do
		[ "$existing" = "$message" ] && return 0
	done
	WORKSPACE_ERRORS+=("$message")
}

# Index of variable NAME in workspace__var_names (case-insensitive), empty when undeclared.
workspace__var_index() {
	local i
	for ((i = 0; i < ${#workspace__var_names[@]}; i++)); do
		if foundation_ieq "${workspace__var_names[i]}" "$1"; then
			printf '%s' "$i"
			return 0
		fi
	done
	return 1
}

# Declares or sets a variable. Usage: workspace__var_put NAME HAS-VALUE VALUE
workspace__var_put() {
	local index
	if index=$(workspace__var_index "$1"); then
		workspace__var_has[index]=$2
		workspace__var_values[index]=$3
	else
		workspace__var_names+=("$1")
		workspace__var_has+=("$2")
		workspace__var_values+=("$3")
	fi
}

# Substitutes every {Name} of TEXT into WORKSPACE__OUT (a global, so errors collect here and not
# in a subshell). Usage: workspace__expand TEXT WHERE [DEPTH]
workspace__expand() {
	local text=$1 where=$2 depth=${3:-0} out='' token name index lower
	while [[ $text =~ $workspace__token_re ]]; do
		token=${BASH_REMATCH[0]}
		name=${BASH_REMATCH[1]}
		out+=${text%%"$token"*}
		text=${text#*"$token"}
		if foundation_ieq "$name" Workspace; then
			out+=$workspace__name
			continue
		fi
		if index=$(workspace__var_index "$name"); then
			if [ "${workspace__var_has[index]}" != 1 ]; then
				workspace__error "variable [$name] is used but has no value - set it with a set line or on the command line (--$name VALUE)"
				out+=$token
			elif [ "$depth" -ge 8 ]; then
				workspace__error "variable [$name] references itself (a cycle through its default)"
				out+=$token
			else
				workspace__expand "${workspace__var_values[index]}" "variable [$name]" $((depth + 1))
				out+=$WORKSPACE__OUT
			fi
			continue
		fi
		lower=$(foundation_lower "$name")
		case $workspace__reserved in *" $lower "*) ;; *)
			[ "$workspace__strict" = 1 ] &&
				workspace__error "unknown placeholder {$name} in $where - declare it with a var line in the template or a set line in the workspace"
			;;
		esac
		out+=$token
	done
	WORKSPACE__OUT=$out$text
}

# Index of the action KEY in the working list: an :ID first, then a unique action name.
# Prints the index; fails with status 1 when nothing matches, 2 when the name is ambiguous.
workspace__target() {
	local key=$1 i hits=0 hit=''
	for ((i = 0; i < ${#workspace__lines[@]}; i++)); do
		if [ -n "${workspace__ids[i]}" ] && foundation_ieq "${workspace__ids[i]}" "$key"; then
			printf '%s' "$i"
			return 0
		fi
	done
	for ((i = 0; i < ${#workspace__lines[@]}; i++)); do
		if foundation_ieq "$(workspace_action_name "${workspace__lines[i]}")" "$key"; then
			hits=$((hits + 1))
			hit=$i
		fi
	done
	[ "$hits" -eq 1 ] && {
		printf '%s' "$hit"
		return 0
	}
	[ "$hits" -eq 0 ] && return 1
	return 2
}

# Inserts LINE (ID, FROM-TEMPLATE) at POSITION of the working list.
workspace__insert() { # POSITION LINE ID FROM-TEMPLATE
	local position=$1 i
	local lines=() ids=() origin=()
	for ((i = 0; i < ${#workspace__lines[@]}; i++)); do
		if [ "$i" -eq "$position" ]; then
			lines+=("$2")
			ids+=("$3")
			origin+=("$4")
		fi
		lines+=("${workspace__lines[i]}")
		ids+=("${workspace__ids[i]}")
		origin+=("${workspace__origin[i]}")
	done
	if [ "$position" -ge "${#workspace__lines[@]}" ]; then
		lines+=("$2")
		ids+=("$3")
		origin+=("$4")
	fi
	workspace__lines=(${lines[@]+"${lines[@]}"})
	workspace__ids=(${ids[@]+"${ids[@]}"})
	workspace__origin=(${origin[@]+"${origin[@]}"})
}

workspace__remove() { # POSITION
	local i lines=() ids=() origin=()
	for ((i = 0; i < ${#workspace__lines[@]}; i++)); do
		[ "$i" -eq "$1" ] && continue
		lines+=("${workspace__lines[i]}")
		ids+=("${workspace__ids[i]}")
		origin+=("${workspace__origin[i]}")
	done
	workspace__lines=(${lines[@]+"${lines[@]}"})
	workspace__ids=(${ids[@]+"${ids[@]}"})
	workspace__origin=(${origin[@]+"${origin[@]}"})
}

# Resolves workspace NAME of FILE into globals, never printing:
#   WORKSPACE_LINES      the action lines to run, :ID removed, +scope kept (see workspace_for_projects)
#   WORKSPACE_ERRORS     one message per problem; non-empty means WORKSPACE_LINES is empty
#   WORKSPACE_TEMPLATE   the template name ('' for a plain workspace)
#   WORKSPACE_VARIABLES  the variables the template and the instance declare
#   WORKSPACE_APPLIED    the KEY=VALUE arguments whose KEY was a variable (compared without dashes
#                        and case, so --my-var and -MyVar both set MyVar); the others are ignored,
#                        so a caller can hand over every extra flag and forward the rest
# Fails when the section does not exist or has errors.
# Usage: workspace_resolve FILE NAME [KEY=VALUE...]
workspace_resolve() {
	local file=$1 name=$2 raw line kind rest key value index tfile traw i position anchor where
	shift 2
	WORKSPACE_LINES=()
	WORKSPACE_ERRORS=()
	WORKSPACE_TEMPLATE=''
	WORKSPACE_VARIABLES=()
	WORKSPACE_APPLIED=()
	workspace__name=$name
	workspace__strict=0
	workspace__var_names=()
	workspace__var_has=()
	workspace__var_values=()
	workspace__lines=()
	workspace__ids=()
	workspace__origin=()

	raw=$(conf_section "$file" "$name") || {
		workspace__error "no section [$name]"
		return 1
	}
	if ! workspace_is_templated "$file" "$name"; then
		# Plain: only {Workspace}; any other brace text is left for the engine or the action.
		while IFS= read -r line; do
			[ -n "$line" ] || continue
			workspace__expand "$line" "[$(workspace_action_name "$line")]"
			WORKSPACE_LINES+=("$WORKSPACE__OUT")
		done <<<"$raw"
		return 0
	fi

	workspace__strict=1
	local instance=()
	while IFS= read -r line; do
		[ -n "$line" ] || continue
		read -r kind rest <<<"$line"
		case $kind in
			template)
				if [ -n "$WORKSPACE_TEMPLATE" ]; then
					workspace__error "names more than one template"
				else
					WORKSPACE_TEMPLATE=$rest
				fi
				;;
			set | replace | drop | add) instance+=("$line") ;;
			*) workspace__error "a templated workspace takes template, set, replace, drop and add lines, not [$line] - put actions in the template or add them with an add line" ;;
		esac
	done <<<"$raw"
	[ -n "$WORKSPACE_TEMPLATE" ] || workspace__error "the template line names no template"

	if [ -n "$WORKSPACE_TEMPLATE" ]; then
		if ! tfile=$(workspace_templates_file); then
			workspace__error "uses template [$WORKSPACE_TEMPLATE] but there is no config/workspace-templates.conf"
		elif ! traw=$(conf_section "$tfile" "$WORKSPACE_TEMPLATE"); then
			workspace__error "unknown template [$WORKSPACE_TEMPLATE] (workspace-templates.conf defines: $(conf_sections "$tfile" | tr '\n' ' ' | sed 's/ $//' | sed 's/ /, /g'))"
		else
			WORKSPACE_TEMPLATE=$(conf_section_name "$tfile" "$WORKSPACE_TEMPLATE")
			while IFS= read -r line; do
				[ -n "$line" ] || continue
				read -r kind rest <<<"$line"
				if [ "$kind" = var ]; then
					read -r key value <<<"$rest"
					if [ -z "$key" ]; then
						workspace__error "template [$WORKSPACE_TEMPLATE] has a var line without a name"
						continue
					fi
					case $workspace__reserved in *" $(foundation_lower "$key") "*)
						workspace__error "template [$WORKSPACE_TEMPLATE] declares the reserved name [$key] (Workspace, SelectedProjects and ProjectName are engine names)"
						continue
						;;
					esac
					if [ -n "$value" ]; then workspace__var_put "$key" 1 "$value"; else workspace__var_put "$key" 0 ''; fi
					continue
				fi
				key=''
				case $kind in
					:?*)
						key=${kind#:}
						line=$(foundation_trim "$rest")
						;;
				esac
				if [ -z "$line" ]; then
					workspace__error "template [$WORKSPACE_TEMPLATE] has an :$key with no action"
					continue
				fi
				for ((i = 0; i < ${#workspace__ids[@]}; i++)); do
					[ -n "$key" ] && foundation_ieq "${workspace__ids[i]}" "$key" && workspace__error "template [$WORKSPACE_TEMPLATE] uses the id [:$key] more than once"
				done
				workspace__lines+=("$line")
				workspace__ids+=("$key")
				workspace__origin+=(1)
			done <<<"$traw"
		fi
	fi

	# Values: the instance's set lines, then the command line.
	for line in ${instance[@]+"${instance[@]}"}; do
		read -r kind key value <<<"$line"
		[ "$kind" = set ] || continue
		if [ -z "$key" ]; then
			workspace__error "has a set line without a name"
			continue
		fi
		case $workspace__reserved in *" $(foundation_lower "$key") "*)
			workspace__error "sets the reserved name [$key] (Workspace, SelectedProjects and ProjectName are engine names)"
			continue
			;;
		esac
		workspace__var_put "$key" 1 "$value"
	done
	# shellcheck disable=SC2034 # read by the callers (Open-Workspace, Test-ConfigurationSchema)
	WORKSPACE_VARIABLES=(${workspace__var_names[@]+"${workspace__var_names[@]}"})
	local argument wanted
	for argument in "$@"; do
		key=${argument%%=*}
		value=${argument#*=}
		wanted=$(printf '%s' "$key" | tr -d '-' | tr '[:upper:]' '[:lower:]')
		for ((i = 0; i < ${#workspace__var_names[@]}; i++)); do
			[ "$(printf '%s' "${workspace__var_names[i]}" | tr -d '-' | tr '[:upper:]' '[:lower:]')" = "$wanted" ] || continue
			workspace__var_has[i]=1
			workspace__var_values[i]=$value
			WORKSPACE_APPLIED+=("$argument")
		done
	done

	if [ ${#WORKSPACE_ERRORS[@]} -gt 0 ]; then
		return 1
	fi

	# replace and drop, in the order written.
	local status
	for line in ${instance[@]+"${instance[@]}"}; do
		read -r kind key rest <<<"$line"
		case $kind in replace | drop) ;; *) continue ;; esac
		if [ -z "$key" ]; then
			workspace__error "has a $kind line without an action"
			continue
		fi
		index=$(workspace__target "$key")
		status=$?
		if [ "$status" -eq 1 ]; then
			workspace__error "$kind [$key] matches no action of template [$WORKSPACE_TEMPLATE]"
			continue
		elif [ "$status" -eq 2 ]; then
			workspace__error "$kind [$key] matches several actions of template [$WORKSPACE_TEMPLATE] - give them an :ID in the template and $kind by it"
			continue
		fi
		if [ "$kind" = drop ]; then
			workspace__remove "$index"
		elif [ -z "$rest" ]; then
			workspace__error "replace [$key] has no new line - drop it instead"
		else
			workspace__lines[index]=$rest
		fi
	done

	# add, in the order written.
	for line in ${instance[@]+"${instance[@]}"}; do
		read -r kind rest <<<"$line"
		[ "$kind" = add ] || continue
		read -r where anchor value <<<"$rest"
		case $where in
			before | after)
				if [ -z "$value" ]; then
					workspace__error "add $where [$anchor] has no line to add"
					continue
				fi
				index=$(workspace__target "$anchor")
				status=$?
				if [ "$status" -eq 1 ]; then
					workspace__error "add $where [$anchor] matches no action of the workspace"
					continue
				elif [ "$status" -eq 2 ]; then
					workspace__error "add $where [$anchor] matches several actions - give the template action an :ID and anchor on it"
					continue
				fi
				position=$index
				[ "$where" = after ] && position=$((index + 1))
				workspace__insert "$position" "$value" '' 0
				;;
			'')
				workspace__error "has an add line without a line to add"
				;;
			*)
				position=${#workspace__lines[@]}
				for ((i = 0; i < ${#workspace__lines[@]}; i++)); do
					if [ "${workspace__origin[i]}" = 1 ] && [ "$(workspace_action_name "${workspace__lines[i]}")" = Set-WorkspaceWindowLayout ]; then
						position=$i
						break
					fi
				done
				workspace__insert "$position" "$rest" '' 0
				;;
		esac
	done

	# Variables over the final list only: a dropped or replaced action never reports a placeholder
	# it no longer has.
	local expanded=()
	for ((i = 0; i < ${#workspace__lines[@]}; i++)); do
		workspace__expand "${workspace__lines[i]}" "[$(workspace_action_name "${workspace__lines[i]}")]"
		expanded+=("$WORKSPACE__OUT")
	done
	if [ ${#WORKSPACE_ERRORS[@]} -gt 0 ]; then
		return 1
	fi
	WORKSPACE_LINES=(${expanded[@]+"${expanded[@]}"})
	return 0
}

# Prints the resolved lines of workspace NAME, or its errors (one per line, on stderr) and fails.
# Usage: workspace_lines FILE NAME [KEY=VALUE...]
workspace_lines() {
	local message
	if workspace_resolve "$@"; then
		[ ${#WORKSPACE_LINES[@]} -gt 0 ] && printf '%s\n' "${WORKSPACE_LINES[@]}"
		return 0
	fi
	for message in "${WORKSPACE_ERRORS[@]}"; do printf '%s\n' "$message" >&2; done
	return 1
}

# The project scope of a line, as "+A,B" / "+!A,B" (empty without one). Usage: workspace_scope LINE
workspace_scope() {
	case $1 in +*) printf '%s' "${1%%[[:space:]]*}" ;; esac
}

# Project-scope filter for lines on stdin: a line whose +scope does not fit the PROJECTS is
# dropped, the others are printed without their scope. With no project, only +! lines and
# unscoped ones run. Usage: ... | workspace_for_projects [PROJECT...]
workspace_for_projects() {
	local line scope negate list hit project token tokens
	while IFS= read -r line; do
		case $line in
			+*) ;;
			*)
				printf '%s\n' "$line"
				continue
				;;
		esac
		scope=${line%%[[:space:]]*}
		line=$(foundation_trim "${line#"$scope"}")
		list=${scope#+}
		negate=0
		case $list in !*)
			negate=1
			list=${list#!}
			;;
		esac
		hit=0
		IFS=, read -r -a tokens <<<"$list"
		for token in ${tokens[@]+"${tokens[@]}"}; do
			for project in "$@"; do
				foundation_ieq "$token" "$project" && hit=1
			done
		done
		[ "$hit" -ne "$negate" ] && printf '%s\n' "$line"
	done
	return 0
}

# The project names a +scope lists (without + and !), one per line. Usage: workspace_scope_projects SCOPE
workspace_scope_projects() {
	local list=${1#+}
	list=${list#!}
	printf '%s\n' "$list" | tr ',' '\n' | grep -v '^$'
}

# The layout-set scope of a line, as "%A,B" (empty without one). Usage: workspace_layout_scope LINE
workspace_layout_scope() {
	case $1 in %*) printf '%s' "${1%%[[:space:]]*}" ;; esac
}

# Layout-set filter for lines on stdin: a line whose %scope does not name SET is dropped, the
# others are printed without their %scope. Set names compare case-insensitively.
# Usage: ... | workspace_for_layout SET
workspace_for_layout() {
	local set=$1 line scope token tokens hit
	while IFS= read -r line; do
		case $line in
			%*) ;;
			*)
				printf '%s\n' "$line"
				continue
				;;
		esac
		scope=${line%%[[:space:]]*}
		hit=0
		IFS=, read -r -a tokens <<<"${scope#%}"
		for token in ${tokens[@]+"${tokens[@]}"}; do
			foundation_ieq "$token" "$set" && hit=1
		done
		[ "$hit" -eq 1 ] && printf '%s\n' "$(foundation_trim "${line#"$scope"}")"
	done
	return 0
}

# The commands a workspace line may run in the background (a trailing `&`, see Open-Workspace):
# those that only start apps, terminal tabs or containers. Everything else runs in place: window
# placement, focus and tab closing need every window the open starts, and the browser openers each
# take the window that appears after their own launch, which a second browser launch would race.
workspace__background_ok=' open-application open-project open-projectterminals open-vscode open-vscodeworkspace open-obsidian open-claudedesktop open-docker open-acrobat start-containers '

# Usage: workspace_may_background COMMAND
workspace_may_background() {
	case $workspace__background_ok in *" $(foundation_lower "$1") "*) return 0 ;; esac
	return 1
}
