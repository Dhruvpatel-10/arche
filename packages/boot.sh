# Pre-boot UI + TPM2 unlock stack — Plymouth splash, TPM2 PIN enrollment.
# Used by: scripts/12-boot.sh
#
# ttf-ibm-plex is declared in appearance.sh; 12-boot.sh ensures the file is
# present on the ImageMagick render path and fails fast if missing.

PACMAN_PKGS=(
    plymouth                 # pre-boot splash renderer (script-module theme)
    tpm2-tools               # tpm2_* CLIs — used by systemd-cryptenroll's backend
    # tpm2-tss is a dep of systemd itself on Arch (base system), already installed
)

AUR_PKGS=()
