#!/usr/bin/env bash
# Hooks the shared zsh config (/etc/zsh/custom.zsh, shipped via files/system) into
# Fedora's /etc/zshrc so every user gets it. ~/.zshrc is read afterwards, so
# per-user tweaks there still win.
set -euo pipefail

cat >> /etc/zshrc <<'EOF'

# gnome-os: shared zsh setup (history, completion, prompt, plugins)
[ -r /etc/zsh/custom.zsh ] && source /etc/zsh/custom.zsh
EOF
