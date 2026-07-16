#!/usr/bin/env bash
# profiles/server/profile.sh — a lightweight, headless Arch install.
#
# For a development server or VPS: the command-line tools, shell, and prompt,
# with no graphics, no desktop, and no audio. It reuses the same core, adapter,
# and registry as the desktop profile, just a smaller set of steps. This is a
# starting point you can grow (add sshd hardening, docker, tailscale as needed).
#
# Sourced by bootstrap.sh, which has already loaded core/lib.sh + the runner.

PROFILE_NAME="Arch server (headless)"
PROFILE_DESC="Command-line only: tools, shell, prompt. No desktop, graphics, or audio."

# Command-line configs only, nothing that needs a display.
PROFILE_STOW=(fish nvim tmux btop glow)
PROFILE_THEME=(fish starship tmux btop glow)

server_packages() {
    log_info "Installing the command-line tools."
    # The base group is the shared CLI set; shell adds fish/atuin/starship/tmux.
    registry_install arch base
    registry_install arch shell
}

server_configs() {
    log_info "Linking your config files."
    local pkg
    for pkg in "${PROFILE_STOW[@]}"; do
        stow_pkg "$pkg"
    done
}

server_shell() {
    local fish_path; fish_path="$(command -v fish || true)"
    [[ -n "$fish_path" ]] || { log_warn "fish is not installed yet, skipping shell setup."; return 0; }
    set_login_shell "$fish_path"
    setup_fisher
}

server_theme() {
    if [[ ! -e "$ARCHE/theming/themes/active" ]]; then
        log_info "No theme picked yet, using the default (ember)."
        ln -sfn ember.sh "$ARCHE/theming/themes/active"
    fi
    log_info "Rendering your theme for the command line."
    bash "$ARCHE/theming/engine.sh" apply "${PROFILE_THEME[@]}"
}

profile_steps() {
    step packages  server_packages  -  "Install the command-line tools and shell"
    step configs   server_configs   -  "Link your shell, editor, and tool configs"
    step shell     server_shell     -  "Make fish your shell and install its plugins"
    step theme     server_theme     -  "Render your colors and fonts for the terminal"
}
