# Runtime: Claude Code

## Homes

| Path | Role |
|------|------|
| `~/.claude/` | Tool home |
| `~/.claude/CLAUDE.md` | Global wrapper (copied from this pack on install) |
| `~/.claude/hooks/guard.sh` | Bash pre-tool guard (symlink into pack) |
| `~/.claude/skills` | Symlink to `dotfiles/agents/skills/shared` |
| `~/dotfiles/agents/runtimes/claude/` | Portable sources for this runtime |

## Guardrails

`hooks/guard.sh` blocks high-risk Bash when Claude runs with elevated permissions: force-push, push to main/master, `git reset --hard`, `rm -rf`, package publish, etc.

Settings for hooks live in `~/.claude/settings.json` (machine-local; not fully mirrored in the pack). After a new machine bootstrap, confirm PreToolUse still points at `~/.claude/hooks/guard.sh`.

## Clarifications

- Thin global wrapper only - product law stays in each repo's `AGENTS.md` + `@AGENTS.md` CLAUDE.md.
- Doc-heavy multi-file work is a good fit for this runtime.
