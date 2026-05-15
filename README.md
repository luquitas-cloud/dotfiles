# dotfiles

Lucas's personal macOS dotfiles. Flat home-mirror layout — repo tree matches `$HOME`.

## Install

    git clone <repo> ~/dotfiles
    ~/dotfiles/install.sh

`install.sh` is idempotent — already-correct symlinks are skipped; existing files are
moved to `~/dotfiles/.backup-YYYYMMDD-HHMMSS/` before being replaced.

## Tracked files

- `.zshrc`, `.zprofile`, `.gitconfig`
- `.config/ghostty/config`
- `.config/mise/config.toml`
