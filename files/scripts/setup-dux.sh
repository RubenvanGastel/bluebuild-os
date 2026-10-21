#!/usr/bin/env bash
# niri images: add the Dux ujust recipes.
set -euo pipefail

# ujust only imports 60-custom.just by itself (shared by all images)
justfile=/usr/share/ublue-os/justfile
if ! grep -q '61-dux.just' "$justfile"; then
    echo 'import "/usr/share/ublue-os/just/61-dux.just"' >>"$justfile"
fi
