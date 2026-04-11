function iso2sd --description 'Write ISO to SD card'
    if test (count $argv) -ne 2
        echo "Usage: iso2sd <input_file> <output_device>"
        echo "Example: iso2sd ~/Downloads/archlinux.iso /dev/sda"
        echo
        echo "Available SD cards:"
        lsblk -d -o NAME | grep -E '^sd[a-z]' | awk '{print "/dev/"$1}'
        return 1
    end
    sudo dd bs=4M status=progress oflag=sync if=$argv[1] of=$argv[2]
    sudo eject $argv[2]
end
