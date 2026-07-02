# Individual bootstrap scripts + panel-restart. Each is idempotent.

# Run preflight checks (pacman -Syu, link_system_all, kernel mismatch gate)
[group: 'scripts']
preflight:
    bash {{dotfiles}}/scripts/00-preflight.sh

# Install base packages
[group: 'scripts']
base:
    bash {{dotfiles}}/scripts/01-base.sh

# Configure security (ufw, ssh, sysctl hardening, fail2ban)
[group: 'scripts']
security:
    bash {{dotfiles}}/scripts/02-security.sh

# Set up NVIDIA GPU drivers (nvidia-open-dkms + CUDA)
[group: 'scripts']
gpu:
    bash {{dotfiles}}/scripts/03-gpu.sh

# Configure audio (pipewire + wireplumber user services)
[group: 'scripts']
audio:
    bash {{dotfiles}}/scripts/04-audio.sh

# Set up Hyprland compositor + SDDM greeter + Wayland utilities
[group: 'scripts']
hyprland:
    bash {{dotfiles}}/scripts/05-hyprland.sh

# Install and configure shell (fish + atuin + fisher + starship)
[group: 'scripts']
shell:
    bash {{dotfiles}}/scripts/06-shell.sh


# Install runtime managers (fnm, rustup, bun, etc.)
[group: 'scripts']
runtimes:
    bash {{dotfiles}}/scripts/08-runtimes.sh

# Install user applications (editors, browsers, media, docker, syncthing)
[group: 'scripts']
apps:
    bash {{dotfiles}}/scripts/09-apps.sh

# Stow all packages to $HOME
[group: 'scripts']
stow:
    bash {{dotfiles}}/scripts/10-stow.sh

# Set up fonts, icons, cursors, GTK/Qt theming
[group: 'scripts']
appearance:
    bash {{dotfiles}}/scripts/11-appearance.sh

# Install + configure DankMaterialShell (dms) — desktop shell (D032)
[group: 'scripts']
dms:
    bash {{dotfiles}}/scripts/13-dms.sh

# Restart dms (picks up theme / settings changes)
[group: 'scripts']
dms-restart:
    systemctl --user restart dms.service

# Set up sd-encrypt + UKI (TPM2-capable, passphrase/PIN on plain TTY)
[group: 'scripts']
boot:
    bash {{dotfiles}}/scripts/12-boot.sh
