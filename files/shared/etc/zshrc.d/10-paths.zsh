# Add ~/.local/bin and ~/bin to PATH like Fedora's ~/.bashrc does
# (claude, uv and other per-user tools install there); zsh doesn't read it
typeset -U path
path=(~/.local/bin ~/bin $path)
