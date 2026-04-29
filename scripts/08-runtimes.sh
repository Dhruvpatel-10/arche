#!/usr/bin/env bash
# 08-runtimes.sh — development languages and toolchains
source "$(dirname "$0")/lib.sh"

log_info "Setting up runtimes..."
install_group "$ARCHE/packages/runtimes.sh"

# fnm (Node version manager) — installed via its own script
if ! command -v fnm &>/dev/null; then
    log_info "Installing fnm..."
    curl -fsSL https://fnm.vercel.app/install | bash -s -- --skip-shell
    log_ok "fnm installed (restart shell to use)"
else
    log_warn "fnm already installed: $(fnm --version)"
fi

# Install latest LTS Node via fnm
if command -v fnm &>/dev/null; then
    if ! fnm ls | grep -q "lts-latest" 2>/dev/null; then
        log_info "Installing Node LTS via fnm..."
        fnm install --lts
        fnm default lts-latest
    else
        log_warn "Node LTS already installed"
    fi
fi

# Bun — installed via official script
if ! command -v bun &>/dev/null; then
    log_info "Installing Bun..."
    curl -fsSL https://bun.sh/install | bash
    log_ok "Bun installed (restart shell to use)"
else
    log_warn "Bun already installed: $(bun --version)"
fi

# ─── Android SDK post-install ───
# Pin default Java to 17 (Gradle 8.x + Expo SDK 50+ require JDK 17).
if command -v archlinux-java &>/dev/null && pacman -Qi jdk17-openjdk &>/dev/null; then
    current_java=$(archlinux-java get 2>/dev/null || true)
    if [[ "$current_java" != java-17-openjdk ]]; then
        log_info "Setting default JDK to java-17-openjdk..."
        sudo archlinux-java set java-17-openjdk
        log_ok "Default JDK is now java-17-openjdk"
    else
        log_warn "Default JDK already java-17-openjdk"
    fi
fi

# Add every human user (uid >= 1000, < 65000) to the android-sdk group so
# /opt/android-sdk is writable (sdkmanager updates platforms in place).
if getent group android-sdk &>/dev/null; then
    while IFS=: read -r uname _ uid _ _ _ _; do
        (( uid >= 1000 && uid < 65000 )) || continue
        if id -nG "$uname" | tr ' ' '\n' | grep -qx android-sdk; then
            log_warn "$uname already in android-sdk group"
        else
            log_info "Adding $uname to android-sdk group..."
            sudo gpasswd -a "$uname" android-sdk >/dev/null
            log_ok "$uname added to android-sdk (re-login to apply)"
        fi
    done < /etc/passwd
fi

# Verify key runtimes
for cmd in go rustc ruby node bun adb; do
    if command -v "$cmd" &>/dev/null; then
        log_ok "$cmd: $("$cmd" --version 2>/dev/null | head -1)"
    else
        log_warn "$cmd not found"
    fi
done

log_ok "Runtimes setup done"
