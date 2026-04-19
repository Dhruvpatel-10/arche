# User onboarding and SSH/TPM helpers.

# Generate SSH key and configure SSH agent
[group: 'helpers']
ssh-setup:
    bash {{dotfiles}}/helpers/ssh-setup.sh

# Migrate the repo from $HOME/arche to /opt/arche for multi-user setups
[group: 'helpers']
multi-user-init:
    bash {{dotfiles}}/helpers/migrate-to-opt.sh

# Enroll TPM2 + PIN keyslot on root LUKS (interactive; needs 12-boot first)
[group: 'helpers']
tpm-enroll:
    bash {{dotfiles}}/helpers/tpm2-enroll.sh

# Skips system-only scripts (preflight, base, security, gpu, hyprland install, boot)
# — the primary user already did those. Runtime managers (fnm, bun, rustup) are
# intentionally NOT included; run 'just runtimes' separately if you want them.
# Each underlying script is idempotent and safe to re-run.
# Full per-user setup: stow + shell + audio + panel + apps + appearance + theme.
[group: 'helpers']
secondary-user:
    #!/usr/bin/env bash
    set -euo pipefail

    # ─── Preconditions ───
    if [[ ! -d /opt/arche ]]; then
        echo "[✗] /opt/arche not found — primary user must run 'just multi-user-init' first" >&2
        exit 1
    fi
    if ! id -nG | grep -qw users; then
        echo "[✗] $USER is not in the 'users' group. Run as primary user:" >&2
        echo "      sudo usermod -aG users $USER" >&2
        echo "      then log out + back in" >&2
        exit 1
    fi

    # Prime sudo up front — several underlying scripts need it (chsh,
    # svc_enable for system services, link_system_file). Failing here
    # surfaces auth problems before we start, instead of halfway through.
    echo "[*] Priming sudo (needed for chsh, system service enable, bluetooth setup)..."
    if ! sudo -v; then
        echo "[✗] sudo authentication required" >&2
        exit 1
    fi

    # Per-user compat symlink so $HOME/arche keeps working
    if [[ ! -e $HOME/arche ]]; then
        ln -s /opt/arche $HOME/arche
        echo "[✓] Linked $HOME/arche → /opt/arche"
    fi

    cd /opt/arche

    # ─── Per-user setup (bootstrap order, system-only scripts skipped) ───
    # Stow first so subsequent scripts see their configs in place;
    # everything after is idempotent and no-ops on repeat.
    run_step() {
        echo
        echo "═══ $1 ═══"
        shift
        bash "$@"
    }

    run_step "Stow all packages"                          scripts/10-stow.sh
    run_step "Shell (fish default + fisher + prompt)"     scripts/06-shell.sh
    run_step "Audio (pipewire user services)"             scripts/04-audio.sh
    run_step "Panel (quickshell → /opt/arche/shell)"      scripts/07-panel.sh
    run_step "Apps (docker/syncthing/bluetooth/denoise)"  scripts/09-apps.sh
    run_step "Appearance (fonts + GTK/Qt templates)"      scripts/11-appearance.sh
    run_step "Theme apply (render all templates)"         scripts/theme.sh apply

    echo
    echo "[✓] Secondary user setup complete."
    echo "    Log out and back in so fish becomes the login shell."
    echo "    Runtime managers (fnm, bun, rustup) were NOT installed — run 'just runtimes' if you want them."
