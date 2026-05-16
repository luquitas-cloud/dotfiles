# 1Password-backed API keys with per-session caching.
# Requires the 1Password desktop app signed in + `op` CLI authorized.
# Cache TTL: 8h. Cache lives at /tmp/op-cache-$UID (mode 0600).

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

_op_load ANTHROPIC_API_KEY "op://Vault/Item/credential"
# Add more as needed:
# _op_load OPENAI_API_KEY "op://Vault/Item/credential"
# _op_load GROQ_API_KEY   "op://Vault/Item/credential"

unset _op_cache
unfunction _op_load
