#!/usr/bin/env bash
# clone-repos.sh — clone all repos and create project directory structure
# Usage: bash helpers/clone-repos.sh
#
# Creates the standard directory layout and clones repos into place.
# Safe to re-run — skips repos that already exist.

set -euo pipefail

# ─── Colors ───

green='\033[0;32m'
yellow='\033[0;33m'
cyan='\033[0;36m'
bold='\033[1m'
reset='\033[0m'

info()  { echo -e "${cyan}[INFO]${reset} $1"; }
ok()    { echo -e "${green}[✓]${reset} $1"; }
warn()  { echo -e "${yellow}[~]${reset} $1"; }

# ─── Config ───
# Uses stock github.com — ssh-setup.sh writes the key to the default
# ~/.ssh/id_ed25519 so no host alias is needed.

GH_USER="${GH_USER:-Dhruvpatel-10}"

# ─── Directory structure ───

DIRS=(
    "$HOME/projects/system"
    "$HOME/projects/saas/trading"
    "$HOME/projects/experiments"
    "$HOME/projects/oss"
)

# ─── Repos to clone ───
# Format: "target_dir|repo_name"

REPOS=(
    "$HOME/arche|arche"
    "$HOME/projects/system/arche-bin|arche-bin"
    "$HOME/projects/system/ruvi|ruvi"
    "$HOME/projects/saas/trading/mudra-terminal|mudra-terminal"
)

# ─── Main ───

echo -e "\n${bold}Project Structure Setup${reset}\n"

# Create directories
info "Creating directory structure..."
for dir in "${DIRS[@]}"; do
    mkdir -p "$dir"
done
ok "Directories ready"

echo ""

# Clone repos
info "Cloning repositories..."
echo ""

for entry in "${REPOS[@]}"; do
    IFS='|' read -r target repo <<< "$entry"

    if [[ -d "$target/.git" ]]; then
        warn "$repo — already cloned at $target"
        continue
    fi

    if [[ -d "$target" && "$(ls -A "$target" 2>/dev/null)" ]]; then
        warn "$repo — $target exists and is not empty, skipping"
        continue
    fi

    remote="git@github.com:${GH_USER}/${repo}.git"
    info "Cloning $repo..."

    if git clone "$remote" "$target" 2>/dev/null; then
        ok "$repo → $target"
    else
        warn "$repo — clone failed (repo may not exist yet)"
    fi
done

# ─── Summary ───

echo -e "\n${bold}═══ Directory Layout ═══${reset}\n"

echo "  ~/arche/                              # system config (dotfiles)"
echo "  ~/projects/"
echo "  ├── system/"

for entry in "${REPOS[@]}"; do
    IFS='|' read -r target repo <<< "$entry"
    [[ "$target" == *"system/"* ]] && {
        status="✓"
        [[ ! -d "$target/.git" ]] && status="✗"
        echo "  │   ├── $repo/                       [$status]"
    }
done

echo "  ├── saas/"
echo "  │   └── trading/"

for entry in "${REPOS[@]}"; do
    IFS='|' read -r target repo <<< "$entry"
    [[ "$target" == *"trading/"* ]] && {
        status="✓"
        [[ ! -d "$target/.git" ]] && status="✗"
        echo "  │       └── $repo/             [$status]"
    }
done

echo "  ├── experiments/"
echo "  └── oss/"
echo "  ~/Work/                               # work repos (separate git identity)"

arche_status="✓"
[[ ! -d "$HOME/arche/.git" ]] && arche_status="✗"
echo ""
echo "  ~/arche/                              [$arche_status]"

echo ""
ok "Done. Happy hacking."
echo ""
