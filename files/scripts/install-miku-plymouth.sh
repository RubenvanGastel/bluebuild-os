#!/usr/bin/env bash
# Installs the MikuPlymouth boot theme (https://github.com/Thang1191/MikuPlymouth)
# and sets it as the default. Pinned to a commit and checked against a known sha256.
# Upstream's install.sh picks 10 random clips from the pool, so every image build
# gets a fresh selection. The initramfs is regenerated later by the initramfs module.
set -euo pipefail

COMMIT=2ffca526cc3c0fffb95dd2b8c0fd2bc11377a5db
SHA256=30ebb1c906ef9e9a58c8329a3c80f738526117ee78f09cec24dbfd5270a8f2f3

tmp=$(mktemp -d)
trap 'rm -rf "$tmp"' EXIT

curl -fsSL -o "$tmp/miku.tar.gz" \
    "https://github.com/Thang1191/MikuPlymouth/archive/${COMMIT}.tar.gz"
echo "${SHA256}  $tmp/miku.tar.gz" | sha256sum -c -

mkdir "$tmp/src"
tar xzf "$tmp/miku.tar.gz" -C "$tmp/src" --strip-components=1 \
    --exclude='*.mp4'

# Run upstream's installer up to (not including) its initramfs rebuild step,
# which can't run inside a container build.
cd "$tmp/src"
sed '/Step 6/,$d' install.sh > install-no-initramfs.sh
bash install-no-initramfs.sh

test -f /usr/share/plymouth/themes/MikuPlymouth/MikuPlymouth.script

mkdir -p /etc/plymouth
cat > /etc/plymouth/plymouthd.conf <<'EOF'
[Daemon]
Theme=MikuPlymouth
EOF
