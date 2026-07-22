#!/usr/bin/env bash
# Install and verify the portable agent pack. Safe, idempotent, and fail-closed.
set -euo pipefail
umask 077

PACK=$(cd "$(dirname "$0")" && pwd)
HOME_DIR=${HOME:?HOME must be set}
LAW_PUBLIC="$PACK/law/AGENTS.md"
LAW_PRIVATE="$PACK/law/workspace.private.md"
ASSEMBLED="$PACK/law/.AGENTS.assembled.md"
SHARED_SKILLS="$PACK/skills/shared"
STATUS_SRC="$PACK/status.sh"
CLAUDE_SRC="$PACK/runtimes/claude/CLAUDE.md"
GEMINI_SRC="$PACK/runtimes/gemini/GEMINI.md"
GEMINI_POLICY_SRC="$PACK/runtimes/gemini/policy.toml"
GUARD_SRC="$PACK/policy/command-guard.sh"
CODEX_HOOKS_SRC="$PACK/runtimes/codex/hooks.json"
GROK_HOOKS_SRC="$PACK/runtimes/grok/hooks/command-guard.json"
CURSOR_HOOKS_SRC="$PACK/runtimes/cursor/hooks.json"
CLAUDE_SETTINGS_MERGER="$PACK/scripts/merge-claude-settings.js"
GEMINI_SETTINGS_MERGER="$PACK/scripts/merge-gemini-settings.js"
GIT_LOCAL="$HOME_DIR/.config/git/local.gitconfig"
WORKSPACE_CODE="$PACK/workspace/code.AGENTS.md"
WORKSPACE_PERSONAL="$PACK/workspace/personal.AGENTS.md"
WORKSPACE_WORK="$PACK/workspace/work.AGENTS.md"
MANAGED_MARKER='managed-by: dotfiles-agent-pack'
PRIVATE_RUNTIME_FILES=(
  "$HOME_DIR/.claude/settings.local.json"
)

MODE=install
REPLACE=0

usage() {
  cat <<'EOF'
Usage: install.sh [--check] [--dry-run] [--replace]

  no option   Install missing files and update files already managed by this pack.
  --check     Read-only verification of sources, installed files, links, and policy.
  --dry-run   Show the changes an install would make without writing anything.
  --replace   Explicitly replace unmanaged file or symlink collisions. Directories
              are never removed. No backup copies are created.
EOF
}

while [ "$#" -gt 0 ]; do
  case "$1" in
    --check)
      [ "$MODE" = install ] || { usage >&2; exit 2; }
      MODE=check
      ;;
    --dry-run)
      [ "$MODE" = install ] || { usage >&2; exit 2; }
      MODE=dry-run
      ;;
    --replace) REPLACE=1 ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
  shift
done

if [ "$MODE" = check ] && [ "$REPLACE" -eq 1 ]; then
  usage >&2
  exit 2
fi

log() { printf '%s\n' "$*"; }
ok() { log "ok        $1"; }
planned() { log "plan      $1"; }
installed() { log "installed $1"; }
warn() { log "warn      $1"; }
fail() { log "FAIL      $1" >&2; return 1; }

require_file() {
  [ -f "$1" ] && [ -r "$1" ] || fail "missing or unreadable source: $1"
}

require_dir() {
  [ -d "$1" ] && [ -r "$1" ] || fail "missing or unreadable directory: $1"
}

for required in "$LAW_PUBLIC" "$STATUS_SRC" "$CLAUDE_SRC" "$GEMINI_SRC" "$GEMINI_POLICY_SRC" \
  "$GUARD_SRC" "$CODEX_HOOKS_SRC" \
  "$GROK_HOOKS_SRC" "$CURSOR_HOOKS_SRC" "$CLAUDE_SETTINGS_MERGER" \
  "$GEMINI_SETTINGS_MERGER" \
  "$WORKSPACE_CODE" "$WORKSPACE_PERSONAL" "$WORKSPACE_WORK"; do
  require_file "$required"
done
require_dir "$SHARED_SKILLS"

if [ -e "$LAW_PRIVATE" ] && [ ! -r "$LAW_PRIVATE" ]; then
  fail "unreadable private overlay: $LAW_PRIVATE"
fi

for private_runtime in "${PRIVATE_RUNTIME_FILES[@]}"; do
  if { [ -e "$private_runtime" ] || [ -L "$private_runtime" ]; } && { [ ! -f "$private_runtime" ] || [ -L "$private_runtime" ]; }; then
    fail "private runtime config must be a regular file: $private_runtime"
  fi
done

emit_combined() {
  local public="$1" private="$2"
  cat "$public"
  if [ -f "$private" ]; then
    printf '\n\n---\n\n'
    cat "$private"
  fi
}

emit_law() {
  emit_combined "$LAW_PUBLIC" "$LAW_PRIVATE"
}

is_managed_file() {
  [ -f "$1" ] && grep -Fq "$MANAGED_MARKER" "$1" 2>/dev/null
}

can_replace_file() {
  local src="$1" dst="$2"
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    return 0
  fi
  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
    return 0
  fi
  if is_managed_file "$dst"; then
    return 0
  fi
  if [ -L "$dst" ]; then
    case "$(readlink "$dst")" in
      "$PACK"/*) return 0 ;;
    esac
  fi
  [ "$REPLACE" -eq 1 ]
}

preflight_file() {
  local src="$1" dst="$2" derived="${3:-0}"
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    return
  fi
  if [ -d "$dst" ] && [ ! -L "$dst" ]; then
    fail "refusing to replace directory: $dst"
  fi
  if [ "$derived" -eq 1 ]; then
    [ -f "$dst" ] && [ ! -L "$dst" ] && return
    fail "derived configuration target must be a regular file: $dst"
  fi
  can_replace_file "$src" "$dst" || fail "unmanaged collision at $dst; inspect it, then use --replace only if replacement is intended"
}

preflight_link() {
  local src="$1" dst="$2" current
  if [ ! -e "$dst" ] && [ ! -L "$dst" ]; then
    return
  fi
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && [ -e "$dst" ]; then
    return
  fi
  if [ -d "$dst" ] && [ ! -L "$dst" ]; then
    fail "refusing to replace directory: $dst"
  fi
  if [ -L "$dst" ]; then
    current=$(readlink "$dst")
    case "$current" in
      "$PACK"/*) return ;;
      *) [ "$REPLACE" -eq 1 ] || fail "unmanaged symlink collision at $dst -> $current" ;;
    esac
  else
    [ "$REPLACE" -eq 1 ] || fail "unmanaged file collision at $dst"
  fi
}

apply_file() {
  local src="$1" dst="$2" mode="$3" derived="${4:-0}" tmp
  mkdir -p "$(dirname "$dst")"
  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
    chmod "$mode" "$dst"
    ok "$dst"
    return
  fi
  if [ -d "$dst" ] && [ ! -L "$dst" ]; then
    fail "refusing to replace directory: $dst"
  fi
  if { [ -e "$dst" ] || [ -L "$dst" ]; } && [ "$derived" -ne 1 ]; then
    can_replace_file "$src" "$dst" || fail "unmanaged collision at $dst; inspect it, then use --replace only if replacement is intended"
  fi
  tmp=$(mktemp "$(dirname "$dst")/.agent-pack.XXXXXX")
  if ! cp "$src" "$tmp" || ! chmod "$mode" "$tmp"; then
    [ ! -e "$tmp" ] || unlink "$tmp"
    fail "unable to stage replacement for $dst"
  fi
  if [ -L "$dst" ] && ! unlink "$dst"; then
    unlink "$tmp"
    fail "unable to unlink existing symlink: $dst"
  fi
  if ! mv -f "$tmp" "$dst"; then
    [ ! -e "$tmp" ] || unlink "$tmp"
    fail "unable to install staged replacement: $dst"
  fi
  installed "$dst"
}

apply_link() {
  local src="$1" dst="$2" current tmp
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ] && [ -e "$dst" ]; then
    ok "$dst -> $src"
    return
  fi
  if [ -d "$dst" ] && [ ! -L "$dst" ]; then
    fail "refusing to replace directory: $dst"
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    if [ -L "$dst" ]; then
      current=$(readlink "$dst")
      case "$current" in
        "$PACK"/*) ;;
        *) [ "$REPLACE" -eq 1 ] || fail "unmanaged symlink collision at $dst -> $current" ;;
      esac
    else
      [ "$REPLACE" -eq 1 ] || fail "unmanaged file collision at $dst"
    fi
  fi
  tmp=$(mktemp "$(dirname "$dst")/.agent-link.XXXXXX")
  unlink "$tmp"
  if ! ln -s "$src" "$tmp"; then
    fail "unable to stage symlink for $dst"
  fi
  if [ -L "$dst" ] && ! unlink "$dst"; then
    unlink "$tmp"
    fail "unable to unlink existing symlink: $dst"
  fi
  if ! mv -f "$tmp" "$dst"; then
    [ ! -L "$tmp" ] || unlink "$tmp"
    fail "unable to install staged symlink: $dst"
  fi
  installed "$dst -> $src"
}

prepare_claude_settings() {
  local dst="$1" source="$HOME_DIR/.claude/settings.json" input="-"

  if [ -f "$source" ] && [ ! -L "$source" ]; then
    input="$source"
  elif [ -e "$source" ] || [ -L "$source" ]; then
    fail "Claude settings must be a regular JSON file: $source"
  fi

  /usr/bin/osascript -l JavaScript "$CLAUDE_SETTINGS_MERGER" "$input" "$dst" >/dev/null || fail "unable to prepare Claude settings from $source"
  chmod 600 "$dst"
}

prepare_gemini_settings() {
  local dst="$1" source="$HOME_DIR/.gemini/settings.json" input="-"

  if [ -f "$source" ] && [ ! -L "$source" ]; then
    input="$source"
  elif [ -e "$source" ] || [ -L "$source" ]; then
    fail "Gemini settings must be a regular JSON file: $source"
  fi

  /usr/bin/osascript -l JavaScript "$GEMINI_SETTINGS_MERGER" "$input" "$dst" >/dev/null || fail "unable to prepare Gemini settings from $source"
  chmod 600 "$dst"
}

prepare_codex_config() {
  local dst="$1" source="$HOME_DIR/.codex/config.toml" work="$2"

  if [ -f "$source" ] && [ ! -L "$source" ]; then
    awk '
      BEGIN {
        in_top = 1
        seen_approval = 0
        seen_sandbox = 0
      }
      function emit_missing() {
        if (!seen_approval) {
          print "approval_policy = \"never\""
          seen_approval = 1
        }
        if (!seen_sandbox) {
          print "sandbox_mode = \"danger-full-access\""
          seen_sandbox = 1
        }
      }
      in_top && /^[[:space:]]*\[/ {
        emit_missing()
        in_top = 0
        print
        next
      }
      in_top && /^approval_policy[[:space:]]*=/ {
        if (!seen_approval) print "approval_policy = \"never\""
        seen_approval = 1
        next
      }
      in_top && /^sandbox_mode[[:space:]]*=/ {
        if (!seen_sandbox) print "sandbox_mode = \"danger-full-access\""
        seen_sandbox = 1
        next
      }
      { print }
      END {
        if (in_top) emit_missing()
      }
    ' "$source" > "$dst"
  elif [ -e "$source" ] || [ -L "$source" ]; then
    fail "Codex config must be a regular TOML file: $source"
  else
    printf 'approval_policy = "never"\nsandbox_mode = "danger-full-access"\n' > "$dst"
  fi
  chmod 600 "$dst"

  if command -v codex >/dev/null 2>&1; then
    mkdir -p "$work/codex-home"
    cp "$dst" "$work/codex-home/config.toml"
    CODEX_HOME="$work/codex-home" codex --strict-config --version >/dev/null 2>&1 || fail "candidate Codex config failed strict validation"
  elif [ -f "$source" ]; then
    fail "Codex is unavailable, so an existing Codex config cannot be safely rewritten"
  fi
}

prepare_grok_config() {
  local dst="$1" source="$HOME_DIR/.grok/config.toml"

  if [ -f "$source" ] && [ ! -L "$source" ]; then
    awk '
      BEGIN {
        in_ui = 0
        seen_ui = 0
        seen_yolo = 0
        seen_perm = 0
      }
      function emit_ui_keys() {
        if (!seen_yolo) {
          print "yolo = true"
          seen_yolo = 1
        }
        if (!seen_perm) {
          print "permission_mode = \"always-approve\""
          seen_perm = 1
        }
      }
      /^[[:space:]]*\[/ {
        if (in_ui) emit_ui_keys()
        in_ui = ($0 ~ /^[[:space:]]*\[ui\][[:space:]]*$/)
        if (in_ui) seen_ui = 1
        print
        next
      }
      in_ui && /^yolo[[:space:]]*=/ {
        if (!seen_yolo) print "yolo = true"
        seen_yolo = 1
        next
      }
      in_ui && /^permission_mode[[:space:]]*=/ {
        if (!seen_perm) print "permission_mode = \"always-approve\""
        seen_perm = 1
        next
      }
      { print }
      END {
        if (in_ui) emit_ui_keys()
        if (!seen_ui) {
          print ""
          print "[ui]"
          print "yolo = true"
          print "permission_mode = \"always-approve\""
        }
      }
    ' "$source" > "$dst"
  elif [ -e "$source" ] || [ -L "$source" ]; then
    fail "Grok config must be a regular TOML file: $source"
  else
    printf '[ui]\nyolo = true\npermission_mode = "always-approve"\n' > "$dst"
  fi
  chmod 600 "$dst"
}

check_file() {
  local label="$1" actual="$2" expected="$3" mode="${4:-}"
  if [ -f "$actual" ] && [ ! -L "$actual" ] && cmp -s "$actual" "$expected"; then
    if [ -n "$mode" ] && [ "$(stat -f '%Lp' "$actual" 2>/dev/null || true)" != "$mode" ]; then
      fail "$label has mode $(stat -f '%Lp' "$actual" 2>/dev/null || printf unknown), expected $mode"
    else
      ok "$label"
    fi
  else
    fail "$label"
  fi
}

check_generated() {
  local label="$1" actual="$2" expected="$3" mode="${4:-}"
  check_file "$label" "$actual" "$expected" "$mode"
}

check_link() {
  local label="$1" actual="$2" expected="$3"
  if [ -L "$actual" ] && [ "$(readlink "$actual")" = "$expected" ] && [ -e "$actual" ]; then
    ok "$label"
  else
    fail "$label"
  fi
}

check_private_mode_if_present() {
  local label="$1" path="$2"
  if [ ! -e "$path" ] && [ ! -L "$path" ]; then
    ok "$label absent"
  elif [ -f "$path" ] && [ ! -L "$path" ] && [ "$(stat -f '%Lp' "$path" 2>/dev/null || true)" = "600" ]; then
    ok "$label"
  else
    fail "$label"
  fi
}

check_private_file_mode() {
  local label="$1" path="$2"
  if [ -f "$path" ] && [ ! -L "$path" ] && [ "$(stat -f '%Lp' "$path" 2>/dev/null || true)" = "600" ]; then
    ok "$label"
  else
    fail "$label"
  fi
}

check_private_ignored() {
  local label="$1" path="$2"
  if git -C "$PACK" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
    if git -C "$PACK" check-ignore -q "$path"; then
      ok "$label"
    else
      fail "$label"
    fi
  else
    warn "$label not checked because the pack is outside a Git worktree"
  fi
}

make_stage() {
  local stage="$1"
  emit_law > "$stage/law.md"
  cp "$CLAUDE_SRC" "$stage/claude.md"
  cp "$GEMINI_SRC" "$stage/gemini.md"
  cp "$WORKSPACE_CODE" "$stage/code.md"
  cp "$WORKSPACE_PERSONAL" "$stage/personal.md"
  cp "$WORKSPACE_WORK" "$stage/work.md"
  prepare_claude_settings "$stage/claude-settings.json"
  prepare_gemini_settings "$stage/gemini-settings.json"
  prepare_codex_config "$stage/codex-config.toml" "$stage"
  prepare_grok_config "$stage/grok-config.toml"
  chmod 600 "$stage/law.md"
  chmod 644 "$stage/claude.md" "$stage/gemini.md" "$stage/code.md" "$stage/personal.md" "$stage/work.md"
}

preflight_all() {
  local stage="$1" git_local="$HOME_DIR/.config/git/local.gitconfig"
  preflight_file "$stage/law.md" "$ASSEMBLED" 1
  preflight_file "$stage/law.md" "$HOME_DIR/.codex/AGENTS.md"
  preflight_file "$stage/law.md" "$HOME_DIR/.grok/AGENTS.md"
  preflight_file "$stage/claude.md" "$HOME_DIR/.claude/CLAUDE.md"
  preflight_file "$stage/gemini.md" "$HOME_DIR/.gemini/GEMINI.md"
  preflight_file "$stage/claude-settings.json" "$HOME_DIR/.claude/settings.json" 1
  preflight_file "$stage/gemini-settings.json" "$HOME_DIR/.gemini/settings.json" 1
  preflight_file "$stage/codex-config.toml" "$HOME_DIR/.codex/config.toml" 1
  preflight_file "$stage/grok-config.toml" "$HOME_DIR/.grok/config.toml" 1
  preflight_link "$GUARD_SRC" "$HOME_DIR/.claude/hooks/guard.sh"
  preflight_link "$GUARD_SRC" "$HOME_DIR/.codex/hooks/guard.sh"
  preflight_link "$GUARD_SRC" "$HOME_DIR/.grok/hooks/guard.sh"
  preflight_link "$GUARD_SRC" "$HOME_DIR/.cursor/hooks/guard.sh"
  preflight_link "$GUARD_SRC" "$HOME_DIR/.gemini/hooks/guard.sh"
  preflight_link "$CODEX_HOOKS_SRC" "$HOME_DIR/.codex/hooks.json"
  preflight_link "$GROK_HOOKS_SRC" "$HOME_DIR/.grok/hooks/command-guard.json"
  preflight_link "$CURSOR_HOOKS_SRC" "$HOME_DIR/.cursor/hooks.json"
  preflight_link "$GEMINI_POLICY_SRC" "$HOME_DIR/.gemini/policies/dotfiles-agent-pack.toml"
  preflight_link "$SHARED_SKILLS" "$HOME_DIR/.claude/skills"
  preflight_link "$SHARED_SKILLS" "$HOME_DIR/.agents/skills"
  preflight_link "$SHARED_SKILLS" "$HOME_DIR/.cursor/skills"
  preflight_link "$STATUS_SRC" "$HOME_DIR/.local/bin/agent-status"
  preflight_file "$stage/code.md" "$HOME_DIR/code/AGENTS.md"
  preflight_file "$stage/personal.md" "$HOME_DIR/code/personal/AGENTS.md"
  preflight_file "$stage/work.md" "$HOME_DIR/code/work/AGENTS.md"
  if { [ -e "$git_local" ] || [ -L "$git_local" ]; } && { [ ! -f "$git_local" ] || [ -L "$git_local" ]; }; then
    fail "Git identity target must be a regular file: $git_local"
  fi
}

run_check() (
  local stage
  stage=$(mktemp -d "${TMPDIR:-/tmp}/agent-pack-check.XXXXXX")
  trap 'find "$stage" -depth -delete 2>/dev/null || true' EXIT
  make_stage "$stage"

  log "Agent pack check"
  check_generated "generated machine law" "$ASSEMBLED" "$stage/law.md" 600
  check_generated "Codex machine law" "$HOME_DIR/.codex/AGENTS.md" "$stage/law.md" 600
  check_generated "Grok machine law" "$HOME_DIR/.grok/AGENTS.md" "$stage/law.md" 600
  check_file "Claude wrapper" "$HOME_DIR/.claude/CLAUDE.md" "$stage/claude.md" 644
  check_file "Gemini wrapper" "$HOME_DIR/.gemini/GEMINI.md" "$stage/gemini.md" 644
  check_file "Claude settings policy" "$HOME_DIR/.claude/settings.json" "$stage/claude-settings.json" 600
  check_file "Gemini settings policy" "$HOME_DIR/.gemini/settings.json" "$stage/gemini-settings.json" 600
  check_file "Codex autonomy config" "$HOME_DIR/.codex/config.toml" "$stage/codex-config.toml" 600
  check_file "Grok autonomy config" "$HOME_DIR/.grok/config.toml" "$stage/grok-config.toml" 600
  check_link "Claude command guard" "$HOME_DIR/.claude/hooks/guard.sh" "$GUARD_SRC"
  check_link "Codex command guard" "$HOME_DIR/.codex/hooks/guard.sh" "$GUARD_SRC"
  check_link "Grok command guard" "$HOME_DIR/.grok/hooks/guard.sh" "$GUARD_SRC"
  check_link "Cursor command guard" "$HOME_DIR/.cursor/hooks/guard.sh" "$GUARD_SRC"
  check_link "Gemini command guard" "$HOME_DIR/.gemini/hooks/guard.sh" "$GUARD_SRC"
  check_link "Codex hooks" "$HOME_DIR/.codex/hooks.json" "$CODEX_HOOKS_SRC"
  check_link "Grok hooks" "$HOME_DIR/.grok/hooks/command-guard.json" "$GROK_HOOKS_SRC"
  check_link "Cursor hooks" "$HOME_DIR/.cursor/hooks.json" "$CURSOR_HOOKS_SRC"
  check_link "Gemini autonomy policy" "$HOME_DIR/.gemini/policies/dotfiles-agent-pack.toml" "$GEMINI_POLICY_SRC"
  check_link "Claude shared skills" "$HOME_DIR/.claude/skills" "$SHARED_SKILLS"
  check_link "Codex open-agent skills" "$HOME_DIR/.agents/skills" "$SHARED_SKILLS"
  check_link "Cursor shared skills" "$HOME_DIR/.cursor/skills" "$SHARED_SKILLS"
  check_link "agent-status command" "$HOME_DIR/.local/bin/agent-status" "$STATUS_SRC"
  check_private_mode_if_present "Claude local settings private mode" "$HOME_DIR/.claude/settings.local.json"
  check_private_file_mode "Git local identity private mode" "$GIT_LOCAL"
  check_file "code container law" "$HOME_DIR/code/AGENTS.md" "$stage/code.md" 644
  check_file "personal container law" "$HOME_DIR/code/personal/AGENTS.md" "$stage/personal.md" 644
  check_file "work container law" "$HOME_DIR/code/work/AGENTS.md" "$stage/work.md" 644
  check_private_ignored "private machine map is gitignored" "$LAW_PRIVATE"
  check_private_ignored "generated machine law is gitignored" "$ASSEMBLED"
  "$PACK/tests/guard-tests.sh"
  log "Agent pack check passed."
)

if [ "$MODE" = check ]; then
  run_check
  exit 0
fi

STAGE=$(mktemp -d "${TMPDIR:-/tmp}/agent-pack-install.XXXXXX")
trap 'find "$STAGE" -depth -delete 2>/dev/null || true' EXIT
make_stage "$STAGE"
preflight_all "$STAGE"

if [ "$MODE" = dry-run ]; then
  log "Agent pack dry run"
  for target in \
    "$HOME_DIR/.codex/AGENTS.md" "$HOME_DIR/.grok/AGENTS.md" \
    "$HOME_DIR/.claude/CLAUDE.md" "$HOME_DIR/.claude/settings.json" \
    "$HOME_DIR/.gemini/GEMINI.md" "$HOME_DIR/.gemini/settings.json" \
    "$HOME_DIR/.codex/config.toml" "$HOME_DIR/.grok/config.toml" \
    "$HOME_DIR/.codex/hooks.json" "$HOME_DIR/.grok/hooks/command-guard.json" \
    "$HOME_DIR/.cursor/hooks.json" "$HOME_DIR/.gemini/policies/dotfiles-agent-pack.toml" \
    "$HOME_DIR/.codex/hooks/guard.sh" "$HOME_DIR/.claude/hooks/guard.sh" \
    "$HOME_DIR/.grok/hooks/guard.sh" "$HOME_DIR/.cursor/hooks/guard.sh" "$HOME_DIR/.gemini/hooks/guard.sh" \
    "$HOME_DIR/.agents/skills" "$HOME_DIR/.claude/skills" "$HOME_DIR/.cursor/skills" \
    "$HOME_DIR/.local/bin/agent-status" \
    "$HOME_DIR/.claude/settings.local.json (mode 600 if present)" \
    "$HOME_DIR/code/AGENTS.md" "$HOME_DIR/code/personal/AGENTS.md" "$HOME_DIR/code/work/AGENTS.md"; do
    planned "$target"
  done
  exit 0
fi

log "Agent pack install"
log "  pack: $PACK"
log "  home: $HOME_DIR"

for dir in "$HOME_DIR/.codex/hooks" "$HOME_DIR/.grok/hooks" "$HOME_DIR/.claude/hooks" \
  "$HOME_DIR/.cursor/hooks" "$HOME_DIR/.gemini/hooks" "$HOME_DIR/.gemini/policies" \
  "$HOME_DIR/.agents" "$HOME_DIR/.local/bin" \
  "$HOME_DIR/code/personal" "$HOME_DIR/code/work" "$HOME_DIR/.config/git"; do
  mkdir -p "$dir"
done

if [ -f "$LAW_PRIVATE" ]; then
  chmod 600 "$LAW_PRIVATE"
fi
for private_runtime in "${PRIVATE_RUNTIME_FILES[@]}"; do
  [ ! -f "$private_runtime" ] || chmod 600 "$private_runtime"
done

apply_file "$STAGE/law.md" "$ASSEMBLED" 600 1
apply_file "$STAGE/law.md" "$HOME_DIR/.codex/AGENTS.md" 600
apply_file "$STAGE/law.md" "$HOME_DIR/.grok/AGENTS.md" 600
apply_file "$STAGE/claude.md" "$HOME_DIR/.claude/CLAUDE.md" 644
apply_file "$STAGE/gemini.md" "$HOME_DIR/.gemini/GEMINI.md" 644
apply_file "$STAGE/claude-settings.json" "$HOME_DIR/.claude/settings.json" 600 1
apply_file "$STAGE/gemini-settings.json" "$HOME_DIR/.gemini/settings.json" 600 1
apply_file "$STAGE/codex-config.toml" "$HOME_DIR/.codex/config.toml" 600 1
apply_file "$STAGE/grok-config.toml" "$HOME_DIR/.grok/config.toml" 600 1

apply_link "$GUARD_SRC" "$HOME_DIR/.claude/hooks/guard.sh"
apply_link "$GUARD_SRC" "$HOME_DIR/.codex/hooks/guard.sh"
apply_link "$GUARD_SRC" "$HOME_DIR/.grok/hooks/guard.sh"
apply_link "$GUARD_SRC" "$HOME_DIR/.cursor/hooks/guard.sh"
apply_link "$GUARD_SRC" "$HOME_DIR/.gemini/hooks/guard.sh"
apply_link "$CODEX_HOOKS_SRC" "$HOME_DIR/.codex/hooks.json"
apply_link "$GROK_HOOKS_SRC" "$HOME_DIR/.grok/hooks/command-guard.json"
apply_link "$CURSOR_HOOKS_SRC" "$HOME_DIR/.cursor/hooks.json"
apply_link "$GEMINI_POLICY_SRC" "$HOME_DIR/.gemini/policies/dotfiles-agent-pack.toml"
apply_link "$SHARED_SKILLS" "$HOME_DIR/.claude/skills"
apply_link "$SHARED_SKILLS" "$HOME_DIR/.agents/skills"
apply_link "$SHARED_SKILLS" "$HOME_DIR/.cursor/skills"
apply_link "$STATUS_SRC" "$HOME_DIR/.local/bin/agent-status"

apply_file "$STAGE/code.md" "$HOME_DIR/code/AGENTS.md" 644
apply_file "$STAGE/personal.md" "$HOME_DIR/code/personal/AGENTS.md" 644
apply_file "$STAGE/work.md" "$HOME_DIR/code/work/AGENTS.md" 644

if [ ! -e "$GIT_LOCAL" ]; then
  cp "$PACK/config/git.local.example" "$GIT_LOCAL"
  chmod 600 "$GIT_LOCAL"
  installed "$GIT_LOCAL (replace placeholder identity values)"
else
  chmod 600 "$GIT_LOCAL"
  ok "$GIT_LOCAL"
fi

log ""
run_check
log ""
log "Done. Start a new agent session so every runtime reloads the installed policy."
log "Codex may require one-time hook review with /hooks after a hook definition changes."
