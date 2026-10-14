#!/usr/bin/env bash
# Install the MoreWaita icon theme system-wide from upstream GitHub.
# (The Fedora COPR builds are outdated, so we fetch the source directly.)
set -euo pipefail

DEST=/usr/share/icons/MoreWaita
TMP=$(mktemp -d)

curl -fsSL https://github.com/somepaulo/MoreWaita/archive/refs/heads/main.tar.gz \
  | tar -xz -C "$TMP" --strip-components=1

mkdir -p "$DEST"
cp -a "$TMP"/. "$DEST"/

# Remove repo files that aren't part of the icon theme
rm -rf "$DEST"/{.git*,*.sh,*.md,*.py,LICENSE*,_dev,.github} 2>/dev/null || true

gtk-update-icon-cache -f -t "$DEST" || true
rm -rf "$TMP"
