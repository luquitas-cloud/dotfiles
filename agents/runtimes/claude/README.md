# Runtime: Claude Code

## Homes

| Path | Role |
|------|------|
| `~/.claude/` | Tool home |
| `~/.claude/CLAUDE.md` | Global wrapper (copied from this pack on install) |
| `~/.claude/hooks/guard.sh` | Bash pre-tool guard (symlink into pack) |
| `~/.claude/skills` | Symlink to `dotfiles/agents/skills/shared` |
| `~/dotfiles/agents/runtimes/claude/` | Portable sources for this runtime |

## Autonomy and guardrails

Installer enforces:

- `permissions.defaultMode = "bypassPermissions"` (high autonomy / always-approve)
- Managed `PreToolUse` hook on Bash → `~/.claude/hooks/guard.sh`

The shared command guard hard-stops only destructive/irreversible actions (force-push, direct or implicit push to main, bare push, destructive Git cleanup, `rm -rf`, force-kill, disk/system mutation, `curl|sh`, infra destroy, and protected-path mutation). Scoped package commands and normal deploys are allowed. Unrelated user settings are preserved. Grok also discovers this Claude hook path for compatibility.

## Clarifications

- Thin global wrapper only - product law stays in each repo's `AGENTS.md` + `@AGENTS.md` CLAUDE.md.
- Doc-heavy multi-file work is a good fit for this runtime.
