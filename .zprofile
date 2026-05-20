eval "$(/opt/homebrew/bin/brew shellenv)"

# uv tool installs land here
export PATH="$HOME/.local/bin:$PATH"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :


# Added by Antigravity CLI installer
export PATH="/Users/lucas/.local/bin:$PATH"
