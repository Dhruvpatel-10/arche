# NVIDIA GPU packages — open kernel module + CUDA.
# Used by: scripts/03-gpu.sh

PACMAN_PKGS=(
    nvidia-open-dkms
    nvidia-utils
    nvidia-settings
    lib32-nvidia-utils
    libva-nvidia-driver      # VA-API for hardware decode
    egl-wayland              # EGL on Wayland
    cuda                     # CUDA toolkit
)

AUR_PKGS=()
