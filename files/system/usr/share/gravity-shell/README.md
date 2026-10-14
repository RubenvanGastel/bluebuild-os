# Gravity shell

A Quickshell desktop for niri inspired by Gravity Rush: Hekseville at dusk, with floating
islands, crates, street lamps and gems drifting in a shared "gravity field".

- **Wallpaper**: animated floating city. Switching workspaces shifts gravity (things swing
  up when you move down the strip, sideways when you scroll columns), with a violet ripple.
  Every minute or so a random gravity storm passes through.
- **Bar**: a floating island that drops in on login and sways with gravity shifts.
  It holds niri workspace orbs, the window title, the tray, volume, battery and a clock.
- **Notifications**: cards drift in from the right; when they expire they fall away.
- **Lock screen** (`Super+Alt+L`, or after 10 idle minutes): the desktop floats up and blurs
  into the scene, and the clock digits fall into place. Your password appears as gems; a
  wrong one makes them tumble. On unlock the desktop drops back into place.

## How the lock stays seamless

Every moving thing is a pure function of the shared scene time (`services/Gravity.qml`) and
fixed seeds, so the wallpaper, the transition overlay (`modules/lock/Curtain.qml`) and the
lock surface all draw identical frames. Locking snapshots the desktop with screencopy and
animates that picture away before the real session lock engages on an identical frame.
Unlocking freezes scene time, draws that frozen frame on a fresh overlay, unlocks underneath
it, and then lets the desktop picture fall back in before fading to the live desktop.

## Settings

Optional `~/.config/gravity-shell/config.json` (live-reloaded):

```json
{
  "wallpaper": "/path/to/image.jpg",
  "animatedBackground": true,
  "debrisCount": 18,
  "starCount": 90,
  "ambientShifts": true,
  "idleLockMinutes": 10,
  "use24h": true
}
```

`"animatedBackground": false` freezes the scene. On battery this takes the shell from
roughly a tenth of a CPU core to near zero.

## Changing the shell itself

`cp -r /usr/share/gravity-shell ~/.config/quickshell/gravity`, then edit. `gravity-shell`
prefers that copy, and Quickshell reloads it live as you save.

Useful commands: `gravity-shell lock`, `gravity-shell ipc show`, `gravity-shell log`.
