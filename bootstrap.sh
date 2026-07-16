#!/usr/bin/env bash
# bootstrap.sh — the one command for arche.
#
#   bash bootstrap.sh                 set everything up (asks before each step)
#   bash bootstrap.sh --yes           set everything up without asking
#   bash bootstrap.sh doctor          check the setup is healthy
#   bash bootstrap.sh doctor --repair check and fix what is safe to fix
#   bash bootstrap.sh clean           unlink the config files it created
#   bash bootstrap.sh --profile NAME  force a profile (linux-hyprland | macos | server)
#
# It picks the right profile for your system automatically. On macOS it runs
# under a modern bash when one is installed.

set -euo pipefail

ARCHE="$(cd "$(dirname "$0")" && pwd)"
export ARCHE

# ─── Prefer a modern bash ───
# macOS still ships bash 3.2. The core is written to survive it, but if a current
# bash is already installed we re-exec under it. We do NOT install bash here (that
# would surprise a plain `doctor` run); the installer adds it via packages/macos.reg,
# so later runs pick it up. This block stays POSIX-plain so 3.2 can execute it.
if [ "${BASH_VERSINFO:-0}" -lt 4 ]; then
    for _b in /opt/homebrew/bin/bash /usr/local/bin/bash; do
        [ -x "$_b" ] && exec "$_b" "$0" "$@"
    done
fi

# ─── Load the core ───
source "$ARCHE/core/lib.sh"
source "$ARCHE/core/runner.sh"
source "$ARCHE/core/doctor.sh"
source "$ARCHE/core/clean.sh"

show_help() {
    # Print the leading comment block (minus the shebang), stripped of "# ".
    awk 'NR==1{next} /^#/{sub(/^# ?/,""); print; next} {exit}' "$0"
}

# ─── Parse subcommand + flags ───
cmd="install"
case "${1:-}" in
    install|doctor|clean) cmd="$1"; shift ;;
    -h|--help)            show_help; exit 0 ;;
esac

ARCHE_YES=0
ARCHE_ONLY=""
ARCHE_PROFILE=""
EXTRA_ARGS=()
while [ $# -gt 0 ]; do
    case "$1" in
        --yes|-y)     ARCHE_YES=1 ;;
        --only)       ARCHE_ONLY="${2:-}"; shift ;;
        --only=*)     ARCHE_ONLY="${1#*=}" ;;
        --profile)    ARCHE_PROFILE="${2:-}"; shift ;;
        --profile=*)  ARCHE_PROFILE="${1#*=}" ;;
        *)            EXTRA_ARGS+=("$1") ;;
    esac
    shift
done
export ARCHE_YES ARCHE_ONLY

# ─── Pick the profile for this machine ───
if [ -z "$ARCHE_PROFILE" ]; then
    case "$ARCHE_PLATFORM" in
        arch)  ARCHE_PROFILE="linux-hyprland" ;;
        macos) ARCHE_PROFILE="macos" ;;
        *)     log_err "No profile for this platform ($ARCHE_PLATFORM). Pass --profile NAME."; exit 1 ;;
    esac
fi

PROFILE_DIR="$ARCHE/profiles/$ARCHE_PROFILE"
if [ ! -f "$PROFILE_DIR/profile.sh" ]; then
    log_err "Profile not found: $ARCHE_PROFILE  (looked in $PROFILE_DIR)"
    exit 1
fi
export PROFILE_DIR
# shellcheck source=/dev/null
source "$PROFILE_DIR/profile.sh"

# ─── Dispatch ───
case "$cmd" in
    install)
        log_init
        log_info "arche installer"
        log_info "Profile: $PROFILE_NAME"
        log_info "Log file: $ARCHE_LOG_FILE"
        profile_steps
        run_profile
        ;;
    doctor)
        run_doctor ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
        ;;
    clean)
        run_clean ${EXTRA_ARGS[@]+"${EXTRA_ARGS[@]}"}
        ;;
esac
