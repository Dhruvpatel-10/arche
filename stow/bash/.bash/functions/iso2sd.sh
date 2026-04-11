#!/usr/bin/env bash
# Write ISO to SD card.
iso2sd() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: iso2sd <input_file> <output_device>"
        echo "Example: iso2sd ~/Downloads/archlinux.iso /dev/sda"
        echo
        echo "Available SD cards:"
        lsblk -d -o NAME | grep -E '^sd[a-z]' | awk '{print "/dev/"$1}'
        return 1
    fi
    sudo dd bs=4M status=progress oflag=sync if="$1" of="$2"
    sudo eject "$2"
}
