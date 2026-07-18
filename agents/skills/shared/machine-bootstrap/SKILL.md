---
name: machine-bootstrap
description: Wire or repair Lucas's portable agent pack on this Mac (Grok, Codex, Claude global law, skills, container AGENTS). Use when setting up a new machine, fixing broken AGENTS symlinks, or when Lucas says bootstrap agents / install agent pack / rewire global rules.
---

# Machine bootstrap

## Source of truth

Portable pack: `~/dotfiles/agents/`

Read first:

1. `~/dotfiles/agents/README.md`
2. `~/dotfiles/agents/BOOTSTRAP.md`
3. `~/dotfiles/agents/law/AGENTS.md`

## Do

1. Ensure private overlays exist when this is a personal machine:
   - `agents/law/workspace.private.md` (from example)
   - `~/.config/git/local.gitconfig` (from example)
   - optional `~/.config/zsh/op-keys.local.zsh`
2. Run:

```bash
bash ~/dotfiles/agents/install.sh
```

If `~/dotfiles` is missing, stop and ask for the git remote. Do not invent a partial law file under `~/.codex` only.

## Verify

- `~/.codex/AGENTS.md` and `~/.grok/AGENTS.md` are non-empty assembled law files
- If `workspace.private.md` exists, installed law includes the private inventory section
- `~/.claude/CLAUDE.md` includes machine law via `@../.codex/AGENTS.md`
- `~/.claude/hooks/guard.sh` is linked
- `~/code/AGENTS.md` (and personal/work containers) exist

## Never

- Fork machine law into chat or a second conflicting AGENTS file
- Commit secrets, emails, client names, or private product lists into tracked pack files
- Treat Documents Codex session folders as product roots
