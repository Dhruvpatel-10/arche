# Audio packages — full PipeWire stack.
# Used by: scripts/04-audio.sh

PACMAN_PKGS=(
    pipewire
    pipewire-alsa
    pipewire-jack
    pipewire-pulse
    wireplumber
    gst-plugin-pipewire      # GStreamer integration
    alsa-utils               # amixer, aplay, etc.
    pamixer                  # CLI volume control
    wiremix                  # TUI audio mixer for PipeWire
    playerctl                # MPRIS media controls
    sof-firmware             # Sound Open Firmware
)

AUR_PKGS=()
