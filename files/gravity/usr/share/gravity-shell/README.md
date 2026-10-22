# Gravity shell

A Quickshell desktop for niri inspired by Gravity Rush: floating wallpapers, notifications that
fall away and a lock screen, all coloured by an accent colour of your choice or by your
wallpaper.

Everything shares one Material 3 Expressive style: solid surfaces without borders, fully
rounded pills, the accent colour for whatever is focused or selected, tonal fills for the
rest, and bold [Google Sans Flex](https://fonts.google.com/specimen/Google+Sans+Flex) text.

- **Wallpaper**: your own image or video (mp4, webm, mkv, mov; muted and looping, decoded
  with VA-API), on every screen. Videos also play live in the picker; for colours and the
  lock screen a still frame is taken with ffmpeg. `Super+Y` (or `gravity-shell wallpaper`)
  opens the picker: the wallpaper zooms out into a preview and three wallpapers rise from the
  bottom and float there. Left/Right (or the mouse wheel) scrolls them, Enter
  applies, Esc closes. It lists only your wallpaper folder: `Wallpapers` inside your Pictures
  folder (whatever it is called in your language, e.g. `~/Afbeeldingen/Wallpapers`), or the
  folder set as `wallpaperDir`. The folder is created the first time the picker opens.
  Beside the preview you pick light or dark: by hand, by the wallpaper (the preview shows
  each one's as you browse) or by time of day. `gravity-shell wallpaper ~/pic.jpg` sets one
  directly.
- **Colours**: a Material You palette made by [matugen](https://github.com/InioX/matugen)
  from one accent colour (GNOME's nine accents, or any other), or picked from the
  wallpaper. The default is GNOME's blue, built in so it works without matugen. GNOME apps
  get the nearest of their accents to match. Switch in the settings or the picker, which also
  offer matugen's scheme variants (tonal, vibrant, expressive, ...).
- **Bar**: a solid Material 3 Expressive style bar along the top edge (or the bottom, left
  or right; along a side its contents stack) that curves into the screen with inverted
  corners, with status in tonal pills and the clock in an accent pill.
  The niri workspaces are numbered circles in it; switching stretches an accent pill from
  the old one to the new one. It also holds the window title, the tray, a battery pill (on
  laptops), a status pill (network, Bluetooth and a volume icon) and a clock.
- **System monitor**: a pill in the bar with short bars for CPU and memory use. Click it
  (or `Super+M`) and the bar grows down into a panel with the last minute of CPU and memory
  use, every core, all temperature sensors and fans, memory and GPU use and the busiest
  processes.
- **Battery panel**: click the battery pill (laptops). The bar grows into a panel with the
  level, the power going in or out, energy left, battery health and charge cycles, the
  charge over the last 12 hours (from UPower's history), the power mode and the battery's
  make and charging mode. Also `gravity-shell ipc call battery toggle`.
- **Quick panel**: click the status pill. The cog opens the settings. Wi-Fi and Bluetooth tiles (the round icon
  switches them on or off, the rest of the tile unfolds the networks or devices to connect
  to, and asks for a Wi-Fi password in place), the audio output, volume and brightness
  sliders, Light/Dark and the power mode.
- **Light and dark**: the Light/Dark switch in the quick panel (or
  `gravity-shell ipc call appearance toggle`) turns the shell, niri's borders and every app
  light or dark. It sets GNOME's `color-scheme`, which GNOME (libadwaita) apps and, through
  the desktop portal, browsers and Flatpaks follow, and switches GTK 3 apps between
  `adw-gtk3` and `adw-gtk3-dark`. The shell's colours switch to their light variant.
  Changing the setting elsewhere (e.g. with gsettings) is picked up too. In the settings it can
  also go automatic: by the **wallpaper** (light when its average brightness is above 35%,
  measured with ffmpeg) or by **time of day**: light between sunrise and sunset where you
  live (worked out on the machine; the place is looked up once with Open-Meteo's place
  search). The quick panel's Light/Dark buttons grey out then; clicking one goes back to
  choosing by hand.
- **Settings** (`Super+Comma`, or the cog in the quick panel): the screen dims and a card
  springs up with a sidebar of pages. *Appearance*: light or dark, built-in or wallpaper
  colours and the scheme, the wallpaper and its folder. *Bar*: which edge it
  runs along and what it shows. *Wi-Fi*: on or off, the network you're on with its addresses,
  every network in range (join, with the password asked in place, or forget) and hidden
  networks. *Bluetooth*: on or off, visible to other devices, your devices (connect, rename,
  trust, forget) and devices nearby to pair. *Lock & clock*: idle lock time, 24-hour time and
  the date. Changes apply at once. Ctrl+Tab goes through the pages, Esc closes.
- **Session menu** (`Super+Shift+Q`): the screen dims and a card springs up with Lock,
  Suspend (locks first), Log out, Reboot, BIOS (reboot into the firmware setup; only when the
  machine supports it) and Power off. Left/Right or Tab picks one, Enter or a click runs it,
  Esc or a click outside closes. The number keys 1-6 run one after a three-second countdown
  (Enter skips it, Esc or any other key cancels), so a mispress can be undone.
- **Keybind cheatsheet** (`Super+F1`): the screen dims and a card springs up with all niri
  keybinds at once, grouped into blocks spread over even columns. The groups are the
  comments in the `binds` block of your niri config (a comment after a blank line starts
  one) and each bind shows its `hotkey-overlay-title`, or else its action. Esc or a click
  outside closes.
- **Notifications**: solid rounded cards drift in from the right, with the first action as an
  accent pill and the others tonal; when they expire they fall away.
- **Lock screen** (`Super+Alt+L`, or after 10 idle minutes): your wallpaper blurs in behind a
  bold clock, the date in a tonal pill and a password pill.
- **Password prompt for apps** (polkit): when an app or `pkexec` needs an administrator
  password, a card springs up with the same password pill, the request's message and a
  Cancel/Authenticate button group.

## Settings

Optional `~/.config/gravity-shell/config.json` (live-reloaded). The settings card and the
picker write it, storing only settings that differ from the defaults:

```json
{
  "wallpaper": "/path/to/image.jpg",
  "wallpaperDir": "~/Somewhere/Else",
  "colors": "wallpaper",
  "accent": "#3584e4",
  "colorScheme": "scheme-tonal-spot",
  "appearanceMode": "manual",
  "locationName": "Eindhoven, North Brabant, Netherlands",
  "latitude": 51.44,
  "longitude": 5.48,
  "idleLockMinutes": 10,
  "use24h": true,
  "showDate": true,
  "barPosition": "top",
  "barWorkspaces": true,
  "barTitle": true,
  "barClock": true,
  "barStats": true,
  "barTray": true,
  "barBattery": true,
  "barStatus": true
}
```

`"colors"` is `"default"`, `"accent"` (made from `"accent"`, a `#rrggbb` colour) or
`"wallpaper"`; `"appearanceMode"` is `"manual"`, `"wallpaper"` or `"sun"`; `"barPosition"` is `"top"`, `"bottom"`, `"left"`
or `"right"`. Generated colours are cached in
`~/.cache/gravity-shell/colors.json`. matugen can't read `.jxl` images, so with those the
default colours are used. From a terminal:

```sh
gravity-shell ipc call theme set wallpaper     # or: accent, default
gravity-shell ipc call theme accent "#e62d42"  # switches to accent colours
gravity-shell ipc call theme scheme vibrant
```

## Changing the shell itself

`cp -r /usr/share/gravity-shell ~/.config/quickshell/gravity`, then edit. `gravity-shell`
prefers that copy, and Quickshell reloads it live as you save.

Keybinds use the IPC targets `volume` (increase, decrease, muteOutput, muteInput),
`powerProfile` (cycle), `wallpaper` (toggle, set), `theme`, `appearance` (toggle, set
`light|dark`, auto `wallpaper|sun|manual`), `settings` (toggle, open `appearance|bar|wifi|bluetooth|general`), `lock`, `keybinds` (toggle), `session`
(toggle, run `lock|suspend|logout|reboot|firmware|poweroff`) and `polkit` (cancel).

Useful commands: `gravity-shell lock`, `gravity-shell wallpaper [image]`, `gravity-shell ipc show`, `gravity-shell log`.
