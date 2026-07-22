# Runtime: Gemini CLI

## Homes

| Path | Role |
|------|------|
| `~/.gemini/` | Gemini CLI home and runtime state |
| `~/.gemini/GEMINI.md` | Thin global import of the assembled machine law |
| `~/.gemini/settings.json` | User settings merged with the shared command guard |
| `~/.gemini/policies/dotfiles-agent-pack.toml` | Portable high-autonomy policy outside plan mode |
| `~/.gemini/hooks/guard.sh` | Shared command guard linked from this pack |
| `~/.agents/skills` | Shared portable skills discovered through the open-agent path |

## Law and skills

Gemini loads `~/.gemini/GEMINI.md` globally. The wrapper imports the same assembled
machine law installed for Codex and Grok. User settings include both `AGENTS.md`
and `GEMINI.md` as context names, so product repositories continue to use their
canonical root `AGENTS.md` without needing a duplicated product-law file.

Gemini discovers the open-agent user skill path at `~/.agents/skills`. The pack
uses that one path instead of also linking `~/.gemini/skills`, which would expose
the same skill twice and produce a duplicate-skill warning.

## Autonomy and guardrails

Gemini does not support persisting YOLO as its default approval setting. The
portable user policy therefore allows tools automatically in default, auto-edit,
and YOLO modes while leaving plan mode read-only. A `BeforeTool` hook routes shell
commands through the same destructive-command guard as the other runtimes.

Runtime sessions and authentication remain vendor-owned. Run `gemini` and choose
Google sign-in on each new machine.
