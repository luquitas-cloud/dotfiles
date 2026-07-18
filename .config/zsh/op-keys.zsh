# 1Password-backed API keys with private per-user caching.
# Requires the 1Password desktop app signed in + `op` CLI authorized.
# Cache TTL: 8h. Cache lives below the user's macOS TMPDIR.
#
# PUBLIC-SAFE: no real vault item paths in this file.
# Put real _op_load lines in ~/.config/zsh/op-keys.local.zsh (gitignored).

_op_old_umask="$(umask)"
umask 077
_op_cache_dir="${TMPDIR:-/tmp}/op-cache-$UID"
_op_cache="$_op_cache_dir/exports.zsh"

if [ -e "$_op_cache_dir" ] && { [ ! -d "$_op_cache_dir" ] || [ -L "$_op_cache_dir" ] || [ ! -O "$_op_cache_dir" ]; }; then
  print -u2 "Refusing unsafe 1Password cache directory: $_op_cache_dir"
  umask "$_op_old_umask"
  unset _op_old_umask _op_cache_dir _op_cache
  return 1
fi

mkdir -p "$_op_cache_dir"
chmod 700 "$_op_cache_dir"
if [ "$(stat -f '%Lp' "$_op_cache_dir" 2>/dev/null)" != "700" ]; then
  print -u2 "Refusing 1Password cache directory with unsafe permissions: $_op_cache_dir"
  umask "$_op_old_umask"
  unset _op_old_umask _op_cache_dir _op_cache
  return 1
fi

if [ -L "$_op_cache" ]; then
  print -u2 "Refusing 1Password cache symlink: $_op_cache"
  umask "$_op_old_umask"
  unset _op_old_umask _op_cache_dir _op_cache
  return 1
fi

# Expire cache after 8h
if [ -f "$_op_cache" ] && [ "$(find "$_op_cache" -mmin +480 2>/dev/null)" ]; then
  unlink "$_op_cache"
fi

# Load only a regular, user-owned cache with private permissions.
if [ -f "$_op_cache" ] && [ ! -L "$_op_cache" ] && [ -O "$_op_cache" ]; then
  if [ "$(stat -f '%Lp' "$_op_cache" 2>/dev/null)" = "600" ]; then
    [ ! -s "$_op_cache" ] || source "$_op_cache"
  else
    print -u2 "Ignoring 1Password cache with unsafe permissions: $_op_cache"
  fi
fi

# _op_load VAR "op://vault/item/field"
#   - skip if already set (from cache or parent env)
#   - skip silently if op isn't signed in
_op_load() {
  local var="$1" path="$2" val
  [ -n "${(P)var:-}" ] && return 0
  op whoami &>/dev/null || return 1
  val="$(op read "$path" 2>/dev/null)" || return 1
  [ -z "$val" ] && return 1
  if [ ! -e "$_op_cache" ]; then
    : > "$_op_cache"
    chmod 600 "$_op_cache"
  fi
  [ -f "$_op_cache" ] && [ ! -L "$_op_cache" ] && [ -O "$_op_cache" ] || return 1
  printf 'export %s=%q\n' "$var" "$val" >> "$_op_cache"
  chmod 600 "$_op_cache"
  export "$var=$val"
}

# Machine-local loads (not in public git):
#   ~/.config/zsh/op-keys.local.zsh
# Example lines for that file:
#   _op_load SOME_API_KEY "op://Vault/Item/credential"

if [ -f "$HOME/.config/zsh/op-keys.local.zsh" ] && [ ! -L "$HOME/.config/zsh/op-keys.local.zsh" ] && [ -O "$HOME/.config/zsh/op-keys.local.zsh" ]; then
  # shellcheck disable=SC1090
  source "$HOME/.config/zsh/op-keys.local.zsh"
fi

umask "$_op_old_umask"
unset _op_old_umask _op_cache_dir _op_cache
unfunction _op_load
