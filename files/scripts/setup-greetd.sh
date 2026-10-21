#!/usr/bin/env bash
# gravity and niri images: keep Fedora's PAM config for the greetd login screen.
set -euo pipefail

# dms-greeter's install script writes its own /etc/pam.d/greetd when there is none, which
# hides Fedora's /usr/lib/pam.d/greetd; Fedora's also unlocks GNOME Keyring at login.
if [ -f /usr/lib/pam.d/greetd ]; then
    rm -f /etc/pam.d/greetd
fi
