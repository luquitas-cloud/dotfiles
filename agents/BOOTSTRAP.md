# Bootstrap: new machine

**Audience:** Lucas or any coding agent on a fresh Mac.

**Goal:** Wire Grok, Codex, and Claude to the portable pack so machine law, runtimes, and shared skills load correctly.

## Preconditions

1. `git` available.
2. This pack exists at `~/dotfiles/agents` (full `dotfiles` clone preferred).
3. Optional but recommended: shell already installed via `~/dotfiles/install.sh`.

If `~/dotfiles` is missing:

```bash
git clone <your-dotfiles-remote> ~/dotfiles
```

## Private overlays (required for a useful personal map)

These are **not** in public git. Create them before or after first install:

```bash
# Product inventory (merged into machine law at install)
cp ~/dotfiles/agents/law/workspace.private.example.md \
   ~/dotfiles/agents/law/workspace.private.md
# edit workspace.private.md with your real paths

# Git identity
mkdir -p ~/.config/git
cp ~/dotfiles/agents/config/git.local.example ~/.config/git/local.gitconfig
# edit name/email

# Optional API key loads from 1Password
# create ~/.config/zsh/op-keys.local.zsh with _op_load lines only
```

Never put vault item paths, emails, client names, or private product lists into tracked files.

## Agent procedure (do this in order)

1. **Read** `~/dotfiles/agents/README.md` and `~/dotfiles/agents/law/AGENTS.md`.
2. Ensure private overlays exist (above) if this is the operator's personal machine.
3. **Run** (do not invent paths):

   ```bash
   bash ~/dotfiles/agents/install.sh
   ```

4. **Verify** install output shows `ok` / `linked` / `copied` for:
   - `~/.codex/AGENTS.md`
   - `~/.grok/AGENTS.md`
   - `~/.claude/CLAUDE.md`
   - `~/.claude/hooks/guard.sh`
   - `~/.claude/skills`
   - `~/code/AGENTS.md` (and personal/work containers)
5. **Confirm law content** is non-empty:

   ```bash
   wc -l ~/.codex/AGENTS.md ~/.grok/AGENTS.md ~/.claude/CLAUDE.md
   head -5 ~/.codex/AGENTS.md
   ```

6. **Install agent CLIs/apps** if missing (Grok, Codex, Claude Code). Then re-run `install.sh`.
7. **Secrets:** 1Password CLI + `op-keys.local.zsh` only. Never copy secrets into the pack.
8. **Products:** clone product repos under `~/code/personal/` and `~/code/work/`. Each product keeps its own `AGENTS.md`.
9. **Codex trust (optional):** trust product roots under `$HOME/code/...`, not random Documents folders.
10. **Report:** what was linked, what tools are missing, any path that failed.

## Human one-liner

```bash
~/dotfiles/install.sh && ~/dotfiles/agents/install.sh
```

## Do not

- Create parallel machine law files that fork `law/AGENTS.md`.
- Put recovery keys, API tokens, emails, client names, or private product inventories into **tracked** pack files.
- Commit `workspace.private.md`, `op-keys.local.zsh`, or `local.gitconfig`.
- Treat `~/Documents/Codex/*` session folders as product roots.

## After bootstrap

Work from product repos. Machine meta from `~` is fine. Edit global rules only under `~/dotfiles/agents/`.
