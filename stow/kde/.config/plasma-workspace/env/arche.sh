#!/bin/bash
# arche environment — sourced by KDE Plasma at login
# KDE reads ~/.config/plasma-workspace/env/*.sh once at session start

# ─── Cursor ───
export XCURSOR_THEME="Bibata-Modern-Classic"
export XCURSOR_SIZE=24

# ─── Qt ───
export QT_QPA_PLATFORMTHEME=kde

# ─── Wayland ───
export MOZ_ENABLE_WAYLAND=1

# ─── NVIDIA ───
export NVD_BACKEND=direct
export LIBVA_DRIVER_NAME=nvidia
export __GLX_VENDOR_LIBRARY_NAME=nvidia

# ─── PATH ───
export PATH="$HOME/.local/bin/arche:$PATH"
