# shellcheck shell=bash
# Test-run helpers of Run-Tests - the Unix port of the Windows harness's Get-AdaptiveWorkerCount,
# Test-WorkerSampleRecordable, Get-RunConditionSummary, Get-ChangedPaths, Get-TestImpact,
# Get-WorkingTreeFingerprint and Get-SelectorMisses. Arguments and files in, lines out, so
# tests/testrun.bats pins every rule without starting a run.
#
# Everything Run-Tests remembers between runs lives in Unix/tests/Results (gitignored) and is
# optional: a missing or unreadable file only means "nothing known yet".
#   suite-timings.tsv    SUITE<TAB>MS                          the last time of every suite
#   worker-history.tsv   MACHINE<TAB>WORKERS<TAB>WALL-SEC<TAB>AT<TAB>PHASE   full runs, oldest first
#   last-green           FINGERPRINT<TAB>AT                    the last passing full run
#   last-selection       FINGERPRINT, then one selected suite per line   the last --changed run
#
# Committed beside the suites:
#   required-bats-version  the lowest bats the suites are verified with (RequiredPesterVersion.txt)
#   contract-baseline.tsv  the contract at the last release (ContractBaseline.json), once there is one
#   suite-weights.tsv      SUITE<TAB>MS, each suite's time in a CI run: the --shard split, and the queue
#                          order for a suite suite-timings.tsv does not know (Run-Tests --update-suite-weights)

# ---------------------------------------------------------------------------------------------
# Tiers
# ---------------------------------------------------------------------------------------------

# Does the suite FILE carry the integration tag (`# bats file_tags=integration`)? A suite whose
# value is real I/O (real git, real processes, real waits) carries it, so --quick can leave it
# out; a suite that is slow only because it is large stays untagged.
testrun_is_integration() {
	grep -qiE '^#[[:space:]]*bats[[:space:]]+file_tags=([^[:space:]]*,)?integration(,|[[:space:]]|$)' "$1" 2>/dev/null
}

# ---------------------------------------------------------------------------------------------
# Worker count
# ---------------------------------------------------------------------------------------------

# This machine as a worker-history key: model, CPU count and power source, so a laptop learns
# its plugged-in and its battery count separately (the battery one is usually lower).
testrun_machine() {
	local model cpus power=AC
	model=$(sysctl -n hw.model 2>/dev/null || uname -m)
	cpus=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo 4)
	pmset -g batt 2>/dev/null | head -1 | grep -q "'Battery Power'" && power=Battery
	printf '%s/%s/%s' "$model" "$cpus" "$power"
}

# The WORKERS<TAB>WALL-SEC samples of MACHINE in the history FILE, oldest first. Another
# machine's lines and malformed ones (a count or a wall clock that is not a positive number) are
# skipped: a corrupt line only means one sample less.
testrun_history_runs() {
	[ -r "$1" ] || return 0
	awk -F'\t' -v m="$2" '$1 == m && $2 ~ /^[0-9]+$/ && $3 ~ /^[0-9]+(\.[0-9]+)?$/ && $2 + 0 > 0 && $3 + 0 > 0 { print $2 "\t" $3 }' "$1"
}

# Picks the worker count for a run from the wall clocks of earlier full runs on this machine.
# Usage: testrun_worker_choice RUNS-FILE CPUS FILES TOTAL-MS SCOPED [DEFAULT-CAP] [MIN-WORK-MS]
# RUNS-FILE holds WORKERS<TAB>WALL-SEC lines, oldest first (testrun_history_runs); SCOPED is 1
# for a run that is not the full suite. Prints COUNT<TAB>BEST<TAB>PHASE<TAB>REASON.
#   - No history: min(CPUS, DEFAULT-CAP).
#   - Best: the count with the lowest median over its newest five samples, among counts with at
#     least two samples (a count needs two before it can displace the default).
#   - Explore: each neighbour of the best - round(best * 1.25), then round(best * 0.75), both
#     inside [2, CPUS] - is tried once. Confirm: a neighbour whose one sample beat the best is
#     tried again. Settle: the best is used (a second sample first, when it has one).
#   - Re-check: every 20th recorded run tries one neighbour again, alternating.
#   - A scoped run never explores: the best, capped so no worker gets less than MIN-WORK-MS of
#     work, and never more workers than files.
testrun_worker_choice() {
	awk -F'\t' -v cpu="$2" -v files="$3" -v total="$4" -v scoped="$5" \
		-v cap="${6:-12}" -v minwork="${7:-2000}" '
		function rnd(x) { return int(x + 0.5) }
		function median(k,   n, i, j, t, a) {
			n = 0
			for (i = (count[k] > 5 ? count[k] - 4 : 1); i <= count[k]; i++) a[++n] = sample[k, i]
			for (i = 2; i <= n; i++) { t = a[i]; for (j = i - 1; j >= 1 && a[j] > t; j--) a[j + 1] = a[j]; a[j + 1] = t }
			return (n % 2) ? a[(n + 1) / 2] : (a[n / 2] + a[n / 2 + 1]) / 2
		}
		function out(c, phase, reason) {
			if (c > files) c = files
			if (c < 1) c = 1
			printf "%d\t%d\t%s\t%s\n", c, best, phase, reason
			exit
		}
		$1 + 0 > 0 && $2 + 0 > 0 { k = $1 + 0; count[k]++; sample[k, count[k]] = $2 + 0; recorded++ }
		END {
			if (cpu < 1) cpu = 1
			def = (cpu < cap) ? cpu : cap
			if (def < 1) def = 1
			low = (cpu < 2) ? cpu : 2
			best = def; bestmed = -1
			if (count[def] >= 2) bestmed = median(def)
			for (k in count) if (count[k] >= 2) { m = median(k); if (bestmed < 0 || m < bestmed) { best = k + 0; bestmed = m } }
			if (scoped == 1) {
				bywork = (minwork > 0 && total > 0) ? int((total + minwork - 1) / minwork) : best
				c = (bywork < best) ? bywork : best
				out(c, "Scoped", sprintf("scoped run: best %d, capped by %.1fs of work at %.1fs per worker", best, total / 1000, minwork / 1000))
			}
			if (recorded == 0) out(def, "Default", sprintf("no history: min(CPU %d, %d)", cpu, cap))
			n = 0
			split("1.25 0.75", factors, " ")
			for (f = 1; f <= 2; f++) {
				c = rnd(best * factors[f]); if (c > cpu) c = cpu; if (c < low) c = low
				if (c != best && (n == 0 || nb[1] != c)) nb[++n] = c
			}
			for (i = 1; i <= n; i++) if (!(nb[i] in count)) out(nb[i], "Explore", sprintf("exploring neighbour %d of best %d", nb[i], best))
			bestknown = (best in count) ? median(best) : -1
			for (i = 1; i <= n; i++) if (count[nb[i]] == 1 && (bestknown < 0 || sample[nb[i], 1] < bestknown))
				out(nb[i], "Confirm", sprintf("confirming neighbour %d (%.1fs) against best %d", nb[i], sample[nb[i], 1], best))
			if (count[best] < 2) out(best, "Settle", sprintf("second sample for best %d", best))
			if (recorded % 20 == 0 && n > 0) { c = nb[int(recorded / 20) % n + 1]; out(c, "Recheck", sprintf("periodic re-check of neighbour %d (run %d)", c, recorded)) }
			out(best, "Settle", sprintf("learned best %d (median %.1fs over %d run(s))", best, bestmed, count[best]))
		}' "$1"
}

# May this run's wall clock teach the worker count? Usage:
#   testrun_recordable SCOPED EXPLICIT-WORKERS FAILED BROKEN LINT LOAD CPUS [FOREIGN]
# (flags are 1/0, LINT is on/off, LOAD the one-minute load average before the run, FOREIGN the
# average share of the machine, in percent, that processes outside the run used while it ran -
# testrun_foreign_cpu sampled every 2 s). Prints the reason; returns 0 when recordable. Only a
# clean full run with the lint alongside (what a full run always does) on an otherwise quiet
# machine is comparable with the others: busy before the run, or more than 15% foreign load
# during it (Test-WorkerSampleRecordable of Windows), is not. A load that is not a number (an
# `unknown` from testrun_load) says nothing about the machine and is no reason to refuse.
testrun_recordable() {
	[ "$1" = 1 ] && {
		echo "scoped run"
		return 1
	}
	[ "$2" = 1 ] && {
		echo "--workers given"
		return 1
	}
	[ "$3" = 1 ] && {
		echo "the run failed"
		return 1
	}
	[ "$4" = 1 ] && {
		echo "a suite did not run cleanly"
		return 1
	}
	[ "$5" = on ] || {
		echo "the lint did not run"
		return 1
	}
	if awk -v l="$6" -v c="$7" 'BEGIN { exit !(l ~ /^[0-9]+(\.[0-9]+)?$/ && c > 0 && l + 0 > c / 2) }'; then
		echo "the machine was busy before the run (load $6 on $7 CPUs)"
		return 1
	fi
	if [ -n "${8:-}" ] && awk -v f="$8" 'BEGIN { exit !(f > 15) }'; then
		echo "the machine was busy during the run (${8}% foreign load, more than 15%)"
		return 1
	fi
	echo recordable
}

# One sample of the run conditions (Start-RunConditionSampler): the share of the whole machine,
# in percent of all CPUs, that processes outside the process tree of ROOT use right now (`ps`
# %cpu is per core). The run's own workers, bats and the sampler sit below ROOT and are left out.
# Usage: testrun_foreign_cpu ROOT-PID CPUS
testrun_foreign_cpu() {
	ps -A -o %cpu=,pid=,ppid= 2>/dev/null | awk -v root="$1" -v cpus="$2" '
		{ cpu[$2] = $1; parent[$2] = $3 }
		END {
			for (p in cpu) {
				q = p; mine = 0
				for (n = 0; n < 64 && q > 1; n++) { if (q == root) { mine = 1; break } q = parent[q] }
				if (!mine) sum += cpu[p]
			}
			printf "%.1f\n", (cpus > 0) ? sum / cpus : sum
		}'
}

# The average of the samples in FILE (one percentage per line), one decimal; nothing without
# samples. Usage: testrun_foreign_average FILE
testrun_foreign_average() {
	[ -s "$1" ] || return 0
	awk '$1 ~ /^[0-9.]+$/ { s += $1; n++ } END { if (n) printf "%.1f\n", s / n }' "$1"
}

# --build-impact-map: merges RAW (SUITE<TAB>KIND<TAB>NAME lines, one per command started or
# library loaded during the run) into the impact map MAP, replacing what MAP held for each suite
# that ran (the SUITE... arguments, repository-relative), keeping the other suites' lines.
# Usage: testrun_impact_merge MAP RAW SUITE...
testrun_impact_merge() {
	local map=$1 raw=$2 tmp
	shift 2
	tmp=$(mktemp "${TMPDIR:-/tmp}/foundation-impact.XXXXXX") || return 1
	{
		[ -r "$map" ] && printf '%s\n' "$@" | awk -F'\t' 'NR == FNR { ran[$1] = 1; next } !($1 in ran)' - "$map"
		[ -r "$raw" ] && awk -F'\t' 'NF == 3 && $1 != ""' "$raw"
	} | LC_ALL=C sort -u >"$tmp" && mv "$tmp" "$map"
}

# The suites the impact map MAP saw start the changed PATH (a command of Unix/modules/*/bin) or
# load it (a library of Unix/lib, drivers/ included), one per line: the runtime backstop the
# static selection unions with (Read-ImpactMap). Usage: testrun__impacted MAP PATH
testrun__impacted() {
	local map=$1 path=$2 kind name
	[ -r "$map" ] || return 0
	case $path in
		Unix/modules/*/bin/*)
			kind='command'
			name=${path##*/}
			;;
		Unix/lib/*.sh)
			kind='lib'
			name=${path#Unix/lib/}
			name=${name%.sh}
			;;
		*) return 0 ;;
	esac
	awk -F'\t' -v k="$kind" -v n="$name" '$2 == k && $3 == n { print $1 }' "$map" | LC_ALL=C sort -u
}

# The suites on stdin (repository-relative, one per line) in queue order: the slowest of the
# previous run first (TIMINGS is suite-timings.tsv, SUITE<TAB>MS), a suite without a timing ahead
# of them all (it is new, and may be the slowest), equal times by name. So the long suites never
# start last and leave one worker running alone. WEIGHTS (the committed suite-weights.tsv, same
# shape) stands in for a suite TIMINGS does not know, so a first run (CI) also starts with the
# long suites. Usage: testrun_queue_order TIMINGS [WEIGHTS]
testrun_queue_order() {
	awk -F'\t' -v f="$1" -v w="${2:-}" '
		function read(file,   line, t) {
			if (file == "") return
			while ((getline line < file) > 0) { split(line, t, "\t"); if (t[2] ~ /^[0-9]+$/) ms[t[1]] = t[2] }
			close(file)
		}
		BEGIN { read(w); read(f) }
		$0 != "" { print (($0 in ms) ? ms[$0] : 999999999) "\t" $0 }' | LC_ALL=C sort -t$'\t' -k1,1nr -k2,2 | cut -f2-
}

# Is SPEC a shard of the form I/N (1 <= I <= N)? Usage: testrun_shard_valid SPEC
testrun_shard_valid() {
	case $1 in */*) ;; *) return 1 ;; esac
	local i=${1%%/*} n=${1#*/}
	case $i$n in '' | *[!0-9]*) return 1 ;; esac
	[ -n "$i" ] && [ -n "$n" ] && [ "$i" -ge 1 ] && [ "$n" -ge 1 ] && [ "$i" -le "$n" ]
}

# The suites on stdin (repository-relative, one per line) that shard I of N runs, heaviest first.
# Every shard of the same input and WEIGHTS (SUITE<TAB>MS) splits the same way, and each suite
# lands in exactly one: heaviest first, each to the shard with the least weight so far (the
# lowest number on a tie), equal weights by name. A suite WEIGHTS does not know weighs the median
# of the ones it does (1000 ms when it knows none). Usage: testrun_shard_pick I N WEIGHTS
testrun_shard_pick() {
	awk -F'\t' -v f="$3" '
		BEGIN {
			while ((getline line < f) > 0) { split(line, t, "\t"); if (t[2] ~ /^[0-9]+$/) { ms[t[1]] = t[2] + 0; v[++k] = t[2] + 0 } }
			for (i = 2; i <= k; i++) { x = v[i]; for (j = i - 1; j >= 1 && v[j] > x; j--) v[j + 1] = v[j]; v[j + 1] = x }
			median = k ? v[int((k + 1) / 2)] : 1000
		}
		$0 != "" && !seen[$0]++ { print (($0 in ms) ? ms[$0] : median) "\t" $0 }' |
		LC_ALL=C sort -t$'\t' -k1,1nr -k2,2 |
		awk -F'\t' -v want="$1" -v n="$2" '{
			best = 1
			for (s = 2; s <= n; s++) if (load[s] + 0 < load[best] + 0) best = s
			load[best] += $1
			if (best == want) print $2
		}'
}

# The bats version on PATH (1.14.0), nothing when there is none.
testrun_bats_version() {
	bats --version 2>/dev/null | sed -nE 's/^Bats ([0-9]+(\.[0-9]+)*).*/\1/p' | head -1
}

# Compares two versions (X.Y.Z, a -suffix ignored): prints -1, 0 or 1. Usage: testrun_version_cmp A B
testrun_version_cmp() {
	awk -v a="$1" -v b="$2" 'BEGIN {
		sub(/-.*/, "", a); sub(/-.*/, "", b); split(a, x, "."); split(b, y, ".")
		for (i = 1; i <= 3; i++) { if (x[i] + 0 < y[i] + 0) { print -1; exit } if (x[i] + 0 > y[i] + 0) { print 1; exit } }
		print 0 }'
}

# Is the bats on PATH (HAVE) one the suites are verified with? REQUIRED is the minimum of
# Unix/tests/required-bats-version (RequiredPesterVersion.txt of Windows: Homebrew installs only the
# newest bats-core, so the pin is a minimum). Prints `ok`, `old` (below the minimum: --timing,
# --count or the TAP the counter reads may differ), `newer-major` (a major release the suites have
# not met yet) or `unknown` (no version). Usage: testrun_bats_verdict HAVE REQUIRED
testrun_bats_verdict() {
	[ -n "$1" ] || {
		echo unknown
		return 0
	}
	[ -n "$2" ] || {
		echo ok
		return 0
	}
	if [ "$(testrun_version_cmp "$1" "$2")" = -1 ]; then
		echo old
	elif [ "${1%%.*}" -gt "${2%%.*}" ] 2>/dev/null; then
		echo newer-major
	else
		echo ok
	fi
}

# ---------------------------------------------------------------------------------------------
# Run conditions
# ---------------------------------------------------------------------------------------------

# The one-minute load average, or `unknown` when no probe answers (unknown, not zero, as
# Get-RunConditionSummary of Windows).
testrun_load() {
	local load
	load=$(sysctl -n vm.loadavg 2>/dev/null | awk '{ gsub(/[{}]/, ""); print $1; exit }')
	case $load in '' | *[!0-9.]*) load=$(uptime 2>/dev/null | sed -nE 's/.*load averages?: *([0-9.]+).*/\1/p') ;; esac
	case $load in '' | *[!0-9.]*) load=unknown ;; esac
	printf '%s\n' "$load"
}

# The machine line of the run log: model and cores (performance and efficiency when the CPU has
# both, as Apple silicon does).
testrun_machine_line() {
	local model cpus perf eff
	model=$(sysctl -n hw.model 2>/dev/null || uname -m)
	cpus=$(sysctl -n hw.ncpu 2>/dev/null || nproc 2>/dev/null || echo '?')
	perf=$(sysctl -n hw.perflevel0.logicalcpu 2>/dev/null)
	eff=$(sysctl -n hw.perflevel1.logicalcpu 2>/dev/null)
	if [ -n "$perf" ] && [ -n "$eff" ]; then
		printf '%s, %s CPUs (%s performance, %s efficiency)' "$model" "$cpus" "$perf" "$eff"
	else
		printf '%s, %s CPUs' "$model" "$cpus"
	fi
}

# What can slow a run down besides the suites: power source, Low Power Mode, a CPU speed limit
# and the load. One line for the run log; a probe that is unavailable is left out.
testrun_conditions() {
	local parts=() power lowpower limit
	power=$(pmset -g batt 2>/dev/null | head -1 | sed -n "s/.*'\(.*\)'.*/\1/p")
	[ -n "$power" ] && parts+=("power $power")
	lowpower=$(pmset -g 2>/dev/null | awk '$1 == "lowpowermode" { print ($2 == 1) ? "on" : "off" }')
	[ -n "$lowpower" ] && parts+=("Low Power Mode $lowpower")
	limit=$(pmset -g therm 2>/dev/null | awk -F'= *' '/CPU_Speed_Limit/ { print $2 }')
	[ -n "$limit" ] && parts+=("CPU speed limit $limit%")
	parts+=("load $(testrun_load)")
	local IFS=';'
	printf '%s' "${parts[*]}" | sed 's/;/, /g'
}

# ---------------------------------------------------------------------------------------------
# Selection (--changed)
# ---------------------------------------------------------------------------------------------

# The paths changed since the merge base of REF and HEAD, plus the uncommitted and untracked
# ones, as STATUS<TAB>PATH (A added, D deleted, M anything else; a rename is its two paths),
# repository-relative, run from the repository root. Fails when REF does not resolve.
testrun_changed_paths() {
	local base
	base=$(git merge-base "$1" HEAD 2>/dev/null) || return 1
	{
		git diff --name-status --no-renames "$base" 2>/dev/null
		git ls-files --others --exclude-standard 2>/dev/null | awk '{ print "A\t" $0 }'
	} | awk -F'\t' '$2 != "" { s = substr($1, 1, 1); if (s != "A" && s != "D") s = "M"; if (!seen[$2]++) print s "\t" $2 }'
}

# Is PATH code a suite depends on through its name (a command, a library, a test helper)?
testrun__is_code() {
	case $1 in
		Unix/modules/*/bin/* | Unix/lib/*.sh | Unix/tests/*.bash | Unix/modules/*/functions.sh | Unix/bootstrap.sh) return 0 ;;
	esac
	return 1
}

# ERE-escapes a fixed string.
testrun__escape() {
	printf '%s\n' "$1" | sed 's/[][\.*^$+?(){}|]/\\&/g'
}

# The patterns (ERE, one per line) whose presence in a file means it depends on PATH, changed
# with STATUS. A command is matched by its name, a library by its file name or its foundation_load
# name, a test helper by its load line. Other files are matched by their path and every parent
# of two or more segments (a suite reading $DOTFILES_ROOT/AI/Skills depends on every skill),
# with or without the leading Unix/. A file that appeared or vanished also matches the globs
# that enumerate its folder (modules/*/bin/*, lib/*.sh), since the set those loops see changed.
testrun__patterns() {
	local status=$1 path=$2 rel name stem
	rel=${path#Unix/}
	name=${path##*/}
	case $path in
		Unix/modules/*/bin/*)
			printf '(^|[^A-Za-z0-9_-])%s([^A-Za-z0-9_-]|$)\n' "$(testrun__escape "$name")"
			;;
		Unix/lib/*.sh)
			stem=${rel#lib/}
			stem=${stem%.sh}
			testrun__escape "$name"
			printf 'foundation_load([^#]*[[:space:]])%s([[:space:];)&|]|$)\n' "$(testrun__escape "$stem")"
			;;
		Unix/tests/*.bash)
			stem=${name%.bash}
			printf '^[[:space:]]*load[[:space:]]+([^[:space:]]*/)?%s(\\.bash)?[[:space:]]*$\n' "$(testrun__escape "$stem")"
			;;
		Unix/modules/*/functions.sh | Unix/bootstrap.sh)
			testrun__escape "$rel"
			;;
		*)
			awk -v p="$path" -v r="$rel" 'BEGIN {
				n = split(p, s, "/"); acc = s[1]; if (n == 1) print p
				for (i = 2; i <= n; i++) { acc = acc "/" s[i]; print acc }
				if (r != p) { n = split(r, s, "/"); acc = s[1]; if (n == 1) print r
					for (i = 2; i <= n; i++) { acc = acc "/" s[i]; print acc } }
			}' | while IFS= read -r key; do testrun__escape "$key"; done
			;;
	esac
	[ "$status" = A ] || [ "$status" = D ] || return 0
	# Globs over the folder: every segment but the first may be a *, and the file name may be
	# *.EXT; only the variants that contain a * are new patterns.
	awk -v r="$rel" 'BEGIN {
		n = split(r, s, "/"); if (n < 2) exit
		ext = s[n]; sub(/^[^.]*/, "", ext)
		for (mask = 0; mask < 2 ^ (n - 1); mask++) {
			out = s[1]; star = 0
			for (i = 2; i <= n; i++) {
				bit = int(mask / 2 ^ (i - 2)) % 2
				if (bit) { out = out "/" ((i == n && ext != "") ? "*" ext : "*"); star = 1 }
				else out = out "/" s[i]
			}
			if (star) print out
			if (n >= 3) { trimmed = out; sub(/\/[^\/]*$/, "", trimmed); if (trimmed ~ /\*/) print trimmed }
		}
	}' | sort -u | while IFS= read -r key; do testrun__escape "$key"; done
}

# The suites a change can affect. Usage: testrun_select CORPUS-DIR CHANGES-FILE [IMPACT-MAP]
# CORPUS-DIR mirrors the repository's suites, test helpers, commands and libraries with their
# full-line comments removed (testrun_corpus); CHANGES-FILE holds STATUS<TAB>PATH lines
# (testrun_changed_paths). Prints SUITE<TAB>REASON per selected suite (repository-relative), or
# one `*<TAB>REASON` line when everything must run. Conservative: whatever references a changed
# file is affected, and whatever references an affected command, library or helper is too. With
# an IMPACT-MAP (Run-Tests --build-impact-map), the suites it saw start a changed or affected
# command, or load such a library, are added: a dependency no name in the code shows. A module
# manifest selects that module's suites and the two gates that read every manifest; a file of
# Unix/config selects the suites that read $UNIX_DIR/config, and a shipped base file also the
# contract gate (the other suites read the fixture config). A changed
# path under Unix/ that selects nothing at all (testrun__untraced) runs everything: what cannot
# be traced is not assumed safe, as Get-TestImpact runs the full suite for a path no rule knows.
testrun_select() {
	local corpus=$1 changes=$2 impact=${3:-} queue status path pattern_file hits hit reason visited picked suite
	queue=$(mktemp "${TMPDIR:-/tmp}/foundation-select.XXXXXX") || return 1
	pattern_file=$queue.patterns
	visited=$queue.visited
	: >"$visited"
	awk -F'\t' '{ print $1 "\t" $2 "\t" $2 }' "$changes" >"$queue"
	while [ -s "$queue" ]; do
		IFS=$'\t' read -r status path reason <"$queue"
		tail -n +2 "$queue" >"$queue.next" && mv "$queue.next" "$queue"
		grep -qxF "$path" "$visited" && continue
		printf '%s\n' "$path" >>"$visited"
		# Whether anything at all was selected for PATH: only an original change that picked
		# nothing is untraced.
		picked=0
		if [ -n "$impact" ]; then
			hits=$(testrun__impacted "$impact" "$path")
			for hit in $hits; do
				printf '%s\t%s (impact map)\n' "$hit" "$reason"
				picked=1
			done
		fi
		case $path in
			Unix/tests/Results/*) continue ;;
			Unix/lib/foundation.sh)
				printf '*\t%s (every command and suite sources it)\n' "$reason"
				rm -f "$queue" "$pattern_file" "$visited"
				return 0
				;;
			*.bats)
				[ "$status" = D ] || printf '%s\t%s\n' "$path" "$reason"
				# A suite that changed affects only itself; one that appeared or vanished also
				# changes what the completeness check sees.
				[ "$status" = M ] && continue
				;;
			Unix/modules/*/module.conf)
				suite=${path#Unix/modules/}
				suite=${suite%/module.conf}
				printf 'Unix/tests/commands.bats\t%s (the completeness check reads every manifest)\n' "$reason"
				printf 'Unix/tests/guides.bats\t%s (a guide per command line of every manifest)\n' "$reason"
				[ -d "$corpus/Unix/tests/modules/$suite" ] &&
					(cd "$corpus" && find "Unix/tests/modules/$suite" -maxdepth 1 -name '*.bats' -type f | LC_ALL=C sort) |
					while IFS= read -r hit; do printf "%s\t%s (its module's manifest)\n" "$hit" "$reason"; done
				continue
				;;
			Unix/config/*)
				# The suites that read the committed config ($UNIX_DIR/config: the base-file checks,
				# Test-ConfigurationSchema on a copy), and for a shipped base file the contract.
				(cd "$corpus" && grep -rlE 'UNIX_DIR\}?"?/config([/"[:space:]]|$)' Unix/tests 2>/dev/null | grep '\.bats$' | LC_ALL=C sort) |
					while IFS= read -r hit; do printf '%s\t%s (it reads Unix/config)\n' "$hit" "$reason"; done
				case ${path#Unix/config/} in */* | *.local.conf) ;; *.conf)
					printf 'Unix/tests/contract.bats\t%s (the contract lists the line kinds of the shipped base files)\n' "$reason"
					;;
				esac
				picked=1
				;;
		esac
		case $status:$path in
			[AD]:Unix/modules/* | [AD]:Unix/tests/modules/*)
				printf 'Unix/tests/commands.bats\t%s (the completeness check lists commands and suites)\n' "$reason"
				picked=1
				;;
		esac
		if [ "$status" = F ]; then
			# A fixture config file that names a changed command: the commands that read that
			# file (Open-Workspace runs the actions of workspaces.conf by name) are affected.
			path=${path#Unix/tests/fixtures/config/}
			testrun__escape "${path%%/*}" >"$pattern_file"
			hits=$(cd "$corpus" && grep -rlE -f "$pattern_file" Unix/modules Unix/tests 2>/dev/null |
				grep -vE '^Unix/tests/(fixtures/|[^/]*\.bash$)' | LC_ALL=C sort)
		else
			testrun__patterns "$status" "$path" >"$pattern_file"
			hits=''
			[ -s "$pattern_file" ] && hits=$(cd "$corpus" && grep -rlE -f "$pattern_file" . 2>/dev/null | sed 's#^\./##' | LC_ALL=C sort)
		fi
		for hit in $hits; do
			[ "$hit" = "$path" ] && continue
			case $hit in
				*.bats)
					printf '%s\t%s\n' "$hit" "$reason"
					picked=1
					;;
				Unix/tests/fixtures/config/*)
					# Only a command's name in a fixture makes a dependency; a path or a library
					# name there is data.
					case $path in Unix/modules/*/bin/*)
						printf 'F\t%s\t%s via %s\n' "$hit" "$reason" "$hit" >>"$queue"
						picked=1
						;;
					esac
					;;
				*) testrun__is_code "$hit" && printf 'M\t%s\t%s via %s\n' "$hit" "$reason" "$hit" >>"$queue" && picked=1 ;;
			esac
		done
		if [ "$picked" -eq 0 ] && [ "$reason" = "$path" ] && testrun__untraced "$path"; then
			printf '*\t%s (no suite or code under Unix references it, so everything runs)\n' "$path"
			rm -f "$queue" "$pattern_file" "$visited"
			return 0
		fi
	done
	rm -f "$queue" "$pattern_file" "$visited"
}

# Does a change to PATH that selected nothing mean everything must run? Yes for a file under
# Unix/ (Unix/shell, Unix/home, a command no one names); no for the data no suite reads
# (Unix/config, Unix/logs, Unix/tests/Results), prose (Markdown) and a suite (it runs itself,
# or was deleted), and for anything outside Unix/ (the other half, the docs).
testrun__untraced() {
	case $1 in
		Unix/config/* | Unix/logs/* | Unix/tests/Results/* | *.md | *.bats) return 1 ;;
		Unix/*) return 0 ;;
	esac
	return 1
}

# The suites (Unix/tests/... paths on stdin) whose path below Unix/tests contains one of the
# PATTERNs, case-insensitively (Run-Tests layout => tests/layout.bats; Run-Tests Application =>
# every suite of tests/modules/Application). Usage: testrun_match_patterns PATTERN...
testrun_match_patterns() {
	local suite base pattern
	while IFS= read -r suite; do
		base=$(foundation_lower "${suite#*Unix/tests/}")
		for pattern in "$@"; do
			case $base in *"$(foundation_lower "$pattern")"*)
				printf '%s\n' "$suite"
				break
				;;
			esac
		done
	done
}

# Did the subject of SUITE itself change (CHANGES-FILE: STATUS<TAB>PATH lines)? The suite file, the
# command of a tests/modules/<Module>/<Command>.bats, or the library of a tests/<name>.bats. Such
# a suite runs under --quick even when it is in the integration tier: the change is to what it
# tests (Invoke-TestSuite runs a file selected for its own subject whole). Usage:
# testrun_own_subject SUITE CHANGES-FILE
testrun_own_subject() {
	local suite=$1 subject='' name
	name=${suite##*/}
	name=${name%.bats}
	case $suite in
		Unix/tests/modules/*/*.bats)
			subject=${suite#Unix/tests/modules/}
			subject=Unix/modules/${subject%/*}/bin/$name
			;;
		Unix/tests/*.bats) subject=Unix/lib/$name.sh ;;
	esac
	awk -F'\t' -v s="$suite" -v c="$subject" '$1 != "D" && ($2 == s || (c != "" && $2 == c)) { found = 1 } END { exit !found }' "$2"
}

# The selection (SUITE<TAB>REASON lines, testrun_select | testrun_selection_unique) as the terminal
# shows it before the run: `SUITE  <=  REASON`, at most MAX lines (default 40), then how many more
# the run log holds. Usage: testrun_selection_preview FILE [MAX]
testrun_selection_preview() {
	awk -F'\t' -v max="${2:-40}" '
		NR <= max { print (($1 == "*") ? "everything" : $1) "  <=  " $2 }
		END { if (NR > max) print "... and " (NR - max) " more - see the run log" }' "$1"
}

# Builds the selection corpus in DIR: every suite, test helper, fixture config file, command,
# module functions.sh and library under Unix/, with full-line comments removed (a name in a
# comment is no dependency). Run from the repository root.
testrun_corpus() {
	local dir=$1 file
	while IFS= read -r file; do
		mkdir -p "$dir/$(dirname "$file")"
		grep -vE '^[[:space:]]*#' "$file" >"$dir/$file" 2>/dev/null
	done < <(
		find Unix/tests -name '*.bats' -type f -not -path 'Unix/tests/Results/*'
		find Unix/tests -maxdepth 1 -name '*.bash' -type f
		find Unix/tests/fixtures/config -type f
		find Unix/lib -name '*.sh' -type f
		ls Unix/modules/*/bin/* Unix/modules/*/functions.sh Unix/modules/Custom/*/bin/* Unix/modules/Custom/*/functions.sh Unix/bootstrap.sh 2>/dev/null
	)
}

# Collapses a selection (testrun_select output) to one line per suite, first reason kept, and
# prints `*` lines alone when one is present.
testrun_selection_unique() {
	awk -F'\t' '$1 == "*" { all = all $0 "\n"; next } !seen[$1]++ { rest = rest $0 "\n" }
		END { printf "%s", (all != "") ? all : rest }'
}

# The files shellcheck lints, one repository-relative path per line (run from the repository
# root): the libraries and drivers, bootstrap.sh, every module's functions.sh (the Custom area's
# too), the shared rc and the bash rc files, and every command whose shebang is bash or sh. The
# one list Run-Tests --lint and the CI workflow (through Run-Tests --lint-files) both check.
testrun_lint_files() {
	local f first
	for f in Unix/lib/*.sh Unix/lib/drivers/*.sh Unix/bootstrap.sh Unix/modules/*/functions.sh \
		Unix/modules/Custom/*/functions.sh Unix/shell/shellrc.sh Unix/shell/bashrc Unix/shell/bash_profile; do
		[ -f "$f" ] && printf '%s\n' "$f"
	done
	for f in Unix/modules/*/bin/* Unix/modules/Custom/*/bin/*; do
		[ -f "$f" ] || continue
		first=''
		IFS= read -r first <"$f" || [ -n "$first" ] || continue
		case $first in '#!/usr/bin/env bash' | '#!/bin/bash' | '#!/usr/bin/env sh' | '#!/bin/sh') printf '%s\n' "$f" ;; esac
	done
}

# Does any changed path (STATUS<TAB>PATH lines in FILE) need the lint? A shell file under Unix/.
testrun_needs_lint() {
	awk -F'\t' '$2 ~ /^Unix\// && $2 !~ /^Unix\/(config|tests\/Results|logs)\// &&
		($2 ~ /\.(sh|bash|bats)$/ || $2 ~ /^Unix\/modules\/[^\/]+\/bin\// || $2 ~ /^Unix\/shell\//) { found = 1 }
		END { exit !found }' "$1"
}

# ---------------------------------------------------------------------------------------------
# The gate
# ---------------------------------------------------------------------------------------------

# A fingerprint of the working tree: HEAD, the uncommitted diff and every untracked file's
# content. Two equal fingerprints mean the same code was tested. Run from the repository root.
testrun_fingerprint() {
	{
		git rev-parse HEAD 2>/dev/null
		git diff HEAD --binary 2>/dev/null
		git ls-files --others --exclude-standard -z 2>/dev/null | xargs -0 shasum 2>/dev/null
	} | shasum | cut -c1-16
}

# The failing suites (FAILED-FILE, one per line) that the selection (SELECTED-FILE, one suite
# per line, or `*`) left out: what --changed would have missed.
testrun_misses() {
	[ -r "$1" ] || return 0
	grep -qxF '*' "$1" && return 0
	while IFS= read -r suite; do
		[ -n "$suite" ] || continue
		grep -qxF "$suite" "$1" || printf '%s\n' "$suite"
	done <"$2"
}

# ---------------------------------------------------------------------------------------------
# The contract (Get-ContractSnapshot, Test-ContractCompatibility, New-ContractBaseline,
# Get-ChangelogReleases, Test-ChangelogVersionBumps)
# ---------------------------------------------------------------------------------------------

# The contract a release promises, KIND<TAB>ITEM per line, sorted: what a fork or a script relies
# on and a later release may not take away without a deprecation (VERSIONING.md).
#   command  NAME                     every `command` line of an engine module's manifest (the
#                                     Custom area is the fork's own, not the contract)
#   flag     NAME --FLAG              every long flag the command documents in its header
#   key      FILE KIND                a line kind of a shipped base Unix/config/FILE (the first
#   key      FILE [Section]           word, lowercase, after any @TYPE; a capitalised first word
#   key      FILE [Section] KIND      is data: a zone, a repository, a workspace action), each
#                                     section, and the line kinds inside it; .local.conf files
#                                     are the fork's values, not the contract
#   step     Bootstrap NAME           every step of the Bootstrap catalog
# Usage: testrun_contract_snapshot [UNIX-DIR]   (default: this checkout's Unix/)
testrun_contract_snapshot() {
	local unix=${1:-$FOUNDATION_UNIX} manifest dir name flag file
	{
		for manifest in "$unix"/modules/*/module.conf; do
			[ -f "$manifest" ] || continue
			dir=$(dirname "$manifest")
			for name in $(awk '$1 == "command" && NF >= 2 { print $2 }' "$manifest"); do
				printf 'command\t%s\n' "$name"
				[ -f "$dir/bin/$name" ] || continue
				for flag in $(foundation_command_flags "$dir/bin/$name"); do printf 'flag\t%s %s\n' "$name" "$flag"; done
			done
		done
		for file in "$unix"/config/*.conf; do
			[ -f "$file" ] || continue
			case $file in *.local.conf) continue ;; esac
			awk -v f="${file##*/}" '
				{ sub(/^[[:space:]]+/, ""); sub(/[[:space:]]+$/, "") }
				$0 == "" || /^#/ { next }
				$1 ~ /^@/ { $1 = ""; sub(/^[[:space:]]+/, "") }
				/^\[.*\]$/ { section = $0; print "key\t" f " " section; next }
				$1 ~ /^[a-z][a-z0-9-]*$/ { print "key\t" f " " ((section != "") ? section " " : "") $1 }' "$file"
		done
		file=$unix/modules/Bootstrap/bin/Bootstrap
		[ -f "$file" ] && awk '/^CATALOG=\(/ { on = 1; next } on && /^\)/ { exit }
			on { line = $0; gsub(/"/, "", line); split(line, w, " "); if (w[1] != "") print "step\tBootstrap " w[1] }' "$file"
	} | LC_ALL=C sort -u
}

# The changelog of Foundation, or nothing (status 1) when this checkout has none: FOUNDATION_CHANGELOG
# when set, else Unix/CHANGELOG.md under the repository root ROOT (Foundation's project documents
# live in its own folder, so the same path holds in Foundation and in a fork of several upstreams;
# the root CHANGELOG.md is a generic pointer). Usage: testrun_changelog_path ROOT
testrun_changelog_path() {
	if [ -n "${FOUNDATION_CHANGELOG:-}" ]; then
		[ -r "$FOUNDATION_CHANGELOG" ] || return 1
		printf '%s\n' "$FOUNDATION_CHANGELOG"
		return 0
	fi
	[ -r "$1/Unix/CHANGELOG.md" ] || return 1
	printf '%s\n' "$1/Unix/CHANGELOG.md"
}

# The released versions of a Keep-a-Changelog file, newest first: VERSION<TAB>SUBSECTIONS (the
# `### Name` headings of that release, comma-separated). [Unreleased] and the compare links at the
# bottom are left out. Usage: testrun_changelog_releases CHANGELOG
testrun_changelog_releases() {
	[ -r "$1" ] || return 0
	awk '
		function flush() { if (version != "") print version "\t" sections; version = ""; sections = "" }
		/^## / {
			flush()
			if (match($0, /^## \[[0-9]+\.[0-9]+\.[0-9]+(-[0-9A-Za-z.-]+)?\]/)) version = substr($0, 5, RLENGTH - 5)
			next
		}
		/^\[/ && index($0, "]: ") { flush(); next }
		version != "" && /^### / { s = $0; sub(/^### +/, "", s); sub(/[[:space:]]+$/, "", s); sections = sections ((sections == "") ? "" : ",") s }
		END { flush() }' "$1"
}

# The text of one subsection (Removed, Breaking, ...) of the changelog's [Unreleased] section.
# Usage: testrun_changelog_unreleased CHANGELOG SUBSECTION
testrun_changelog_unreleased() {
	[ -n "$1" ] && [ -r "$1" ] || return 0
	awk -v want="$2" '
		/^## / { unreleased = ($0 ~ /^## \[Unreleased\]/); on = 0; next }
		/^\[/ && index($0, "]: ") { unreleased = 0; next }
		unreleased && /^### / { s = $0; sub(/^### +/, "", s); sub(/[[:space:]]+$/, "", s); on = (s == want); next }
		unreleased && on' "$1"
}

# Every release from 1.0.0 on whose version bump does not match its changelog sections, one
# violation per line (VERSIONING.md's bump table; the 0.x series is exempt):
#   - ### Removed or ### Breaking must be a MAJOR, and a MAJOR must have one of them;
#   - ### Added, ### Changed or ### Deprecated must be at least a MINOR (a PATCH carries only
#     ### Fixed and ### Security);
#   - a MAJOR resets MINOR and PATCH to 0, a MINOR resets PATCH, and every version is higher than
#     the one before it.
# Usage: testrun_version_bumps CHANGELOG
testrun_version_bumps() {
	testrun_changelog_releases "$1" | awk -F'\t' '
		function part(v, i,   x) { sub(/-.*/, "", v); split(v, x, "."); return x[i] + 0 }
		{ version[NR] = $1; sections[NR] = "," $2 "," }
		END {
			for (i = 1; i < NR; i++) {
				new = version[i]; old = version[i + 1]
				if (part(old, 1) < 1) continue
				s = sections[i]
				breaks = (s ~ /,(Removed|Breaking),/)
				adds = (s ~ /,(Added|Changed|Deprecated),/)
				major = part(new, 1) > part(old, 1)
				minor = !major && part(new, 1) == part(old, 1) && part(new, 2) > part(old, 2)
				patch = part(new, 1) == part(old, 1) && part(new, 2) == part(old, 2) && part(new, 3) > part(old, 3)
				if (!(major || minor || patch)) { print "[" new "] is not higher than the release before it, [" old "]."; continue }
				if (breaks && !major) print "[" new "] removes or breaks part of the contract (### Removed or ### Breaking), so it must be a MAJOR release, not a bump from [" old "]."
				if (major && !breaks) print "[" new "] is a MAJOR release but removes and breaks nothing (no ### Removed or ### Breaking); release it as a MINOR or PATCH."
				if (adds && patch) print "[" new "] adds, changes or deprecates something (### Added, ### Changed or ### Deprecated), so it must be at least a MINOR release; a PATCH carries only ### Fixed and ### Security."
				if (major && (part(new, 2) != 0 || part(new, 3) != 0)) print "[" new "] is a MAJOR release, so its MINOR and PATCH must be 0."
				if (minor && part(new, 3) != 0) print "[" new "] is a MINOR release, so its PATCH must be 0."
			}
		}'
}

# Every way the snapshot SNAPSHOT (testrun_contract_snapshot) breaks the contract BASELINE
# (contract-baseline.tsv: `version X.Y.Z`, the snapshot lines of that release and the
# hand-written `deprecated KIND ITEM VERSION` lines), one violation per line. Additions are never
# violations; a flag of a removed command is the command's violation. A removal is sanctioned, as
# on Windows, by the [Unreleased] section of CHANGELOG (what makes the next release a MAJOR): a
# `### Breaking` subsection naming the item in backticks, or a `### Removed` one naming an item
# whose deprecation shipped in a release (its VERSION no later than the baseline's).
# Usage: testrun_contract_violations BASELINE SNAPSHOT [CHANGELOG]
testrun_contract_violations() {
	local removed breaking
	removed=$(testrun_changelog_unreleased "${3:-}" Removed)
	breaking=$(testrun_changelog_unreleased "${3:-}" Breaking)
	CONTRACT_REMOVED=$removed CONTRACT_BREAKING=$breaking awk -F'\t' '
		function vcmp(a, b,   x, y, i) {
			sub(/-.*/, "", a); sub(/-.*/, "", b); split(a, x, "."); split(b, y, ".")
			for (i = 1; i <= 3; i++) { if (x[i] + 0 < y[i] + 0) return -1; if (x[i] + 0 > y[i] + 0) return 1 }
			return 0
		}
		function sanctioned(kind, item,   token, since) {
			token = "`" item "`"
			if (index(ENVIRON["CONTRACT_BREAKING"], token)) return 1
			since = deprecated[kind SUBSEP item]
			return since != "" && vcmp(since, baseline) <= 0 && index(ENVIRON["CONTRACT_REMOVED"], token)
		}
		# By file name, not FNR == NR: an empty snapshot would make every baseline line look present.
		FILENAME == ARGV[1] { now[$1 SUBSEP $2] = 1; next }
		/^#/ || NF < 2 { next }
		$1 == "version" { baseline = $2; next }
		$1 == "deprecated" { deprecated[$2 SUBSEP $3] = $4; next }
		{ n++; kind[n] = $1; item[n] = $2; if ($1 == "command") was[$2] = 1 }
		END {
			for (i = 1; i <= n; i++) {
				k = kind[i]; it = item[i]
				if ((k SUBSEP it) in now) continue
				if (k == "flag") { c = it; sub(/ .*/, "", c); f = it; sub(/^[^ ]* /, "", f); if ((c in was) && !(("command" SUBSEP c) in now)) continue }
				if (sanctioned(k, it)) continue
				if (k == "command") print "Command [" it "] was removed. Keep it working and deprecate it first (VERSIONING.md, Deprecation policy); it can be removed in the next MAJOR."
				else if (k == "flag") print "Flag [" f "] of [" c "] was removed or renamed. Keep it working (the old spelling as a synonym) and deprecate it first."
				else if (k == "key") print "Config line [" it "] is no longer in the shipped base file. Keep reading it and deprecate it first; it can be removed in the next MAJOR."
				else if (k == "step") print "Step [" it "] was removed. Keep it in the catalog and deprecate it first; it can be removed in the next MAJOR."
				else print "Contract item [" k " " it "] is gone. Deprecate it first."
			}
		}' "$2" "$1" | LC_ALL=C sort
}

# The contract baseline for release VERSION: the snapshot SNAPSHOT stamped with it, plus the
# deprecation records of the PREVIOUS baseline that still apply (maintained by hand: a change that
# deprecates an item adds `deprecated KIND ITEM VERSION`). A record whose item was in the previous
# contract and is gone from the new snapshot was removed in this release and is dropped; one for an
# item the snapshot cannot see (a line kind the code still reads but the base file no longer
# ships) is kept. Usage: testrun_contract_baseline SNAPSHOT VERSION [PREVIOUS]
testrun_contract_baseline() {
	printf '# The contract of Foundation release %s: the commands, their documented flags, the line kinds\n' "$2"
	printf '# of the shipped base Unix/config files and the Bootstrap steps (Unix/lib/testrun.sh,\n'
	printf '# testrun_contract_snapshot). Written by Run-Tests --update-contract-baseline at each release;\n'
	printf '# held by Unix/tests/contract.bats. Add `deprecated<TAB>KIND<TAB>ITEM<TAB>VERSION` lines by hand.\n'
	printf 'version\t%s\n' "$2"
	cat "$1"
	[ -n "${3:-}" ] && [ -r "$3" ] || return 0
	awk -F'\t' '
		FILENAME == ARGV[1] { now[$1 SUBSEP $2] = 1; next }
		FNR == 1 { pass++ }
		pass == 1 { if ($1 != "deprecated" && $1 != "version" && $1 !~ /^#/ && NF >= 2) was[$1 SUBSEP $2] = 1; next }
		$1 == "deprecated" && NF >= 4 { key = $2 SUBSEP $3; if ((key in was) && !(key in now)) next; print }' "$1" "$3" "$3"
}

# ---------------------------------------------------------------------------------------------
# Results retention
# ---------------------------------------------------------------------------------------------

# Keeps RESULTS bounded, as the Windows harness does at run start and Invoke-LogMaintenance does on
# its sweep: the ten newest TestRun_*.log stay, an older one goes only once it is a day old; with
# TMP-ROOT, a scratch folder foundation-tests.* that a killed run left there goes once it is a day
# old (a run removes its own on the way out). The one-day gate means a run in flight never loses a
# file. The other files of RESULTS (suite-timings.tsv, worker-history.tsv, last-green,
# last-selection, impact-map.tsv) are never touched. Prints one `removed NAME` line per removal.
testrun_prune_results() { # RESULTS [TMP-ROOT]
	local results=$1 tmp=${2:-} file kept=0
	if [ -d "$results" ]; then
		while IFS= read -r file; do
			kept=$((kept + 1))
			[ "$kept" -gt 10 ] || continue
			[ -n "$(find "$file" -mtime +0 2>/dev/null)" ] || continue
			rm -f "$file" && printf 'removed %s\n' "${file##*/}"
		done < <(find "$results" -maxdepth 1 -name 'TestRun_*.log' -type f | LC_ALL=C sort -r)
	fi
	[ -n "$tmp" ] && [ -d "$tmp" ] || return 0
	while IFS= read -r file; do
		rm -rf "$file" && printf 'removed %s\n' "${file##*/}"
	done < <(find "$tmp" -maxdepth 1 -name 'foundation-tests.*' -type d -mtime +0 2>/dev/null)
	return 0
}
