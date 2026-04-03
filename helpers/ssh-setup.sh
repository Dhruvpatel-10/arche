#!/usr/bin/env bash
# ssh-setup.sh — generate SSH keys for multiple GitHub accounts
# Usage: bash helpers/ssh-setup.sh

set -euo pipefail

SSH_DIR="$HOME/.ssh"
SSH_CONFIG="$SSH_DIR/config"

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

# ─── Helpers ───

ask() {
    local prompt="$1" default="${2:-}" input
    if [[ -n "$default" ]]; then
        echo -en "  ${dim}${prompt}${reset} ${dim}[${default}]${reset} " >/dev/tty
        read -r input </dev/tty
        [[ -z "$input" ]] && input="$default"
    else
        input=""
        while [[ -z "$input" ]]; do
            echo -en "  ${dim}${prompt}${reset} " >/dev/tty
            read -r input </dev/tty
            [[ -z "$input" ]] && err "Required" >/dev/tty
        done
    fi
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

generate_key() {
    local label="$1" email="$2" keyfile="$3"

    if [[ -f "$keyfile" ]]; then
        warn "Key exists: ${dim}$keyfile${reset}"
        if ! confirm "Overwrite?"; then
            return 0
        fi
    fi

    ssh-keygen -t ed25519 -C "$email" -f "$keyfile" -N "" -q
    chmod 600 "$keyfile"
    chmod 644 "$keyfile.pub"
    ok "Key generated"
}

write_ssh_config_entry() {
    local host_alias="$1" keyfile="$2"

    if grep -q "^Host $host_alias$" "$SSH_CONFIG" 2>/dev/null; then
        warn "SSH config entry exists — skipping"
        return 0
    fi

    cat >> "$SSH_CONFIG" <<EOF

Host $host_alias
    HostName github.com
    User git
    IdentityFile $keyfile
    IdentitiesOnly yes
EOF
    ok "SSH config updated"
}

# ─── Main ───

echo ""
echo -e "  ${bold}SSH Key Setup${reset}"
echo -e "  ${dim}Generate keys and configure ~/.ssh/config for GitHub${reset}"

mkdir -p "$SSH_DIR"
chmod 700 "$SSH_DIR"
touch "$SSH_CONFIG"
chmod 600 "$SSH_CONFIG"

header "Accounts"
num_accounts=$(ask "How many GitHub accounts?" "2")

declare -a accounts=()

for i in $(seq 1 "$num_accounts"); do
    header "Account $i"

    label=$(ask "Label (personal/work):")
    label="${label,,}"
    label="${label// /-}"

    name=$(ask "Name (for commits):")
    email=$(ask "Email (for commits):")
    github_user=$(ask "GitHub username:")

    keyfile="$SSH_DIR/id_ed25519_$label"
    host_alias="github-$label"

    echo ""
    generate_key "$label" "$email" "$keyfile"
    write_ssh_config_entry "$host_alias" "$keyfile"

    accounts+=("$label|$name|$email|$github_user|$keyfile|$host_alias")
done

# ─── Git Config ───

header "Git Config"

IFS='|' read -r def_label def_name def_email _ _ _ <<< "${accounts[0]}"
git config --global user.name "$def_name"
git config --global user.email "$def_email"
ok "Default: $def_name <$def_email>"

for entry in "${accounts[@]:1}"; do
    IFS='|' read -r label name email github_user keyfile host_alias <<< "$entry"

    gitconfig_file="$HOME/.gitconfig-$label"
    cat > "$gitconfig_file" <<EOF
[user]
    name = $name
    email = $email
EOF
    chmod 600 "$gitconfig_file"

    case "$label" in
        work*)   dir="$HOME/Work/" ;;
        *)       dir="" ;;
    esac

    if [[ -n "$dir" ]]; then
        if ! git config --global --get-all "includeIf.gitdir:$dir.path" &>/dev/null; then
            git config --global --add "includeIf.gitdir:$dir.path" "$gitconfig_file"
            ok "$dir → $name <$email>"
        else
            warn "Conditional include for $dir already set"
        fi
    else
        ok "Created $gitconfig_file"
        info "Add includeIf to ~/.gitconfig for auto-switching"
    fi
done

# ─── Summary ───

echo ""
echo ""
echo -e "  ${bold}═══════════════════════════════════════════${reset}"
echo ""

for entry in "${accounts[@]}"; do
    IFS='|' read -r label name email github_user keyfile host_alias <<< "$entry"

    echo -e "  ${bold}${label}${reset} ${dim}(${github_user})${reset}"
    echo ""
    echo -e "    Host alias    ${cyan}${host_alias}${reset}"
    echo -e "    Identity      ${name} <${email}>"
    echo -e "    Key           ${dim}${keyfile}${reset}"
    echo ""
    echo -e "    ${dim}Public key:${reset}"
    echo -e "    ${green}$(cat "$keyfile.pub")${reset}"
    echo ""
    echo -e "    ${dim}Clone:${reset}  git clone ${cyan}git@${host_alias}:${github_user}/repo.git${reset}"
    echo ""
    echo -e "  ${dim}───────────────────────────────────────────${reset}"
    echo ""
done

echo -e "  ${bold}Next steps${reset}"
echo ""
echo -e "    ${dim}1.${reset} Add public keys above to ${cyan}https://github.com/settings/keys${reset}"
echo -e "    ${dim}2.${reset} Test connections:"
echo ""
for entry in "${accounts[@]}"; do
    IFS='|' read -r _ _ _ _ _ host_alias <<< "$entry"
    echo -e "       ${dim}\$${reset} ssh -T git@${host_alias}"
done
echo ""
echo -e "    ${dim}3.${reset} Use host alias in remotes instead of github.com"
echo ""
