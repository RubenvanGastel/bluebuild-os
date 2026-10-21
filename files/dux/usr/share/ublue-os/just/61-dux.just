# niri image ujust recipes (imported from /usr/share/ublue-os/justfile by setup-dux.sh)

# Give the login screen (Dux Greeter) your Dux Shell theme, wallpaper and settings; log out and back in afterwards
dux-greeter-sync:
    dms-greeter sync

# Replace ~/.config/niri with the image's Dux Shell config (keeps a backup), e.g. after rebasing from another image
dux-niri-config:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
    if [ -e "$dir" ]; then
        backup="$dir.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$dir" "$backup"
        echo "Old config moved to $backup"
    fi
    /usr/libexec/dux-niri-config
    echo "Done. Log out and back in to start Dux Shell."
