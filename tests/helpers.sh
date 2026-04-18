#!/usr/bin/env bash
# helpers.sh — shared test utilities (counters, output, section headers)
# Sourced by run.sh — never run directly.

PASS=0
FAIL=0
SKIP=0

pass() { PASS=$((PASS + 1)); printf '\033[1;32m  ✓\033[0m %s\n' "$*"; }
fail() { FAIL=$((FAIL + 1)); printf '\033[1;31m  ✗\033[0m %s\n' "$*"; }
skip() { SKIP=$((SKIP + 1)); printf '\033[1;33m  ~\033[0m %s\n' "$*"; }

section() { printf '\n\033[1;36m── %s ──\033[0m\n' "$*"; }

summary() {
    echo ""
    section "Results"
    printf '  pass: %d  fail: %d  skip: %d\n' "$PASS" "$FAIL" "$SKIP"
    [[ $FAIL -gt 0 ]] && exit 1 || exit 0
}
