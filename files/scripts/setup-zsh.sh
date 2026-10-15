#!/usr/bin/env bash
# Hooks the shared zsh config (/etc/zsh/custom.zsh, shipped via files/system) into
# Fedora's /etc/zshrc so every user gets it. ~/.zshrc is read afterwards, so
# per-user tweaks there still win.
set -euo pipefail

cat >> /etc/zshrc <<'EOF'

# gnome-os: shared zsh setup (history, completion, prompt, plugins)
[ -r /etc/zsh/custom.zsh ] && source /etc/zsh/custom.zsh
EOF

# New users get zsh as their login shell (existing users: ujust set-shell-zsh)
sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd

# Powerlevel10k prompt (not packaged in Fedora). Loaded from /etc/zsh/custom.zsh.
P10K_VERSION=v1.20.0
p10k_dir=/usr/share/zsh-theme-powerlevel10k
mkdir -p "$p10k_dir"
curl -fsSL "https://github.com/romkatv/powerlevel10k/archive/refs/tags/${P10K_VERSION}.tar.gz" |
    tar xz --strip-components=1 -C "$p10k_dir"
# Ship gitstatusd (fast git status for the prompt) in the image; otherwise every
# user downloads it to ~/.cache on first start
GITSTATUS_CACHE_DIR="$p10k_dir/gitstatus/usrbin" sh "$p10k_dir/gitstatus/install" -f
