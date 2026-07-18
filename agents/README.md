# Agent pack (portable)

This directory is the portable agent infrastructure for the operator's machines.

Clone `dotfiles` to `~/dotfiles` on a new Mac, open a terminal agent, and say:

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
  install.sh                # safe installer with check, dry-run, and replace modes
  login-check.sh            # fast read-only invariant check for shell startup
  policy/                   # canonical cross-runtime command policy
  tests/                    # behavioral and clean-home installation tests
  law/
    AGENTS.md               # canonical machine law (one source of truth)
  runtimes/
    grok/                   # Grok-only notes, install expectations
    codex/                  # Codex-only notes, trust recipe
    claude/                 # Claude wrapper source + Bash guard
    cursor/                 # secondary IDE notes
  skills/
    README.md               # skill registry and conventions
    shared/                 # skills visible to Codex, Claude, and Grok
  workspace/
    *.AGENTS.md             # container templates installed under ~/code
```

## Design

| Layer | Purpose | Who loads it |
|-------|---------|--------------|
| **Law** | Map, hierarchy, autonomy, secrets, launch | Every agent (via install targets) |
| **Runtime space** | Tool-specific clarifications and guardrails | Humans + agents when debugging that tool |
| **Product repo** | Product law (`AGENTS.md`) | Agents working inside that repo |
| **Skills** | Reusable procedures | Shared by Codex, Claude, and Grok |

**Canonical edit path for machine law:** `law/AGENTS.md`  
After edits, run `install.sh`. Use `install.sh --check` to audit the current installation without changing files.

Do not fork machine law into `~/.codex`, `~/.grok`, or chat memory. Edit the pack.

## Tool load graph (after install)

```
law/AGENTS.md + law/workspace.private.md
    └── generated → law/.AGENTS.assembled.md
        ├── copy → ~/.codex/AGENTS.md    (Codex global)
        ├── copy → ~/.grok/AGENTS.md     (Grok global)
        └── include ← ~/.claude/CLAUDE.md (Claude global, thin)

skills/shared/
    └── symlink → ~/.agents/skills
    └── symlink → ~/.claude/skills
    └── Grok discovers the open-agent skills path

policy/command-guard.sh
    ├── symlink → ~/.codex/hooks/guard.sh
    ├── symlink → ~/.claude/hooks/guard.sh
    ├── symlink → ~/.grok/hooks/guard.sh
    └── symlink → ~/.cursor/hooks/guard.sh

runtimes/codex/hooks.json
    └── symlink → ~/.codex/hooks.json

runtimes/grok/hooks/command-guard.json
    └── symlink → ~/.grok/hooks/command-guard.json

runtimes/cursor/hooks.json
    └── symlink → ~/.cursor/hooks.json

workspace/*.AGENTS.md + workspace/*.private.md
    └── merged copy → ~/code/{personal,work}/AGENTS.md
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
| `workspace/*.AGENTS.md` templates | `workspace/*.private.md` overlays |
| `op-keys.zsh` loader only | `~/.config/zsh/op-keys.local.zsh` |
| `.gitconfig` without identity | `~/.config/git/local.gitconfig` |
| skills, runtimes, install, bootstrap | generated `law/.AGENTS.assembled.md` |

## Safety model

- Default install refuses unmanaged files and symlinks instead of hiding or replacing them.
- `--replace` is explicit, creates no backup, and never removes directories.
- `--check` and `--dry-run` do not modify installed state.
- High autonomy baseline: Codex `approval_policy = "never"` + `sandbox_mode = "danger-full-access"`; Claude `bypassPermissions`; Grok `yolo = true` + `permission_mode = "always-approve"`.
- Shared command guard is linked into Codex, Claude, Grok, and Cursor hook locations. Hard stops stay armed while prompts stay off.
- Shared skills live under `skills/shared/` and install to `~/.agents/skills` and `~/.claude/skills` (Grok discovers the open-agent path).
- Claude local settings stay private with mode `0600`. Managed autonomy keys in Codex/Claude/Grok configs are rewritten by install; unrelated keys are preserved.
- Hooks hard-stop only destructive/irreversible actions (force-push, direct or implicit push to main, bare push, destructive Git cleanup, recursive force-delete, force-kill, disk/system mutation, `curl|sh`, infra destroy, protected path writes). Scoped package commands and normal deploys are allowed under yolo.
- `~/dotfiles/check.sh` is the final source and live-machine verification entrypoint.
- Interactive shells run a fast read-only invariant check and stay silent unless installed agent policy has drifted.
