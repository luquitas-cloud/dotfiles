#!/usr/bin/env bash
# Fast, read-only agent-policy invariant check for interactive shell startup.
set -u

PACK=$(cd "$(dirname "$0")" && pwd)
HOME_DIR=${HOME:?HOME must be set}
LAW_PUBLIC="$PACK/law/AGENTS.md"
LAW_PRIVATE="$PACK/law/workspace.private.md"
ASSEMBLED="$PACK/law/.AGENTS.assembled.md"
GUARD_SRC="$PACK/policy/command-guard.sh"
SHARED_SKILLS="$PACK/skills/shared"
STATUS_SRC="$PACK/status.sh"
WORKSPACE_CODE="$PACK/workspace/code.AGENTS.md"
WORKSPACE_PERSONAL="$PACK/workspace/personal.AGENTS.md"
WORKSPACE_WORK="$PACK/workspace/work.AGENTS.md"
DRIFT=0

mark_drift() {
  DRIFT=1
}

check_file() {
  local actual="$1" expected="$2" mode="$3"
  [ -f "$actual" ] && [ ! -L "$actual" ] && cmp -s "$actual" "$expected" && \
    [ "$(stat -f '%Lp' "$actual" 2>/dev/null || true)" = "$mode" ] || mark_drift
}

check_link() {
  local actual="$1" expected="$2"
  [ -L "$actual" ] && [ "$(readlink "$actual")" = "$expected" ] && [ -e "$actual" ] || mark_drift
}

if [ ! -f "$LAW_PUBLIC" ] || [ ! -f "$ASSEMBLED" ]; then
  mark_drift
else
  {
    cat "$LAW_PUBLIC"
    if [ -f "$LAW_PRIVATE" ]; then
      printf '\n\n---\n\n'
      cat "$LAW_PRIVATE"
    fi
  } | cmp -s - "$ASSEMBLED" || mark_drift
fi

check_file "$HOME_DIR/.codex/AGENTS.md" "$ASSEMBLED" 600
check_file "$HOME_DIR/.grok/AGENTS.md" "$ASSEMBLED" 600
check_file "$HOME_DIR/.claude/CLAUDE.md" "$PACK/runtimes/claude/CLAUDE.md" 644
check_file "$HOME_DIR/.gemini/GEMINI.md" "$PACK/runtimes/gemini/GEMINI.md" 644
check_link "$HOME_DIR/.codex/hooks.json" "$PACK/runtimes/codex/hooks.json"
check_link "$HOME_DIR/.grok/hooks/command-guard.json" "$PACK/runtimes/grok/hooks/command-guard.json"
check_link "$HOME_DIR/.cursor/hooks.json" "$PACK/runtimes/cursor/hooks.json"
check_link "$HOME_DIR/.gemini/policies/dotfiles-agent-pack.toml" "$PACK/runtimes/gemini/policy.toml"
check_link "$HOME_DIR/.codex/hooks/guard.sh" "$GUARD_SRC"
check_link "$HOME_DIR/.claude/hooks/guard.sh" "$GUARD_SRC"
check_link "$HOME_DIR/.grok/hooks/guard.sh" "$GUARD_SRC"
check_link "$HOME_DIR/.cursor/hooks/guard.sh" "$GUARD_SRC"
check_link "$HOME_DIR/.gemini/hooks/guard.sh" "$GUARD_SRC"
check_link "$HOME_DIR/.agents/skills" "$SHARED_SKILLS"
check_link "$HOME_DIR/.claude/skills" "$SHARED_SKILLS"
check_link "$HOME_DIR/.cursor/skills" "$SHARED_SKILLS"
check_link "$HOME_DIR/.local/bin/agent-status" "$STATUS_SRC"
check_file "$HOME_DIR/code/AGENTS.md" "$WORKSPACE_CODE" 644
check_file "$HOME_DIR/code/personal/AGENTS.md" "$WORKSPACE_PERSONAL" 644
check_file "$HOME_DIR/code/work/AGENTS.md" "$WORKSPACE_WORK" 644

if ! awk '
  /^[[:space:]]*\[/ { exit }
  /^approval_policy[[:space:]]*=[[:space:]]*"never"[[:space:]]*$/ { approval++ }
  /^sandbox_mode[[:space:]]*=[[:space:]]*"danger-full-access"[[:space:]]*$/ { sandbox++ }
  END { exit !(approval == 1 && sandbox == 1) }
' "$HOME_DIR/.codex/config.toml" 2>/dev/null; then
  mark_drift
fi

if ! awk '
  BEGIN { in_ui = 0; yolo = 0; perm = 0 }
  /^[[:space:]]*\[/ { in_ui = ($0 ~ /^[[:space:]]*\[ui\][[:space:]]*$/) }
  in_ui && /^yolo[[:space:]]*=[[:space:]]*true[[:space:]]*$/ { yolo++ }
  in_ui && /^permission_mode[[:space:]]*=[[:space:]]*"always-approve"[[:space:]]*$/ { perm++ }
  END { exit !(yolo == 1 && perm == 1) }
' "$HOME_DIR/.grok/config.toml" 2>/dev/null; then
  mark_drift
fi

claude_mode=$(/usr/bin/plutil -extract permissions.defaultMode raw -o - "$HOME_DIR/.claude/settings.json" 2>/dev/null || true)
guard_count=$(grep -cF '.claude/hooks/guard.sh' "$HOME_DIR/.claude/settings.json" 2>/dev/null || true)
[ -n "$guard_count" ] || guard_count=0
if [ "$claude_mode" != "bypassPermissions" ] || [ "$guard_count" -ne 1 ]; then
  mark_drift
fi

gemini_skills=$(/usr/bin/plutil -extract skills.enabled raw -o - "$HOME_DIR/.gemini/settings.json" 2>/dev/null || true)
gemini_hooks=$(/usr/bin/plutil -extract hooksConfig.enabled raw -o - "$HOME_DIR/.gemini/settings.json" 2>/dev/null || true)
gemini_guard_count=$(grep -cF '.gemini/hooks/guard.sh' "$HOME_DIR/.gemini/settings.json" 2>/dev/null || true)
gemini_agents_count=$(grep -cF '"AGENTS.md"' "$HOME_DIR/.gemini/settings.json" 2>/dev/null || true)
gemini_context_count=$(grep -cF '"GEMINI.md"' "$HOME_DIR/.gemini/settings.json" 2>/dev/null || true)
[ -n "$gemini_guard_count" ] || gemini_guard_count=0
[ -n "$gemini_agents_count" ] || gemini_agents_count=0
[ -n "$gemini_context_count" ] || gemini_context_count=0
if [ "$gemini_skills" != "true" ] || [ "$gemini_hooks" != "true" ] || \
  [ "$gemini_guard_count" -ne 1 ] || [ "$gemini_agents_count" -ne 1 ] || [ "$gemini_context_count" -ne 1 ]; then
  mark_drift
fi

if [ -e "$HOME_DIR/.claude/settings.local.json" ]; then
  [ -f "$HOME_DIR/.claude/settings.local.json" ] && [ ! -L "$HOME_DIR/.claude/settings.local.json" ] && \
    [ "$(stat -f '%Lp' "$HOME_DIR/.claude/settings.local.json" 2>/dev/null || true)" = "600" ] || mark_drift
fi

if [ "$DRIFT" -ne 0 ]; then
  printf '%s\n' "dotfiles: agent policy drift detected; run ~/dotfiles/install.sh --dry-run" >&2
  exit 1
fi

exit 0
