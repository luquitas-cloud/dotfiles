# Modern CLI aliases
alias ls='eza --icons --git'
alias ll='eza -l --icons --git --header'
alias la='eza -la --icons --git'
# Disabled — break scripts that expect POSIX behavior:
#   alias cat='bat --paging=never'
#   alias find='fd'
#   alias grep='rg'
alias top='btop'

# History
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# Shell integrations
eval "$(zoxide init zsh)"
eval "$(starship init zsh)"
eval "$(mise activate zsh)"
eval "$(direnv hook zsh)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# bat — inherit terminal palette
export BAT_THEME="ansi"

# API keys from 1Password (cached per session)
[ -f ~/.config/zsh/op-keys.zsh ] && source ~/.config/zsh/op-keys.zsh
