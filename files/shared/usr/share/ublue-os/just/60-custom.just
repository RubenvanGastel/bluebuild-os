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

# Install JetBrains Toolbox for the current user (~/.local/opt); it installs and updates the IDEs, and itself
# (what Bluefin and Bazzite do with Homebrew's ublue-os/tap cask, without needing brew)
install-jetbrains-toolbox:
    #!/usr/bin/env bash
    set -euo pipefail
    # The current release's tarball and its checksum, from JetBrains' releases API
    release=$(curl -fsSL 'https://data.services.jetbrains.com/products/releases?code=TBA&latest=true&type=release')
    url=$(jq -r '.TBA[0].downloads.linux.link' <<<"$release")
    sum=$(jq -r '.TBA[0].downloads.linux.checksumLink' <<<"$release")
    if [ -z "$url" ] || [ "$url" = null ]; then
        echo "Could not find the Linux download on data.services.jetbrains.com" >&2
        exit 1
    fi
    dest="$HOME/.local/opt/jetbrains-toolbox"
    mkdir -p "$HOME/.local/opt" "$HOME/.local/bin" "$HOME/.local/share/applications"
    tmp=$(mktemp -d "$HOME/.local/opt/.jetbrains-toolbox.XXXXXX")
    trap 'rm -rf "$tmp"' EXIT
    echo "Downloading ${url##*/}"
    curl -fL --progress-bar -o "$tmp/toolbox.tar.gz" "$url"
    (cd "$tmp" && echo "$(curl -fsSL "$sum" | cut -d' ' -f1)  toolbox.tar.gz" | sha256sum -c --quiet)
    tar xzf "$tmp/toolbox.tar.gz" -C "$tmp" --strip-components=1
    rm "$tmp/toolbox.tar.gz"
    rm -rf "$dest"
    mv "$tmp" "$dest"
    trap - EXIT
    ln -sf "$dest/bin/jetbrains-toolbox" "$HOME/.local/bin/jetbrains-toolbox"
    # Toolbox writes its own launcher (and icon) on first run; this one gets it there
    cat > "$HOME/.local/share/applications/jetbrains-toolbox.desktop" <<DESKTOP
    [Desktop Entry]
    Name=JetBrains Toolbox
    Exec=$dest/bin/jetbrains-toolbox %u
    Icon=$dest/bin/toolbox.svg
    Type=Application
    Categories=Development;
    StartupWMClass=jetbrains-toolbox
    Terminal=false
    MimeType=x-scheme-handler/jetbrains;
    StartupNotify=false
    DESKTOP
    setsid -f "$dest/bin/jetbrains-toolbox" >/dev/null 2>&1 || true
    echo "Done. JetBrains Toolbox is starting; install IDEs from it (they go in ~/.local/share/JetBrains)."
