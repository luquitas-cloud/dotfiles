#!/usr/bin/env bash
# Stream private machine metadata between local files and one 1Password Secure Note.
set -euo pipefail
umask 077

PACK=${DOTFILES_PRIVATE_PACK:-$(cd "$(dirname "$0")" && pwd)}
HOME_DIR=${HOME:?HOME must be set}
MODE=pull
ITEM=${DOTFILES_PRIVATE_ITEM:-}
VAULT=${DOTFILES_PRIVATE_VAULT:-}
DRY_RUN=0
REPLACE=0
CLONE_PRODUCTS=0
STAGED_PRIVATE=""

cleanup_staged_private() {
  [ -z "$STAGED_PRIVATE" ] || [ ! -e "$STAGED_PRIVATE" ] || unlink "$STAGED_PRIVATE"
}
trap cleanup_staged_private EXIT

usage() {
  cat <<'EOF'
Usage: private-state.sh pull|push --item ITEM [options]

  pull                 Restore private files from a 1Password Secure Note.
  push                 Capture current private files and direct product repos.
  --item ITEM          1Password item name, ID, or sharing link. Required.
  --vault VAULT        Optional 1Password vault name or ID.
  --clone-products     With pull, clone products from the private manifest.
  --dry-run            Validate and report without changing files or 1Password.
  --replace            Replace differing private files without backups.

Environment alternatives: DOTFILES_PRIVATE_ITEM and DOTFILES_PRIVATE_VAULT.
The item reference is intentionally never stored in public Git.
EOF
}

case "${1:-}" in
  pull|push) MODE=$1; shift ;;
  -h|--help) usage; exit 0 ;;
  *) usage >&2; exit 2 ;;
esac

while [ "$#" -gt 0 ]; do
  case "$1" in
    --item) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; ITEM=$2; shift 2 ;;
    --vault) [ "$#" -ge 2 ] || { usage >&2; exit 2; }; VAULT=$2; shift 2 ;;
    --clone-products) CLONE_PRODUCTS=1; shift ;;
    --dry-run) DRY_RUN=1; shift ;;
    --replace) REPLACE=1; shift ;;
    -h|--help) usage; exit 0 ;;
    *) usage >&2; exit 2 ;;
  esac
done

[ -n "$ITEM" ] || { printf '%s\n' "FAIL      --item or DOTFILES_PRIVATE_ITEM is required" >&2; exit 2; }
[ "$MODE" = pull ] || [ "$CLONE_PRODUCTS" -eq 0 ] || { printf '%s\n' "FAIL      --clone-products is only valid with pull" >&2; exit 2; }

log() { printf '%s\n' "$*"; }
fail() { printf 'FAIL      %s\n' "$1" >&2; exit 1; }

for command_name in jq op; do
  command -v "$command_name" >/dev/null 2>&1 || fail "$command_name is required"
done

op_get() {
  if [ -n "$VAULT" ]; then
    op item get "$ITEM" --vault "$VAULT" --format json
  else
    op item get "$ITEM" --format json
  fi
}

op_create() {
  if [ -n "$VAULT" ]; then
    op item create --vault "$VAULT" -
  else
    op item create -
  fi
}

op_edit() {
  if [ -n "$VAULT" ]; then
    op item edit "$ITEM" --vault "$VAULT"
  else
    op item edit "$ITEM"
  fi
}

validate_payload() {
  jq -e '
    .version == 1 and
    (.files.workspace_private_md | type == "string") and
    (.files.git_local_gitconfig | type == "string") and
    ((.files.op_keys_local_zsh // "") | type == "string") and
    (.products | type == "array") and
    all(.products[]; (.path | type == "string") and (.repository | type == "string"))
  ' >/dev/null || fail "1Password payload does not match private-state version 1"
}

install_private_file() {
  local payload="$1" filter="$2" destination="$3" required="$4" staged
  staged=$(mktemp "${TMPDIR:-/tmp}/dotfiles-private.XXXXXX")
  STAGED_PRIVATE=$staged
  if ! printf '%s' "$payload" | jq -erj "$filter" > "$staged" 2>/dev/null; then
    unlink "$staged"
    [ "$required" -eq 0 ] && return 0
    fail "private payload is missing $filter"
  fi
  chmod 600 "$staged"

  if [ ! -s "$staged" ] && [ "$required" -eq 0 ]; then
    unlink "$staged"
    log "skip      $destination (empty optional value)"
    return 0
  fi
  if [ -d "$destination" ] && [ ! -L "$destination" ]; then
    unlink "$staged"
    fail "refusing to replace directory: $destination"
  fi
  if [ -f "$destination" ] && [ ! -L "$destination" ] && cmp -s "$staged" "$destination"; then
    unlink "$staged"
    [ "$DRY_RUN" -eq 1 ] || chmod 600 "$destination"
    log "ok        $destination"
    return 0
  fi
  if { [ -e "$destination" ] || [ -L "$destination" ]; } && [ "$REPLACE" -ne 1 ]; then
    unlink "$staged"
    fail "private file collision at $destination; inspect it before using --replace"
  fi
  if [ "$DRY_RUN" -eq 1 ]; then
    unlink "$staged"
    log "plan      $destination"
    return 0
  fi

  mkdir -p "$(dirname "$destination")"
  if ! mv -f "$staged" "$destination"; then
    [ ! -e "$staged" ] || unlink "$staged"
    fail "unable to install $destination"
  fi
  chmod 600 "$destination"
  log "installed $destination"
}

clone_products() {
  local payload="$1" product rel repository destination current
  while IFS= read -r product; do
    rel=$(printf '%s' "$product" | jq -er '.path')
    repository=$(printf '%s' "$product" | jq -er '.repository')
    case "$rel" in
      code/personal/*|code/work/*) ;;
      *) fail "product path must stay under code/personal or code/work: $rel" ;;
    esac
    printf '%s\n' "$rel" | grep -Eq '^code/(personal|work)/[^/[:cntrl:]]+(/[^/[:cntrl:]]+)*$' || \
      fail "product path contains unsupported characters: $rel"
    case "/$rel/" in
      */../*|*/./*) fail "product path contains an unsafe component: $rel" ;;
    esac
    printf '%s\n' "$repository" | grep -Eq '^(git@github\.com:|https://github\.com/)[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+(\.git)?$' || \
      fail "unsupported product repository URL: $repository"

    destination="$HOME_DIR/$rel"
    if [ -d "$destination/.git" ]; then
      current=$(git -C "$destination" remote get-url origin 2>/dev/null || true)
      [ "$current" = "$repository" ] || fail "$destination has a different origin: $current"
      log "ok        $destination"
    elif [ -e "$destination" ] || [ -L "$destination" ]; then
      fail "product destination already exists and is not the expected Git repo: $destination"
    elif [ "$DRY_RUN" -eq 1 ]; then
      log "plan      git clone $repository -> $destination"
    else
      mkdir -p "$(dirname "$destination")"
      git clone -- "$repository" "$destination"
      log "installed $destination"
    fi
  done < <(printf '%s' "$payload" | jq -c '.products[]')
}

capture_products() {
  local scope repo_dir repository rel
  for scope in personal work; do
    for repo_dir in "$HOME_DIR/code/$scope"/*; do
      [ -d "$repo_dir/.git" ] || continue
      repository=$(git -C "$repo_dir" remote get-url origin 2>/dev/null || true)
      [ -n "$repository" ] || continue
      rel=${repo_dir#"$HOME_DIR/"}
      jq -n --arg path "$rel" --arg repository "$repository" '{path: $path, repository: $repository}'
    done
  done
}

capture_payload() {
  local workspace="$PACK/law/workspace.private.md"
  local git_local="$HOME_DIR/.config/git/local.gitconfig"
  local op_keys="$HOME_DIR/.config/zsh/op-keys.local.zsh"

  [ -f "$workspace" ] && [ ! -L "$workspace" ] || fail "missing private workspace map: $workspace"
  [ -f "$git_local" ] && [ ! -L "$git_local" ] || fail "missing private Git identity: $git_local"
  [ -f "$op_keys" ] && [ ! -L "$op_keys" ] || op_keys=/dev/null

  capture_products | jq -s \
    --rawfile workspace_private_md "$workspace" \
    --rawfile git_local_gitconfig "$git_local" \
    --rawfile op_keys_local_zsh "$op_keys" \
    '{
      version: 1,
      files: {
        workspace_private_md: $workspace_private_md,
        git_local_gitconfig: $git_local_gitconfig,
        op_keys_local_zsh: $op_keys_local_zsh
      },
      products: .
    }'
}

if [ "$MODE" = pull ]; then
  payload=$(op_get | jq -er '.fields[] | select(.id == "notesPlain") | .value') || fail "unable to read Secure Note payload from 1Password"
  printf '%s' "$payload" | validate_payload
  install_private_file "$payload" '.files.workspace_private_md' "$PACK/law/workspace.private.md" 1
  install_private_file "$payload" '.files.git_local_gitconfig' "$HOME_DIR/.config/git/local.gitconfig" 1
  install_private_file "$payload" '.files.op_keys_local_zsh // ""' "$HOME_DIR/.config/zsh/op-keys.local.zsh" 0
  [ "$CLONE_PRODUCTS" -eq 0 ] || clone_products "$payload"
  log "Private state pull complete."
  exit 0
fi

payload=$(capture_payload)
printf '%s' "$payload" | validate_payload
if [ "$DRY_RUN" -eq 1 ]; then
  log "plan      update 1Password item with private files and product manifest"
  log "Private state push dry run complete."
  exit 0
fi

if op_get >/dev/null 2>&1; then
  op_get | jq -e 'any(.fields[]; .id == "notesPlain")' >/dev/null || \
    fail "existing 1Password item is not a Secure Note with notesPlain"
  printf '%s' "$payload" | jq -Rs --slurpfile item <(op_get) '
    . as $payload
    | $item[0]
    | (.fields[] | select(.id == "notesPlain").value) = $payload
  ' | op_edit >/dev/null
  log "updated   1Password private-state item"
else
  printf '%s' "$payload" | jq -Rs --arg title "$ITEM" --slurpfile item <(op item template get "Secure Note") '
    . as $payload
    | $item[0]
    | .title = $title
    | (.fields[] | select(.id == "notesPlain").value) = $payload
  ' | op_create >/dev/null
  log "created   1Password private-state item"
fi
log "Private state push complete."
