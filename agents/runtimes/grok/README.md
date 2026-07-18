# Runtime: Grok

## Homes

| Path | Role |
|------|------|
| `~/.grok/` | Tool home (sessions, config, bundled skills) |
| `~/.grok/AGENTS.md` | Global rules - assembled copy of public law and the private map |
| `~/.grok/hooks/guard.sh` | Shared command guard (symlink into pack) |
| `~/.grok/hooks/command-guard.json` | Native Grok PreToolUse hook definition (symlink into pack) |
| `~/.grok/skills/` | User skills installed by Grok / you |
| `~/.grok/bundled/skills/` | Vendor bundled skills |
| `~/dotfiles/agents/runtimes/grok/` | Portable notes for this runtime |
| `~/dotfiles/agents/skills/shared/` | Shared source exposed through `~/.agents/skills` |

## Expected config (`~/.grok/config.toml`)

Portable baseline (installer enforces these keys under `[ui]`):

- `yolo = true`
- `permission_mode = "always-approve"`

Hard stops stay in the shared command guard (native `~/.grok/hooks/` plus Claude-compat discovery). Unrelated config keys are preserved. Mode stays `0600`.

## Skills

Shared portable skills install to `~/.agents/skills` → `dotfiles/agents/skills/shared`. Grok discovers that open-agent path. Grok-only skills remain under `~/.grok/skills/` and bundled.

## Clarifications

- Default terminal agent for multi-file and machine meta work.
- When started from `~`, still obey machine law and `cd` into product roots before product edits.
- Do not edit `~/.grok/AGENTS.md` directly. Edit the pack law and re-run `install.sh`.
