# Bootstrap: new Mac

**Audience:** The operator or any coding agent on a fresh Mac.

**Outcome:** A full developer Mac with the same public dotfiles, package manifest,
machine law, shared skills, guardrails, and empirical checks. Private metadata is
restored from 1Password. Runtime credentials and application sessions are created
through manual vendor logins.

## Data model

| Class | Portable source | Restore behavior |
|------|-----------------|------------------|
| Public machine configuration | Public `dotfiles` Git repo | Clone and install |
| Private machine metadata | One 1Password Secure Note | Pull after 1Password login |
| Secrets and credentials | 1Password and vendor auth stores | Re-authenticate manually |
| Generated state | Sessions, caches, logs, memories, indexes | Recreated by runtimes |

The public and private layers are intentionally separate. Never put product names,
email, secret references, tokens, or the 1Password item reference in tracked Git.

## One manual installation checkpoint

Install Homebrew once using the official macOS installer:

<https://docs.brew.sh/Installation>

This is the only manual package installation. The bootstrap deliberately does not
pipe remote content into a shell to install Homebrew.

## Agent procedure

1. Clone the public repository to its canonical path:

   ```bash
   git clone https://github.com/luquitas-cloud/dotfiles.git ~/dotfiles
   ```

2. Read `~/dotfiles/agents/README.md` and
   `~/dotfiles/agents/law/AGENTS.md`.

3. Preview the complete machine operation:

   ```bash
   ~/dotfiles/bootstrap.sh --dry-run
   ```

4. Provision the public machine layer:

   ```bash
   ~/dotfiles/bootstrap.sh
   ```

   This installs missing `Brewfile` entries, mise runtimes, Codex, Claude, Grok,
   Gemini, Cursor, dotfile links, global law adapters, shared skills, and hooks.
   It installs missing packages only and does not run a broad machine upgrade.

5. Complete the manual sign-ins printed by the bootstrap:

   ```text
   1Password desktop and CLI
   GitHub CLI
   Codex
   Claude
   Grok
   Gemini
   Cursor UI
   ```

6. Restore the encrypted private layer and optionally clone products:

   ```bash
   ~/dotfiles/bootstrap.sh \
     --private-item "$DOTFILES_PRIVATE_ITEM" \
     --clone-products
   ```

   The item reference is supplied interactively or through the environment and
   is never stored in the repository. Use `--private-vault` only if needed.

7. Verify the complete contract:

   ```bash
   ~/dotfiles/bootstrap.sh --check
   agent-status --verbose
   ```

   A healthy agent contract ends with `COPACETIC`. Compare the public pack and
   skills fingerprints between machines. Private maps are excluded intentionally.

## First-time 1Password seed on the source Mac

After signing in to 1Password CLI, create or refresh the encrypted payload directly
from the current private files and direct product repositories:

```bash
~/dotfiles/agents/private-state.sh push --item "$DOTFILES_PRIVATE_ITEM" --dry-run
~/dotfiles/agents/private-state.sh push --item "$DOTFILES_PRIVATE_ITEM"
```

The push streams directly to a Secure Note. It creates no plaintext archive or
backup file. The pull allowlists only these destinations:

- `~/dotfiles/agents/law/workspace.private.md`
- `~/.config/git/local.gitconfig`
- `~/.config/zsh/op-keys.local.zsh` when present in the payload
- optional Git clones under `~/code/personal/` and `~/code/work/`

Existing differing files fail closed. Inspect them before explicitly using
`--replace`. Directories are never replaced and backups are never created.

## Runtime wiring after install

| Runtime | Global law | Shared skills | Hard stop |
|---------|------------|---------------|-----------|
| Codex | `~/.codex/AGENTS.md` | `~/.agents/skills` | Codex hook |
| Claude | `~/.claude/CLAUDE.md` import | `~/.claude/skills` | Claude hook |
| Grok | `~/.grok/AGENTS.md` | open-agent skills | Grok hook |
| Gemini | `~/.gemini/GEMINI.md` import | open-agent skills | Gemini hook |
| Cursor | repo `AGENTS.md` | `~/.cursor/skills` | Cursor hook |

Every path points back to the same tracked public source. Product architecture stays
inside each product repository's `AGENTS.md`.

## Do not

- Create parallel global law files that fork `law/AGENTS.md`.
- Copy runtime auth databases or session folders between Macs.
- Create backup, quarantine, or migration archives.
- Commit `workspace.private.md`, `op-keys.local.zsh`, `local.gitconfig`, or a
  1Password item reference.
- Treat `~/Documents/` session folders as product roots.
