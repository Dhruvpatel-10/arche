# arche

Personal Arch Linux dotfiles. Clone, run, get a fully configured Hyprland desktop.

## Quick Start

```bash
curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/install.sh | bash
```

Or manually:

```bash
sudo install -d -m 2775 -o $USER -g users /opt/arche
git clone git@github.com:Dhruvpatel-10/arche.git /opt/arche
ln -s /opt/arche ~/arche                    # per-user compat symlink
cd /opt/arche
bash bootstrap.sh
```

The repo lives at `/opt/arche` so it can be shared between multiple human
users on the same machine (e.g. personal + work). Each user gets a per-user
`~/arche` → `/opt/arche` symlink for backward compat — anything that
hardcodes `~/arche` keeps working. See `docs/decisions.md` D014 for the full
reasoning. To add a second user later, see [Multi-user setup](#multi-user-setup).

## Multi-user setup

The repo is designed for one machine with multiple human accounts (personal +
work). System-level state (pacman packages, `/etc/` configs, the SDDM theme)
is installed once by the primary user; the secondary user only needs to
deploy stow dotfiles into their own `$HOME`.

```bash
# As root or via sudo: create the second user, add to wheel + users
sudo useradd -m -G wheel,users <work-username>
sudo passwd <work-username>

# As the second user: deploy dotfiles, no system scripts re-run
su - <work-username>
cd /opt/arche
just secondary-user
```

`just secondary-user` runs only the stow + per-user shell setup (06-shell).
Per-user runtime managers (fnm, rustup, bun) are deliberately not installed
automatically — work and personal projects usually need different toolchain
versions, so each user opts in via `just runtimes` if they want them.

## Stack

| Layer         | Tool                                      |
|---------------|-------------------------------------------|
| OS            | Arch Linux (btrfs, Limine)                |
| Compositor    | Hyprland via uwsm                        |
| Shell         | bash + ble.sh + bash-preexec + atuin + bash-completion + starship |
| Terminal      | Kitty                                     |
| Editor        | Neovim (LazyVim)                          |
| Bar           | Waybar                                    |
| Launcher      | Rofi (Wayland, combi mode)                |
| Notifications | Mako                                      |
| Theme         | Ember (warm amber on deep charcoal)       |
| GPU           | NVIDIA open-dkms                          |
| Audio         | PipeWire full stack                       |
| Login         | SDDM + SilentSDDM (vendored, glassmorphism) |

## Structure

```
arche/
├── bootstrap.sh        # orchestrator — runs all scripts in order
├── install.sh          # curl one-liner entry point
├── Justfile            # day-to-day interface
├── themes/             # color palettes, fonts, layout values
├── templates/          # visual configs rendered via envsubst
├── packages/           # declarative package lists (pacman + AUR)
├── scripts/            # numbered setup scripts + shared library
├── stow/               # behavior configs symlinked via GNU Stow
├── system/             # /etc/ configs (pacman, systemd, sysctl)
├── tools/bin/          # pre-built binaries (greeter, legion)
├── tests/              # lint, stow, and integration checks
└── docs/               # architecture, decisions, status
```

## Three-Layer Config Split

Every config belongs to exactly one layer:

- **Templates** `templates/` — colors, fonts, sizes. Rendered by theme engine.
- **Stow** `stow/` — behavior: keybinds, modules, rules. Symlinked as-is.
- **Generated** `~/.config/` — rendered output. Never committed.

## Theme

Ember ships as the default — warm amber (`#c9943e`) on deep charcoal (`#13151c`).

Themes are defined in `themes/` and rendered across 24 templates covering Hyprland, kitty, waybar, rofi, mako, GTK, Qt, and more.

```bash
just theme apply     # render templates + reload services
just switch <name>   # switch to a different theme
just themes          # list available themes
```

## Day-to-Day

```bash
just install         # full bootstrap
just theme apply     # re-render theme
just reload          # render + reload Hyprland
just test            # lint checks
just test-all        # lint + stow + integration
just restow bash     # re-stow a single package
```

## Security

- UFW firewall (deny incoming, SSH + Tailscale allowed)
- SSH key-only auth (ed25519, no passwords, no root)
- DNS-over-TLS (NextDNS primary, Cloudflare fallback, DNSSEC)
- Kernel hardening (SYN cookies, ptrace, BPF, symlink protection)
- USBGuard (block unknown devices)
- MAC address randomization
- Firejail for untrusted apps
- btrfs snapshots on every pacman transaction

## Hardware

Built for **Lenovo Legion Pro 5 16ARX8** (AMD Ryzen + RTX 4060 Laptop).
`arche-legion` TUI manages battery conservation, fan profiles, camera kill switch, and USB charging.

## Requirements

- Arch Linux (fresh install)
- `git` and `sudo`
- Internet connection

Everything else is installed by the bootstrap.

## License

Personal dotfiles. Use what you find useful.
