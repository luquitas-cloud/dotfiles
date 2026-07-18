#!/bin/bash
# Compatibility wrapper. The canonical guard lives under agents/policy.

set -euo pipefail
SCRIPT_DIR=$(cd "$(dirname "$0")" && pwd)
exec "$SCRIPT_DIR/../../../policy/command-guard.sh"
