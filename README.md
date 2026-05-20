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
- `.config/zsh/op-keys.zsh` — 1Password-backed API key loader, sourced from `.zshrc`

## Keyboard Layout & Shell Features

This setup includes high-fidelity configurations designed to supercharge engineering loops.

### 💻 Ghostty "Quake-Style" Dropdown & Panel Splitting
Ghostty manages splits natively with zero resource overhead. The following bindings are active:

*   **`Cmd + Shift + D` (Global Quick Terminal):** Toggles a dropdown terminal sliding down from the top of the screen instantly from **any application** in macOS. Hit it again to slide it back out of sight.
*   **`Cmd + D` (Vertical Split):** Split the terminal vertically (creates a panel to the right).
*   **`Cmd + Shift + E` (Horizontal Split):** Split the terminal horizontally (creates a panel below).
*   **Pane Navigation (`Cmd + Option + Arrow Keys`):** Ghostty's native, conflict-free hotkey to move focus between split panes:
    *   `Cmd + Option + Left Arrow` $\rightarrow$ switch focus left
    *   `Cmd + Option + Right Arrow` $\rightarrow$ switch focus right
    *   `Cmd + Option + Up Arrow` $\rightarrow$ switch focus up
    *   `Cmd + Option + Down Arrow` $\rightarrow$ switch focus down

### 📂 Interactive Fuzzy Searching (`fzf` + `fd` + `bat`)
The shell integrates modern CLI utilities to turn generic lists into rich visual interfaces.

*   **`Ctrl + T` (Fuzzy File Explorer):** Fuzzy search files. A responsive side panel will dynamically render syntax-highlighted previews of your files using `bat`. Select a file and hit `Enter` to output its path.
*   **`Alt + C` (Fuzzy Folder Jumping):** Fuzzy search all directories. The side preview panel runs `eza` showing git status, file structure, and sizes of the highlighted folder. Press `Enter` to instantly `cd` into it.
*   **`** + Tab` (Command Completion):** Type any command (e.g. `cat **` or `cd **`) and press `Tab` to trigger fuzzy completions with live side panel previews.

### 🔑 Secret Key Caching (`op-keys.zsh`)
Loads API keys securely from 1Password CLI (`op`) and caches them under `0600` permissions inside `/tmp/op-cache-$UID` with an 8-hour cache TTL to bypass continuous 1Password authorizations in new terminals.

