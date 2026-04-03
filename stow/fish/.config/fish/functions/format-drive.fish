function format-drive --description 'Format entire drive as ext4'
    if test (count $argv) -ne 2
        echo "Usage: format-drive <device> <name>"
        echo "Example: format-drive /dev/sda 'My Stuff'"
        echo
        echo "Available drives:"
        lsblk -d -o NAME -n | awk '{print "/dev/"$1}'
        return 1
    end

    set -l device $argv[1]
    set -l label $argv[2]

    echo "WARNING: This will completely erase all data on $device and label it '$label'."
    read -P "Are you sure? (y/N): " confirm

    if string match -qi 'y' $confirm
        sudo wipefs -a $device
        sudo dd if=/dev/zero of=$device bs=1M count=100 status=progress
        sudo parted -s $device mklabel gpt
        sudo parted -s $device mkpart primary ext4 1MiB 100%

        # Handle nvme vs sd partition naming
        set -l part1
        if string match -q '*nvme*' $device
            set part1 {$device}p1
        else
            set part1 {$device}1
        end

        sudo mkfs.ext4 -L $label $part1
        echo "Drive $device formatted and labeled '$label'."
    end
end
