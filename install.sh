#!/usr/bin/env bash
set -euo pipefail
cd "$(dirname "$0")"
DOTFILES="$(pwd)"
BACKUP="$DOTFILES/.backup-$(date +%Y%m%d-%H%M%S)"

declare -a FILES=(
  ".zshrc"
  ".zprofile"
  ".gitconfig"
  ".config/ghostty/config"
  ".config/mise/config.toml"
  ".config/zsh/op-keys.zsh"
)

backup_made=0
for rel in "${FILES[@]}"; do
  src="$DOTFILES/$rel"
  dst="$HOME/$rel"
  mkdir -p "$(dirname "$dst")"

  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    echo "ok        $rel"
    continue
  fi

  if [ -e "$dst" ] || [ -L "$dst" ]; then
    mkdir -p "$BACKUP/$(dirname "$rel")"
    mv "$dst" "$BACKUP/$rel"
    backup_made=1
    echo "backed up $rel"
  fi

  ln -s "$src" "$dst"
  echo "linked    $rel"
done

if [ "$backup_made" = 1 ]; then
  echo "Backups in: $BACKUP"
fi

# Portable agent pack (machine law, runtime wrappers, shared skills)
if [ -x "$DOTFILES/agents/install.sh" ]; then
  echo ""
  echo "=== agents pack ==="
  "$DOTFILES/agents/install.sh"
elif [ -f "$DOTFILES/agents/install.sh" ]; then
  echo ""
  echo "=== agents pack ==="
  bash "$DOTFILES/agents/install.sh"
fi
