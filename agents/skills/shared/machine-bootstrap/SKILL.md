---
name: machine-bootstrap
description: Wire or repair the portable agent pack on this Mac (Grok, Codex, Claude global law, skills, command policy, and container AGENTS). Use when setting up a new machine, fixing a broken agent install, or when the operator asks to bootstrap agents, install the agent pack, or rewire global rules.
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
2. Dry-run, install, and verify:

```bash
bash ~/dotfiles/install.sh --dry-run
bash ~/dotfiles/install.sh
bash ~/dotfiles/check.sh
```

Scoped dependency commands such as `brew install`, `brew bundle`, `npm ci`, and `npx` are allowed when needed. Avoid surprise broad machine upgrades.

If `~/dotfiles` is missing, stop and ask for the git remote. Do not invent a partial law file under `~/.codex` only.

## Verify

- `~/.codex/AGENTS.md` and `~/.grok/AGENTS.md` are non-empty assembled law files
- If `workspace.private.md` exists, installed law includes the private inventory section
- `~/.claude/CLAUDE.md` includes machine law via `@../.codex/AGENTS.md`
- `~/.claude/hooks/guard.sh`, `~/.codex/hooks/guard.sh`, `~/.grok/hooks/guard.sh`, and `~/.cursor/hooks/guard.sh` are linked
- `~/.codex/hooks.json`, `~/.grok/hooks/command-guard.json`, and `~/.cursor/hooks.json` are linked
- High autonomy baseline is installed (Codex never/danger-full-access, Claude bypassPermissions, Grok yolo + always-approve)
- `~/.agents/skills` and `~/.claude/skills` point to the same shared source
- `~/code/AGENTS.md` (and personal/work containers) exist

## Never

- Fork machine law into chat or a second conflicting AGENTS file
- Commit secrets, emails, client names, or private product lists into tracked pack files
- Treat Documents Codex session folders as product roots
