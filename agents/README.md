# Agent pack (portable)

This directory is the **portable agent infrastructure** for Lucas's machines.

Clone `dotfiles` (or copy `agents/`) onto a new laptop, open a terminal agent, and say:

> Read `~/dotfiles/agents/BOOTSTRAP.md` and implement it.

Or run:

```bash
~/dotfiles/agents/install.sh
```

## Layout

```
agents/
  README.md                 # this file - pack index
  BOOTSTRAP.md              # new-machine procedure for humans and agents
  install.sh                # wires tool homes to this pack (idempotent)
  law/
    AGENTS.md               # canonical machine law (one source of truth)
  runtimes/
    grok/                   # Grok-only notes, install expectations
    codex/                  # Codex-only notes, trust recipe
    claude/                 # Claude wrapper source + Bash guard
    cursor/                 # secondary IDE notes
  skills/
    README.md               # skill registry and conventions
    shared/                 # skills visible to Grok + Claude after install
  workspace/
    *.AGENTS.md             # container templates installed under ~/code
```

## Design

| Layer | Purpose | Who loads it |
|-------|---------|--------------|
| **Law** | Map, hierarchy, autonomy, secrets, launch | Every agent (via install targets) |
| **Runtime space** | Tool-specific clarifications and guardrails | Humans + agents when debugging that tool |
| **Product repo** | Product law (`AGENTS.md`) | Agents working inside that repo |
| **Skills** | Reusable procedures | Grok / Claude / Codex discovery paths |

**Canonical edit path for machine law:** `law/AGENTS.md`  
After edits, run `install.sh` (or rely on symlinks already pointing here).

Do not fork machine law into `~/.codex`, `~/.grok`, or chat memory. Edit the pack.

## Tool load graph (after install)

```
law/AGENTS.md
    ├── symlink → ~/.codex/AGENTS.md     (Codex global)
    ├── symlink → ~/.grok/AGENTS.md      (Grok global)
    └── include ← ~/.claude/CLAUDE.md    (Claude global, thin)

runtimes/claude/hooks/guard.sh
    └── symlink → ~/.claude/hooks/guard.sh

skills/shared/
    └── symlink → ~/.claude/skills
    └── Grok [skills].paths entry
```

## What does not live here (especially in public git)

- Secrets, recovery codes, `.env` values, 1Password item paths  
- Real name / email (use `~/.config/git/local.gitconfig`)  
- Private product inventory, client names, work codenames (use `law/workspace.private.md`)  
- Product architecture (belongs in each private/public product repo)  
- Huge session logs / sqlite DBs (tool homes only)  

## Public vs private

| Public (tracked) | Private (gitignored / outside repo) |
|------------------|-------------------------------------|
| `law/AGENTS.md` skeleton | `law/workspace.private.md` |
| `workspace/*.AGENTS.md` templates | `workspace/*.private.md` |
| `op-keys.zsh` loader only | `~/.config/zsh/op-keys.local.zsh` |
| `.gitconfig` without identity | `~/.config/git/local.gitconfig` |
| skills, runtimes, install, bootstrap | generated `law/.AGENTS.assembled.md` |
