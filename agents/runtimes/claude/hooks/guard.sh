#!/bin/bash
# Claude Code pre-tool-use guard — blocks dangerous commands in bypass mode.
# Exit 0 = allow, exit 1 = block (stderr shown as reason).

set -euo pipefail

INPUT=$(cat)
TOOL=$(echo "$INPUT" | jq -r '.tool_name // empty')

# Only guard Bash calls
[[ "$TOOL" != "Bash" ]] && exit 0

CMD=$(echo "$INPUT" | jq -r '.tool_input.command // empty')
[[ -z "$CMD" ]] && exit 0

block() {
  echo "BLOCKED: $1" >&2
  exit 1
}

# --- Destructive Git ---

# Force push
echo "$CMD" | grep -qE 'git\s+push\s+.*(-f|--force|--force-with-lease)' && \
  block "git force push"

# Push to main/master
echo "$CMD" | grep -qE 'git\s+push\s+\S+\s+(main|master)\b' && \
  block "git push to main/master"

# All git push (including bare 'git push')
echo "$CMD" | grep -qE 'git\s+push(\s|$)' && \
  block "git push — review and run manually"

# Reset hard
echo "$CMD" | grep -qE 'git\s+reset\s+--hard' && \
  block "git reset --hard"

# Checkout discard all
echo "$CMD" | grep -qE 'git\s+checkout\s+--\s*\.' && \
  block "git checkout -- . (discard all changes)"

# Restore discard all
echo "$CMD" | grep -qE 'git\s+restore\s+\.' && \
  block "git restore . (discard all changes)"

# Force-delete branch
echo "$CMD" | grep -qE 'git\s+branch\s+-D' && \
  block "git branch -D (force delete)"

# Clean untracked
echo "$CMD" | grep -qE 'git\s+clean\s+-[a-zA-Z]*f' && \
  block "git clean -f (delete untracked files)"

# --- Dangerous Filesystem ---

# rm -rf
echo "$CMD" | grep -qE '\brm\s+-[a-zA-Z]*r[a-zA-Z]*f|\brm\s+-[a-zA-Z]*f[a-zA-Z]*r' && \
  block "rm -rf (recursive force delete)"

# rm -r targeting home or root
echo "$CMD" | grep -qE '\brm\s+-[a-zA-Z]*r.*\s+(~/|/Users|/home|/tmp|/var|/)' && \
  block "rm -r on sensitive path"

# chmod 777
echo "$CMD" | grep -qE '\bchmod\s+777' && \
  block "chmod 777"

# Writing to system paths
echo "$CMD" | grep -qE '>\s*/etc/|>\s*/usr/' && \
  block "write to system path (/etc or /usr)"

# --- Network / Deploy / Publish ---

# npm/pnpm/yarn publish
echo "$CMD" | grep -qE '\b(npm|pnpm|yarn)\s+publish' && \
  block "package publish"

# docker push
echo "$CMD" | grep -qE '\bdocker\s+push' && \
  block "docker push"

# curl/wget with mutating methods
echo "$CMD" | grep -qE '\bcurl\s.*-X\s*(POST|PUT|DELETE|PATCH)' && \
  block "curl with mutating HTTP method"
echo "$CMD" | grep -qE '\bcurl\s.*--data|curl\s.*-d\s' && \
  block "curl with data (implicit POST)"
echo "$CMD" | grep -qE '\bwget\s+--post' && \
  block "wget POST"

# gh destructive actions
echo "$CMD" | grep -qE '\bgh\s+pr\s+merge' && \
  block "gh pr merge"
echo "$CMD" | grep -qE '\bgh\s+issue\s+close' && \
  block "gh issue close"

# --- Other ---

# kill -9 / killall
echo "$CMD" | grep -qE '\bkill\s+-9|\bkillall\b' && \
  block "kill -9 / killall"

# All checks passed
exit 0
