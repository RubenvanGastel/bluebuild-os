# hyprland image ujust recipes (imported from /usr/share/ublue-os/justfile by setup-hyprland.sh)

# Make ~/.config/hypr/hyprland.lua for your own Hyprland settings: it loads the image's config first, then yours (keeps a backup of an existing one)
hyprland-user-config:
    #!/usr/bin/env bash
    set -euo pipefail
    file="${XDG_CONFIG_HOME:-$HOME/.config}/hypr/hyprland.lua"
    mkdir -p "$(dirname "$file")"
    if [ -e "$file" ]; then
        backup="$file.backup-$(date +%Y%m%d-%H%M%S)"
        mv "$file" "$backup"
        echo "Old config moved to $backup"
    fi
    cat >"$file" <<'LUA'
    -- Your Hyprland config. Settings below the next line win over the image's.
    dofile("/etc/xdg/hypr/hyprland.lua")

    -- Examples (remove the "--" in front to use them):
    -- hl.monitor({ output = "eDP-1", mode = "2560x1600@165", position = "0x0", scale = 1.6 })
    -- hl.config({ general = { gaps_in = 4, gaps_out = 8 } })
    -- The image's niri-like actions can be bound to other keys too:
    -- hl.bind("SUPER + L", function() niri.focus_column("right") end)
    -- hl.bind("SUPER + H", function() niri.focus_column("left") end)
    -- A key the image already uses runs both binds, so unbind it first:
    -- hl.unbind("SUPER + B")
    -- hl.bind("SUPER + B", hl.dsp.exec_cmd("firefox"))
    LUA
    echo "Made $file. Hyprland reloads it when you save it."
