# shellcheck shell=bash
# Workspace benchmark - Write-WorkspaceBenchmark / Get-WorkspaceBenchmarkPath of Windows: one CSV
# row per workspace open, so a change to the open flow can be judged by numbers.
#
#   $XDG_STATE_HOME/foundation/WorkspaceBenchmark.csv
#   Timestamp,Workspace,Machine,LayoutSet,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,
#   ArrangeSeconds,Found,Expected,Outcome,EarlyMove,Source,Mode,Attempts
#
# Mode is Plain or Alongside (an --alongside open), so the medians of the two never mix; Attempts
# is the most arrange passes one desktop of the layout needed (1 at the first try, 0 without a
# layout), Attempts - 1 the retries the Timing line reports. Source is empty for an everyday open; Measure-WorkspaceOpen sets FOUNDATION_BENCHMARK_SOURCE to
# "Measure-WorkspaceOpen <session>", and Get-WorkspaceBenchmark leaves those rows out unless asked.
#
# Outcome: Applied (every layout window found and placed), Partial, NotFound (no layout window
# appeared) or NoLayout (the workspace has no Set-WorkspaceWindowLayout action). Recording is off
# unless `benchmark on` is set in workspaces.conf, as WorkspaceBenchmark.Enabled on Windows;
# Measure-WorkspaceOpen's opens pass benchmark=on through FOUNDATION_SETTING_OVERRIDES, so they
# always record. What the end of an open shows is `benchmark-display` (Display on Windows):
# table (the default: the workspace's last benchmark-history rows, Get-WorkspaceBenchmark), line
# (the one Timing line) or none. Needs lib/config.sh.

benchmark_file() {
	printf '%s/WorkspaceBenchmark.csv' "$FOUNDATION_STATE_DIR"
}

benchmark__seconds() { # MS
	printf '%d.%d' $(($1 / 1000)) $((($1 % 1000) / 100))
}

# Appends the row of one open and shows it as benchmark-display says.
benchmark_record() { # WORKSPACE TOTAL-MS ACTIONS-MS LAYOUT-MS TIMINGS-FILE [MODE]
	local file config wait=0 arrange=0 found=0 expected=0 outcome=NoLayout attempts=0 type display mode=${6:-Plain}
	config=$(conf_path workspaces.conf) || return 0
	[ "$(foundation_lower "$(conf_value "$config" benchmark 2>/dev/null)")" = on ] || return 0
	display=$(foundation_lower "$(conf_value "$config" benchmark-display 2>/dev/null)")
	local early=-
	if [ -r "$5" ]; then
		read -r wait arrange found expected outcome attempts <"$5"
		# A timings file without the attempt count (an older writer) ran its layout once.
		case $attempts in '' | *[!0-9]*) attempts=1 ;; esac
	fi
	[ -r "$(dirname "$5")/layout-early-move" ] && early=$(cat "$(dirname "$5")/layout-early-move")
	type=$(layout_type 2>/dev/null) || type=''
	file=$(benchmark_file)
	mkdir -p "$(dirname "$file")" || return 0
	[ -s "$file" ] || echo 'Timestamp,Workspace,Machine,LayoutSet,TotalSeconds,ActionsSeconds,LayoutSeconds,WaitSeconds,ArrangeSeconds,Found,Expected,Outcome,EarlyMove,Source,Mode,Attempts' >"$file"
	# Files from before a column get it added to the header once, in column order; their rows read
	# it as empty (Get-WorkspaceBenchmark shows an empty Mode as Plain).
	local column
	for column in EarlyMove Source Mode Attempts; do
		head -n 1 "$file" | tr ',' '\n' | grep -qx "$column" || { sed -i.bak "1s/\$/,$column/" "$file" && rm -f "$file.bak"; }
	done
	printf '%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s,%s\n' "$(date +%Y-%m-%dT%H:%M:%S)" "$1" "$(foundation_machine_type)" "$type" \
		"$(benchmark__seconds "$2")" "$(benchmark__seconds "$3")" "$(benchmark__seconds "$4")" \
		"$(benchmark__seconds "$wait")" "$(benchmark__seconds "$arrange")" "$found" "$expected" "$outcome" "$early" "${FOUNDATION_BENCHMARK_SOURCE:-}" "$mode" "$attempts" >>"$file"
	case $display in
		none) return 0 ;;
		line) ;;
		*)
			# Table: the workspace's recent runs (Get-WorkspaceBenchmark WORKSPACE, its row count
			# benchmark-history), as Windows renders Get-WorkspaceBenchmark -Last after the open.
			foundation_run Get-WorkspaceBenchmark "$1" || true
			return 0
			;;
	esac
	# The summary of Write-WorkspaceBenchmark: each phase of at least 0.05 s, the rest as other,
	# the retries when the layout needed more than one pass, and the outcome only when it is not a
	# plain Applied (or NoLayout).
	local parts=() other=$(($2 - $3 - wait - arrange)) summary
	[ "$3" -ge 50 ] && parts+=("actions $(benchmark__seconds "$3")s")
	[ "$wait" -ge 50 ] && parts+=("wait $(benchmark__seconds "$wait")s")
	[ "$arrange" -ge 50 ] && parts+=("arrange $(benchmark__seconds "$arrange")s")
	[ "$other" -ge 50 ] && parts+=("other $(benchmark__seconds "$other")s")
	[ "$attempts" -gt 1 ] && parts+=("retries $((attempts - 1))")
	case $outcome in Applied | NoLayout) ;; *) parts+=("outcome $outcome $found/$expected") ;; esac
	summary='no phases recorded'
	[ ${#parts[@]} -gt 0 ] && summary=$(printf '%s | ' "${parts[@]}") && summary=${summary% | }
	log_step " Timing [$1] => $summary"
}
