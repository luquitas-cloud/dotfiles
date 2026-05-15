# Modern CLI aliases
alias ls='eza --icons --git'
alias ll='eza -l --icons --git --header'
alias la='eza -la --icons --git'
alias cat='bat --paging=never'
alias find='fd'
alias grep='rg'
alias top='btop'

# Better history
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# Zoxide (smarter cd — use `z foldername`)
eval "$(zoxide init zsh)"

# Starship prompt
eval "$(starship init zsh)"

# FZF
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

eval "$(mise activate zsh)"
