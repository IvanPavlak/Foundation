# DotnetBuildAndRun

Builds the .NET project in the current directory, then runs it even when the build failed (as on Windows) (alias `dnbr`); the arguments go to `dotnet run`.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
DotnetBuildAndRun
dnbr --launch-profile MyProfile
```

## Related

- [`DotnetBuildAndRun` in the Helper module reference](../../modules/Helper.md#dotnetbuildandrun)
- [Helper configuration guides](README.md)
