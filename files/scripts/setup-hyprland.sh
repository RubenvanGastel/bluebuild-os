#!/usr/bin/env bash
# hyprland images: the Hyprland session's systemd target, and the Hyprland ujust recipes.
set -euo pipefail

# Hyprland starts hyprland-session.target (which starts graphical-session.target: the polkit
# agent, XDG autostart, ...). Some Hyprland packages put it in /usr/lib64/systemd/user,
# where systemd doesn't look; then it's copied to where it does. Its drop-in is in
# files/hyprland.
target=hyprland-session.target
if [ ! -f "/usr/lib/systemd/user/$target" ] && [ -f "/usr/lib64/systemd/user/$target" ]; then
    cp "/usr/lib64/systemd/user/$target" "/usr/lib/systemd/user/$target"
fi

# ujust only imports 60-custom.just by itself (shared by all images)
justfile=/usr/share/ublue-os/justfile
if ! grep -q '61-hyprland.just' "$justfile"; then
    echo 'import "/usr/share/ublue-os/just/61-hyprland.just"' >>"$justfile"
fi
