@../.codex/AGENTS.md

# Claude Code - global wrapper

This file must live at `~/.claude/CLAUDE.md` (install copies it there so the relative include resolves).

## Role

- Machine law: `~/.codex/AGENTS.md` (symlink into the portable pack `law/AGENTS.md`).
- Product law: the open repo's `AGENTS.md`.
- Bash guardrails: `~/.claude/hooks/guard.sh` (force-push, push to main/master, `reset --hard`, `rm -rf`, etc.).

## Rules

- Stay thin. Do not duplicate or fork machine or product law here.
- On conflict: user task > repo `AGENTS.md` > machine law > this wrapper.
- Portable pack: `~/dotfiles/agents/` (see README + BOOTSTRAP).
