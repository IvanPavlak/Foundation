# A hard time limit for zsh-autocomplete's completion worker. zsh only: shellrc.sh sources this
# file right after the plugin, which defines the worker function when it is sourced.
#
# For every key typed, the plugin forks a worker (a copy of the interactive shell) that starts a
# second zsh on its own pseudo-terminal (zpty) and waits for the completion list. Nothing stops
# that pair once the completion runs long: cancelling a job only closes the pipe the shell reads,
# the worker's 1-second timeout covers only the first byte the helper prints, the helper's TMOUT
# fires only while it waits for input, and the helper sits in a session of its own, so closing the
# terminal never reaches it. A helper that loops then grows until macOS runs out of RAM and swap.
#
# The guard wraps the worker: a watchdog forked next to it checks once a second whether the worker
# is still its parent, and once the limit has passed kills every child of the worker (each zpty
# helper with its whole process group) and the worker itself. A worker that ends in time leaves
# the watchdog without its parent, and the watchdog ends at its next check.
#
# Reported upstream: https://github.com/marlonrichert/zsh-autocomplete/issues/909. Remove this file
# (and its source line in shellrc.sh) once a release bounds the worker itself.

[[ -v functions[.autocomplete:async:start-worker] ]] || return 0
zmodload -F zsh/system p:sysparams
zmodload -F zsh/zselect b:zselect

# Seconds a worker may run. The plugin's own completion timeout is 1 second; this only catches
# the ones nothing else stops. Tests set it lower before sourcing.
typeset -gi _foundation_autocomplete_limit=${_foundation_autocomplete_limit:-10}

# Wrap once: a second source would otherwise wrap the wrapper.
if [[ ! -v functions[.foundation:autocomplete:start-worker] ]]; then
	functions[.foundation:autocomplete:start-worker]=$functions[.autocomplete:async:start-worker]

	.autocomplete:async:start-worker() {
		# Read before the fork: a background job expands its arguments in the forked child.
		local -i _foundation_worker=$sysparams[pid]
		(( _foundation_autocomplete_limit > 0 )) &&
			.foundation:autocomplete:watchdog $_foundation_worker $_foundation_autocomplete_limit \
				</dev/null >/dev/null 2>&1 &!
		.foundation:autocomplete:start-worker "$@"
	}
fi

# Kills WORKER and everything it started once it outlives LIMIT seconds. Runs as WORKER's child,
# with no stdout of its own: the shell reads the worker's output until every writer has closed it.
# Usage: .foundation:autocomplete:watchdog WORKER LIMIT
.foundation:autocomplete:watchdog() {
	local -i worker=$1 limit=$2 waited=0 child=0
	while (( waited < limit )); do
		zselect -t 100
		# Reparented: the worker has ended (its pid may already belong to another process).
		(( sysparams[ppid] == worker )) || return 0
		(( ++waited ))
	done
	for child in ${(f)"$(command pgrep -P $worker 2>/dev/null)"}; do
		(( child == sysparams[pid] )) && continue
		# A zpty helper leads its own process group, which holds what it forked; any other child
		# leads none and is killed alone.
		kill -KILL -- -$child 2>/dev/null || kill -KILL -- $child 2>/dev/null
	done
	kill -KILL -- $worker 2>/dev/null
	return 0
}
