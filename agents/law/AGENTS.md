# Machine Law (global)

Portable source: `~/dotfiles/agents/law/AGENTS.md`  
Installed load targets: `~/.codex/AGENTS.md`, `~/.grok/AGENTS.md`  
Claude enters via `~/.claude/CLAUDE.md` (thin wrapper).

This file is **machine-wide only** and is safe to publish. Product architecture lives in each repo's `AGENTS.md`. Optional private map: `workspace.private.md` (gitignored; merged at install).

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

1. Direct user instructions for the current task  
2. Repo-root `AGENTS.md` (and deeper scoped `AGENTS.md`)  
3. Repo docs linked from that `AGENTS.md`  
4. This machine law file (plus installed private map section)  
5. Runtime wrappers (`CLAUDE.md`, Cursor rules, runtime README notes) - thin only; must not fork product law  

Durable knowledge belongs in git-tracked public files under `~/dotfiles/agents` or a product repo - not chat-only memory. Private machine facts stay in gitignored private overlays.

## Agents On This Machine

Primary (interchangeable; separate session stores):

| Agent | Runtime home | Pack space | Role |
|-------|--------------|------------|------|
| **Grok** | `~/.grok/` | `dotfiles/agents/runtimes/grok/` | Default terminal coding; multi-file; machine tasks |
| **Codex** (ChatGPT) | `~/.codex/` | `dotfiles/agents/runtimes/codex/` | Planning + agent loops in ChatGPT / Codex CLI |
| **Claude** | `~/.claude/` | `dotfiles/agents/runtimes/claude/` | Doc-heavy multi-file; alternate coding agent |

Secondary: Cursor (`~/.cursor/`, pack `runtimes/cursor/`).

Each runtime has its own pack space for clarifications, guardrails, and install notes. Shared machine law stays in `law/AGENTS.md`. Product law stays in repos.

## Autonomy And Guardrails

High autonomy is intentional (solo operator). Still:

- Ask before irreversible, security-sensitive, or publicly visible actions.
- Protected: `~/.ssh`, agent homes (`~/.codex`, `~/.grok`, `~/.claude`), `~/.config`, LaunchAgents, disks, `/etc`, routing, firewall.
- Prefer the least destructive option.
- No backup/quarantine copies unless the user asks.
- Claude Bash guard: `~/.claude/hooks/guard.sh` (blocks force-push, push to main, `rm -rf`, etc.).

## Git And Delivery

- Prefer feature branches and PRs for production-facing work.
- Never commit secrets, real `.env` values, recovery keys, or password exports.
- Do not commit directly to `main` for live public sites unless the user explicitly overrides.
- Run the repo's check/lint/test scripts before claiming done when code changed.

## Secrets

- API keys via 1Password CLI / local key loaders - never hardcode into AGENTS or public git.
- Local `.env` stays gitignored. Document variable **names** only in `.env.example` or docs.
- This public pack must not contain vault item paths, emails, client names, or private product inventories.

## Skills

| Scope | Location |
|-------|----------|
| Shared (portable, Grok + Claude) | `~/dotfiles/agents/skills/shared/` |
| Grok user | `~/.grok/skills/` (+ bundled under `~/.grok/bundled/`) |
| Codex user | `~/.codex/skills/` |
| Claude user | `~/.claude/skills/` (wired to shared on install) |
| Product | repo-documented skill dirs |

Registry: `~/dotfiles/agents/skills/README.md`.

## New Machine / Portability

1. Clone this `dotfiles` repo.  
2. Copy private templates:  
   - `agents/law/workspace.private.example.md` → `workspace.private.md`  
   - `agents/config/git.local.example` → `~/.config/git/local.gitconfig`  
   - optional key loads → `~/.config/zsh/op-keys.local.zsh`  
3. Tell any agent: read `~/dotfiles/agents/BOOTSTRAP.md` and run `install.sh`.  
4. Install agent CLIs; re-run `agents/install.sh`.  

Pack index: `~/dotfiles/agents/README.md`.

## How To Add A Product

1. Create repo under `~/code/personal/` or `~/code/work/`.  
2. Add root `AGENTS.md` (product law) and thin `CLAUDE.md` with `@AGENTS.md`.  
3. Add a row to **`law/workspace.private.md`** (not the public map).  
4. Re-run `agents/install.sh` so installed machine law picks up the private map.  
5. Prefer feature branches; never put secrets in git.
