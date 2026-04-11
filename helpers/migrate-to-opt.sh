#!/usr/bin/env bash
# migrate-to-opt.sh — move arche from $HOME to /opt for multi-user setups
#
# Why /opt/arche?
#   The repo holds the source of truth for the whole system. Two human users
#   (e.g. personal + work) should share the same arche source — installing
#   pacman packages and writing /etc/ configs is system-wide, so duplicating
#   the repo into each home is wasted disk and a synchronisation hazard.
#   /opt/arche lives outside any user's home, is reachable by every user, and
#   /opt itself is mode 755 so the `sddm` system user (and any other system
#   user) can traverse it.
#
# What this script does:
#   1. Moves /home/<user>/arche to /opt/arche (one-way; safe to re-run)
#   2. Sets group ownership to `users` (gid 100, the default Arch shared group)
#   3. Adds setgid bit on every directory so newly created files inherit
#      group=users — both users keep write access to anything either creates
#   4. Adds the current user to the `users` group (idempotent)
#   5. Creates ~/arche → /opt/arche compat symlink so anything still hardcoding
#      the old path keeps working transparently
#
# After running:
#   - Run `usermod -aG users <work-user>` for the second user
#   - From the second user's session, run `just secondary-user` to deploy
#     stow dotfiles into their $HOME (no system scripts re-run; the system
#     was already configured by the primary user's bootstrap)
#
# Safe to re-run. If /opt/arche already exists and looks like the repo, the
# script just fixes permissions and makes sure the symlink is in place.

set -euo pipefail

green='\033[0;32m'
yellow='\033[0;33m'
red='\033[0;31m'
cyan='\033[0;36m'
bold='\033[1m'
reset='\033[0m'

info()  { echo -e "${cyan}[INFO]${reset} $1"; }
ok()    { echo -e "${green}[✓]${reset} $1"; }
warn()  { echo -e "${yellow}[~]${reset} $1"; }
err()   { echo -e "${red}[✗]${reset} $1"; exit 1; }

src="$HOME/arche"
dst="/opt/arche"
shared_group="users"

[[ $EUID -eq 0 ]] && err "Run as your normal user, not root. The script uses sudo where needed."

# ─── Sanity checks ───

if [[ -L "$src" ]]; then
    target="$(readlink -f "$src")"
    if [[ "$target" == "$dst" ]]; then
        ok "$src already symlinks to $dst — re-checking permissions"
    else
        err "$src is a symlink to $target, not $dst — refusing to touch it"
    fi
elif [[ ! -d "$src" && ! -d "$dst" ]]; then
    err "Neither $src nor $dst exists. Nothing to migrate."
fi

# ─── Move (only if /opt/arche doesn't already exist) ───

if [[ ! -e "$dst" ]]; then
    if [[ ! -d "$src/.git" ]]; then
        err "$src does not look like a git repo (no .git/) — refusing to move"
    fi

    info "Moving $src → $dst (this needs sudo)..."
    sudo mv "$src" "$dst"
    ok "Moved"
elif [[ -d "$dst/.git" ]]; then
    warn "$dst already exists and looks like the repo — skipping move"
else
    err "$dst exists but is not a git repo — investigate manually before re-running"
fi

# ─── Ownership + permissions ───

info "Setting ownership: $USER:$shared_group on $dst..."
sudo chown -R "$USER:$shared_group" "$dst"

info "Setting permissions: dirs 2775 (setgid), files 0664, executables 0775..."
sudo find "$dst" -type d -exec chmod 2775 {} \;
sudo find "$dst" -type f -exec chmod 0664 {} \;

# Re-mark legitimately-executable files. We can't chmod by extension because
# many *.sh files in this repo are DATA (sourced, not run):
#   packages/*.sh                    — sourced by install_group, declare PACMAN_PKGS arrays
#   themes/*.sh                      — sourced by theme_render, declare COLOR_* variables
#   stow/bash/.bash/{conf.d,functions}/*.sh — sourced by .bashrc at login
#   vendor/{blesh,bash-preexec}/*    — sourced by .bashrc (ble.sh, preexec)
# Heuristic: a file is executable iff it (a) has a #! shebang at byte 0, or
# (b) lives under a bin/ directory (catches binaries without shebangs like
# tools/bin/arche-legion). Everything else stays 0664.
sudo find "$dst" -type f -path '*/bin/*' -exec chmod 0775 {} \;
sudo find "$dst" -type f -not -path '*/bin/*' -not -path '*/.git/*' -print0 \
| while IFS= read -r -d '' f; do
    if [[ "$(head -c 2 "$f" 2>/dev/null)" == "#!" ]]; then
        sudo chmod 0775 "$f"
    fi
done
ok "Permissions set"

# ─── Add current user to shared group ───

if id -nG "$USER" | grep -qw "$shared_group"; then
    warn "$USER already in $shared_group group"
else
    info "Adding $USER to $shared_group group..."
    sudo usermod -aG "$shared_group" "$USER"
    ok "Added — log out + back in for the group to take effect"
fi

# ─── Compat symlink ($HOME/arche → /opt/arche) ───

if [[ -L "$src" ]]; then
    warn "$src symlink already exists"
elif [[ -e "$src" ]]; then
    err "$src still exists after migration — investigate manually"
else
    ln -s "$dst" "$src"
    ok "Created symlink: $src → $dst"
fi

# ─── Done ───

echo ""
ok "Migration complete."
echo ""
echo "  ${bold}Repo location:${reset}        $dst"
echo "  ${bold}Compat symlink:${reset}       $src → $dst"
echo "  ${bold}Group:${reset}                $shared_group (gid $(getent group "$shared_group" | cut -d: -f3))"
echo ""
echo "  ${bold}Add a second user:${reset}"
echo "    sudo useradd -m -G wheel,$shared_group <work-username>"
echo "    sudo passwd <work-username>"
echo ""
echo "  ${bold}From the second user's session:${reset}"
echo "    cd /opt/arche && just secondary-user"
echo ""
echo "  ${bold}If you are an existing user being added:${reset}"
echo "    sudo usermod -aG $shared_group <existing-user>"
echo "    # then log out + back in"
echo ""
