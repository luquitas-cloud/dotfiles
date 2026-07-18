#!/usr/bin/env bash
# Install the tracked dotfiles into HOME without backups or silent replacement.
set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")" && pwd)
HOME_DIR=${HOME:?HOME must be set}
MODE=install
REPLACE=0

usage() {
  cat <<'EOF'
Usage: install.sh [--check] [--dry-run] [--replace]

  no option   Install missing links and update already-managed links.
  --check     Read-only verification of all managed links and the agent pack.
  --dry-run   Show planned targets without changing the machine.
  --replace   Replace unmanaged file or symlink collisions without backups.
              Directories are never removed.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      [ "$MODE" = install ] || { usage >&2; exit 2; }
      MODE=check
      ;;
    --dry-run)
      [ "$MODE" = install ] || { usage >&2; exit 2; }
      MODE=dry-run
      ;;
    --replace) REPLACE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

if [ "$MODE" = check ] && [ "$REPLACE" -eq 1 ]; then
  usage >&2
  exit 2
fi

FILES=(
  ".zshrc"
  ".zprofile"
  ".gitconfig"
  ".config/ghostty/config"
  ".config/mise/config.toml"
  ".config/zsh/op-keys.zsh"
)

log() { printf '%s\n' "$*"; }
fail() { printf 'FAIL      %s\n' "$1" >&2; return 1; }

for rel in "${FILES[@]}"; do
  [ -f "$DOTFILES/$rel" ] && [ -r "$DOTFILES/$rel" ] || fail "missing source: $DOTFILES/$rel"
done
[ -f "$DOTFILES/agents/install.sh" ] || fail "missing agent installer: $DOTFILES/agents/install.sh"

check_link() {
  local rel="$1" src="$DOTFILES/$1" dst="$HOME_DIR/$1"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && [ -e "$dst" ]; then
    log "ok        $dst -> $src"
  else
    fail "$dst should link to $src"
  fi
}

plan_link() {
  local rel="$1" src="$DOTFILES/$1" dst="$HOME_DIR/$1"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && [ -e "$dst" ]; then
    log "ok        $dst -> $src"
  elif [ -e "$dst" ] || [ -L "$dst" ]; then
    log "collision $dst (would require --replace after inspection)"
  else
    log "plan      $dst -> $src"
  fi
}

install_link() {
  local rel="$1" src="$DOTFILES/$1" dst="$HOME_DIR/$1" current tmp
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && [ -e "$dst" ]; then
    log "ok        $dst -> $src"
    return
  fi
  if [ -d "$dst" ] && [ ! -L "$dst" ]; then
    fail "refusing to replace directory: $dst"
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -L "$dst" ]; then
      current=$(readlink "$dst")
      case "$current" in
        "$DOTFILES"/*) ;;
        *) [ "$REPLACE" -eq 1 ] || fail "unmanaged symlink collision at $dst -> $current" ;;
      esac
    else
      [ "$REPLACE" -eq 1 ] || fail "unmanaged file collision at $dst; inspect it before using --replace"
    fi
  fi
  tmp=$(mktemp "$(dirname "$dst")/.dotfiles-link.XXXXXX")
  unlink "$tmp"
  if ! ln -s "$src" "$tmp"; then
    fail "unable to stage symlink for $dst"
  fi
  if [ -L "$dst" ] && ! unlink "$dst"; then
    unlink "$tmp"
    fail "unable to unlink existing symlink: $dst"
  fi
  if ! mv -f "$tmp" "$dst"; then
    [ ! -L "$tmp" ] || unlink "$tmp"
    fail "unable to install staged symlink: $dst"
  fi
  log "installed $dst -> $src"
}

case "$MODE" in
  check)
    log "Dotfiles check"
    for rel in "${FILES[@]}"; do check_link "$rel"; done
    bash "$DOTFILES/agents/install.sh" --check
    ;;
  dry-run)
    log "Dotfiles dry run"
    for rel in "${FILES[@]}"; do plan_link "$rel"; done
    if [ "$REPLACE" -eq 1 ]; then
      bash "$DOTFILES/agents/install.sh" --dry-run --replace
    else
      bash "$DOTFILES/agents/install.sh" --dry-run
    fi
    ;;
  install)
    # Refuse all unmanaged collisions before changing any link.
    for rel in "${FILES[@]}"; do
      dst="$HOME_DIR/$rel"
      if [ -d "$dst" ] && [ ! -L "$dst" ]; then
        fail "refusing to replace directory: $dst"
      fi
      if [ -e "$dst" ] || [ -L "$dst" ]; then
        if [ -L "$dst" ]; then
          current=$(readlink "$dst")
          if [ "$current" != "$DOTFILES/$rel" ]; then
            case "$current" in
              "$DOTFILES"/*) ;;
              *) [ "$REPLACE" -eq 1 ] || fail "unmanaged symlink collision at $dst -> $current" ;;
            esac
          fi
        elif [ "$REPLACE" -ne 1 ]; then
          fail "unmanaged file collision at $dst; inspect it before using --replace"
        fi
      fi
    done

    # Verify every agent-pack target before changing root-level links.
    if [ "$REPLACE" -eq 1 ]; then
      bash "$DOTFILES/agents/install.sh" --dry-run --replace
    else
      bash "$DOTFILES/agents/install.sh" --dry-run
    fi

    log "Dotfiles install"
    for rel in "${FILES[@]}"; do install_link "$rel"; done
    if [ "$REPLACE" -eq 1 ]; then
      bash "$DOTFILES/agents/install.sh" --replace
    else
      bash "$DOTFILES/agents/install.sh"
    fi
    ;;
esac
