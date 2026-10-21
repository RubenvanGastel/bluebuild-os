# Use eza (with icons) instead of ls in interactive shells
if [ -n "$PS1" ] && command -v eza >/dev/null 2>&1; then
    alias ls='eza --icons=auto --group-directories-first'
    alias ll='eza -l --icons=auto --group-directories-first --git'
    alias la='eza -la --icons=auto --group-directories-first --git'
    alias lt='eza --tree --level=2 --icons=auto'
fi
