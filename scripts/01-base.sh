#!/usr/bin/env bash
# 01-base.sh — install core system packages
source "$(dirname "$0")/lib.sh"

log_info "Installing base packages..."
install_group "$ARCHE/packages/base.sh"

# ─── shellcheck (static binary from upstream) ───
# The pacman shellcheck package pulls ~56 Haskell runtime packages for a single
# 4 MB binary. Upstream ships a precompiled static binary — prefer that.

SHELLCHECK_VERSION="v0.11.0"
SHELLCHECK_SHA256="8c3be12b05d5c177a04c29e3c78ce89ac86f1595681cab149b65b97c4e227198"
SHELLCHECK_URL="https://github.com/koalaman/shellcheck/releases/download/${SHELLCHECK_VERSION}/shellcheck-${SHELLCHECK_VERSION}.linux.x86_64.tar.xz"
SHELLCHECK_DEST="/usr/local/bin/shellcheck"

installed_version=""
if [[ -x "$SHELLCHECK_DEST" ]]; then
    installed_version="v$("$SHELLCHECK_DEST" --version | awk '/^version:/ {print $2}')"
fi

if [[ "$installed_version" == "$SHELLCHECK_VERSION" ]]; then
    log_warn "shellcheck $SHELLCHECK_VERSION already installed"
else
    log_info "Installing shellcheck $SHELLCHECK_VERSION static binary..."
    tmpdir=$(mktemp -d)
    trap 'rm -rf "$tmpdir"' EXIT

    curl -sfL "$SHELLCHECK_URL" -o "$tmpdir/shellcheck.tar.xz"
    got_sha=$(sha256sum "$tmpdir/shellcheck.tar.xz" | awk '{print $1}')
    if [[ "$got_sha" != "$SHELLCHECK_SHA256" ]]; then
        log_err "shellcheck sha256 mismatch — expected $SHELLCHECK_SHA256, got $got_sha"
        exit 1
    fi

    tar -xJf "$tmpdir/shellcheck.tar.xz" -C "$tmpdir"
    sudo install -m 755 "$tmpdir/shellcheck-${SHELLCHECK_VERSION}/shellcheck" "$SHELLCHECK_DEST"
    log_ok "shellcheck $SHELLCHECK_VERSION installed to $SHELLCHECK_DEST"
fi

log_ok "Base packages done"
