# Gravity shell

A Quickshell desktop for niri inspired by Gravity Rush: a levitating bar, notifications that
fall away and a lock screen, all coloured by the Hekseville palette or by your wallpaper.

- **Wallpaper**: your own image, on every screen. `Super+Shift+W` (or `gravity-shell wallpaper`)
  opens the picker: the wallpaper zooms out into a preview and three wallpapers rise from the
  bottom and float in the gravity field. Left/Right (or the mouse wheel) scrolls them, Enter
  applies, Esc closes. It lists only your wallpaper folder: `Wallpapers` inside your Pictures
  folder (whatever it is called in your language, e.g. `~/Afbeeldingen/Wallpapers`), or the
  folder set as `wallpaperDir`. The folder is created the first time the picker opens.
  `gravity-shell wallpaper ~/pic.jpg` sets one directly.
- **Colours**: the built-in Hekseville palette (indigo, violet and gold), or picked from the
  wallpaper with [matugen](https://github.com/InioX/matugen). Switch in the picker, which also
  offers matugen's scheme variants (tonal, vibrant, expressive, ...).
- **Bar**: a floating island that drops in on login and sways when gravity shifts
  (workspace switches, notifications, the occasional "gravity storm").
  It holds niri workspace orbs, the window title, the tray, volume, battery and a clock.
- **Notifications**: cards drift in from the right; when they expire they fall away.
- **Lock screen** (`Super+Alt+L`, or after 10 idle minutes): your wallpaper blurs in behind a
  clock and a password field.

## Settings

Optional `~/.config/gravity-shell/config.json` (live-reloaded). The picker writes it too,
storing only settings that differ from the defaults:

```json
{
  "wallpaper": "/path/to/image.jpg",
  "wallpaperDir": "~/Somewhere/Else",
  "colors": "wallpaper",
  "colorScheme": "scheme-tonal-spot",
  "ambientShifts": true,
  "idleLockMinutes": 10,
  "use24h": true
}
```

`"colors"` is `"default"` or `"wallpaper"`. Generated colours are cached in
`~/.cache/gravity-shell/colors.json`. matugen can't read `.jxl` images, so with those the
default colours are used. From a terminal:

```sh
gravity-shell ipc call theme set wallpaper     # or: default
gravity-shell ipc call theme scheme vibrant
```

## Changing the shell itself

`cp -r /usr/share/gravity-shell ~/.config/quickshell/gravity`, then edit. `gravity-shell`
prefers that copy, and Quickshell reloads it live as you save.

Useful commands: `gravity-shell lock`, `gravity-shell wallpaper [image]`, `gravity-shell ipc show`, `gravity-shell log`.
