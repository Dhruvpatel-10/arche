# TPM2 unlock stack — TPM2 PIN enrollment tooling.
# Used by: scripts/12-boot.sh

PACMAN_PKGS=(
    tpm2-tools               # tpm2_* CLIs — used by systemd-cryptenroll's backend
    # tpm2-tss is a dep of systemd itself on Arch (base system), already installed
)

AUR_PKGS=()
