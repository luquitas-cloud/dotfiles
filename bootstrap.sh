#!/usr/bin/env bash
# Provision a full developer Mac after the one manual Homebrew installation.
set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")" && pwd)
MODE=install
REPLACE=0
PRIVATE_ITEM=${DOTFILES_PRIVATE_ITEM:-}
PRIVATE_VAULT=${DOTFILES_PRIVATE_VAULT:-}
CLONE_PRODUCTS=0
export PATH="$HOME/.local/bin:$HOME/.grok/bin:$PATH"
export HOMEBREW_BUNDLE_NO_UPGRADE=1

usage() {
  cat <<'EOF'
Usage: bootstrap.sh [--check] [--dry-run] [options]

  no option             Install missing developer tools and the agent pack.
  --check               Read-only verification of the complete machine contract.
  --dry-run             Show missing tools and planned file targets.
  --private-item ITEM   Restore private metadata from a 1Password Secure Note.
  --private-vault NAME  Optional vault for the private item.
  --clone-products      Clone product repos from the private manifest.
  --replace             Replace inspected file collisions without backups.

Homebrew itself is the only manual package installation. If it is absent, this
script prints the official installation checkpoint and exits without mutation.
Agent, GitHub, 1Password, Gemini, and application sign-ins remain manual.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check) [ "$MODE" = install ] || { usage >&2; exit 2; }; MODE=check; shift ;;
    --dry-run) [ "$MODE" = install ] || { usage >&2; exit 2; }; MODE=dry-run; shift ;;
    --replace) REPLACE=1; shift ;;
    --private-item) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; PRIVATE_ITEM=$2; shift 2 ;;
    --private-vault) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; PRIVATE_VAULT=$2; shift 2 ;;
    --clone-products) CLONE_PRODUCTS=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[ "$MODE" = check ] && [ "$REPLACE" -eq 1 ] && { usage >&2; exit 2; }
[ "$CLONE_PRODUCTS" -eq 0 ] || [ -n "$PRIVATE_ITEM" ] || { printf '%s\n' "FAIL      --clone-products requires --private-item" >&2; exit 2; }

log() { printf '%s\n' "$*"; }
fail() { printf 'FAIL      %s\n' "$1" >&2; exit 1; }

[ "$(uname -s)" = Darwin ] || fail "this bootstrap supports macOS only"

if ! command -v brew >/dev/null 2>&1; then
  cat >&2 <<'EOF'
MANUAL CHECKPOINT - Homebrew is not installed.

Install Homebrew once from the official macOS installer:
  https://docs.brew.sh/Installation

Then clone this public repo to ~/dotfiles and rerun:
  ~/dotfiles/bootstrap.sh

No files were changed.
EOF
  exit 3
fi

install_args=()
[ "$REPLACE" -eq 0 ] || install_args+=(--replace)

private_args=()
if [ -n "$PRIVATE_ITEM" ]; then
  private_args+=(--item "$PRIVATE_ITEM")
  [ -z "$PRIVATE_VAULT" ] || private_args+=(--vault "$PRIVATE_VAULT")
  [ "$CLONE_PRODUCTS" -eq 0 ] || private_args+=(--clone-products)
  [ "$REPLACE" -eq 0 ] || private_args+=(--replace)
fi

check_command() {
  local command_name=$1
  if command -v "$command_name" >/dev/null 2>&1; then
    log "ok        command: $command_name"
  else
    fail "missing command: $command_name"
  fi
}

install_npm_agent() {
  local command_name=$1 package_name=$2
  if mise exec node@lts -- sh -c "command -v '$command_name' >/dev/null 2>&1"; then
    log "ok        agent CLI: $command_name"
  else
    log "install   $package_name"
    mise exec node@lts -- npm install --global "$package_name"
  fi
}

install_grok() {
  local installer
  if command -v grok >/dev/null 2>&1; then
    log "ok        agent CLI: grok"
    return
  fi
  installer=$(mktemp "${TMPDIR:-/tmp}/grok-install.XXXXXX")
  trap 'unlink "$installer" 2>/dev/null || true' RETURN
  curl --proto '=https' --tlsv1.2 -fsSLo "$installer" https://x.ai/cli/install.sh
  bash -n "$installer" || fail "downloaded Grok installer failed Bash syntax validation"
  bash "$installer"
  command -v grok >/dev/null 2>&1 || [ -x "$HOME/.grok/bin/grok" ] || fail "Grok installer completed without a runnable CLI"
  unlink "$installer"
  trap - RETURN
  log "installed agent CLI: grok"
}

install_cursor_extensions() {
  local extension
  command -v cursor >/dev/null 2>&1 || return 0
  for extension in anysphere.remote-containers anysphere.remote-ssh; do
    if cursor --list-extensions 2>/dev/null | grep -Fqx "$extension"; then
      log "ok        Cursor extension: $extension"
    else
      cursor --install-extension "$extension"
      log "installed Cursor extension: $extension"
    fi
  done
}

login_report() {
  cat <<'EOF'

Manual sign-ins - runtime credentials are intentionally not copied between Macs:
  1. Open 1Password, sign in, enable CLI integration, then run: op whoami
  2. Run: gh auth login
  3. Run: codex login
  4. Run: claude
  5. Run: grok login
  6. Run: gemini   (choose Sign in with Google)
  7. Open Cursor and sign in through its UI

After 1Password and GitHub sign-in, restore private metadata and optional repos:
  ~/dotfiles/bootstrap.sh --private-item "$DOTFILES_PRIVATE_ITEM" --clone-products

The item reference is a placeholder environment variable, not a tracked value.
EOF
}

case "$MODE" in
  check)
    brew bundle check --file "$DOTFILES/Brewfile"
    for command_name in git gh op mise node npm codex claude grok gemini cursor; do
      check_command "$command_name"
    done
    bash "$DOTFILES/check.sh"
    log "Bootstrap check passed."
    login_report
    ;;
  dry-run)
    log "Bootstrap dry run"
    if brew bundle check --file "$DOTFILES/Brewfile" >/dev/null 2>&1; then
      log "ok        Homebrew bundle"
    else
      log "plan      install missing entries from $DOTFILES/Brewfile"
    fi
    mise install --dry-run -C "$DOTFILES" || true
    for pair in 'codex:@openai/codex' 'claude:@anthropic-ai/claude-code'; do
      command_name=${pair%%:*}
      package_name=${pair#*:}
      if command -v "$command_name" >/dev/null 2>&1; then
        log "ok        agent CLI: $command_name"
      else
        log "plan      npm install --global $package_name"
      fi
    done
    if command -v grok >/dev/null 2>&1; then log "ok        agent CLI: grok"; else log "plan      install Grok from https://x.ai/cli/install.sh"; fi
    bash "$DOTFILES/install.sh" --dry-run "${install_args[@]}"
    if [ -n "$PRIVATE_ITEM" ]; then
      bash "$DOTFILES/agents/private-state.sh" pull "${private_args[@]}" --dry-run
    fi
    login_report
    ;;
  install)
    log "Developer Mac bootstrap"
    log "  dotfiles: $DOTFILES"
    brew bundle --file "$DOTFILES/Brewfile"
    bash "$DOTFILES/install.sh" --dry-run "${install_args[@]}"
    bash "$DOTFILES/install.sh" "${install_args[@]}"
    mise install --yes -C "$DOTFILES"
    eval "$(mise activate bash)"
    install_npm_agent codex @openai/codex
    install_npm_agent claude @anthropic-ai/claude-code
    install_grok
    install_cursor_extensions
    if [ -n "$PRIVATE_ITEM" ]; then
      bash "$DOTFILES/agents/private-state.sh" pull "${private_args[@]}"
    fi
    bash "$DOTFILES/install.sh" "${install_args[@]}"
    bash "$DOTFILES/check.sh"
    login_report
    ;;
esac
