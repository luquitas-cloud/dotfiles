---
name: machine-bootstrap
description: Provision or repair the portable developer Mac and agent pack (Grok, Codex, Claude, Gemini, Cursor, global law, shared skills, command policy, and container AGENTS). Use when setting up a new machine, fixing a broken agent install, or when the operator asks to bootstrap agents, install the agent pack, or rewire global rules.
---

# Machine bootstrap

## Source of truth

Portable pack: `~/dotfiles/agents/`

Read first:

1. `~/dotfiles/agents/README.md`
2. `~/dotfiles/agents/BOOTSTRAP.md`
3. `~/dotfiles/agents/law/AGENTS.md`

## Do

1. Confirm Homebrew was installed through the one manual official checkpoint.
2. Dry-run, provision, and verify the complete machine:

```bash
bash ~/dotfiles/bootstrap.sh --dry-run
bash ~/dotfiles/bootstrap.sh
bash ~/dotfiles/bootstrap.sh --check
```

3. After manual 1Password and GitHub sign-in, restore private metadata and
   optionally clone products with `bootstrap.sh --private-item ... --clone-products`.
   The private item reference must remain untracked.

Scoped dependency commands such as `brew install`, `brew bundle`, `npm ci`, and `npx` are allowed when needed. Keep `HOMEBREW_BUNDLE_NO_UPGRADE=1` for bootstrap provisioning so existing packages are not upgraded unexpectedly.

If `~/dotfiles` is missing, clone the public canonical repository documented in
the root README. Do not invent a partial law file inside one runtime home.

## Verify

- `~/.codex/AGENTS.md` and `~/.grok/AGENTS.md` are non-empty assembled law files
- If `workspace.private.md` exists, installed law includes the private inventory section
- `~/.claude/CLAUDE.md` includes machine law via `@../.codex/AGENTS.md`
- `~/.gemini/GEMINI.md` includes machine law via `@../.codex/AGENTS.md`
- `~/.claude/hooks/guard.sh`, `~/.codex/hooks/guard.sh`, `~/.grok/hooks/guard.sh`, `~/.gemini/hooks/guard.sh`, and `~/.cursor/hooks/guard.sh` are linked
- `~/.codex/hooks.json`, `~/.grok/hooks/command-guard.json`, and `~/.cursor/hooks.json` are linked
- High autonomy baseline is installed (Codex never/danger-full-access, Claude bypassPermissions, Grok yolo + always-approve, Gemini allow policy outside plan mode)
- `~/.agents/skills` and `~/.claude/skills` point to the same shared source
- Gemini discovers the same skill through `~/.agents/skills` without a duplicate `~/.gemini/skills` link
- `~/code/AGENTS.md` (and personal/work containers) exist

## Never

- Fork machine law into chat or a second conflicting AGENTS file
- Commit secrets, emails, client names, or private product lists into tracked pack files
- Treat Documents Codex session folders as product roots
