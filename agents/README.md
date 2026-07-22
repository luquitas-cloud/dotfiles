# Agent pack (portable)

This directory is the portable agent infrastructure for the operator's machines.

After the one manual Homebrew installation, clone `dotfiles` to `~/dotfiles`,
open a terminal agent, and say:

> Read `~/dotfiles/agents/BOOTSTRAP.md` and implement it.

Or run the complete provisioner:

```bash
~/dotfiles/bootstrap.sh
```

## Layout

```
agents/
  README.md                 # this file - pack index
  BOOTSTRAP.md              # new-machine procedure for humans and agents
  private-state.sh          # encrypted 1Password metadata push/pull
  install.sh                # safe installer with check, dry-run, and replace modes
  login-check.sh            # fast read-only invariant check for shell startup
  status.sh                 # human-readable fingerprints and local drift report
  policy/                   # canonical cross-runtime command policy
  tests/                    # behavioral and clean-home installation tests
  law/
    AGENTS.md               # canonical machine law (one source of truth)
  runtimes/
    grok/                   # Grok-only notes, install expectations
    codex/                  # Codex-only notes, trust recipe
    claude/                 # Claude wrapper source + Bash guard
    gemini/                 # Gemini wrapper, policy, and runtime notes
    cursor/                 # secondary IDE notes
  skills/
    README.md               # skill registry and conventions
    shared/                 # skills visible to every supported runtime
  workspace/
    *.AGENTS.md             # container templates installed under ~/code
```

## Design

| Layer | Purpose | Who loads it |
|-------|---------|--------------|
| **Law** | Map, hierarchy, autonomy, secrets, launch | Codex, Claude, Grok, and Gemini globally; Cursor through repo `AGENTS.md` |
| **Runtime space** | Tool-specific clarifications and guardrails | Humans + agents when debugging that tool |
| **Product repo** | Product law (`AGENTS.md`) | Agents working inside that repo |
| **Skills** | Reusable procedures | Shared by Codex, Claude, Grok, Gemini, and Cursor |

**Canonical edit path for machine law:** `law/AGENTS.md`  
After edits, run `install.sh`. Use `install.sh --check` to audit the current installation without changing files.

Do not fork machine law into runtime homes or chat memory. Edit the pack.

## Tool load graph (after install)

```
law/AGENTS.md + law/workspace.private.md
    └── generated → law/.AGENTS.assembled.md
        ├── copy → ~/.codex/AGENTS.md    (Codex global)
        ├── copy → ~/.grok/AGENTS.md     (Grok global)
        ├── include ← ~/.claude/CLAUDE.md (Claude global, thin)
        └── include ← ~/.gemini/GEMINI.md (Gemini global, thin)

skills/shared/
    └── symlink → ~/.agents/skills
    └── symlink → ~/.claude/skills
    └── symlink → ~/.cursor/skills
    └── Grok and Gemini discover the open-agent skills path

status.sh
    └── symlink → ~/.local/bin/agent-status

policy/command-guard.sh
    ├── symlink → ~/.codex/hooks/guard.sh
    ├── symlink → ~/.claude/hooks/guard.sh
    ├── symlink → ~/.grok/hooks/guard.sh
    ├── symlink → ~/.cursor/hooks/guard.sh
    └── symlink → ~/.gemini/hooks/guard.sh

runtimes/gemini/policy.toml
    └── symlink → ~/.gemini/policies/dotfiles-agent-pack.toml

runtimes/codex/hooks.json
    └── symlink → ~/.codex/hooks.json

runtimes/grok/hooks/command-guard.json
    └── symlink → ~/.grok/hooks/command-guard.json

runtimes/cursor/hooks.json
    └── symlink → ~/.cursor/hooks.json

workspace/*.AGENTS.md
    └── copy → ~/code/{personal,work}/AGENTS.md
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
| `workspace/*.AGENTS.md` templates | machine-specific product map in `law/workspace.private.md` |
| `op-keys.zsh` loader only | `~/.config/zsh/op-keys.local.zsh` |
| `.gitconfig` without identity | `~/.config/git/local.gitconfig` |
| skills, runtimes, install, bootstrap | generated `law/.AGENTS.assembled.md` |
| `private-state.sh` schema and restore logic | encrypted 1Password Secure Note payload and untracked item reference |

## Safety model

- Default install refuses unmanaged files and symlinks instead of hiding or replacing them.
- `--replace` is explicit, creates no backup, and never removes directories.
- `--check` and `--dry-run` do not modify installed state.
- High autonomy baseline: Codex `approval_policy = "never"` + `sandbox_mode = "danger-full-access"`; Claude `bypassPermissions`; Grok `yolo = true` + `permission_mode = "always-approve"`; Gemini user policy allows tools outside read-only plan mode.
- Shared command guard is linked into Codex, Claude, Grok, Gemini, and Cursor hook locations. Hard stops stay armed while prompts stay off.
- Shared skills live under `skills/shared/` and install to `~/.agents/skills`, `~/.claude/skills`, and `~/.cursor/skills` (Grok and Gemini discover the open-agent path).
- Claude local settings stay private with mode `0600`. Managed autonomy keys in Codex/Claude/Grok configs are rewritten by install; unrelated keys are preserved.
- Hooks hard-stop only destructive/irreversible actions (force-push, direct or implicit push to main, bare push, destructive Git cleanup, recursive force-delete, force-kill, disk/system mutation, `curl|sh`, infra destroy, protected path writes). Scoped package commands and normal deploys are allowed under yolo.
- `~/dotfiles/check.sh` is the final source and live-machine verification entrypoint.
- Interactive shells run a fast read-only invariant check and stay silent unless installed agent policy has drifted.

## Empirical status

Run this from any directory:

```bash
agent-status
```

It reports:

- the dotfiles commit and whether the portable source has local changes;
- a public pack fingerprint and a shared-skills fingerprint that can be compared across machines;
- the shared skill names;
- the active Git project, its `AGENTS.md`, and whether `CLAUDE.md` imports `@AGENTS.md`;
- whether the installed runtime files and links match the source;
- whether Grok actually discovers the shared skills.

`agent-status --verbose` includes the complete installed contract matrix. A healthy machine ends with `COPACETIC`. Private machine maps are intentionally excluded from fingerprints, so two machines can have different local product inventories while sharing the exact same portable core. Cursor shares the portable skills and command guard and reads product-root `AGENTS.md`; Cursor user rules remain vendor-managed rather than being copied into a second global law file.

## Complete machine bootstrap

The agent installer wires policy only. The root `~/dotfiles/bootstrap.sh` is the
reproducible post-Homebrew entrypoint for packages, mise runtimes, agent CLIs,
private-state restore, optional product cloning, installation, and checks. See
`BOOTSTRAP.md` for the exact new-Mac sequence.
