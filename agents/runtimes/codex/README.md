# Runtime: Codex (ChatGPT / Codex CLI)

## Homes

| Path | Role |
|------|------|
| `~/.codex/` | Tool home (config, sessions, plugins, skills) |
| `~/.codex/AGENTS.md` | Global rules - assembled copy of public law and the private map |
| `~/.agents/skills/` | Open agent user skills, linked to the portable shared source |
| `~/.codex/hooks.json` | User-level lifecycle hook configuration linked from this pack |
| `~/.codex/hooks/guard.sh` | Portable command guard linked from this pack |
| `~/dotfiles/agents/runtimes/codex/` | Portable notes for this runtime |

## Autonomy

Installer enforces top-level high autonomy:

- `approval_policy = "never"`
- `sandbox_mode = "danger-full-access"`

Named profiles and unrelated keys are preserved. Hard stops stay in `hooks.json` → shared command guard.

Machine law still applies as behavioral guidance. Local `developer_instructions` in `config.toml` are optional runtime notes, not a second product law file.

Do not add a package-install approval gate to those local notes. Scoped `brew install`, `brew bundle`, `npm ci`, and `npx` workflows are allowed; the shared command guard owns the destructive hard stops.

Prefer:

- Trust **product roots** under `~/code/...` and `~/dotfiles`, not random Documents session folders.
- Avoid treating `$HOME` as a product workspace even if currently trusted for meta sessions.
- Never put secrets in config or AGENTS.

## Skills

Codex, Claude, and Grok all support `SKILL.md` packages. The installer links the portable shared source to Codex's documented user path at `~/.agents/skills` and Claude's user path at `~/.claude/skills`; Grok discovers the open-agent path.

After a Codex hook definition changes, review and trust it once with `/hooks`. Codex intentionally invalidates trust when the hook hash changes.

## Clarifications

- Strong for planning loops and ChatGPT-integrated work.
- High autonomy is intentional - hooks + machine law are the hard stops.
