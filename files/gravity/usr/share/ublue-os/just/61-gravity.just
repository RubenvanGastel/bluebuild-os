# gravity image ujust recipes (imported from /usr/share/ublue-os/justfile by setup-gravity.sh)

# Move ~/.config/niri aside (keeps a backup) so niri uses the image's Gravity config, e.g. after rebasing from another image
gravity-niri-config:
    #!/usr/bin/env bash
    set -euo pipefail
    dir="${XDG_CONFIG_HOME:-$HOME/.config}/niri"
    if [ ! -e "$dir" ]; then
        echo "No $dir, niri already uses the Gravity config in /etc/niri."
        exit 0
    fi
    backup="$dir.backup-$(date +%Y%m%d-%H%M%S)"
    mv "$dir" "$backup"
    echo "Old config moved to $backup"
    echo "Done. Log out and back in to start the Gravity shell."
