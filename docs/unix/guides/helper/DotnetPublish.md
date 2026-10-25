# DotnetPublish

Publishes a project of the .NET solution near the current directory with one of its `Properties/PublishProfiles/*.pubxml` profiles into `~/Desktop/<Project>_<Profile>_<yyyy_MM_dd>` (alias `dnp`).

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
cd $DEV/MyRepo
DotnetPublish
dnp
```

## Related

- [`DotnetPublish` in the Helper module reference](../../modules/Helper.md#dotnetpublish)
- [Helper configuration guides](README.md)
