# Open-Terminal

Opens WezTerm tabs in a new window, or in this one with `--in-same-shell`, one per command, with
optional titles and directories (alias `t`).

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Open-Terminal
t 'npm run dev' 'lazygit'
Open-Terminal 'dotnet watch' --title MyProject.Api --cwd $DEV/MyProject/src/MyProject.Api
Open-Terminal --in-same-shell --cwd $DEV/MyRepo
Open-Terminal -TabTitles Api, Git -Command 'npm run dev', 'lazygit'
Open-Terminal 'npm run build' --window-id Build
```

`--window-id Build` opens a window the first time and remembers it under that name; every later
`--window-id Build` adds its tabs to that window while it is open. `--window-id 0` is the window
this shell runs in.

## Related

- [`Open-Terminal` in the Application module reference](../../modules/Application.md#open-terminal)
- [Application configuration guides](README.md)
