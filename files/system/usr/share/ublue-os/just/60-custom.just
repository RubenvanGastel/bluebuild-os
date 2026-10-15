# Custom ujust recipes (run with: ujust <name>)

# Install Claude Code for the current user (~/.local/bin, auto-updates itself)
install-claude-code:
    #!/usr/bin/env bash
    set -euo pipefail
    curl -fsSL https://claude.ai/install.sh | bash
    echo "Done. Open a new terminal and run: claude"

# Install or update Antigravity IDE for the current user (~/.local/opt); run again to update
install-antigravity:
    #!/usr/bin/env bash
    set -euo pipefail
    # Google only publishes versioned links, so take the current one from the download page
    # (--compressed: the site sends gzip even when not asked)
    url=$(curl -fsSL --compressed 'https://antigravity.google/download?os=linux' \
        | grep -oE 'https://[^"]+/linux-x64/Antigravity%20IDE\.tar\.gz' | head -n1)
    if [ -z "$url" ]; then
        echo "Could not find the Linux download link on antigravity.google" >&2
        exit 1
    fi
    dest="$HOME/.local/opt/antigravity-ide"
    mkdir -p "$HOME/.local/opt" "$HOME/.local/bin" "$HOME/.local/share/applications"
    tmp=$(mktemp -d "$HOME/.local/opt/.antigravity-ide.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT
    echo "Downloading ${url##*/stable/}"
    curl -fL --progress-bar "$url" | tar xz -C "$tmp"
    rm -rf "$dest"
    mv "$tmp/Antigravity IDE" "$dest"
    ln -sf "$dest/bin/antigravity-ide" "$HOME/.local/bin/antigravity-ide"
    cat > "$HOME/.local/share/applications/antigravity-ide.desktop" <<EOF
    [Desktop Entry]
    Name=Antigravity IDE
    Comment=Experience liftoff
    GenericName=Text Editor
    Exec=$dest/bin/antigravity-ide %F
    Icon=$dest/resources/app/resources/linux/code.png
    Type=Application
    StartupNotify=false
    Categories=TextEditor;Development;IDE;
    Keywords=vscode;
    EOF
    echo "Done. Open Antigravity IDE from the app grid, or run: antigravity-ide"

# Make zsh your login shell (new users get it by default; run once for existing users)
set-shell-zsh:
    #!/usr/bin/env bash
    set -euo pipefail
    # skel is only copied for new users; without ~/.zshrc zsh shows its setup wizard
    [ -e "$HOME/.zshrc" ] || cp /etc/skel/.zshrc "$HOME/.zshrc"
    sudo usermod --shell /usr/bin/zsh "$USER"
    echo "Done. Log out and back in, then open a new terminal."
