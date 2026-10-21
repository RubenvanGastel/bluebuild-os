# Image defaults for interactive zsh, close to what fish does out of the box:
# shared history, Tab completion with a menu, the usual editing keys and a short prompt.
# Override anything in your own ~/.zshrc, which is read after this.

# History, shared between open terminals as you go
HISTFILE=~/.zsh_history
HISTSIZE=50000
SAVEHIST=50000
setopt share_history hist_ignore_all_dups hist_ignore_space hist_reduce_blanks

setopt auto_cd interactive_comments no_beep

# Completion: a menu you can move through, case-insensitive, coloured like ls
autoload -Uz compinit
mkdir -p ~/.cache/zsh
compinit -d ~/.cache/zsh/zcompdump
zstyle ':completion:*' menu select
zstyle ':completion:*' matcher-list 'm:{a-zA-Z}={A-Za-z}' 'r:|[._-]=* r:|=*'
zstyle ':completion:*' list-colors ${(s.:.)LS_COLORS}
zstyle ':completion:*' use-cache on
zstyle ':completion:*' cache-path ~/.cache/zsh/zcompcache

# Keys: emacs style, plus Home/End/Delete, Ctrl+Left/Right by word,
# Ctrl+Backspace/Delete deletes a word, Up/Down search history for what you've typed
bindkey -e
autoload -Uz up-line-or-beginning-search down-line-or-beginning-search
zle -N up-line-or-beginning-search
zle -N down-line-or-beginning-search
bindkey '^[[A' up-line-or-beginning-search
bindkey '^[OA' up-line-or-beginning-search
bindkey '^[[B' down-line-or-beginning-search
bindkey '^[OB' down-line-or-beginning-search
bindkey '^[[H' beginning-of-line
bindkey '^[OH' beginning-of-line
bindkey '^[[F' end-of-line
bindkey '^[OF' end-of-line
bindkey '^[[3~' delete-char
bindkey '^[[1;5C' forward-word
bindkey '^[[1;5D' backward-word
bindkey '^H' backward-kill-word
bindkey '^[[3;5~' kill-word
bindkey '^[[Z' reverse-menu-complete

# Prompt: the folder, the git branch, and a ❯ that turns red when the last command failed;
# user@host only over SSH
autoload -Uz vcs_info
zstyle ':vcs_info:*' enable git
zstyle ':vcs_info:git:*' formats ' %F{magenta}%b%f'
zstyle ':vcs_info:git:*' actionformats ' %F{magenta}%b%f %F{yellow}(%a)%f'
precmd_functions+=(vcs_info)
setopt prompt_subst
PROMPT='%F{blue}%B%~%b%f${vcs_info_msg_0_} %(?.%F{cyan}.%F{red})❯%f '
[[ -n $SSH_CONNECTION ]] && PROMPT="%F{green}%n@%m%f $PROMPT"
RPROMPT=''
