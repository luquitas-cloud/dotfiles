#!/usr/bin/env bash
# Verify collision handling is fail-closed and does not partially install.
set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd)
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-safety-home.XXXXXX")
cleanup() {
  find "$TEST_HOME" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  printf '  FAIL  %s\n' "$1" >&2
  exit 1
}

pass() {
  printf '  pass  %s\n' "$1"
}

printf '%s\n' "Installer safety tests"

mkdir -p "$TEST_HOME/.codex"
printf '%s\n' "unmanaged machine law" > "$TEST_HOME/.codex/AGENTS.md"

set +e
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" > "$TEST_HOME/collision.log" 2>&1
rc=$?
set -e

[ "$rc" -ne 0 ] || fail "unmanaged collision was accepted"
grep -Fq "unmanaged collision" "$TEST_HOME/collision.log" || fail "collision failure was not explained"
[ ! -e "$TEST_HOME/.zshrc" ] || fail "root links changed before agent preflight completed"
pass "unmanaged collision fails before any root link changes"

before=$(shasum -a 256 "$TEST_HOME/.codex/AGENTS.md" | awk '{print $1}')
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --dry-run --replace >/dev/null
after=$(shasum -a 256 "$TEST_HOME/.codex/AGENTS.md" | awk '{print $1}')
[ "$before" = "$after" ] || fail "dry run changed an unmanaged target"
[ ! -e "$TEST_HOME/.zshrc" ] || fail "dry run created a root link"
pass "replace dry run is read-only"

unlink "$TEST_HOME/.codex/AGENTS.md"
mkdir -p "$TEST_HOME/.claude/CLAUDE.md"

set +e
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --replace > "$TEST_HOME/directory.log" 2>&1
rc=$?
set -e

[ "$rc" -ne 0 ] || fail "directory collision was accepted"
[ -d "$TEST_HOME/.claude/CLAUDE.md" ] || fail "directory target was removed"
[ ! -e "$TEST_HOME/.zshrc" ] || fail "root links changed before directory refusal"
pass "replace refuses directories without partial installation"

rmdir "$TEST_HOME/.claude/CLAUDE.md"
printf '%s\n' "unmanaged shell configuration" > "$TEST_HOME/.zshrc"
printf '%s\n' \
  '[profiles.unrestricted]' \
  'approval_policy = "never"' \
  'sandbox_mode = "danger-full-access"' > "$TEST_HOME/.codex/config.toml"
# shellcheck disable=SC2016 # intentional literal $HOME inside seeded JSON fixture
printf '%s\n' \
  '{' \
  '  "permissions": {"defaultMode": "bypassPermissions"},' \
  '  "hooks": {"PreToolUse": [' \
  '    {"matcher": "Read", "hooks": [{"type": "command", "command": "true"}]},' \
  '    {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash $HOME/.claude/hooks/guard.sh"}]},' \
  '    {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash $HOME/.claude/hooks/guard.sh"}]}' \
  '  ]}' \
  '}' > "$TEST_HOME/.claude/settings.json"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --replace >/dev/null
[ -L "$TEST_HOME/.zshrc" ] && [ "$(readlink "$TEST_HOME/.zshrc")" = "$DOTFILES/.zshrc" ] || fail "staged root-link replacement failed"
top_approval=$(awk '/^[[:space:]]*\[/{exit} /^approval_policy[[:space:]]*=/{print $3}' "$TEST_HOME/.codex/config.toml")
top_sandbox=$(awk '/^[[:space:]]*\[/{exit} /^sandbox_mode[[:space:]]*=/{print $3}' "$TEST_HOME/.codex/config.toml")
[ "$top_approval" = '"never"' ] && [ "$top_sandbox" = '"danger-full-access"' ] || fail "Codex top-level high-autonomy policy was not installed"
grep -A2 '^\[profiles.unrestricted\]' "$TEST_HOME/.codex/config.toml" | grep -Fq 'approval_policy = "never"' || fail "Codex named profile was altered"
[ "$(/usr/bin/plutil -extract permissions.defaultMode raw -o - "$TEST_HOME/.claude/settings.json")" = "bypassPermissions" ] || fail "Claude bypassPermissions mode was not installed"
[ "$(grep -cF '.claude/hooks/guard.sh' "$TEST_HOME/.claude/settings.json")" -eq 1 ] || fail "Claude managed hooks were not deduplicated"
grep -Fq '"matcher": "Read"' "$TEST_HOME/.claude/settings.json" || fail "Claude unrelated hook was not preserved"
# Seeded profile already used never/danger-full-access; re-seed restrictive top-level then reinstall.
printf '%s\n' \
  'approval_policy = "on-request"' \
  'sandbox_mode = "workspace-write"' \
  '[profiles.unrestricted]' \
  'approval_policy = "never"' \
  'sandbox_mode = "danger-full-access"' > "$TEST_HOME/.codex/config.toml"
# shellcheck disable=SC2016 # intentional literal $HOME inside seeded JSON fixture
printf '%s\n' \
  '{' \
  '  "permissions": {"defaultMode": "default"},' \
  '  "hooks": {"PreToolUse": [' \
  '    {"matcher": "Read", "hooks": [{"type": "command", "command": "true"}]},' \
  '    {"matcher": "Bash", "hooks": [{"type": "command", "command": "bash $HOME/.claude/hooks/guard.sh"}]}' \
  '  ]}' \
  '}' > "$TEST_HOME/.claude/settings.json"
printf '%s\n' \
  '[ui]' \
  'yolo = false' \
  'permission_mode = "ask"' \
  'theme = "keep-me"' > "$TEST_HOME/.grok/config.toml"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --replace >/dev/null
top_approval=$(awk '/^[[:space:]]*\[/{exit} /^approval_policy[[:space:]]*=/{print $3}' "$TEST_HOME/.codex/config.toml")
top_sandbox=$(awk '/^[[:space:]]*\[/{exit} /^sandbox_mode[[:space:]]*=/{print $3}' "$TEST_HOME/.codex/config.toml")
[ "$top_approval" = '"never"' ] && [ "$top_sandbox" = '"danger-full-access"' ] || fail "Codex restrictive top-level was not upgraded to high autonomy"
grep -A2 '^\[profiles.unrestricted\]' "$TEST_HOME/.codex/config.toml" | grep -Fq 'approval_policy = "never"' || fail "Codex named profile was altered on second install"
[ "$(/usr/bin/plutil -extract permissions.defaultMode raw -o - "$TEST_HOME/.claude/settings.json")" = "bypassPermissions" ] || fail "Claude default mode was not upgraded to bypassPermissions"
grep -Fq 'theme = "keep-me"' "$TEST_HOME/.grok/config.toml" || fail "Grok unrelated config was not preserved"
grep -Eq '^yolo[[:space:]]*=[[:space:]]*true[[:space:]]*$' "$TEST_HOME/.grok/config.toml" || fail "Grok yolo was not installed"
grep -Eq '^permission_mode[[:space:]]*=[[:space:]]*"always-approve"[[:space:]]*$' "$TEST_HOME/.grok/config.toml" || fail "Grok always-approve was not installed"
[ -L "$TEST_HOME/.grok/hooks/guard.sh" ] || fail "Grok guard link missing"
[ -L "$TEST_HOME/.grok/hooks/command-guard.json" ] || fail "Grok hooks link missing"
[ -L "$TEST_HOME/.cursor/hooks/guard.sh" ] || fail "Cursor guard link missing"
[ -L "$TEST_HOME/.cursor/hooks.json" ] || fail "Cursor hooks link missing"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --check >/dev/null
pass "explicit replacement preserves profiles and unrelated hooks"

if find "$TEST_HOME" -name '.backup-*' -print -quit | grep -q .; then
  fail "installer created a backup directory"
fi
pass "no backup directory was created"

printf '%s\n' "Installer safety tests passed."
