# arche

Personal dotfiles for Arch Linux and macOS. Clone the repo, run one command, and
get a fully configured system: a Hyprland desktop on Arch, or the shared
command-line toolkit on macOS.

One engine runs everywhere. Platform differences live behind adapters, and the
concrete choices for each machine live in profiles. The same `bootstrap.sh`
detects your OS and runs the right one.

## Quick start

### Arch Linux (full desktop)

A base Arch install is enough. arche installs the compositor, the greeter, and
the Wayland stack itself.

```bash
curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/install.sh | bash
```

Or manually:

```bash
sudo install -d -m 2775 -o $USER -g users /opt/arche
git clone git@github.com:Dhruvpatel-10/arche.git /opt/arche
ln -s /opt/arche ~/arche
cd /opt/arche
bash bootstrap.sh
```

### macOS (Apple Silicon)

A minimal, cross-platform slice: fish, Neovim, Ghostty, tmux, starship, and the
CLI tools, themed by the same engine. No desktop layer. Install Homebrew, then:

```bash
bash <(curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/install.sh)
```

See [macos/README.md](./macos/README.md) for details.

### Headless server (Arch)

A lightweight command-line profile with no desktop, graphics, or audio:

```bash
bash bootstrap.sh --profile server
```

## How it works

arche is one shared core, plus per-platform adapters, plus profiles.

- `core/` is the platform-agnostic engine: shared shell primitives, the package
  registry parser, the step runner, and the doctor and clean commands.
- `core/adapters/<platform>.sh` is the seam for platform differences: the package
  backend (pacman and paru, or Homebrew), services, and system file linking.
- `profiles/<name>/` holds the ordered steps and the stow and theme sets for one
  target. `bootstrap.sh` picks the profile from `uname`, or you can force it with
  `--profile`.

| Profile | Platform | What it sets up |
|---|---|---|
| `linux-hyprland` | Arch Linux | Full desktop: NVIDIA, Hyprland, dms, encrypted boot, audio, apps |
| `macos` | macOS (Apple Silicon) | Shared CLI tools, Ghostty, editor, shell, and theme (Homebrew) |
| `server` | Headless Arch | CLI tools, shell, and prompt only |

## bootstrap.sh

```bash
bash bootstrap.sh                 # install, asking before each step
bash bootstrap.sh --yes           # install without asking
bash bootstrap.sh --profile NAME  # force a profile
bash bootstrap.sh --only ID       # run a single step
bash bootstrap.sh doctor          # health-check the setup
bash bootstrap.sh doctor --repair # fix the safe problems it finds
bash bootstrap.sh clean           # unlink configs (add --system or --packages for more)
```

## Packages

Every package is declared once in `packages/*.reg`, a small text format that maps
a logical name to a per-platform provider:

```
tool mpv     arch=pacman:mpv         macos=brew:mpv
tool gh      arch=pacman:github-cli  macos=brew:gh
tool ghostty arch=pacman:ghostty     macos=cask:ghostty
```

Steps install through `registry_install <platform> <group>`, never by calling
pacman or brew directly. This keeps a provider from drifting between platforms,
and a lint check guards the format on every run.

## Three-layer config split

Every config file belongs to exactly one layer:

- Templates (`theming/templates/`): anything with colors, fonts, or sizes. The
  engine renders these with envsubst.
- Stow (`stow/`): behavior only, such as keybinds, module lists, and rules.
  Symlinked as-is with GNU Stow.
- Generated (`~/.config/`): the rendered output. Never committed.

## Theme

Ember is the default: warm amber (`#c9943e`) on deep charcoal (`#13151c`). Frost
is an alternate teal theme.

Theme values live in `theming/themes/<name>.sh`, and per-app output specs live in
`theming/templates/<app>/`. `theming/themes/schema.sh` is the single source of
truth for every variable.

```bash
just theme-apply         # render templates and reload services
just theme-switch frost  # switch to another theme
just theme-list          # list available themes
```

## Structure

```
arche/
├── bootstrap.sh     # single entry point: install, doctor, clean
├── install.sh       # curl one-liner that clones and runs bootstrap
├── Justfile         # day-to-day commands
├── core/            # platform-agnostic engine and per-OS adapters
├── profiles/        # ordered steps and stow/theme sets per platform
├── packages/        # package registry (*.reg), one source of truth
├── theming/         # themes, templates, and the render engine
├── stow/            # behavior configs, symlinked with GNU Stow
├── system/          # /etc and /usr/local files (Arch)
├── tools/bin/       # prebuilt arche binaries
├── macos/           # macOS default-player helper and notes
├── tests/           # lint, stow, and integration checks
└── docs/            # architecture, decisions, and status
```

## Desktop stack (Arch)

| Layer | Tool |
|---|---|
| OS | Arch Linux (btrfs, systemd-boot, UKIs) |
| Pre-boot | Plymouth with the arche theme, TPM2 and PIN unlock |
| Compositor | Hyprland (Wayland) via uwsm |
| Greeter | SDDM (default Breeze theme) |
| Shell UI | DankMaterialShell: bar, control center, notifications, OSD, launcher, clipboard, power menu |
| Lock and idle | hyprlock and hypridle |
| Wallpaper | awww |
| Screenshots | grim, slurp, satty |
| Terminal | Ghostty |
| Shell | fish, atuin, fisher, starship |
| Editor | Neovim (LazyVim) |
| GPU | NVIDIA open-dkms |
| Audio | PipeWire full stack |

## Multi-user setup

The Arch install is built for one machine with several accounts, for example
personal and work. System state (packages and `/etc` configs) is installed once
by the first user. A second user only needs to deploy their own dotfiles:

```bash
sudo useradd -m -G wheel,users <work-username>
sudo passwd <work-username>
su - <work-username>
cd /opt/arche
just secondary-user
```

`just secondary-user` runs only the stow and per-user shell setup. Runtime
managers (fnm, rustup, bun) are left out on purpose, since work and personal
projects usually need different versions. Each user opts in with `just runtimes`.

## Security (Arch)

- UFW firewall (deny incoming, allow SSH and Tailscale)
- SSH key-only auth (ed25519, no passwords, no root login)
- DNS over TLS (NextDNS primary, Cloudflare fallback, DNSSEC)
- Kernel hardening (SYN cookies, ptrace and BPF restrictions, symlink protection)
- MAC address randomization
- Firejail for untrusted apps
- fail2ban for SSH
- btrfs snapshots on every pacman transaction

## Hardware

Built for the Lenovo Legion Pro 5 16ARX8 (AMD Ryzen and RTX 4060 Laptop). The
`arche-legion` TUI manages battery conservation, fan profiles, the camera kill
switch, and USB charging.

## Requirements

- Arch Linux (fresh base install), or macOS on Apple Silicon
- git, and sudo on Arch
- An internet connection

## License

Personal dotfiles. Use what you find useful.
