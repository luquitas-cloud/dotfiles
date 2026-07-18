#!/usr/bin/env bash
# Wire tool homes to the portable agent pack. Idempotent. Safe to re-run.
# Public pack + optional private overlays (never commit private overlays).
set -euo pipefail

PACK="$(cd "$(dirname "$0")" && pwd)"
HOME_DIR="${HOME}"
LAW_PUBLIC="$PACK/law/AGENTS.md"
LAW_PRIVATE="$PACK/law/workspace.private.md"
SHARED_SKILLS="$PACK/skills/shared"
CLAUDE_SRC="$PACK/runtimes/claude/CLAUDE.md"
GUARD_SRC="$PACK/runtimes/claude/hooks/guard.sh"
ASSEMBLED="$PACK/law/.AGENTS.assembled.md"  # gitignored generated file

log() { printf '%s\n' "$*"; }
ok() { log "ok        $1"; }
linked() { log "linked    $1"; }
copied() { log "copied    $1"; }
skip() { log "skip      $1 ($2)"; }
warn() { log "warn      $1"; }

link_force() {
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ] && [ "$(readlink "$dst")" = "$src" ]; then
    ok "$dst"
    return 0
  fi
  if [ -e "$dst" ] || [ -L "$dst" ]; then
    rm -f "$dst"
  fi
  ln -s "$src" "$dst"
  linked "$dst -> $src"
}

write_file() {
  # Always replace destination as a real file. Never write through a symlink
  # (that would corrupt pack sources if dst previously linked into the pack).
  local src="$1" dst="$2"
  mkdir -p "$(dirname "$dst")"
  if [ -L "$dst" ]; then
    rm -f "$dst"
  fi
  if [ -f "$dst" ] && [ ! -L "$dst" ] && cmp -s "$src" "$dst"; then
    ok "$dst"
    return 0
  fi
  cp "$src" "$dst"
  copied "$dst"
}

ensure_dir() {
  mkdir -p "$1"
  ok "dir $1"
}

assemble_law() {
  if [ ! -f "$LAW_PUBLIC" ]; then
    echo "error: missing machine law at $LAW_PUBLIC" >&2
    exit 1
  fi
  {
    cat "$LAW_PUBLIC"
    if [ -f "$LAW_PRIVATE" ]; then
      printf '\n\n---\n\n'
      cat "$LAW_PRIVATE"
    fi
  } > "$ASSEMBLED"
  if [ -f "$LAW_PRIVATE" ]; then
    log "assembled private workspace map into machine law"
  else
    warn "no workspace.private.md - using public skeleton only (copy from workspace.private.example.md)"
  fi
}

# --- preflight ---
if [ ! -f "$CLAUDE_SRC" ]; then
  echo "error: missing Claude wrapper at $CLAUDE_SRC" >&2
  exit 1
fi

log "Agent pack install"
log "  pack: $PACK"
log "  home: $HOME_DIR"
log ""

ensure_dir "$HOME_DIR/.codex"
ensure_dir "$HOME_DIR/.grok"
ensure_dir "$HOME_DIR/.claude"
ensure_dir "$HOME_DIR/.claude/hooks"
ensure_dir "$HOME_DIR/code/personal"
ensure_dir "$HOME_DIR/code/work"
ensure_dir "$HOME_DIR/.config/git"

# --- assemble public law + optional private map ---
assemble_law

# Write assembled law into tool homes as real files (not symlinks),
# so private inventory never needs to live in a published path alone.
write_file "$ASSEMBLED" "$HOME_DIR/.codex/AGENTS.md"
write_file "$ASSEMBLED" "$HOME_DIR/.grok/AGENTS.md"

# --- Claude: real file so @../.codex/AGENTS.md resolves from ~/.claude/ ---
write_file "$CLAUDE_SRC" "$HOME_DIR/.claude/CLAUDE.md"

# --- Claude Bash guard ---
if [ -f "$GUARD_SRC" ]; then
  link_force "$GUARD_SRC" "$HOME_DIR/.claude/hooks/guard.sh"
  chmod +x "$HOME_DIR/.claude/hooks/guard.sh" 2>/dev/null || true
else
  warn "no guard.sh in pack"
fi

# --- shared skills → Claude ---
link_force "$SHARED_SKILLS" "$HOME_DIR/.claude/skills"

# --- Grok: ensure skills.paths includes shared (append once) ---
GROK_CFG="$HOME_DIR/.grok/config.toml"
SHARED_PATH="$HOME_DIR/dotfiles/agents/skills/shared"
if [ -f "$GROK_CFG" ]; then
  if grep -q 'dotfiles/agents/skills/shared' "$GROK_CFG" 2>/dev/null; then
    ok "grok skills.paths already includes shared"
  else
    {
      echo ""
      echo "# Managed by ~/dotfiles/agents/install.sh — shared portable skills"
      echo "[skills]"
      echo "paths = [\"$SHARED_PATH\"]"
    } >> "$GROK_CFG"
    linked "grok config.toml skills.paths"
  fi
else
  skip "grok config.toml" "missing - install Grok then re-run"
fi

# --- git local identity template (never overwrite existing) ---
GIT_LOCAL="$HOME_DIR/.config/git/local.gitconfig"
GIT_EXAMPLE="$PACK/config/git.local.example"
if [ ! -f "$GIT_LOCAL" ] && [ -f "$GIT_EXAMPLE" ]; then
  cp "$GIT_EXAMPLE" "$GIT_LOCAL"
  copied "$GIT_LOCAL (edit name/email)"
elif [ -f "$GIT_LOCAL" ]; then
  ok "git local identity present"
else
  skip "git local identity" "no example file"
fi

# --- workspace container AGENTS (public templates only) ---
write_file "$PACK/workspace/code.AGENTS.md" "$HOME_DIR/code/AGENTS.md"
write_file "$PACK/workspace/personal.AGENTS.md" "$HOME_DIR/code/personal/AGENTS.md"
write_file "$PACK/workspace/work.AGENTS.md" "$HOME_DIR/code/work/AGENTS.md"

# Optional private container notes (gitignored if you create them)
if [ -f "$PACK/workspace/personal.private.md" ]; then
  write_file "$PACK/workspace/personal.private.md" "$HOME_DIR/code/personal/AGENTS.md"
fi
if [ -f "$PACK/workspace/work.private.md" ]; then
  write_file "$PACK/workspace/work.private.md" "$HOME_DIR/code/work/AGENTS.md"
fi

# --- verify ---
log ""
log "Verify:"
for f in \
  "$HOME_DIR/.codex/AGENTS.md" \
  "$HOME_DIR/.grok/AGENTS.md" \
  "$HOME_DIR/.claude/CLAUDE.md" \
  "$HOME_DIR/code/AGENTS.md"
do
  if [ -e "$f" ] && [ -s "$f" ]; then
    log "  pass  $f ($(wc -l < "$f" | tr -d ' ') lines)"
  else
    log "  FAIL  $f"
  fi
done

if [ -f "$LAW_PRIVATE" ]; then
  if grep -q 'Private product inventory' "$HOME_DIR/.codex/AGENTS.md" 2>/dev/null; then
    log "  pass  private map merged into installed law"
  else
    log "  FAIL  private map not found in installed law"
  fi
fi

log ""
log "Done. Next: open a new agent session so it reloads global rules."
log "Public pack only is git-safe. Private: workspace.private.md, op-keys.local.zsh, git local.gitconfig"
log "New machine docs: $PACK/BOOTSTRAP.md"
