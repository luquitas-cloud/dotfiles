path_prepend_once() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

# Modern CLI aliases
alias ls='eza --icons --git'
alias ll='eza -l --icons --git --header'
alias la='eza -la --icons --git'
# Disabled - break scripts that expect POSIX behavior:
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
eval "$(direnv hook zsh)"
[ -f ~/.fzf.zsh ] && source ~/.fzf.zsh

# fzf fuzzy finder previews (powered by fd and bat)
export FZF_DEFAULT_COMMAND='fd --type f --strip-cwd-prefix --hidden --follow --exclude .git'
export FZF_CTRL_T_COMMAND="$FZF_DEFAULT_COMMAND"
export FZF_DEFAULT_OPTS="
  --height 45% 
  --layout=reverse 
  --border 
  --info=inline
  --preview 'if [ -d {} ]; then eza --icons --git --color=always {}; else bat --color=always --style=numbers --line-range :500 {}; fi'
  --preview-window='right:55%:wrap'
"


# bat - inherit terminal palette
export BAT_THEME="ansi"

# API keys from 1Password (cached per session)
[ -f ~/.config/zsh/op-keys.zsh ] && source ~/.config/zsh/op-keys.zsh

# Machine-local overrides (not tracked)
[ -f ~/.config/zsh/local.zsh ] && source ~/.config/zsh/local.zsh

# Tool paths added by installers. Keep these idempotent so nested agent shells
# do not duplicate PATH entries.
path_prepend_once "$HOME/.local/bin"

eval "$(mise activate zsh)"
unset -f path_prepend_once


# >>> grok installer >>>
export PATH="$HOME/.grok/bin:$PATH"
fpath=(~/.grok/completions/zsh $fpath)
autoload -Uz compinit && compinit -C
# <<< grok installer <<<
