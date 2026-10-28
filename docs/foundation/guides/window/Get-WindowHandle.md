# Get-WindowHandle

Lists the windows AeroSpace manages (id, app, desktop, title, then the PID and the frame: x, y,
width and height in points), optionally filtered by app and/or title pattern. Piped, the columns
are tab separated in that order; the PID and frame columns were appended, so the first four keep
their place. The frame is read from the window server by window id and needs no permission; a
window whose frame cannot be read has empty frame columns. The id is what
`Resize-Windows --window-handle` takes.

## Configuration Keys

This command reads no `Unix/config` files. There is nothing to configure.

## Usage

```bash
Get-WindowHandle
Get-WindowHandle --process-name Code
Get-WindowHandle --window-title '*MyProject*'
Get-WindowHandle --process-name Browser --window-title '*Google Gemini*'
```

## Related

- [`Get-WindowHandle` in the Window module reference](../../modules/Window.md#get-windowhandle)
- [Window configuration guides](README.md)
