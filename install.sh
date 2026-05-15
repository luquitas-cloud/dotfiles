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

[ "$backup_made" = 1 ] && echo "Backups in: $BACKUP"
