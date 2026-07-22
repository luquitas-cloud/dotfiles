#!/usr/bin/env bash
# Human-readable, read-only proof of the portable agent contract.
set -u

SCRIPT_PATH=$0
while [ -L "$SCRIPT_PATH" ]; do
  LINK_TARGET=$(readlink "$SCRIPT_PATH")
  case "$LINK_TARGET" in
    /*) SCRIPT_PATH=$LINK_TARGET ;;
    *) SCRIPT_PATH=$(cd "$(dirname "$SCRIPT_PATH")" && pwd)/$LINK_TARGET ;;
  esac
done
PACK=$(cd "$(dirname "$SCRIPT_PATH")" && pwd)
DOTFILES=$(cd "$PACK/.." && pwd)
HOME_DIR=${HOME:?HOME must be set}
SHARED_SKILLS="$PACK/skills/shared"
VERBOSE=0
FAILURES=0

usage() {
  printf '%s\n' "Usage: agent-status [--verbose]"
}

case "${1:-}" in
  "") ;;
  --verbose) VERBOSE=1 ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac
[ "$#" -le 1 ] || { usage >&2; exit 2; }

pass() { printf '  %-18s %s\n' "$1" "$2"; }
fail() {
  printf '  %-18s %s\n' "$1" "$2"
  FAILURES=$((FAILURES + 1))
}

fingerprint_tree() {
  local root="$1"
  (
    cd "$DOTFILES" || exit 1
    find "$root" -type f \
      ! -name '.DS_Store' \
      ! -name '.AGENTS.assembled.md' \
      ! -name '*.private.md' \
      -print | LC_ALL=C sort | while IFS= read -r path; do
        printf '%s\n' "$path"
        shasum -a 256 "$path" | awk '{print $1}'
      done
  ) | shasum -a 256 | awk '{print $1}'
}

skill_names() {
  local skill_file name first=1
  for skill_file in "$SHARED_SKILLS"/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    name=$(basename "$(dirname "$skill_file")")
    if [ "$first" -eq 0 ]; then
      printf ', '
    fi
    printf '%s' "$name"
    first=0
  done
  [ "$first" -eq 0 ] || printf '%s' '<none>'
  printf '\n'
}

project_root=""
if project_root=$(git -C "$PWD" rev-parse --show-toplevel 2>/dev/null); then
  :
else
  project_root=""
fi

printf '%s\n' "Agent pack status"
pass "current directory" "$PWD"
pass "portable source" "$DOTFILES"

if git -C "$DOTFILES" rev-parse --is-inside-work-tree >/dev/null 2>&1; then
  commit=$(git -C "$DOTFILES" rev-parse HEAD 2>/dev/null || printf '%s' '<no-commit>')
  pass "source commit" "$commit"
  if [ -n "$(git -C "$DOTFILES" status --porcelain --untracked-files=normal -- agents 2>/dev/null)" ]; then
    pass "source state" "MODIFIED - commit before expecting another machine to match"
  else
    pass "source state" "clean"
  fi
else
  fail "source repository" "MISSING - $DOTFILES is not a Git worktree"
fi

pack_fingerprint=$(fingerprint_tree agents)
skills_fingerprint=$(fingerprint_tree agents/skills/shared)
pass "pack fingerprint" "$pack_fingerprint"
pass "skills fingerprint" "$skills_fingerprint"
pass "shared skills" "$(skill_names)"

if [ -n "$project_root" ]; then
  pass "project root" "$project_root"
  if [ -f "$project_root/AGENTS.md" ]; then
    pass "project law" "$project_root/AGENTS.md"
  elif [[ "$project_root" = "$HOME_DIR/code/"* ]]; then
    fail "project law" "MISSING - add $project_root/AGENTS.md"
  else
    pass "project law" "not required outside a ~/code product root"
  fi

  if [ -f "$project_root/CLAUDE.md" ]; then
    if [ "$(sed -n '1p' "$project_root/CLAUDE.md")" = '@AGENTS.md' ]; then
      pass "Claude project" "imports @AGENTS.md"
    else
      fail "Claude project" "does not begin with @AGENTS.md"
    fi
  else
    pass "Claude project" "absent - optional"
  fi
else
  pass "project root" "none - machine/meta directory"
  pass "project law" "global law only"
fi

check_log=$(mktemp "${TMPDIR:-/tmp}/agent-status.XXXXXX")
if "$PACK/install.sh" --check >"$check_log" 2>&1; then
  pass "installed pack" "MATCH"
else
  fail "installed pack" "DRIFT - run ~/dotfiles/install.sh --dry-run"
fi

if command -v grok >/dev/null 2>&1; then
  grok_inspect=$(grok --cwd "$PWD" inspect --json 2>/dev/null || true)
  expected_skill_count=0
  grok_skill_paths_ok=1
  for skill_file in "$SHARED_SKILLS"/*/SKILL.md; do
    [ -f "$skill_file" ] || continue
    name=$(basename "$(dirname "$skill_file")")
    expected_path="$HOME_DIR/.agents/skills/$name/SKILL.md"
    expected_skill_count=$((expected_skill_count + 1))
    printf '%s' "$grok_inspect" | grep -Fq "$expected_path" || grok_skill_paths_ok=0
  done
  discovered_skill_count=$(printf '%s' "$grok_inspect" | grep -cF "$HOME_DIR/.agents/skills/" || true)
  if [ "$grok_skill_paths_ok" -eq 1 ] && [ "$discovered_skill_count" -eq "$expected_skill_count" ]; then
    pass "Grok skills" "DISCOVERED"
  else
    fail "Grok skills" "DRIFT - runtime discovery differs from shared source"
  fi
else
  fail "Grok skills" "UNVERIFIED - grok is required"
fi

if [ "$VERBOSE" -eq 1 ] || [ "$FAILURES" -ne 0 ]; then
  printf '\n%s\n' "Installed contract details"
  sed 's/^/  /' "$check_log"
fi
unlink "$check_log"

printf '\n'
if [ "$FAILURES" -eq 0 ]; then
  printf '%s\n' "COPACETIC - portable core, installed runtimes, shared skills, and active project law agree."
  exit 0
fi

printf '%s\n' "DRIFT - $FAILURES contract check(s) need attention."
exit 1
