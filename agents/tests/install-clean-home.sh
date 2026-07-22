#!/usr/bin/env bash
# Prove that a clean HOME can be installed, checked, and reinstalled idempotently.
set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd)
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-clean-home.XXXXXX")
TEST_BIN="$TEST_HOME/bin"
cleanup() {
  find "$TEST_HOME" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

mkdir -p "$TEST_BIN"
# shellcheck disable=SC2016 # intentional literal variable expansion in generated stub
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  '[ "${1:-}" = "--strict-config" ] && [ "${2:-}" = "--version" ] || exit 2' \
  '[ -n "${CODEX_HOME:-}" ] && [ -s "$CODEX_HOME/config.toml" ] || exit 1' \
  'printf "%s\\n" "codex-test-stub"' > "$TEST_BIN/codex"
chmod 700 "$TEST_BIN/codex"
# shellcheck disable=SC2016 # intentional literal HOME expansion in generated stub
printf '%s\n' \
  '#!/usr/bin/env bash' \
  'set -euo pipefail' \
  'case "$*" in' \
  '  *"inspect --json"*) printf "{\"skills\":[{\"name\":\"machine-bootstrap\",\"source\":{\"path\":\"%s/.agents/skills/machine-bootstrap/SKILL.md\"}}]}\\n" "$HOME" ;;' \
  '  *) exit 2 ;;' \
  'esac' > "$TEST_BIN/grok"
chmod 700 "$TEST_BIN/grok"
PATH="$TEST_BIN:$PATH"
export PATH

printf 'Clean-home install: %s\n' "$TEST_HOME"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --check
HOME="$TEST_HOME" bash "$DOTFILES/agents/login-check.sh"
HOME="$TEST_HOME" "$TEST_HOME/.local/bin/agent-status" >/dev/null
HOME="$TEST_HOME" bash "$DOTFILES/install.sh"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --check
HOME="$TEST_HOME" bash "$DOTFILES/agents/login-check.sh"
printf '%s\n' "Clean-home install test passed."
