# arche on macOS

A small, self-contained slice of arche for macOS: the cross-platform CLI +
terminal tooling only. No Hyprland, dms, SDDM, pacman, NVIDIA, or systemd:
those layers stay Linux-only. What you get here is the "normal apps" shared
between both platforms, themed by the same engine.

> **Supported:** Apple Silicon (arm64) on a current macOS release only.
> Intel Macs and older macOS versions are not targeted: the installer and
> the `macos` profile exit early on non-arm64.

macOS is now a first-class **profile** (`profiles/macos/`) of the unified
arche core, not a separate bootstrap. The same `install.sh` and `bootstrap.sh`
that run on Arch detect macOS and run this profile.

## What it installs

- **Shell / terminal:** fish (+ atuin + fisher), starship, tmux, ghostty
  (native macOS terminal, tabs in the title bar, ⌥-as-Alt, background blur)
- **Editor:** neovim (LazyVim config)
- **CLI tools:** eza, bat, ripgrep, fd, fzf, zoxide, dust, btop, jq, yq,
  tealdeer, gum, lazygit, lazydocker, glow, aria2, fastfetch, gh, tree-sitter
- **Media:** mpv (with the stowed config)
- **Terminal font:** SF Mono (macOS built-in). Ghostty renders Nerd Font
  icons via its bundled symbol fallback, so nothing to install

Package list: the `macos=` tokens in the shared [`packages/*.reg`](../packages)
registry (every tool with a macOS provider) plus [`packages/macos.reg`](../packages/macos.reg)
for macOS-only tools (coreutils, gettext, bash, fnm, uv, duti, ghostty). Configs
come from the shared [`stow/`](../stow) packages. The `macos` profile links only
the portable ones: `fish nvim ghostty tmux mpv btop glow`.

## Usage

Install Homebrew first if you don't have it:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Quick (one-liner):** the unified installer detects macOS, clones to `~/arche`,
and runs the `macos` profile. `bash <(...)` keeps your terminal attached so sudo /
brew prompts work (a plain `curl | bash` would break them):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/install.sh)
```

Override the clone location with `ARCHE_DIR=/path bash <(curl …)`.

**Manual:** if you've already cloned the repo:

```sh
cd /path/to/arche
bash bootstrap.sh            # auto-selects the macos profile on Apple Silicon
# or force it: bash bootstrap.sh --profile macos
```

> The clone is permanent: stow symlinks (`~/.config/*`) point back into it,
> so keep it where it is (don't delete or move it after install).

The profile is idempotent: safe to re-run. Its steps (see
[`profiles/macos/profile.sh`](../profiles/macos/profile.sh)):

1. **check:** confirm macOS Apple Silicon with Homebrew present.
2. **packages:** `registry_install macos` installs every tool with a `macos=`
   token from the registry (already-installed packages are skipped, so re-runs
   are fast).
3. **configs:** stows the cross-platform config packages to `$HOME`, and points
   the mpv `platform.conf` selector at the macOS variant.
4. **shell:** sets fish as the login shell and installs fisher plugins.
5. **theme:** renders the active theme via `theming/engine.sh apply`, the same
   envsubst engine the Linux path uses. ghostty / tmux / btop / starship / fish
   configs reference these generated files, so this is what makes them work.
6. **player:** runs [`macos/mpv-default.sh`](./mpv-default.sh) to make mpv the
   default player for common video files (via `duti`).

## Re-theming

```sh
bash theming/engine.sh switch frost      # or ember
bash theming/engine.sh apply ghostty fish starship tmux btop glow mpv
```

## Notes / caveats

- Some `stow/fish/conf.d` snippets target Linux paths (`android.fish`,
  `path.fish` sets `ARCHE=/opt/arche`). They're guarded with `test -d` /
  `command -q`, so they no-op harmlessly on macOS, trim to taste.
- `gettext` (envsubst) and `coreutils` are keg-only; the bootstrap puts them
  on PATH for the render step automatically.
