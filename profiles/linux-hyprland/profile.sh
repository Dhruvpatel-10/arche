#!/usr/bin/env bash
# profiles/linux-hyprland/profile.sh — the full Arch Linux + Hyprland desktop.
#
# This is the complete setup for stark's Lenovo Legion: NVIDIA graphics, the
# Hyprland window manager, the DankMaterialShell desktop, encrypted boot, audio,
# security hardening, and every app and config. Each step maps to a script in
# steps/ and can also be run on its own.
#
# Sourced by bootstrap.sh, which has already loaded core/lib.sh + the runner.

PROFILE_NAME="Arch Linux + Hyprland"
PROFILE_DESC="Full desktop: NVIDIA, Hyprland, DankMaterialShell, encrypted boot, audio, apps."

# Every config package gets linked. Used by the doctor and clean commands.
PROFILE_STOW=(
    fish ghostty tmux nvim btop glow mpv
    hypr cliphist wireplumber arche-cli arche-scripts arche-denoise
    hyprland-preview-share-picker vivaldi webapps mimeapps paru
)
# Empty means render every theme component (the engine's default).
PROFILE_THEME=()

# A final pass that renders the theme across every app.
theme_all() {
    log_info "Applying your theme across every app."
    bash "$ARCHE/theming/engine.sh" apply
}

profile_steps() {
    step preflight   steps/00-preflight.sh   reboot  "Check the system, rank mirrors, and do a full update"
    step base        steps/01-base.sh        -       "Core command-line tools and build tools"
    step security    steps/02-security.sh    -       "Firewall, SSH, DNS, and system hardening"
    step gpu         steps/03-gpu.sh         -       "NVIDIA graphics driver and CUDA (skipped without NVIDIA)"
    step audio       steps/04-audio.sh       -       "PipeWire audio stack"
    step hyprland    steps/05-hyprland.sh    -       "Hyprland desktop, Wayland tools, and the login screen"
    step shell       steps/06-shell.sh       -       "Fish shell, prompt, and terminal"
    step runtimes    steps/08-runtimes.sh    -       "Programming language runtimes (Node, Go, Rust, and more)"
    step apps        steps/09-apps.sh        -       "Everyday apps: browser, media, files, Docker"
    step configs     steps/10-stow.sh        -       "Link all your config files into place"
    step appearance  steps/11-appearance.sh  -       "Fonts, icons, and GTK theming"
    step boot        steps/12-boot.sh        -       "Encrypted boot with TPM2 unlock"
    step dms         steps/13-dms.sh         -       "The desktop shell: bar, notifications, and launcher"
    step theme       theme_all               -       "Apply your theme across every app"
}
