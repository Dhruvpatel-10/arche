#!/usr/bin/env bash
# tests/run.sh — arche test runner
# Usage: bash tests/run.sh [lint|stow|integration|all]
#   lint        — syntax, quality, secrets (no root, CI-safe)
#   stow        — dry-run conflicts + structure (no root)
#   integration — verify installed state (needs live system)
#   all         — run everything

set -euo pipefail

ARCHE="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
TEST_DIR="$ARCHE/tests"

# Load helpers and test modules
source "$TEST_DIR/helpers.sh"
source "$TEST_DIR/test_lint.sh"
source "$TEST_DIR/test_stow.sh"
source "$TEST_DIR/test_integration.sh"

# Dispatch
mode="${1:-lint}"

case "$mode" in
    lint)        test_lint ;;
    stow)        test_stow ;;
    integration) test_integration ;;
    all)
        test_lint
        test_stow
        test_integration
        ;;
    *)
        echo "Usage: $0 [lint|stow|integration|all]"
        exit 1
        ;;
esac

summary
