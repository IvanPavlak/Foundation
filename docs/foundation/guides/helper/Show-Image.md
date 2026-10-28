# Show-Image

Displays an image file, drawn into the terminal inside WezTerm or in a Quick Look window elsewhere or with `--window`; without `qlmanage` it opens in the image's default app (`open`).

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Show-Image ~/Pictures/MyWallpaper.jpg
Show-Image ~/Desktop/MyScreenshot.png --width 50%
Show-Image ~/Desktop/MyScreenshot.png --window
```

## Related

- [`Show-Image` in the Helper module reference](../../modules/Helper.md#show-image)
- [Helper configuration guides](README.md)
