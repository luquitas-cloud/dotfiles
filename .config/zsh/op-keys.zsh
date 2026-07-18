# 1Password-backed API keys with per-session caching.
# Requires the 1Password desktop app signed in + `op` CLI authorized.
# Cache TTL: 8h. Cache lives at /tmp/op-cache-$UID (mode 0600).
#
# PUBLIC-SAFE: no real vault item paths in this file.
# Put real _op_load lines in ~/.config/zsh/op-keys.local.zsh (gitignored).

_op_cache="/tmp/op-cache-$UID"

# Expire cache after 8h
if [ -f "$_op_cache" ] && [ "$(find "$_op_cache" -mmin +480 2>/dev/null)" ]; then
  rm -f "$_op_cache"
fi

# Load cached exports if present
[ -f "$_op_cache" ] && [ -s "$_op_cache" ] && source "$_op_cache"

# _op_load VAR "op://vault/item/field"
#   - skip if already set (from cache or parent env)
#   - skip silently if op isn't signed in
_op_load() {
  local var="$1" path="$2" val
  [ -n "${(P)var:-}" ] && return 0
  op whoami &>/dev/null || return 1
  val="$(op read "$path" 2>/dev/null)" || return 1
  [ -z "$val" ] && return 1
  echo "export $var='$val'" >> "$_op_cache"
  chmod 600 "$_op_cache"
  export "$var=$val"
}

# Machine-local loads (not in public git):
#   ~/.config/zsh/op-keys.local.zsh
# Example lines for that file:
#   _op_load SOME_API_KEY "op://Vault/Item/credential"

if [ -f "$HOME/.config/zsh/op-keys.local.zsh" ]; then
  # shellcheck disable=SC1090
  source "$HOME/.config/zsh/op-keys.local.zsh"
fi

unset _op_cache
unfunction _op_load
