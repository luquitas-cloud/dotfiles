# Runtime: Grok

## Homes

| Path | Role |
|------|------|
| `~/.grok/` | Tool home (sessions, config, bundled skills) |
| `~/.grok/AGENTS.md` | Global rules - **symlink** to pack `law/AGENTS.md` |
| `~/.grok/skills/` | User skills installed by Grok / you |
| `~/.grok/bundled/skills/` | Vendor bundled skills |
| `~/dotfiles/agents/runtimes/grok/` | Portable notes for this runtime |
| `~/dotfiles/agents/skills/shared/` | Shared skills (added to Grok skills paths on install) |

## Expected config (`~/.grok/config.toml`)

Prefer:

- `permission_mode = "ask"` (or stricter) for day-to-day safety
- `yolo = false`

Install may append:

```toml
[skills]
paths = ["$HOME/dotfiles/agents/skills/shared"]
```

## Clarifications

- Default terminal agent for multi-file and machine meta work.
- When started from `~`, still obey machine law and `cd` into product roots before product edits.
- Do not rewrite `~/.grok/AGENTS.md` as a real file - keep the symlink (re-run pack `install.sh` if an updater breaks it).
