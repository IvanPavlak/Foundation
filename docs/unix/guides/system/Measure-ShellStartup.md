# Measure-ShellStartup

Times the interactive shell start stage by stage (additive from a bare shell, or leaving one stage
out per row).

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Measure-ShellStartup
Measure-ShellStartup --runs 10
Measure-ShellStartup --leave-one-out
Measure-ShellStartup --mode Isolated --runs 3
Measure-ShellStartup --stages Greeting,FastfetchImageLogo --pass-thru
Measure-ShellStartup --shell /bin/zsh
```

`--pass-thru` prints tab-separated rows (Configuration, Runs, Min, Median, Max, Delta, InShell) for
a script instead of the table.

## Related

- [`Measure-ShellStartup` in the System module reference](../../modules/System.md#measure-shellstartup)
- [System configuration guides](README.md)
