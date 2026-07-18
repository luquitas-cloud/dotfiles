# Runtime: Codex (ChatGPT / Codex CLI)

## Homes

| Path | Role |
|------|------|
| `~/.codex/` | Tool home (config, sessions, plugins, skills) |
| `~/.codex/AGENTS.md` | Global rules - **symlink** to pack `law/AGENTS.md` |
| `~/.codex/skills/` | Codex skills (not shared format with Grok) |
| `~/dotfiles/agents/runtimes/codex/` | Portable notes for this runtime |

## Guardrails

Machine law still applies. Codex may also use `developer_instructions` and `approval_policy` inside `~/.codex/config.toml` - those are **local runtime policy**, not a second product law file.

Prefer:

- Trust **product roots** under `~/code/...` and `~/dotfiles`, not random Documents session folders.
- Avoid treating `$HOME` as a product workspace even if currently trusted for meta sessions.
- Never put secrets in config or AGENTS.

## Skills

Codex skills stay under `~/.codex/skills/` (and plugins). They are not automatically the same as Grok/Claude `SKILL.md` packs. Port procedures by hand if needed, or document in product repos.

## Clarifications

- Strong for planning loops and ChatGPT-integrated work.
- High autonomy configs are intentional on Lucas's machines - still ask before irreversible or security-sensitive actions (machine law).
