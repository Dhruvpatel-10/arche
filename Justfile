# Justfile — day-to-day interface for arche management.
# Module sources live under just/; all targets remain at the top level
# (no namespace prefix). Run `just` or `just --list` to see every target,
# organized by group.

dotfiles := justfile_directory()

import 'just/user.just'       # multi-user-init, secondary-user, ssh-setup, tpm-enroll
import 'just/scripts.just'    # preflight, base, ..., boot, panel-restart
import 'just/theme.just'      # theme-apply, theme-switch, theme-list
import 'just/test.just'       # test, test-stow, gate, test-all
import 'just/util.just'       # restow, relink, backup, sddm-preview

# ─── Bootstrap ───

# Run the full install (picks the right profile for this machine)
[group: 'bootstrap']
install:
    bash {{dotfiles}}/bootstrap.sh

# Run the full install without asking before each step
[group: 'bootstrap']
install-yes:
    bash {{dotfiles}}/bootstrap.sh --yes

# Check the setup is healthy (add repair=1 to fix: just doctor repair=1)
[group: 'bootstrap']
doctor repair='':
    bash {{dotfiles}}/bootstrap.sh doctor {{ if repair == '1' { '--repair' } else { '' } }}

# Unlink the config files arche created (safe, reversible)
[group: 'bootstrap']
clean:
    bash {{dotfiles}}/bootstrap.sh clean
