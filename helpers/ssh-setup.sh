#!/usr/bin/env bash
# ssh-setup.sh — generate an SSH key for GitHub + configure git identity
# Usage: bash helpers/ssh-setup.sh
#
# Single-account flow: one ed25519 key at the SSH default path (~/.ssh/id_ed25519)
# so `git@github.com:user/repo.git` works with no ssh_config aliasing. Also
# sets global git user.name / user.email and offers SSH commit signing.

set -euo pipefail

SSH_DIR="$HOME/.ssh"
KEYFILE="$SSH_DIR/id_ed25519"

# ─── Colors ───

red='\033[0;31m'
green='\033[0;32m'
yellow='\033[0;33m'
cyan='\033[0;36m'
dim='\033[2m'
bold='\033[1m'
reset='\033[0m'

info()  { echo -e "  ${cyan}→${reset} $1"; }
ok()    { echo -e "  ${green}✓${reset} $1"; }
warn()  { echo -e "  ${yellow}~${reset} $1"; }
err()   { echo -e "  ${red}✗${reset} $1"; }

ask() {
    local prompt="$1" input=""
    while [[ -z "$input" ]]; do
        echo -en "  ${dim}${prompt}${reset} " >/dev/tty
        read -r input </dev/tty
        [[ -z "$input" ]] && err "Required" >/dev/tty
    done
    echo "$input"
}

confirm() {
    local prompt="$1" answer
    echo -en "  ${dim}${prompt}${reset} ${dim}[y/N]${reset} " >/dev/tty
    read -r answer </dev/tty
    [[ "$answer" == "y" || "$answer" == "Y" ]]
}

header() {
    echo ""
    echo -e "  ${bold}$1${reset}"
    echo -e "  ${dim}$(printf '%.0s─' $(seq 1 ${#1}))${reset}"
}

# ─── Main ───

echo ""
echo -e "  ${bold}SSH + Git Setup${reset}"
echo -e "  ${dim}Generate an ed25519 key at ~/.ssh/id_ed25519 and set git identity${reset}"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"

header "Identity"
name=$(ask "Name (for commits):")
email=$(ask "Email (for commits):")

# ─── SSH key ───

header "SSH key"

if [[ -f "$KEYFILE" ]]; then
    warn "Key exists: ${dim}$KEYFILE${reset}"
    if confirm "Overwrite?"; then
        ssh-keygen -t ed25519 -C "$email" -f "$KEYFILE" -N "" -q
        chmod 600 "$KEYFILE"
        chmod 644 "$KEYFILE.pub"
        ok "Key regenerated"
    else
        info "Keeping existing key"
    fi
else
    ssh-keygen -t ed25519 -C "$email" -f "$KEYFILE" -N "" -q
    chmod 600 "$KEYFILE"
    chmod 644 "$KEYFILE.pub"
    ok "Key generated"
fi

# ─── Git config ───

header "Git config"

git config --global user.name "$name"
git config --global user.email "$email"
git config --global init.defaultBranch main
git config --global pull.ff only
ok "Identity: $name <$email>"

# Optional: SSH commit signing
echo ""
if confirm "Enable SSH commit signing?"; then
    git config --global gpg.format ssh
    git config --global user.signingKey "$KEYFILE.pub"
    git config --global commit.gpgsign true
    ok "Commit signing enabled (SSH)"
    info "Add ${KEYFILE}.pub to GitHub → Settings → SSH keys (as a Signing key)"
fi

# ─── Summary ───

echo ""
echo -e "  ${bold}═══════════════════════════════════════════${reset}"
echo ""
echo -e "    Identity      ${name} <${email}>"
echo -e "    Key           ${dim}${KEYFILE}${reset}"
echo ""
echo -e "    ${dim}Public key:${reset}"
echo -e "    ${green}$(cat "$KEYFILE.pub")${reset}"
echo ""
echo -e "    ${dim}Clone:${reset}  git clone ${cyan}git@github.com:user/repo.git${reset}"
echo ""
echo -e "  ${dim}───────────────────────────────────────────${reset}"
echo ""

echo -e "  ${bold}Next steps${reset}"
echo ""
echo -e "    ${dim}1.${reset} Add the public key above to ${cyan}https://github.com/settings/keys${reset}"
echo -e "       ${dim}(Auth key + Signing key if you enabled signing)${reset}"
echo -e "    ${dim}2.${reset} Test the connection:"
echo ""
echo -e "       ${dim}\$${reset} ssh -T git@github.com"
echo ""
