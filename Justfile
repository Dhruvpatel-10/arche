# Justfile — day-to-day interface for arche management
# Run `just` or `just --list` to see all targets.

dotfiles := justfile_directory()

# ─── Bootstrap ───

# Run full bootstrap (all scripts in order)
[group: 'bootstrap']
install:
    bash {{dotfiles}}/bootstrap.sh

# ─── Individual Scripts ───

# Run preflight checks
[group: 'scripts']
preflight:
    bash {{dotfiles}}/scripts/00-preflight.sh

# Install base packages
[group: 'scripts']
base:
    bash {{dotfiles}}/scripts/01-base.sh

# Configure security (ufw, ssh)
[group: 'scripts']
security:
    bash {{dotfiles}}/scripts/02-security.sh

# Set up NVIDIA GPU drivers
[group: 'scripts']
gpu:
    bash {{dotfiles}}/scripts/03-gpu.sh

# Configure audio (pipewire)
[group: 'scripts']
audio:
    bash {{dotfiles}}/scripts/04-audio.sh

# Set up Hyprland compositor
[group: 'scripts']
hyprland:
    bash {{dotfiles}}/scripts/05-hyprland.sh

# Install and configure shell (fish)
[group: 'scripts']
shell:
    bash {{dotfiles}}/scripts/06-shell.sh

# Set up waybar
[group: 'scripts']
bar:
    bash {{dotfiles}}/scripts/07-bar.sh

# Set up notifications (mako)
[group: 'scripts']
notifications:
    bash {{dotfiles}}/scripts/08-notifications.sh

# Install runtime managers (fnm, rustup, etc.)
[group: 'scripts']
runtimes:
    bash {{dotfiles}}/scripts/09-runtimes.sh

# Install user applications
[group: 'scripts']
apps:
    bash {{dotfiles}}/scripts/10-apps.sh

# Stow all packages to $HOME
[group: 'scripts']
stow:
    bash {{dotfiles}}/scripts/11-stow.sh

# Set up fonts, icons, cursors, GTK/Qt theming
[group: 'scripts']
appearance:
    bash {{dotfiles}}/scripts/12-appearance.sh

# Re-stow a single package (e.g. just restow fish)
[group: 'utilities']
restow pkg:
    stow -d {{dotfiles}}/stow -t $HOME --restow --no-folding {{pkg}}

# ─── Theme ───

# Apply theme (render templates + reload)
[group: 'theme']
theme target="apply":
    bash {{dotfiles}}/scripts/theme.sh {{target}}

# Switch to a different theme
[group: 'theme']
switch name:
    bash {{dotfiles}}/scripts/theme.sh switch {{name}}

# List available themes
[group: 'theme']
themes:
    bash {{dotfiles}}/scripts/theme.sh list

# Render all templates without reloading services
[group: 'theme']
render:
    bash {{dotfiles}}/scripts/theme.sh apply

# Re-render + reload all running services (rapid iteration)
[group: 'theme']
reload:
    bash {{dotfiles}}/scripts/theme.sh apply
    hyprctl reload 2>/dev/null || true

# ─── Utilities ───

# Snapshot ~/.config before destructive operations
[group: 'utilities']
backup:
    #!/usr/bin/env bash
    stamp=$(date +%Y%m%d-%H%M%S)
    dest="$HOME/.config-backup/$stamp"
    mkdir -p "$dest"
    rsync -a --exclude='chromium' --exclude='Code' --exclude='discord' \
        --exclude='.cache' --exclude='node_modules' \
        "$HOME/.config/" "$dest/"
    echo "Backed up to $dest ($(du -sh "$dest" | cut -f1))"

# ─── Testing ───

# Run lint checks (CI-safe, no root)
[group: 'test']
test:
    bash {{dotfiles}}/tests/run.sh lint

# Verify stow symlink integrity
[group: 'test']
test-stow:
    bash {{dotfiles}}/tests/run.sh stow

# Run all tests (lint + stow + integration)
[group: 'test']
test-all:
    bash {{dotfiles}}/tests/run.sh all
