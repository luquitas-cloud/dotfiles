# Modern CLI aliases
alias ls='eza --icons --git'
alias ll='eza -l --icons --git --header'
alias la='eza -la --icons --git'
# disabled - breaks - alias cat='bat --paging=never'
# disabled - breaks - alias find='fd'
# alias grep='rg'  # disabled — breaks scripts; use `rg` explicitly
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

# 1Password-backed API keys (cached per session)
_op_cache="/tmp/op-cache-$UID"

# Clear cache older than 8 hours
if [ -f "$_op_cache" ] && [ "$(find "$_op_cache" -mmin +480 2>/dev/null)" ]; then
  rm -f "$_op_cache"
fi

# Load from cache if available, else fetch from 1Password
if [ -z "$ANTHROPIC_API_KEY" ]; then
  if [ -f "$_op_cache" ] && [ -s "$_op_cache" ]; then
    source "$_op_cache"
  elif op whoami &>/dev/null; then
    _key="$(op read 'op://Personal/Anthropic API Key/credential' 2>/dev/null)"
    if [ -n "$_key" ]; then
      echo "export ANTHROPIC_API_KEY='$_key'" > "$_op_cache"
      chmod 600 "$_op_cache"
      export ANTHROPIC_API_KEY="$_key"
    fi
    unset _key
  fi
fi
unset _op_cache
