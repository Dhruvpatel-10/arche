# arche on macOS

A small, self-contained slice of arche for macOS — the cross-platform CLI +
terminal tooling only. No Hyprland, dms, SDDM, pacman, NVIDIA, or systemd:
those layers stay Linux-only. What you get here is the "normal apps" shared
between both platforms, themed by the same engine.

> **Supported:** Apple Silicon (arm64) on a current macOS release only.
> Intel Macs and older macOS versions are not targeted — the bootstrap
> exits early on non-arm64.

## What it installs

- **Shell / terminal:** fish (+ atuin + fisher), starship, tmux, ghostty
  (native macOS terminal — tabs in the title bar, ⌥-as-Alt, background blur)
- **Editor:** neovim (LazyVim config)
- **CLI tools:** eza, bat, ripgrep, fd, fzf, zoxide, dust, btop, jq, yq,
  tealdeer, gum, lazygit, lazydocker, glow, aria2, fastfetch, gh, tree-sitter
- **Media:** mpv (with the stowed config)
- **Fonts:** JetBrainsMono Nerd Font Mono (the family the active themes use)

Package list: [`Brewfile`](./Brewfile). Configs come from the shared
[`stow/`](../stow) packages — only the portable ones are linked:
`fish nvim ghostty tmux mpv btop glow`.

## Usage

Install Homebrew first if you don't have it:

```sh
/bin/bash -c "$(curl -fsSL https://raw.githubusercontent.com/Homebrew/install/HEAD/install.sh)"
```

**Quick (one-liner)** — clones to `~/arche` and bootstraps. `bash <(...)`
keeps your terminal attached so sudo / brew prompts work (a plain
`curl | bash` would break them):

```sh
bash <(curl -fsSL https://raw.githubusercontent.com/Dhruvpatel-10/arche/main/macos/install.sh)
```

Override the clone location with `ARCHE_DIR=/path bash <(curl …)`.

**Manual** — if you've already cloned the repo:

```sh
cd /path/to/arche
bash macos/bootstrap.sh
```

> The clone is permanent — stow symlinks (`~/.config/*`) point back into it,
> so keep it where it is (don't delete or move it after install).

The script is idempotent — safe to re-run. It:

1. `brew bundle` installs everything in the Brewfile.
2. Stows the cross-platform config packages to `$HOME`.
3. Sets fish as the login shell and installs fisher plugins.
4. Renders the active theme via `theming/engine.sh apply` — the same
   envsubst engine the Linux path uses. ghostty / tmux / btop / starship / fish
   configs reference these generated files, so this is what makes them work.

## Re-theming

```sh
bash theming/engine.sh switch frost      # or ember
bash theming/engine.sh apply ghostty fish starship tmux btop glow mpv
```

## Notes / caveats

- Some `stow/fish/conf.d` snippets target Linux paths (`android.fish`,
  `path.fish` sets `ARCHE=/opt/arche`). They're guarded with `test -d` /
  `command -q`, so they no-op harmlessly on macOS — trim to taste.
- `gettext` (envsubst) and `coreutils` are keg-only; the bootstrap puts them
  on PATH for the render step automatically.
