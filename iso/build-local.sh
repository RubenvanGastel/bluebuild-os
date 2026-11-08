#!/usr/bin/env bash
# Build the installer ISO on this computer, the same way the build-iso workflow does.
# Usage: iso/build-local.sh [image]     (default: gravity; needs sudo)
# The ISO ends up in ~/Downloads/<image>.iso, where GNOME Boxes can open it.
set -euo pipefail

image="${1:-gravity}"
here="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
out="$HOME/Downloads"
work="$(mktemp -d)"
trap 'sudo rm -rf "$work"' EXIT

echo "==> Building the live image for $image (downloads the image and its Flatpaks)"
sudo podman build \
    --cap-add sys_admin --security-opt label=disable --squash \
    --pull=always --build-arg IMAGE="$image" \
    -t "localhost/$image-live:latest" \
    "$here"

echo "==> Building the ISO with Titanoboa"
git clone --depth 1 https://github.com/ublue-os/titanoboa "$work/titanoboa"
mkdir -p "$work/output"
TITANOBOA_OUTPUT_DIR="$work/output" "$work/titanoboa/main.sh" "localhost/$image-live:latest"

mkdir -p "$out"
sudo mv "$work"/output/*.iso "$out/$image.iso"
sudo chown "$(id -u):$(id -g)" "$out/$image.iso"
ls -lh "$out/$image.iso"
echo "==> Done. Free the space again with: sudo podman rmi localhost/$image-live:latest"
