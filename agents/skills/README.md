# Skills registry

## Where skills live

| Kind | Path | Consumers |
|------|------|-----------|
| **Shared portable** | `~/dotfiles/agents/skills/shared/<name>/SKILL.md` | Grok (via config paths), Claude (`~/.claude/skills` symlink) |
| Grok user | `~/.grok/skills/` | Grok only |
| Grok bundled | `~/.grok/bundled/skills/` | Grok only (vendor) |
| Codex user | `~/.codex/skills/` | Codex only |
| Product | e.g. `<repo>/.agents/skills/` | That product's agents |

## Shared skill layout

```
skills/shared/
  my-skill/
    SKILL.md          # required: name + description + body
    scripts/          # optional
    references/       # optional
```

`SKILL.md` should start with YAML frontmatter (`name`, `description`) so Grok/Claude can auto-route.

## Rules

- Shared skills must be **safe to ship in git** (no secrets).
- Product-specific behavior belongs in the product repo, not shared.
- Codex does not auto-load this folder - document or port if Codex needs the same procedure.
- Prefer one good skill over many thin duplicates.

## Adding a shared skill

1. Create `skills/shared/<name>/SKILL.md`.
2. Commit under `dotfiles`.
3. On each machine, `agents/install.sh` already points Grok/Claude at `shared/`.
4. Open a new agent session (or `/skills`) to pick it up.
