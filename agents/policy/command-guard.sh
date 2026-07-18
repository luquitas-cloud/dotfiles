#!/bin/bash
# Portable PreToolUse command guard for Codex, Claude, Grok, and Cursor.
# High autonomy (yolo) is the baseline. This guard only hard-stops destructive
# or irreversible machine/repo actions.
# Exit 0 allows the tool call. Exit 2 blocks it and surfaces stderr.
# Accepts Claude/Codex snake_case payloads and Grok camelCase payloads.

set -euo pipefail

INPUT=$(cat)

json_raw() {
  local keypath="$1"
  if [ -x /usr/bin/plutil ]; then
    printf '%s' "$INPUT" | /usr/bin/plutil -extract "$keypath" raw -o - - 2>/dev/null || true
    return
  fi
  if command -v jq >/dev/null 2>&1; then
    printf '%s' "$INPUT" | jq -r --arg k "$keypath" '
      getpath($k | split(".")) // empty
    ' 2>/dev/null || true
    return
  fi
  printf '%s\n' "BLOCKED: no supported JSON parser is available for the command guard" >&2
  exit 2
}

json_first() {
  local key value
  for key in "$@"; do
    value=$(json_raw "$key")
    if [ -n "$value" ] && [ "$value" != "null" ]; then
      printf '%s' "$value"
      return 0
    fi
  done
  return 0
}

TOOL=$(json_first tool_name toolName)
case "$TOOL" in
  Bash|run_terminal_command|Shell) ;;
  *) exit 0 ;;
esac

CMD=$(json_first tool_input.command toolInput.command)
[ -n "$CMD" ] || exit 0

block() {
  # Claude/Codex: exit 2 + stderr. Grok: exit 2 and optional deny JSON on stdout.
  printf 'BLOCKED: %s\n' "$1" >&2
  printf '%s\n' '{"decision":"deny","reason":"blocked by portable command guard"}'
  exit 2
}

matches() {
  printf '%s\n' "$CMD" | grep -Eq "$1"
}

# Destructive Git history / branch / working-tree operations.
# Feature-branch pushes with an explicit non-main refspec are allowed.
GIT_COMMAND='(^|[;&|[:space:]])([^;&|[:space:]]*/)?git([[:space:]]+(-C|--git-dir|--work-tree)[[:space:]]+[^;&|[:space:]]+)*[[:space:]]+'
matches "${GIT_COMMAND}push[[:space:]][^;&|]*--force(-with-lease|-if-includes)?([=[:space:]]|$)" && block "force-push is destructive"
matches "${GIT_COMMAND}push[[:space:]]+([^;&|[:space:]]+[[:space:]]+)*-[^;&|[:space:]]*f([^;&|[:space:]]*)?([[:space:]]|$)" && block "force-push is destructive"
matches "${GIT_COMMAND}push[[:space:]][^;&|]*[[:space:]]\\+[^;&|[:space:]]+" && block "a leading plus refspec is a force-push"
matches "${GIT_COMMAND}push[[:space:]]+([^;&|[:space:]]+[[:space:]]+)*([^;&|[:space:]]*:)?(refs/heads/)?(main|master)([[:space:]]|$)" && block "direct push to main or master is not allowed"
matches "${GIT_COMMAND}push[[:space:]][^;&|]*--delete([=[:space:]]|$)" && block "deleting a remote ref is destructive"
matches "${GIT_COMMAND}push[[:space:]]+[^;&|[:space:]]+[[:space:]]+:[^;&|[:space:]]+" && block "deleting a remote ref is destructive"
matches "${GIT_COMMAND}push([[:space:]]+-[^;&|[:space:]]+)*([[:space:]]+[^;&|[:space:]]+)?[[:space:]]*$" && block "git push requires an explicit non-main refspec"
matches "${GIT_COMMAND}reset[[:space:]]+--hard([[:space:]]|$)" && block "git reset --hard is destructive"
matches "${GIT_COMMAND}clean[[:space:]][^;&|]*(-[^;&|[:space:]]*f[^;&|[:space:]]*|--force)([[:space:]]|$)" && block "git clean with force deletes untracked files"
matches "${GIT_COMMAND}branch[[:space:]][^;&|]*(-D([[:space:]]|$)|--delete[[:space:]][^;&|]*--force|--force[[:space:]][^;&|]*--delete)" && block "force-deleting a branch is destructive"
matches "${GIT_COMMAND}(checkout[[:space:]]+--[[:space:]]*\.|restore[[:space:]]+\.)" && block "discarding all working-tree changes is destructive"

# Recursive forced deletion and disk/system destruction.
if matches '(^|[;&|[:space:]])([^;&|[:space:]]*/)?rm([[:space:]]|$)'; then
  if { matches '(^|[[:space:]])--recursive([=[:space:]]|$)' || matches '(^|[[:space:]])-[a-zA-Z]*r[a-zA-Z]*([[:space:]]|$)'; } && \
     { matches '(^|[[:space:]])--force([=[:space:]]|$)' || matches '(^|[[:space:]])-[a-zA-Z]*f[a-zA-Z]*([[:space:]]|$)'; }; then
    block "recursive forced deletion is not allowed"
  fi
fi
matches '(^|[;&|[:space:]])(diskutil[[:space:]]+(erase|partition)|mkfs([.[:alnum:]_-]*)?[[:space:]]|dd[[:space:]][^;&|]*of=)' && block "disk erase, partition, filesystem, and raw-write commands require manual execution"
matches '(^|[;&|[:space:]])(launchctl[[:space:]]+(bootout|unload|remove)|pfctl[[:space:]]|route[[:space:]]+(add|delete|change)|networksetup[[:space:]])' && block "service, firewall, or routing changes require explicit approval"
matches '(^|[;&|[:space:]])([^;&|[:space:]]*/)?(kill|pkill)[[:space:]]+(-9|-KILL|-SIGKILL|-s[[:space:]]+(9|KILL|SIGKILL)|--signal(=|[[:space:]])(9|KILL|SIGKILL))([[:space:]]|$)' && block "force-killing processes requires explicit approval"
matches '(^|[;&|[:space:]])([^;&|[:space:]]*/)?killall([[:space:]]|$)' && block "killall requires explicit approval"
matches '(^|[;&|[:space:]])chmod[[:space:]]+(-R[[:space:]]+)?777([[:space:]]|$)' && block "chmod 777 is unsafe"

# Pipe remote content into a shell (classic footgun).
matches '(curl|wget)[^;&|]*\|[[:space:]]*(sudo[[:space:]]+)?(sh|bash|zsh)([[:space:]]|$)' && block "piping network content into a shell is not allowed"

# Destructive infrastructure teardown.
matches '(^|[;&|[:space:]])([^;&|[:space:]]*/)?(terraform|tofu)([[:space:]]+-chdir(=|[[:space:]])[^;&|[:space:]]+)*[[:space:]]+(destroy([[:space:]]|$)|apply[[:space:]][^;&|]*-destroy([=[:space:]]|$))' && block "destructive infrastructure mutation requires manual execution"
matches '(^|[;&|[:space:]])(kubectl[[:space:]]+delete|helm[[:space:]]+uninstall)([[:space:]]|$)' && block "destructive infrastructure mutation requires manual execution"

# Mutations of protected system paths. Copying a protected file out for reading
# remains allowed; mutation commands must target the protected path.
PROTECTED_SYSTEM='/(etc|usr|System|Library)(/[^;&|[:space:]]*)?'
matches "(>|>>|tee[[:space:]]+)([[:space:]]*)${PROTECTED_SYSTEM}([[:space:]]|$)" && block "writing to protected system paths requires explicit approval"
matches "(^|[;&|[:space:]])([^;&|[:space:]]*/)?(rm|chmod|chown|chgrp)[[:space:]][^;&|]*${PROTECTED_SYSTEM}([[:space:]]|$)" && block "mutating protected system paths requires explicit approval"
matches "(^|[;&|[:space:]])([^;&|[:space:]]*/)?(cp|mv|install|ln|mkdir|touch)[[:space:]]+([^;&|[:space:]]+[[:space:]]+)*${PROTECTED_SYSTEM}[[:space:]]*($|[;&|])" && block "writing to protected system paths requires explicit approval"

exit 0
