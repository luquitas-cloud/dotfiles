# dotfiles

Personal macOS dotfiles. The repository mirrors `$HOME` for shell files and includes a portable agent pack shared by Codex, Claude, and Grok.

## Install

    git clone <repo> ~/dotfiles
    ~/dotfiles/install.sh

`install.sh` is idempotent and creates no backups. It installs missing links, updates files already managed by this repository, and refuses unmanaged collisions. Inspect any collision before using the explicit `--replace` mode.

```bash
~/dotfiles/install.sh --dry-run
~/dotfiles/install.sh
~/dotfiles/check.sh
```

Read-only verification is always available:

```bash
~/dotfiles/install.sh --check
~/dotfiles/check.sh
```

### Agent pack only (new machine or repair)

    ~/dotfiles/agents/install.sh

Or tell any coding agent: read `agents/BOOTSTRAP.md` and implement it.

## Provisioning

The installer never downloads or upgrades packages. `Brewfile` is the explicit package manifest for shell and verification dependencies:

```bash
brew bundle --file ~/dotfiles/Brewfile
```

Scoped package and workflow commands such as `brew install`, `brew bundle`, `npm ci`, and `npx` are allowed when the task requires them. Avoid surprise broad machine upgrades. Codex, Claude, Grok, authentication, private overlays, and application data may still require one-time vendor login or secure restore steps.

## Build and verification policy

This is a shell and configuration repository, not a Node project. Its canonical verification command is `~/dotfiles/check.sh`; there is no `npm` or `npx` build to invent here. The portable command guard allows normal package, build, test, and deployment workflows while retaining narrow hard stops for destructive or irreversible commands.

## Tracked files

- `.zshrc`, `.zprofile`, `.gitconfig`
- `.config/ghostty/config`
- `.config/mise/config.toml`
- `.config/zsh/op-keys.zsh` - 1Password-backed API key loader, sourced from `.zshrc`
- `agents/` - portable machine law, per-runtime spaces, shared skills, bootstrap (see `agents/README.md`)

## Public repository safety

This repo is intended to be **public**. Tracked files must not contain:

- API keys, tokens, recovery codes, or 1Password item paths  
- Real git name/email (use `~/.config/git/local.gitconfig`)  
- Private product inventory, client names, or work codenames (use `agents/law/workspace.private.md`)  

See `agents/README.md` (Public vs private) and `.gitignore`.

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

### Secret Key Caching (`op-keys.zsh`)

Loads API keys from 1Password CLI (`op`) and caches shell-escaped exports under the user's private macOS temporary directory. The cache directory is `0700`, the cache file is `0600`, symlinks are rejected, and entries expire after 8 hours.
