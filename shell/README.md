# arche-shell

Quickshell-based desktop shell for arche. Top bar + control center drawer styled to
the ember theme.

## What's here

- `shell.qml` — entry point, spawns bar per screen + control center.
- `Theme.qml` — singleton, ember palette + fonts + sizing.
- `State.qml` — singleton, cross-component UI state (drawer open, DND, caffeine).
- `components/` — visual units: `Bar`, `Pill`, `Icon`, `IconButton`, `ControlCenter`,
  `ToggleTile`, `SliderRow`, `StatCard`, `MediaCard`, `NotificationsList`,
  `NotificationItem`.
- `services/` — polled data sources: `Net` (nmcli), `Bt` (bluetoothctl),
  `Brightness` (brightnessctl), `SystemStats` (/proc + df).
- `qmldir` — registers Theme and State singletons.

## Run

```
quickshell -p ./shell.qml
```

Hot-reloads on save.

## Deps

- `quickshell` (official repo)
- `brightnessctl`
- `networkmanager` (nmcli)
- `bluez-utils` (bluetoothctl)
- A Wayland compositor with `wlr-layer-shell` (KDE/Plasma, Hyprland, Sway, Niri all fine)

## Icons

Uses Nerd Font glyphs (MesloLGS Nerd Font Mono) — already on the system.

## Folded into arche

Eventually: stow package at `stow/quickshell/.config/quickshell/` with theme values
rendered from `themes/active` via envsubst templates. For now, iterate standalone
here and symlink from `~/.config/quickshell/` → this repo.
