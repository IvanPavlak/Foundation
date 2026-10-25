# shellcheck shell=bash
# Docker Desktop and Compose stacks (config/docker.conf) - the DockerWizard core of Windows.

# The waits show the loading spinner, and Docker Desktop is looked up by bundle id (app_installed);
# loaded here so every caller of the library gets them.
foundation_load spinner apps

docker__file() {
	conf_path docker.conf
}

# Seconds of the last `timeout start|stop` line; without one, the shipped base docker.conf values
# (start 180, stop 60 - DockerTimeouts StartSeconds / StopSeconds of Windows).
docker_timeout() { # start|stop
	local file value fallback=180
	[ "$1" = stop ] && fallback=60
	file=$(docker__file) || {
		printf '%s' "$fallback"
		return
	}
	value=$(conf_lines "$file" | awk -v k="$1" '$1 == "timeout" && $2 == k { print $3 }' | tail -1)
	printf '%s' "${value:-$fallback}"
}

# Stack names in file order, each name once (case-insensitively, as first written).
docker_stacks() {
	local file
	file=$(docker__file) || return 0
	conf_lines "$file" | awk '$1 == "stack" && !seen[tolower($2)]++ { print $2 }'
}

# The folder relative compose files resolve under: the `directory PATH` line of docker.conf
# (PathTemplates.DockerDirectory), relative to the repository root, Docker without one.
docker_directory() {
	local file dir=''
	file=$(docker__file) && dir=$(conf_value "$file" directory 2>/dev/null)
	[ -n "$dir" ] || dir=Docker
	dir=$(foundation_expand_path "$dir")
	case $dir in /*) ;; *) dir=$DOTFILES_ROOT/$dir ;; esac
	printf '%s' "$dir"
}

# Compose file of a stack (relative paths under docker_directory). The last line for the name
# wins, so an overlay stack line overrides the base stack of the same name.
docker_stack_file() {
	local file path
	file=$(docker__file) || return 1
	path=$(conf_lines "$file" | awk -v n="$(foundation_lower "$1")" '$1 == "stack" && tolower($2) == n { sub(/^stack[[:space:]]+[^[:space:]]+[[:space:]]+/, ""); p = $0 } END { print p }')
	[ -n "$path" ] || return 1
	path=$(foundation_expand_path "$path")
	case $path in /*) ;; *) path=$(docker_directory)/$path ;; esac
	printf '%s' "$path"
}

docker_running() {
	command -v docker >/dev/null 2>&1 && docker info >/dev/null 2>&1 </dev/null
}

# Is Docker Desktop itself running (its app or its backend), whether or not the daemon answers yet?
docker_app_running() {
	pgrep -xq "Docker Desktop" || pgrep -xq com.docker.backend
}

# Open-Docker: launch Docker Desktop with no window and return at once.
docker_launch() {
	# The fixed path first (FOUNDATION_DOCKER_APP stands in for it in the suites), then Spotlight by
	# bundle id, so a cask installed with --appdir ~/Applications or a drag-install elsewhere counts.
	if [ ! -d "${FOUNDATION_DOCKER_APP:-/Applications/Docker.app}" ] && ! app_installed com.docker.docker >/dev/null; then
		log_error "Docker Desktop is not installed => brew install --cask docker-desktop"
		return 1
	fi
	log_step "Starting Docker Desktop..."
	foundation_launch open -g -a Docker </dev/null >/dev/null 2>&1
}

# DockerWizard start: launch Docker Desktop (no window) and wait for the daemon.
docker_start() {
	local timeout waited=0
	docker_running && return 0
	docker_launch || return 1
	timeout=$(docker_timeout start)
	spinner_start "Waiting for the Docker daemon"
	while [ "$waited" -lt "$timeout" ]; do
		sleep 1
		if docker_running; then
			spinner_stop
			log_success "Docker is running!"
			return 0
		fi
		waited=$((waited + 1))
	done
	spinner_stop --discard
	log_error "Docker did not become ready within ${timeout}s"
	return 1
}

# DockerWizard -Stop: stop running containers, then quit Docker Desktop.
docker_stop() {
	local timeout waited=0 ids
	if ! docker_app_running; then
		log_debug "[docker_stop] Docker Desktop is not running"
		return 0
	fi
	if docker_running; then
		ids=$(docker ps -q </dev/null)
		if [ -n "$ids" ]; then
			log_step "Stopping $(printf '%s\n' "$ids" | grep -c .) container(s)..."
			# shellcheck disable=SC2086 # one argument per id
			docker stop $ids >/dev/null </dev/null
		fi
	fi
	log_step "Quitting Docker Desktop..."
	osascript -e 'quit app "Docker"' </dev/null >/dev/null 2>&1
	timeout=$(docker_timeout stop)
	spinner_start "Waiting for Docker Desktop to quit"
	while [ "$waited" -lt "$timeout" ]; do
		pgrep -xq "Docker Desktop" || {
			spinner_stop
			return 0
		}
		sleep 1
		waited=$((waited + 1))
	done
	spinner_stop --discard
	pkill -x "Docker Desktop" 2>/dev/null
	return 0
}

# Published host ports of a compose file, "service -> host:port" per line.
docker_stack_ports() {
	docker compose -f "$1" ps --format '{{.Service}} -> {{.Publishers}}' </dev/null 2>/dev/null
}
