#!/usr/bin/env bash
# zsh as the default shell: new users get it from useradd, and /etc/zshrc loads the
# image defaults in /etc/zshrc.d (Fedora's zsh has no drop-in directory of its own),
# without zsh's first-run wizard.
set -euo pipefail

sed -i 's|^SHELL=.*|SHELL=/usr/bin/zsh|' /etc/default/useradd
grep -qx 'SHELL=/usr/bin/zsh' /etc/default/useradd

if ! grep -q '/etc/zshrc.d' /etc/zshrc; then
    cat >>/etc/zshrc <<'EOF'

# gnome-os: image defaults (prompt, completion, keys, plugins); ~/.zshrc comes after
for _zshrc_d in /etc/zshrc.d/*.zsh(N); do
    source "$_zshrc_d"
done
unset _zshrc_d
EOF
fi

# No first-run wizard for users without a ~/.zshrc: the image defaults already cover it.
# zsh runs it right after /etc/zshenv, so an empty one defined there wins.
if ! grep -q 'zsh-newuser-install' /etc/zshenv; then
    cat >>/etc/zshenv <<'EOF'

# gnome-os: skip zsh's first-run wizard, the image defaults are in /etc/zshrc.d
zsh-newuser-install() { :; }
EOF
fi
