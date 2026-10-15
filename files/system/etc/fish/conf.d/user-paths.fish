# Add ~/.local/bin and ~/bin to PATH like Fedora's ~/.bashrc does
# (claude, uv and other per-user tools install there); fish doesn't read it
fish_add_path --global --path ~/.local/bin ~/bin
