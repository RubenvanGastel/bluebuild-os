# Shared zsh setup for every user, sourced at the end of /etc/zshrc.
# Fedora's /etc/zshrc already sources /etc/profile.d, so the eza aliases work here too.
# Per-user tweaks go in ~/.zshrc, which is read after this file.

# Powerlevel10k instant prompt: shows the prompt right away while the rest loads.
# Must stay at the top; anything that asks for input goes above this block.
if [[ -r "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh" ]]; then
    source "${XDG_CACHE_HOME:-$HOME/.cache}/p10k-instant-prompt-${(%):-%n}.zsh"
fi

# History: big, shared between open terminals, no duplicates
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt share_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks extended_history

setopt auto_cd interactive_comments no_beep
bindkey -e

# Completion: arrow-key menu, case-insensitive, colored like ls
autoload -Uz compinit && compinit
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}'
zstyle ':completion:*' list-colors "${(s.:.)LS_COLORS}"

# Up/Down search history for commands starting with what's already typed
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search

# Keys that zsh doesn't map by default: Home/End/Delete, Ctrl+Left/Right by word
bindkey '^[[H' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word

# Prompt: Powerlevel10k with the shared config in /etc/zsh/p10k.zsh.
# `p10k configure` writes ~/.p10k.zsh, which is used instead when it exists.
source /usr/share/zsh-theme-powerlevel10k/powerlevel10k.zsh-theme
if [[ -r ~/.p10k.zsh ]]; then
    source ~/.p10k.zsh
else
    source /etc/zsh/p10k.zsh
fi

# Plugins (syntax highlighting must be sourced last)
[ -r /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh ] &&
    source /usr/share/zsh-autosuggestions/zsh-autosuggestions.zsh
[ -r /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh ] &&
    source /usr/share/zsh-syntax-highlighting/zsh-syntax-highlighting.zsh
