# Justfile — day-to-day interface for arche management.
# Module sources live under just/; all targets remain at the top level
# (no namespace prefix). Run `just` or `just --list` to see every target,
# organized by group.

dotfiles := justfile_directory()

import 'just/user.just'       # multi-user-init, secondary-user, ssh-setup, tpm-enroll
import 'just/scripts.just'    # preflight, base, ..., boot, panel-restart
import 'just/theme.just'      # theme, switch, themes, render, reload
import 'just/test.just'       # test, test-stow, gate, test-all
import 'just/util.just'       # restow, relink, backup, sddm-preview

# ─── Bootstrap ───

# Run full bootstrap (all scripts in order)
[group: 'bootstrap']
install:
    bash {{dotfiles}}/bootstrap.sh
