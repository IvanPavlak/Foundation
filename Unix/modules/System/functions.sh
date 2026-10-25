# shellcheck shell=bash
# System shell functions, sourced by Unix/shell/shellrc.sh. Functions, not executables: only the
# shell itself can reload itself.

# Reload-PowerShellProfile analog: replace this shell with a fresh login shell, which re-reads the
# rc files and every module (history is kept, the directory too). FOUNDATION_RELOADING tells the new
# shell to list the modules it loaded, like Reload-WinuXModules does.
Reload-Profile() {
	FOUNDATION_RELOADING=1 exec "${SHELL:-/bin/zsh}" -l
}

# The greeting a shell opens with and what `c` redraws (Show-TerminalGreeting), in three steps
# that greeting.conf switches on and off one by one: Invoke-Clear, Invoke-Fastfetch (the panel,
# without its logo when it does not fit), then the onefetch repository panel when the directory is
# inside a git repository (Invoke-Onefetch). Onefetch is measured first and its height passed as
# --extra-rows, so fastfetch is fitted to both panels together. A function, not a command:
# Invoke-Fastfetch execs fastfetch, whose Shell module reports its parent process, which must stay
# this shell. --no-clear, --no-fastfetch and --no-onefetch skip one step for this call (the
# measurement goes with --no-fastfetch, --no-onefetch and --no-resize); --no-resize, --settle,
# --prompt-reserve N, --max-shrink-steps N and --reflow-timeout-milliseconds N go to
# Invoke-Fastfetch. Flags match case- and dash-insensitively, as PowerShell binds them (-NoClear,
# -noclear, --no-clear); an unknown word is warned about and ignored, so the greeting still draws.
Show-TerminalGreeting() {
	_stg_clear=1
	_stg_fastfetch=1
	_stg_onefetch=1
	_stg_resize=1
	_stg_value=
	# Keep only the Invoke-Fastfetch flags in "$@", one word each. Rebuilding the positional
	# parameters works the same in zsh and bash; a joined string would reach Invoke-Fastfetch as
	# ONE argument under zsh, which does not word-split unquoted variables.
	for _stg_arg in "$@"; do
		shift
		# The value of the flag before it.
		if [ -n "$_stg_value" ]; then
			set -- "$@" "$_stg_value" "$_stg_arg"
			_stg_value=
			continue
		fi
		# The Unix spelling as it is (no process at shell start), any other one by its dash-less
		# lowercase key.
		case $_stg_arg in
			--no-clear | --no-fastfetch | --no-onefetch | --no-resize | --settle | --prompt-reserve | --max-shrink-steps | --reflow-timeout-milliseconds)
				_stg_flag=$_stg_arg
				;;
			*)
				case $(printf '%s' "$_stg_arg" | tr -d '-' | tr '[:upper:]' '[:lower:]') in
					noclear) _stg_flag=--no-clear ;;
					nofastfetch) _stg_flag=--no-fastfetch ;;
					noonefetch) _stg_flag=--no-onefetch ;;
					noresize) _stg_flag=--no-resize ;;
					settle) _stg_flag=--settle ;;
					promptreserve) _stg_flag=--prompt-reserve ;;
					maxshrinksteps) _stg_flag=--max-shrink-steps ;;
					reflowtimeoutmilliseconds) _stg_flag=--reflow-timeout-milliseconds ;;
					*) _stg_flag= ;;
				esac
				;;
		esac
		case $_stg_flag in
			--no-clear) _stg_clear=0 ;;
			--no-fastfetch) _stg_fastfetch=0 ;;
			--no-onefetch) _stg_onefetch=0 ;;
			--no-resize)
				_stg_resize=0
				set -- "$@" --no-resize
				;;
			--settle) set -- "$@" --settle ;;
			--prompt-reserve | --max-shrink-steps | --reflow-timeout-milliseconds) _stg_value=$_stg_flag ;;
			*) log_warning "Show-TerminalGreeting does not take [$_stg_arg] - ignored" ;;
		esac
	done
	[ -z "$_stg_value" ] || log_warning "Show-TerminalGreeting: $_stg_value needs a number - ignored"
	_stg_rows=0
	if [ "$_stg_onefetch" -eq 1 ] && [ "$_stg_fastfetch" -eq 1 ] && [ "$_stg_resize" -eq 1 ]; then
		_stg_rows=$(Invoke-Onefetch --measure 2>/dev/null) || _stg_rows=0
	fi
	case $_stg_rows in '' | *[!0-9]*) _stg_rows=0 ;; esac
	[ "$_stg_clear" -eq 0 ] || Invoke-Clear
	[ "$_stg_fastfetch" -eq 0 ] || Invoke-Fastfetch --extra-rows "$_stg_rows" "$@"
	# Drawn from one captured run, with a blank line between the panels only when there is one.
	if [ "$_stg_onefetch" -eq 1 ]; then
		_stg_panel=$(Invoke-Onefetch 2>/dev/null)
		[ -z "$_stg_panel" ] || printf '\n%s\n' "$_stg_panel"
	fi
	unset _stg_clear _stg_fastfetch _stg_onefetch _stg_resize _stg_value _stg_arg _stg_flag _stg_rows _stg_panel
}
