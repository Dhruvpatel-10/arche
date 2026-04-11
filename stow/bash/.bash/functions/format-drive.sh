#!/usr/bin/env bash
# Format entire drive as ext4.
format-drive() {
    if [[ $# -ne 2 ]]; then
        echo "Usage: format-drive <device> <name>"
        echo "Example: format-drive /dev/sda 'My Stuff'"
        echo
        echo "Available drives:"
        lsblk -d -o NAME -n | awk '{print "/dev/"$1}'
        return 1
    fi

    local device="$1" label="$2" confirm part1

    echo "WARNING: This will completely erase all data on $device and label it '$label'."
    read -r -p "Are you sure? (y/N): " confirm

    if [[ $confirm =~ ^[Yy]$ ]]; then
        sudo wipefs -a "$device"
        sudo dd if=/dev/zero of="$device" bs=1M count=100 status=progress
        sudo parted -s "$device" mklabel gpt
        sudo parted -s "$device" mkpart primary ext4 1MiB 100%

        # nvme vs sd partition naming
        if [[ $device == *nvme* ]]; then
            part1="${device}p1"
        else
            part1="${device}1"
        fi

        sudo mkfs.ext4 -L "$label" "$part1"
        echo "Drive $device formatted and labeled '$label'."
    fi
}
