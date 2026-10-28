<!-- reference: module unix Helper -->

# Helper

General helpers: search, translation, the command reference, the colour palette, countdowns, backups, project runs and the .NET/npm shorthands.

Manifest: [`Unix/modules/Helper/module.conf`](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/module.conf). One entry per command, alphabetical; the bullet block right under each heading is the parsed part.

## [Cd-Desktop](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/functions.sh)

- **Description:** Shell function: changes the current directory to `~/Desktop`
- **Usage:** `Cd-Desktop`
- **Alias:** `cd-desktop`

## [Clear-OldBackups](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/Clear-OldBackups)

- **Description:** Prunes the backup sink `Backups/Unix` by the three limits of `Unix/config/backups.conf` (each 0 = off, flags override for one run): backups older than `max-age-days`, more than `max-backups-per-key` per key, and the oldest while the sink exceeds `max-total-size-mb`. The newest backup of every key is never deleted. Only folders named `yyyy-MM-dd_HH-mm-ss` are backups: anything else in a key folder (a manual copy, an unpacked archive) is never counted, never taken for the newest and never removed, as on Windows; the per-key limit enforced right after every backup follows the same rule. `--dry-run` lists what would go
- **Usage:** `Clear-OldBackups [--dry-run] [--max-age-days N] [--max-backups-per-key N] [--max-total-size-mb N]`; Windows-style `--what-if` is `--dry-run`

## [Countdown](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/Countdown)

- **Description:** Counts down on one line (cyan above 3, red from 3), for use before destructive operations; Ctrl+C aborts with exit status 130, so `Countdown 5 && ...` stops what follows.
- **Usage:** `Countdown SECONDS [--message TEXT]`; Windows-style `--seconds N` also works

## [DotnetBuildAndRun](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/DotnetBuildAndRun)

- **Description:** Builds the .NET project in the current directory, then runs it even when the build failed, as on Windows (`dotnet build`, then `dotnet run` with the arguments; passing arguments is a Unix addition). A leading `-h` or `--help` prints its header and builds nothing; `DotnetBuildAndRun -- --help` hands `--help` to the program.
- **Usage:** `DotnetBuildAndRun [ARGUMENTS...]`
- **Alias:** `dnbr`

## [DotnetPublish](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/DotnetPublish)

- **Description:** Finds the solution near the current directory, lists its projects that have `Properties/PublishProfiles/*.pubxml`, asks for project and profile when there are several, publishes into `~/Desktop/<Project>_<Profile>_<yyyy_MM_dd>` and offers to open the folder in Finder
- **Usage:** `DotnetPublish`
- **Alias:** `dnp`

## [DotnetRun](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/DotnetRun)

- **Description:** Runs the already built .NET project in the current directory (`dotnet run` with the arguments). A leading `-h` or `--help` prints its header instead of reaching `dotnet run`; `DotnetRun -- --help` hands `--help` to the program.
- **Usage:** `DotnetRun [ARGUMENTS...]`
- **Alias:** `dnr`

## [Find-Item](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/Find-Item)

- **Description:** Finds files (or directories with `--directory`, or both) by a case-insensitive name glob, level by level as on Windows: the start path and its subtree to `--max-downward-depth` levels (default 5, counted as Get-ChildItem `-Depth` counts them, so 0 still sees the children), then, while nothing matched, each parent and its whole subtree (a sibling project folder is found) up to `--max-upward-depth` levels (default 5). The first level with a match wins; several matches from that level show a menu (`--select-first` takes the first). `--name-filter TEXT` keeps matches whose folder name (files, both) or own name (directories) contains TEXT. `.git` and `node_modules` are never searched. Only the chosen path goes to stdout, so `cd "$(Find-Item -d src)"` works.
- **Usage:** `Find-Item PATTERN [--directory] [--search-target file|directory|both] [--name-filter TEXT] [--start-path DIR] [--max-downward-depth N] [--max-upward-depth N] [--select-first]`; Windows-style `--search-target directory` is `--directory`

## [Get-RepositoryPath](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/Get-RepositoryPath)

- **Description:** Prints the repository root, or its Unix, modules (`Unix/modules`, the Windows `Modules`), Windows, config or docs folder, found by the anchor file `Unix/lib/foundation.sh`: walking up from this executable, or with `--start-path DIR` (the Windows `-StartPath`) from any folder of another clone or worktree, where config is that root's `Unix/config`. The Windows part exists only in a clone that holds both halves (Dotfiles); in one without a `Windows` folder, as Foundation's, it fails with `No Windows half in this clone` instead of printing a folder that is not there.
- **Usage:** `Get-RepositoryPath [unix|modules|windows|config|docs] [--start-path DIR]`

## [Invoke-GoogleTranslate](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/Invoke-GoogleTranslate)

- **Description:** Translates TEXT (several words need no quotes) with Google Translate; the source language is detected unless given (`auto`, `detect` or `automatic` also detect it), the target defaults to `output` of `Unix/config/translate.conf`. Languages are English names or codes, the list of the Windows function (`Chinese` is `zh-CN`); an unsupported one fails with the supported names.
- **Usage:** `Invoke-GoogleTranslate [--input-language LANGUAGE] [--output-language LANGUAGE] TEXT...`; Windows-style `--text TEXT` also works
- **Alias:** `translate`

## [List-AvailableColors](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/List-AvailableColors)

- **Description:** Prints the terminal's colour palette, as the Windows List-AvailableColors prints the console colours: the 16 ANSI colours, each name in its own colour with its SGR code (30-37, 90-97), then the 256-colour palette as numbered swatches. The terminal theme decides what each one looks like
- **Usage:** `List-AvailableColors`

## [List-Functions](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/List-Functions)

- **Description:** Lists the Unix commands from the module pages in the layout of the Windows List-Functions: a centered `[Module]` border per module, each command's name and description and then every other bullet of its entry as `Key => value`, one indent deeper and in the next colour each (backticks dropped and a Markdown link printed as its text), a `[Total function count => N]` border, and the discrepancy report after the full listing; the modules of the [Custom area](../custom/README.md) are listed as `Custom/<Module>` from their pages in `docs/foundation/custom`. Name patterns and `--module` filter the listing; `--category` and `--function` take names or show a menu (`Resolve-Selection`), each with its own count border; `--names` prints names only. `--list-discrepancies` checks each module's bin and functions.sh, its `module.conf` manifest and its page against each other, and that each page lists its entries in alphabetical order (case-insensitive, as the Windows Infrastructure-FunctionReference gate), and exits 1 on any mismatch; `--quiet` keeps it silent when there is none. Colours and the names the check ignores come from `Unix/config/list-functions.conf` (ListFunctionsColors, ShowFunctionDetailsColors, FunctionDiscrepancyExclusions). A `--category` or `--function` name given as a number is that entry of its menu, as on Windows.
- **Usage:** `List-Functions [PATTERN...] [--module NAME...] [--category [NAME...]] [--function [NAME...]] [--list-discrepancies] [--quiet] [--names]`

## [Loading-Spinner](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/Loading-Spinner)

- **Description:** Runs COMMAND while a spinner (`Unix/config/spinners.conf`, `--style`) redraws `FRAME LABEL` on stderr after a blank line, as on Windows, and leaves a green ` ✓ LABEL` when COMMAND succeeded (the line is erased when it failed), passing its output and exit status through; a frame is cut to the terminal width, read again for every frame, so a terminal a tiling window manager narrows mid-wait never wraps it; `--preview` animates every style once (Preview-LoadingSpinners). The last `spinners.conf` line of a style name wins, so an overlay line replaces a base style. The same spinner (`lib/spinner.sh`) shows during Docker start/stop and the layout's wait for windows; it stays silent when stderr is no terminal and at the verbose level
- **Usage:** `Loading-Spinner [--label TEXT] [--style STYLE] -- COMMAND [ARGS...]`, `Loading-Spinner --preview`
- **Alias:** `Preview-LoadingSpinners` (`Loading-Spinner --preview`, the Windows command name; each style in turn rather than all together)

## [NpmInstallAndStart](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/NpmInstallAndStart)

- **Description:** Installs the npm dependencies, then starts the project even when the install failed, as on Windows (`npm install`, then `npm start` with the arguments; passing arguments is a Unix addition). A leading `-h` or `--help` prints its header and installs nothing; `NpmInstallAndStart -- --help` hands `--help` to `npm start`.
- **Usage:** `NpmInstallAndStart [ARGUMENTS...]`
- **Alias:** `nir`

## [Run-Project](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/Run-Project)

- **Description:** Opens a runnable project's tabs and types each tab's `run` command into it (a `run KEY` without a `tab KEY` line runs nothing, as on Windows; Test-ConfigurationSchema reports it); menu of runnable projects when none is given, where Enter runs the first. Running a project again does not stack a second set of tabs: its open tabs are closed first (Close-ProjectTerminals, which keeps the tab this shell runs in), and when this shell's tab is one of the project's tabs it is reused - its run command is typed into it last, after Run-Project ends - instead of a duplicate opening. Docker step first: each `docker` line of the project (a `docker.conf` stack such as PostgreSQL, or a path key holding the project's own compose file) is brought up, starting Docker Desktop when needed. Of several stacks (the project's database providers, `DatabaseProviders` on Windows) only one starts: `--database-provider NAME` names it, else a menu picks it (Enter takes the first); a path key with the project's own compose file always starts; `step Docker on|off` in `projects.conf` sets the default, `--skip Docker` / `--include Docker` override it. When Docker or one of the project's targets cannot be started, the project is skipped with an error (no tab opens, exit status 1) and the next one runs, as on Windows. The Docker step resolves through `lib/steps.sh` like every other step list: `--skip` wins over `--include` with a warning, and a step name other than Docker or a flag it does not know stops it before anything runs. A project given as a number is that entry of the menu of runnable projects, as `-Project 2` is on Windows.
- **Usage:** `Run-Project [PROJECT[,PROJECT...]...] [--new-window] [--database-provider NAME] [--skip Docker] [--include Docker]`; Windows-style `--project NAME` (a bare NAME) and `--in-same-shell` (the default) also work
- **Alias:** `rp`

## [Show-Image](https://github.com/IvanPavlak/Foundation/blob/master/Unix/modules/Helper/bin/Show-Image)

- **Description:** Displays an image file: inside WezTerm drawn into the terminal (`wezterm imgcat`, aspect ratio kept, `--width` in cells, `N%` or `Npx`), with `--window` or in any other terminal in a Quick Look window the size of the image - the dialog of the Windows Show-Image; without `qlmanage` it opens in the default app (`open`); useful for wallpapers and screenshots
- **Usage:** `Show-Image PATH [--width N|N%|Npx] [--window]`; Windows-style `--image-path PATH` also works
