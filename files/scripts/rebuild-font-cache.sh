#!/usr/bin/env bash
# Rebuilds the system font cache after the fonts module. ostree resets every
# timestamp to 1970, so fontconfig can't tell that a cache built before the
# Nerd Font was added is outdated, and terminals never find the icon glyphs.
set -euo pipefail

fc-cache --force --system-only
