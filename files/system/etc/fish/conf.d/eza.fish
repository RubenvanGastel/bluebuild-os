# Use eza (with icons) instead of ls; fish doesn't read /etc/profile.d/eza.sh
if status is-interactive; and command -q eza
    alias ls 'eza --icons=auto --group-directories-first'
    alias ll 'eza -l --icons=auto --group-directories-first --git'
    alias la 'eza -la --icons=auto --group-directories-first --git'
    alias lt 'eza --tree --level=2 --icons=auto'
end
