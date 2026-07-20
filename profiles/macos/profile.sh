#!/usr/bin/env bash
# profiles/macos/profile.sh — the macOS (Apple Silicon) setup.
#
# A clean, cross-platform slice of arche: the shared command-line tools, the
# terminal (Ghostty), editor, shell, and the theme, all installed with Homebrew
# and linked into your home directory. No window manager, no system services.
#
# Sourced by bootstrap.sh, which has already loaded core/lib.sh + the runner.

PROFILE_NAME="macOS (Apple Silicon)"
PROFILE_DESC="Shared CLI tools, terminal, editor, shell, and theme on macOS."

# Config packages to link, and theme components to render. Used by the install
# steps and by the doctor and clean commands.
PROFILE_STOW=(fish nvim ghostty tmux mpv btop glow arche-cli)
PROFILE_THEME=(ghostty fish starship tmux btop glow mpv)

# ─── Steps (run in this order) ───

macos_check() {
    [[ "$(uname -s)" == "Darwin" ]] || { log_err "This profile is for macOS."; return 1; }
    [[ "$(uname -m)" == "arm64" ]]  || { log_err "This setup targets Apple Silicon (arm64)."; return 1; }
    if ! command -v brew >/dev/null 2>&1; then
        log_err "Homebrew is required. Install it first from https://brew.sh, then run this again."
        return 1
    fi
    log_ok "macOS Apple Silicon with Homebrew, good to go."
}

macos_packages() {
    log_info "Installing the command-line tools and apps with Homebrew."
    registry_install macos
}

macos_configs() {
    log_info "Linking your config files."
    local pkg
    for pkg in "${PROFILE_STOW[@]}"; do
        stow_pkg "$pkg"
    done
    # mpv ships one shared config that includes a per-OS file; point it at macOS.
    select_platform_variant "$HOME/.config/mpv/platform.conf" platform.linux.conf platform.macos.conf
}

macos_shell() {
    local fish_path; fish_path="$(command -v fish || true)"
    [[ -n "$fish_path" ]] || { log_warn "fish is not installed yet, skipping shell setup."; return 0; }
    set_login_shell "$fish_path"
    setup_fisher
}

macos_theme() {
    # The theme engine needs GNU envsubst (gettext) and GNU readlink (coreutils),
    # both keg-only on Homebrew. Put them on PATH for this render.
    export PATH="$(brew --prefix gettext)/bin:$(brew --prefix coreutils)/libexec/gnubin:$PATH"
    if [[ ! -e "$ARCHE/theming/themes/active" ]]; then
        log_info "No theme picked yet, using the default (ember)."
        ln -sfn ember.sh "$ARCHE/theming/themes/active"
    fi
    log_info "Rendering your theme."
    bash "$ARCHE/theming/engine.sh" apply "${PROFILE_THEME[@]}"
}

macos_default_player() {
    if [[ -f "$ARCHE/macos/mpv-default.sh" ]]; then
        log_info "Making mpv the default player for common video files."
        bash "$ARCHE/macos/mpv-default.sh" || log_warn "Could not set mpv as default player (not fatal)."
    else
        log_warn "Skipping default-player setup (macos/mpv-default.sh is not present yet)."
    fi
}

profile_steps() {
    step check     macos_check          -  "Check this is macOS on Apple Silicon with Homebrew"
    step packages  macos_packages       -  "Install the command-line tools and apps (Homebrew)"
    step configs   macos_configs        -  "Link your shell, terminal, editor, and app configs"
    step shell     macos_shell          -  "Make fish your shell and install its plugins"
    step theme     macos_theme          -  "Render your colors and fonts across all apps"
    step player    macos_default_player -  "Set mpv as the default player for common video files"
}
