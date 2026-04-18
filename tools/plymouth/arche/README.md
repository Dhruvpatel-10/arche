# plymouth-arche

Custom Plymouth theme for arche. Subtle lavender on near-black, wordmark-first.

## Contents

- `arche.plymouth` — Plymouth theme descriptor (ModuleName=script).
- `arche.script` — Plymouth script-module logic (password widget, error flash).
- `title.png`, `rule.png`, `dot.png`, `dot_error.png` — PNG assets.
  **Not committed.** Rendered at install time by `scripts/12-boot.sh` via
  ImageMagick from the palette defined in the script. Keeps the repo small
  and makes `just boot` self-contained.

## How it renders

Each PNG is drawn by ImageMagick with transparent background:
- `title.png` — "ARCHE" in IBM Plex Sans Medium, ~72pt, letter-spacing 8, light lavender (`#c8bbdd`). No drop shadow, no fill gradient — flat.
- `rule.png` — 1px × 220px, muted lavender (`#a08dc4`), ~40% alpha.
- `dot.png` — 10×10 filled circle, muted lavender (`#a08dc4`).
- `dot_error.png` — same shape, dusty rose (`#b88a9a`).

The install script parameterises the wordmark text and colour so a different
user/fork can regenerate without editing ImageMagick commands by hand.

## Why pre-rendered PNGs

Plymouth *can* use `Image.Text()` with Pango at runtime, but that depends on
fontconfig + freetype + pango all working inside the initramfs with the right
font cache. Pre-rendering sidesteps the whole stack — Plymouth just blits a
PNG. Faster, deterministic, one less failure mode.

## Installed to

`/usr/share/plymouth/themes/arche/` — `scripts/12-boot.sh` copies the `.script`
and `.plymouth` files there and generates the PNGs in place.
`plymouth-set-default-theme arche` makes it active; `mkinitcpio -P` bakes it
into the UKI.
