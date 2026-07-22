#!/usr/bin/env bash
# Verify collision-safe 1Password private-state restore without contacting 1Password.
set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd)
TEST_ROOT=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-private-state.XXXXXX")
TEST_HOME="$TEST_ROOT/home"
TEST_PACK="$TEST_ROOT/pack"
TEST_BIN="$TEST_ROOT/bin"
FIXTURE="$TEST_ROOT/item.json"

cleanup() {
  find "$TEST_ROOT" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

fail() {
  printf '  FAIL  %s\n' "$1" >&2
  exit 1
}

pass() {
  printf '  pass  %s\n' "$1"
}

mkdir -p "$TEST_HOME" "$TEST_PACK/law" "$TEST_BIN"

# shellcheck disable=SC2016 # intentional literal expansion in generated op stub
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  '[ "${1:-} ${2:-}" = "item get" ] || exit 2' \
  'cat "$OP_FIXTURE"' > "$TEST_BIN/op"
chmod 700 "$TEST_BIN/op"
export PATH="$TEST_BIN:$PATH"
export OP_FIXTURE="$FIXTURE"
export DOTFILES_PRIVATE_PACK="$TEST_PACK"

make_fixture() {
  local workspace=$1 identity=$2 keys=$3 products=$4
  jq -n \
    --arg workspace "$workspace" \
    --arg identity "$identity" \
    --arg keys "$keys" \
    --argjson products "$products" \
    '{
      version: 1,
      files: {
        workspace_private_md: $workspace,
        git_local_gitconfig: $identity,
        op_keys_local_zsh: $keys
      },
      products: $products
    }' | jq -Rs '{fields: [{id: "notesPlain", value: .}]}' > "$FIXTURE"
}

printf '%s\n' "Private-state tests"
make_fixture $'private workspace\n' $'[user]\nname = Test\n' $'# references only\n' '[]'

HOME="$TEST_HOME" bash "$DOTFILES/agents/private-state.sh" pull --item test --dry-run >/dev/null
[ ! -e "$TEST_PACK/law/workspace.private.md" ] || fail "dry run wrote the private workspace map"
[ ! -e "$TEST_HOME/.config/git/local.gitconfig" ] || fail "dry run wrote the Git identity"
pass "pull dry run is read-only"

HOME="$TEST_HOME" bash "$DOTFILES/agents/private-state.sh" pull --item test >/dev/null
[ "$(cat "$TEST_PACK/law/workspace.private.md")" = "private workspace" ] || fail "workspace map content mismatch"
[ "$(cat "$TEST_HOME/.config/git/local.gitconfig")" = $'[user]\nname = Test' ] || fail "Git identity content mismatch"
[ "$(stat -f '%Lp' "$TEST_HOME/.config/git/local.gitconfig")" = 600 ] || fail "Git identity mode mismatch"
[ "$(stat -f '%Lp' "$TEST_HOME/.config/zsh/op-keys.local.zsh")" = 600 ] || fail "key loader mode mismatch"
pass "pull restores only the allowlisted private files with private modes"

printf '%s\n' "local collision" > "$TEST_HOME/.config/git/local.gitconfig"
set +e
HOME="$TEST_HOME" bash "$DOTFILES/agents/private-state.sh" pull --item test > "$TEST_ROOT/collision.log" 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "differing private collision was accepted"
grep -Fq "private file collision" "$TEST_ROOT/collision.log" || fail "collision failure was not explained"
[ "$(cat "$TEST_HOME/.config/git/local.gitconfig")" = "local collision" ] || fail "collision changed the existing file"
pass "pull refuses differing private files without replacement"

HOME="$TEST_HOME" bash "$DOTFILES/agents/private-state.sh" pull --item test --replace >/dev/null
[ "$(cat "$TEST_HOME/.config/git/local.gitconfig")" = $'[user]\nname = Test' ] || fail "explicit replacement did not install the manifest value"
pass "explicit replacement is deterministic and creates no backup"

HOME="$TEST_HOME" bash "$DOTFILES/agents/private-state.sh" push --item test --dry-run >/dev/null
pass "push dry run validates current private state without contacting 1Password"

make_fixture $'private workspace\n' $'[user]\nname = Test\n' "" '[{"path":"Documents/unsafe","repository":"git@github.com:owner/repo.git"}]'
set +e
HOME="$TEST_HOME" bash "$DOTFILES/agents/private-state.sh" pull --item test --clone-products --dry-run --replace > "$TEST_ROOT/path.log" 2>&1
rc=$?
set -e
[ "$rc" -ne 0 ] || fail "unsafe product path was accepted"
grep -Fq "must stay under code/personal or code/work" "$TEST_ROOT/path.log" || fail "unsafe product path failure was not explained"
pass "product cloning is constrained to declared code containers"

if find "$TEST_ROOT" -name '.backup-*' -print -quit | grep -q .; then
  fail "private-state workflow created a backup directory"
fi
pass "no backup directory was created"

printf '%s\n' "Private-state tests passed."
