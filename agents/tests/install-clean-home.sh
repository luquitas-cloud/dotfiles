#!/usr/bin/env bash
# Prove that a clean HOME can be installed, checked, and reinstalled idempotently.
set -euo pipefail

DOTFILES=$(cd "$(dirname "$0")/../.." && pwd)
TEST_HOME=$(mktemp -d "${TMPDIR:-/tmp}/dotfiles-clean-home.XXXXXX")
cleanup() {
  find "$TEST_HOME" -depth -delete 2>/dev/null || true
}
trap cleanup EXIT

printf 'Clean-home install: %s\n' "$TEST_HOME"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --check
HOME="$TEST_HOME" bash "$DOTFILES/agents/login-check.sh"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh"
HOME="$TEST_HOME" bash "$DOTFILES/install.sh" --check
HOME="$TEST_HOME" bash "$DOTFILES/agents/login-check.sh"
printf '%s\n' "Clean-home install test passed."
