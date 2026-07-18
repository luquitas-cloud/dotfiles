<!-- managed-by: dotfiles-agent-pack -->
# Machine Law (global)

Portable source: `~/dotfiles/agents/law/AGENTS.md`  
Installed load targets: `~/.codex/AGENTS.md`, `~/.grok/AGENTS.md`  
Claude enters via `~/.claude/CLAUDE.md` (thin wrapper).

This file is **machine-wide only** and is safe to publish. Product architecture lives in each repo's `AGENTS.md`. Optional private map: `workspace.private.md` (gitignored; merged at install).

## Machine Contract

The portable pack has four separate data classes:

| Class | Source | Portability rule |
|------|--------|------------------|
| Public machine configuration | `~/dotfiles` | Tracked and reproducible |
| Private machine metadata | `agents/**/*.private.md` | Restored separately, never committed |
| Secrets and credentials | 1Password, local key loaders, runtime auth stores | Re-authenticate or restore through the secret manager |
| Generated state | Sessions, caches, logs, indexes, memories | Runtime-owned and not treated as configuration |

All supported agents receive the same machine law and shared portable skills. Runtime adapters may differ because Codex, Claude, and Grok use different configuration formats, but they must enforce the same safety outcomes.

`~/dotfiles/install.sh` is the only supported machine installer. It must be idempotent, must refuse unmanaged collisions by default, must not create backups, and must provide read-only `--check` and `--dry-run` modes.

## Writing Style

Use the normal ASCII hyphen (`-`) instead of em dashes or en dashes in user-facing copy, documentation, comments, and agent-authored prose.

## Workspace Map (public skeleton)

| Path | Role |
|------|------|
| `~/code/personal/` | Personal products and experiments (container) |
| `~/code/work/` | Work products (container) |
| `~/dotfiles` | Shell, git, terminal, toolchain, agent pack |
| `~/dotfiles/agents` | Portable agent pack (law, runtimes, skills, bootstrap) |
| `~/Documents/` | Human documents - not a product root for coding |
| `~/` | Machine / multi-project meta only - not a product root |

Concrete product paths (private names, client work, sensitive apps) belong in **`law/workspace.private.md`** on each machine. Copy from `workspace.private.example.md`. Never commit the private file.

Product law lives in each **repo** `AGENTS.md`. This file is machine-wide only.

## Launch Rules

Starting an agent from `~` is normal (chat, planning, machine meta).

Before **editing a product**:

1. Identify the target repo (public map + private map if present).
2. `cd` into that git root (or work only under that path).
3. Read that repo's `AGENTS.md` first - do not invent architecture.

Home is not a product root. Repo `AGENTS.md` is product law.

## Instruction Hierarchy

Platform, runtime, organization, and system policies always remain above user-controlled files. Within the user-controlled instruction layer:

1. Direct user instructions for the current task  
2. Repo-root `AGENTS.md` (and deeper scoped `AGENTS.md`)  
3. Repo docs linked from that `AGENTS.md`  
4. This machine law file (plus installed private map section)  
5. Runtime wrappers (`CLAUDE.md`, Cursor rules, runtime README notes) - thin only; must not fork product law  

Durable knowledge belongs in git-tracked public files under `~/dotfiles/agents` or a product repo - not chat-only memory. Private machine facts stay in gitignored private overlays.

## Agents On This Machine

Primary agents share policy and portable skills but keep separate runtime state and session stores:

| Agent | Runtime home | Pack space | Role |
|-------|--------------|------------|------|
| **Grok** | `~/.grok/` | `dotfiles/agents/runtimes/grok/` | Default terminal coding; multi-file; machine tasks |
| **Codex** (ChatGPT) | `~/.codex/` | `dotfiles/agents/runtimes/codex/` | Planning + agent loops in ChatGPT / Codex CLI |
| **Claude** | `~/.claude/` | `dotfiles/agents/runtimes/claude/` | Doc-heavy multi-file; alternate coding agent |

Secondary: Cursor (`~/.cursor/`, pack `runtimes/cursor/`).

Each runtime has its own pack space for clarifications, guardrails, and install notes. Shared machine law stays in `law/AGENTS.md`. Product law stays in repos.

## Autonomy And Guardrails

High autonomy is the portable baseline (solo operator). Permission prompts stay off; hard stops live in shared hooks and this law.

| Runtime | High-autonomy setting | Shared hard stop |
|---------|----------------------|------------------|
| **Grok** | `[ui] yolo = true`, `permission_mode = "always-approve"` | `~/.grok/hooks/` + Claude-compat hooks |
| **Codex** | `approval_policy = "never"`, `sandbox_mode = "danger-full-access"` | `~/.codex/hooks.json` |
| **Claude** | `permissions.defaultMode = "bypassPermissions"` | `~/.claude/settings.json` PreToolUse |
| **Cursor** (secondary) | vendor UI settings | `~/.cursor/hooks.json` |

Shared command guard source: `~/dotfiles/agents/policy/command-guard.sh` (linked into every runtime hooks dir). Shared skills source: `~/dotfiles/agents/skills/shared/` (linked to `~/.agents/skills` and `~/.claude/skills`; Grok discovers the open-agent path).

Still obey as behavioral law (even when auto-approved):

- Prefer the least destructive option that satisfies the request.
- Protected: `~/.ssh`, agent homes (`~/.codex`, `~/.grok`, `~/.claude`), `~/.config`, LaunchAgents, disks, `/etc`, routing, firewall.
- No backup/quarantine copies unless the user asks.
- Simulate first for destructive or broad changes and verify health afterward.
- Scoped package and workflow commands such as `brew install`, `brew bundle`, `npm ci`, and `npx` are allowed under yolo; still avoid surprise broad upgrades of the machine without a clear need.
- Resolve exact targets before destructive commands. Never use broad home-directory or workspace-root deletion.
- The shared guard hard-stops only destructive/irreversible actions (force-push, direct or implicit push to main, bare push, `reset --hard`, `clean -f`, `branch -D`, `rm -rf`, force-kill, disk/system mutation, `curl|sh`, infra destroy, protected path writes). It is not a package or workflow gate.
- Hooks are defense in depth, not a substitute for judgment or this law.

## Git And Delivery

- Prefer feature branches and PRs for production-facing work.
- Never commit secrets, real `.env` values, recovery keys, or password exports.
- Do not commit directly to `main` for live public sites unless the user explicitly overrides.
- Run the repo's check/lint/test scripts before claiming done when code changed.
- For changes to this dotfiles repository, run `~/dotfiles/check.sh` before claiming done.

## Secrets

- API keys via 1Password CLI / local key loaders - never hardcode into AGENTS or public git.
- Local `.env` stays gitignored. Document variable **names** only in `.env.example` or docs.
- This public pack must not contain vault item paths, emails, client names, or private product inventories.

## Skills

| Scope | Location |
|-------|----------|
| Shared portable source (Codex + Grok + Claude) | `~/dotfiles/agents/skills/shared/` |
| Open agent user path (Codex) | `~/.agents/skills/` (wired to shared source) |
| Grok user | `~/.grok/skills/` (+ bundled under `~/.grok/bundled/`) |
| Claude user | `~/.claude/skills/` (wired to shared on install) |
| Product | repo-documented skill dirs |

Registry: `~/dotfiles/agents/skills/README.md`.

## New Machine / Portability

1. Clone this `dotfiles` repo.  
2. Copy private templates:  
   - `agents/law/workspace.private.example.md` → `workspace.private.md`  
   - `agents/config/git.local.example` → `~/.config/git/local.gitconfig`  
   - optional key loads → `~/.config/zsh/op-keys.local.zsh`  
3. Run `~/dotfiles/install.sh`.
4. Run `~/dotfiles/check.sh`.
5. Install missing agent CLIs when needed for the requested workflow, avoid surprise broad machine upgrades, then re-run the installer and checker.

Pack index: `~/dotfiles/agents/README.md`.

## How To Add A Product

1. Create repo under `~/code/personal/` or `~/code/work/`.  
2. Add root `AGENTS.md` (product law) and thin `CLAUDE.md` with `@AGENTS.md`.  
3. Add a row to **`law/workspace.private.md`** (not the public map).  
4. Re-run `agents/install.sh` so installed machine law picks up the private map.  
5. Prefer feature branches; never put secrets in git.
