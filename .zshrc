path_prepend_once() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

# Modern CLI aliases
if command -v eza >/dev/null 2>&1; then
  alias ls='eza --icons --git'
  alias ll='eza -l --icons --git --header'
  alias la='eza -la --icons --git'
fi
# Disabled - break scripts that expect POSIX behavior:
#   alias cat='bat --paging=never'
#   alias find='fd'
#   alias grep='rg'
command -v btop >/dev/null 2>&1 && alias top='btop'

# History
HISTSIZE=50000
SAVEHIST=50000
setopt HIST_IGNORE_DUPS HIST_IGNORE_SPACE

# Shell integrations
command -v zoxide >/dev/null 2>&1 && eval "$(zoxide init zsh)"
if [ "${TERM:-}" != "dumb" ] && command -v starship >/dev/null 2>&1; then
  eval "$(starship init zsh)"
fi
command -v direnv >/dev/null 2>&1 && eval "$(direnv hook zsh)"
[ ! -f "$HOME/.fzf.zsh" ] || source "$HOME/.fzf.zsh"

# fzf fuzzy finder previews (powered by fd, bat, and eza)
if command -v fd >/dev/null 2>&1 && command -v bat >/dev/null 2>&1 && command -v eza >/dev/null 2>&1; then
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
fi


# bat - inherit terminal palette
export BAT_THEME="ansi"

# API keys from 1Password (cached per session)
[ -f ~/.config/zsh/op-keys.zsh ] && source ~/.config/zsh/op-keys.zsh

# Machine-local overrides (not tracked)
[ -f ~/.config/zsh/local.zsh ] && source ~/.config/zsh/local.zsh

# Tool paths added by installers. Keep these idempotent so nested agent shells
# do not duplicate PATH entries.
path_prepend_once "$HOME/.local/bin"
path_prepend_once "$HOME/.grok/bin"

# Stay silent when aligned; report agent-policy drift at interactive login.
if [[ -o interactive ]] && [ -x "$HOME/dotfiles/agents/login-check.sh" ]; then
  "$HOME/dotfiles/agents/login-check.sh" || true
fi

if [ -d "$HOME/.grok/completions/zsh" ]; then
  case " ${fpath[*]} " in
    *" $HOME/.grok/completions/zsh "*) ;;
    *) fpath=("$HOME/.grok/completions/zsh" $fpath) ;;
  esac
  autoload -Uz compinit && compinit -C
fi

# Activate mise last so its managed tool versions take PATH precedence.
command -v mise >/dev/null 2>&1 && eval "$(mise activate zsh)"
unset -f path_prepend_once
