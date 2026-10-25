<!-- reference: module unix Logging -->

# Logging

Finds, pins and prunes the session and error logs every Foundation command writes.

Manifest: [`Unix/modules/Logging/module.conf`](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Logging/module.conf). One entry per command, alphabetical; the bullet block right under each heading is the parsed part.

The logging voice itself is `Unix/lib/log.sh` (`log_title`, `log_step`, `log_success`, `log_warning`, `log_error`, `log_segments`) plus `log_debug`. It lays lines out the way Write-Log does: a blank line before every line (a first argument of `-n` drops it, the `-NoLeadingNewline` of Windows), a step printed as given, a success or error after `=> `, a warning after one space, a title in brackets; `log_segments` prints one line of differently colored parts (Write-LogSegments). `Unix/lib/logfile.sh` mirrors every line into a file, the Start-Logging / Write-Log analog of Windows:

- **Session log** - `Unix/logs/Session_<yyyy-MM-dd_HH-mm-ss>_<Command>.log`, one per top-level command. Commands it runs write into the same file, so `w` produces one log with every action, including the debug lines `-v` would show. `Unix/bootstrap.sh` opens one too (`Session_<timestamp>_bootstrap.sh.log`), which chezmoi's first apply, `bootstrap-first-run` and Bootstrap write into.
- **Error log** - `Unix/logs/Errors.log` (the `error-file` of `logging.conf`), every `log_error` line of every session with its date and session name.
- **Folder** - `Unix/logs`, or the `directory` of `logging.conf` (`~` is the home folder, a relative path is under the repository); `FOUNDATION_LOG_DIR` moves it for one run.
- **Retention** - the limits of `Unix/config/logging.conf` (7 days, 20 sessions, 50 MB, error log 5 MB, trimmed to its newest half), applied in the background whenever a session starts. `Unix/logs/Pinned` is never pruned: move a log there to keep it. The same background step runs Invoke-LogMaintenance once its interval has passed (daily by default), which also prunes the backups and the test results.
- **Level** - the Set-LogLevel of Windows: `FOUNDATION_LOG_LEVEL` is `normal`, `quiet` (only warnings and errors on the console; title, step, success and segments lines are left out, the spinner too) or `verbose` (`log_debug` lines too). Export it for a shell (session-wide), prefix it for one command (`FOUNDATION_LOG_LEVEL=quiet w MyProject`, the scoped form); `-v` makes one command verbose. The `level` line of `logging.conf` is the default when the variable is unset (Logging.DefaultLevel). The session log gets every line at every level.
- **Colours** - title cyan, step plain, success green, warning yellow, error red, debug grey, the `info` segment blue; a `color STYLE COLOR` line of `logging.conf` (Logging.Colors) changes one, COLOR a [List-AvailableColors](Helper.md#list-availablecolors) name (`Cyan`, `BrightBlack`), `plain`, or an SGR code (`38;5;208`). An unknown name keeps the default. Read once when a command starts, so the shell functions of the rc keep the defaults.
- `Unix/logs` is gitignored except `Pinned/.gitkeep`. `logging off` in `logging.conf`, or `FOUNDATION_LOGGING=off` for one run, turns file logging off; the test suites run with it off. What every new terminal runs never logs - the greeting (Invoke-Clear, Invoke-Fastfetch, Invoke-Onefetch) and the prompt-theme lookup of the shell rc (`foundation-prompt-theme`) - so opening terminals never pushes the command logs out of the session limit.

## [Clear-OldLogs](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Logging/bin/Clear-OldLogs)

- **Description:** Applies the retention of `Unix/config/logging.conf` now, or the limits given for this run: session logs older than `max-age-days`, more than `max-session-files` (oldest first), the oldest while all exceed `max-total-size-mb`, and `Errors.log`, once past `max-error-file-size-mb`, trimmed to its newest half of that size; `Pinned/` untouched; `--dry-run` (or `--what-if`, the Windows `-WhatIf`) lists what would go. The settings are read as every config file is: the overlay, `@TYPE` lines and `-LINE` removals apply
- **Parameters:** `--dry-run` (or `--what-if`) lists what would go, each file once; `--max-age-days N`, `--max-session-files N`, `--max-total-size-mb N`, `--max-error-file-size-mb N` override `logging.conf` for this run (whole numbers, `0` = off; the Windows `-MaxSessionFiles 5` spelling works)
- **Usage:** `Clear-OldLogs [--dry-run | --what-if] [--max-age-days N] [--max-session-files N] [--max-total-size-mb N] [--max-error-file-size-mb N]`

## [Get-LogPath](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Logging/bin/Get-LogPath)

- **Description:** Prints the newest session log, or the newest of one command (`Get-LogPath Open-Workspace`, case-insensitive; the aliases `w`, `cw` and `rp` name their commands), `--errors` (or `--error-log`, the Windows `-ErrorLog`) for the error log (`Errors.log`, or the `error-file` of `logging.conf`), `--directory` for the folder (the `directory` of `logging.conf`), `--all` for every session log; an unknown flag is an error, as on Windows. Only the path goes to stdout, so `less "$(Get-LogPath w)"` works
- **Usage:** `Get-LogPath [COMMAND] [--errors | --error-log] [--directory] [--all]`

## [Invoke-LogMaintenance](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Logging/bin/Invoke-LogMaintenance)

- **Description:** The periodic sweep over every store Foundation fills, as the Windows Invoke-LogMaintenance: the Clear-OldLogs rules, Clear-OldBackups (`backups.conf`, over `Backups/Unix`) and the Run-Tests results retention of `Unix/tests/Results` (the ten newest `TestRun_*.log` stay, an older one goes once it is a day old, and so does a `foundation-tests.*` scratch folder a killed run left in `$TMPDIR`; the timings, history and last-green files are never touched). Prints nothing (`-v` shows what it did) and always exits 0. Throttled by the stamp `Unix/logs/.last-maintenance`: it runs only with `maintenance on` (the default) once `maintenance-interval-hours` (24) have passed, and writes the stamp first, so shells opened together do not sweep twice. Every new session's background retention calls it when it is due (Windows fires it from the profile's idle hook)
- **Parameters:** `--force` runs it now, whatever the switch and the stamp; `--results-directory DIR` prunes DIR instead of `Unix/tests/Results` (default `$FOUNDATION_TEST_RESULTS`, else `Unix/tests/Results`)
- **Usage:** `Invoke-LogMaintenance [--force] [--results-directory DIR]`

## [Protect-Log](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Logging/bin/Protect-Log)

- **Description:** Pins a log into `Unix/logs/Pinned`, which Clear-OldLogs and the retention every session runs always skip, as the Windows Protect-Log does; the original stays in place. Without an argument it pins the newest session log, which on macOS is the last command you ran (every command writes its own session log; this command's own run is not one). COMMAND pins the newest log of that command (`Protect-Log w`), PATH a log file of your choosing, and `--error-log` (or `--errors`) a snapshot of the error log (`Errors.log`, or the `error-file` of `logging.conf`) named after it with the time it was taken (`Errors_<timestamp>.log`). An argument with a `/` or ending in `.log` is a PATH: a missing one, like a missing `Errors.log` for `--error-log`, is a warning (`No log file to pin at`) with exit status 0, as on Windows, never taken as a COMMAND. A COMMAND with no log is an error
- **Usage:** `Protect-Log [PATH | COMMAND] [--error-log | --errors]`
