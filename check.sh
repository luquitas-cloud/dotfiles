#!/usr/bin/env bash
# Source and live-machine verification for the portable dotfiles contract.
set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")" && pwd)
SOURCE_ONLY=0
FAILURES=0
WARNINGS=0

usage() {
  printf '%s\n' "Usage: check.sh [--source-only]"
}

case "${1:-}" in
  "") ;;
  --source-only) SOURCE_ONLY=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { usage >&2; exit 2; }

pass() { printf '  pass  %s\n' "$1"; }
warn() { printf '  warn  %s\n' "$1"; WARNINGS=$((WARNINGS + 1)); }
fail() { printf '  FAIL  %s\n' "$1"; FAILURES=$((FAILURES + 1)); }

printf '%s\n' "Dotfiles source checks"

if git -C "$DOTFILES" diff --check; then pass "git diff has no whitespace errors"; else fail "git diff whitespace check"; fi

if bash -n "$DOTFILES/install.sh" "$DOTFILES/bootstrap.sh" "$DOTFILES/check.sh" \
  "$DOTFILES/agents/install.sh" "$DOTFILES/agents/login-check.sh" "$DOTFILES/agents/status.sh" \
  "$DOTFILES/agents/private-state.sh" \
  "$DOTFILES/agents/policy/command-guard.sh" \
  "$DOTFILES/agents/runtimes/claude/hooks/guard.sh" \
  "$DOTFILES/agents/tests/guard-tests.sh" "$DOTFILES/agents/tests/install-clean-home.sh" \
  "$DOTFILES/agents/tests/install-safety-tests.sh" "$DOTFILES/agents/tests/private-state-tests.sh"; then
  pass "Bash syntax"
else
  fail "Bash syntax"
fi

if zsh -n "$DOTFILES/.zprofile" "$DOTFILES/.zshrc" "$DOTFILES/.config/zsh/op-keys.zsh"; then
  pass "Zsh syntax"
else
  fail "Zsh syntax"
fi

dash_pattern=$(printf '\342\200\224|\342\200\223')
if grep -RInE --exclude-dir=.git --exclude=.DS_Store --exclude='*.private.md' \
  --exclude=.AGENTS.assembled.md "$dash_pattern" "$DOTFILES"; then
  fail "portable source contains em dash or en dash characters"
else
  pass "ASCII hyphen policy"
fi
unset dash_pattern

if command -v jq >/dev/null 2>&1; then
  if jq empty "$DOTFILES/agents/runtimes/codex/hooks.json"; then pass "Codex hooks JSON"; else fail "Codex hooks JSON"; fi
  if jq empty "$DOTFILES/agents/runtimes/grok/hooks/command-guard.json"; then pass "Grok hooks JSON"; else fail "Grok hooks JSON"; fi
  if jq empty "$DOTFILES/agents/runtimes/cursor/hooks.json"; then pass "Cursor hooks JSON"; else fail "Cursor hooks JSON"; fi
  if jq empty "$DOTFILES/agents/config/private-state.example.json"; then pass "private-state example JSON"; else fail "private-state example JSON"; fi
else
  warn "jq unavailable; skipped JSON validation"
fi

CLAUDE_CHECK=$(mktemp "${TMPDIR:-/tmp}/dotfiles-claude-settings-check.XXXXXX")
if /usr/bin/osascript -l JavaScript "$DOTFILES/agents/scripts/merge-claude-settings.js" - "$CLAUDE_CHECK" >/dev/null 2>&1; then
  unlink "$CLAUDE_CHECK"
  pass "Claude settings merger"
else
  [ ! -e "$CLAUDE_CHECK" ] || unlink "$CLAUDE_CHECK"
  fail "Claude settings merger"
fi
unset CLAUDE_CHECK

GEMINI_CHECK=$(mktemp "${TMPDIR:-/tmp}/dotfiles-gemini-settings-check.XXXXXX")
if /usr/bin/osascript -l JavaScript "$DOTFILES/agents/scripts/merge-gemini-settings.js" - "$GEMINI_CHECK" >/dev/null 2>&1; then
  unlink "$GEMINI_CHECK"
  pass "Gemini settings merger"
else
  [ ! -e "$GEMINI_CHECK" ] || unlink "$GEMINI_CHECK"
  fail "Gemini settings merger"
fi
unset GEMINI_CHECK

if "$DOTFILES/agents/tests/guard-tests.sh"; then pass "portable command guard behavior"; else fail "portable command guard behavior"; fi
if "$DOTFILES/agents/tests/install-safety-tests.sh"; then pass "fail-closed installer behavior"; else fail "fail-closed installer behavior"; fi
if "$DOTFILES/agents/tests/private-state-tests.sh"; then pass "private-state restore behavior"; else fail "private-state restore behavior"; fi
if [ "$SOURCE_ONLY" -eq 0 ]; then
  if "$DOTFILES/agents/login-check.sh"; then pass "interactive-login agent invariants"; else fail "interactive-login agent invariants"; fi
else
  pass "interactive-login agent invariants skipped for source-only verification"
fi

if command -v shellcheck >/dev/null 2>&1; then
  if shellcheck "$DOTFILES/install.sh" "$DOTFILES/bootstrap.sh" "$DOTFILES/check.sh" "$DOTFILES/agents/install.sh" \
    "$DOTFILES/agents/login-check.sh" "$DOTFILES/agents/status.sh" "$DOTFILES/agents/policy/command-guard.sh" \
    "$DOTFILES/agents/private-state.sh" \
    "$DOTFILES/agents/runtimes/claude/hooks/guard.sh" \
    "$DOTFILES/agents/tests/guard-tests.sh" "$DOTFILES/agents/tests/install-clean-home.sh" \
    "$DOTFILES/agents/tests/install-safety-tests.sh" "$DOTFILES/agents/tests/private-state-tests.sh"; then
    pass "ShellCheck"
  else
    fail "ShellCheck"
  fi
else
  warn "shellcheck unavailable"
fi

if command -v gitleaks >/dev/null 2>&1; then
  if gitleaks dir --redact --no-banner "$DOTFILES" && gitleaks git --redact --no-banner "$DOTFILES"; then
    pass "Gitleaks worktree and history scans"
  else
    fail "Gitleaks worktree and history scans"
  fi
else
  warn "gitleaks unavailable"
fi

if [ "$SOURCE_ONLY" -eq 0 ]; then
  printf '%s\n' "Dotfiles live-machine checks"

  if bash "$DOTFILES/install.sh" --check; then pass "installed dotfiles and agent pack"; else fail "installed dotfiles and agent pack"; fi
  if "$DOTFILES/agents/status.sh" >/dev/null; then pass "portable agent status report"; else fail "portable agent status report"; fi

  for tool in git zsh brew gh mise op ghostty delta zoxide starship direnv fzf fd bat eza btop rg codex claude grok gemini cursor; do
    if command -v "$tool" >/dev/null 2>&1; then pass "tool available: $tool"; else fail "tool missing: $tool"; fi
  done

  if ghostty +validate-config >/dev/null 2>&1; then pass "Ghostty config"; else fail "Ghostty config"; fi
  if mise doctor >/dev/null 2>&1; then pass "mise doctor"; else fail "mise doctor"; fi

  if git config --includes --global --get user.name >/dev/null 2>&1 && git config --includes --global --get user.email >/dev/null 2>&1; then
    if [ "$(git config --includes --global --get user.name)" = "Your Name" ] || [ "$(git config --includes --global --get user.email)" = "you@example.com" ]; then
      fail "Git identity still uses template values"
    else
      pass "Git identity configured"
    fi
  else
    fail "Git identity missing"
  fi

  if grok inspect --json 2>/dev/null | grep -Fq "$HOME/.grok/Agents.md"; then pass "Grok global machine law discovery"; else fail "Grok global machine law discovery"; fi
  if grok inspect --json 2>/dev/null | grep -Fq "$HOME/.claude/hooks/guard.sh"; then pass "Grok command guard discovery"; else fail "Grok command guard discovery"; fi

  if [ -f "$DOTFILES/agents/law/workspace.private.md" ]; then pass "private workspace map present"; else warn "private workspace map absent"; fi
  if [ ! -e "$HOME/.config/zsh/op-keys.local.zsh" ]; then
    warn "optional 1Password key map absent"
  elif [ -f "$HOME/.config/zsh/op-keys.local.zsh" ] && [ ! -L "$HOME/.config/zsh/op-keys.local.zsh" ] && [ "$(stat -f '%Lp' "$HOME/.config/zsh/op-keys.local.zsh" 2>/dev/null || true)" = "600" ]; then
    pass "1Password key map private mode"
  else
    fail "1Password key map must be a regular mode-600 file"
  fi
fi

printf '\nChecks complete: %s failure(s), %s warning(s).\n' "$FAILURES" "$WARNINGS"
[ "$FAILURES" -eq 0 ]
