# Security packages — firewall, SSH hardening, sandboxing, USB security.
# Used by: scripts/02-security.sh

PACMAN_PKGS=(
    ufw
    openssh
    tailscale
    firejail                 # sandbox for untrusted apps and AppImages
    fail2ban                 # brute-force protection (SSH jail)
)

AUR_PKGS=()
