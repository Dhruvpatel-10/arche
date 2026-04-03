---
disable-model-invocation: true
---

Run weekly system maintenance sequence:

1. `paru -Syu` — full system update
2. `dkms status` — verify NVIDIA rebuilt after any kernel update
3. `systemctl --failed` — check for broken units
4. `journalctl -p err -b` — errors since last boot
5. `pacman -Qdt` — orphaned packages
6. `paccache -rk2` — prune package cache to 2 versions

Report anything that needs attention. Flag if NVIDIA DKMS is not current with the running kernel.
