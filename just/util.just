# Utility targets — stow/system symlink management, backups, previews.

# Re-stow a single package (e.g. just restow fish)
[group: 'utilities']
restow pkg:
    stow -d {{dotfiles}}/stow -t $HOME --restow --no-folding {{pkg}}

# Re-symlink all system files (/etc/, /usr/local/bin/arche/, profile.d/)
[group: 'utilities']
relink:
    bash -c 'source {{dotfiles}}/scripts/lib.sh && link_system_all'

# Snapshot ~/.config before destructive operations
[group: 'utilities']
backup:
    #!/usr/bin/env bash
    stamp=$(date +%Y%m%d-%H%M%S)
    dest="$HOME/.config-backup/$stamp"
    mkdir -p "$dest"
    rsync -a --exclude='chromium' --exclude='Code' --exclude='discord' \
        --exclude='.cache' --exclude='node_modules' \
        "$HOME/.config/" "$dest/"
    echo "Backed up to $dest ($(du -sh "$dest" | cut -f1))"

# Preview the custom SDDM theme in a windowed test mode (no actual login)
[group: 'utilities']
sddm-preview:
    sddm-greeter-qt6 --test-mode --theme {{dotfiles}}/system/usr/share/sddm/themes/arche

# Re-render /etc/systemd/resolved.conf from the template + secrets.sh,
# restart systemd-resolved, flush caches. Same flow bootstrap uses.
[group: 'utilities']
dns:
    bash {{dotfiles}}/scripts/dns.sh
