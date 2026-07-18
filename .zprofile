eval "$(/opt/homebrew/bin/brew shellenv)"

path_prepend_once() {
  [ -d "$1" ] || return 0
  case ":$PATH:" in
    *":$1:"*) ;;
    *) export PATH="$1:$PATH" ;;
  esac
}

# uv tool installs land here.
path_prepend_once "$HOME/.local/bin"

# Added by OrbStack: command-line tools and integration
# This won't be added again if you remove it.
source ~/.orbstack/shell/init.zsh 2>/dev/null || :

unset -f path_prepend_once
