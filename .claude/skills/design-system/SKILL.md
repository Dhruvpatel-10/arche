---
name: design-system
description: Arche design system — typography, color, iconography, and visual language for all components. Auto-load when designing UI, choosing icons, picking fonts, or making any visual decision.
user-invocable: false
---

# Arche Design System

The visual identity for stark's Arch Linux environment. Every component — terminal, bar, launcher, notifications, lock screen — speaks the same design language.

## Design Philosophy

**Ember aesthetic**: Warm, refined, industrial. Think whiskey bar meets command center.
Not cute. Not pastel. Not generic dark mode. Every pixel earns its place.

Principles:
1. **Warmth over cold** — amber/gold tones, warm grays, never blue-gray defaults
2. **Density with breathing room** — information-rich but never cramped
3. **Monospace-first** — terminal environment, mono is native; sans is accent
4. **Restrained motion** — transitions exist to orient, not to entertain
5. **Icon clarity** — every icon must be instantly readable at 10px

---

## Typography

### Font Stack

| Role | Font | Package | Fallback |
|------|-------|---------|----------|
| **Mono (primary)** | MesloLGS Nerd Font Mono | `ttf-meslo-nerd` | JetBrainsMono Nerd Font Mono |
| **Sans (UI accent)** | IBM Plex Sans | `ttf-ibm-plex` | iA Writer Quattro |
| **Display (headers)** | Bricolage Grotesque | Google Fonts / manual | IBM Plex Sans Medium |

### Why These Fonts

**MesloLGS Nerd Font Mono** — Menlo lineage. Apple's terminal DNA — clean, tight, premium at small sizes. Full Nerd Font glyph coverage for icons. Slightly rounder than JetBrains Mono which softens the industrial Ember aesthetic just enough. Used everywhere: terminal, bar, prompt, notification titles, data labels.

**IBM Plex Sans** — Geometric but human. Has the precision of a monospace sensibility but reads as refined UI text. Pairs well with Meslo because both share that "engineered, not decorative" DNA. Used in: notification body text, launcher input, GTK apps.

**Bricolage Grotesque** — The personality font. Quirky serifs on a grotesque frame — unexpected and characterful. Reserved for high-impact moments: OSD percentage, lock screen clock. Never for body text.

### Size Scale

| Token | Size | Where |
|-------|------|-------|
| `FONT_SIZE_BAR` | 10pt | Waybar modules, clock |
| `FONT_SIZE_NORMAL` | 10pt | Notifications, dialogs, GTK |
| `FONT_SIZE_SMALL` | 8pt | Tooltips, secondary text |
| Terminal | 9pt | Kitty (set in kitty.conf, not theme) |

### Typography Rules

- Never use Inter, Roboto, or Arial — they signal "default, unconfigured"
- Mono for data, sans for prose. If unsure, use mono.
- Bar text: always mono, always 10pt, always regular weight
- Notification titles: mono bold. Notification body: sans regular.
- Never go below 8pt — unreadable on HiDPI at 1.5-1.6x scale

---

## Color Palette — Ember

The Ember palette is warm amber on deep charcoal. No purple tint, no blue-gray.

### Core Colors

| Token | Hex | Role | Usage |
|-------|-----|------|-------|
| `COLOR_BG` | `#13151c` | Base | Window backgrounds, bar background |
| `COLOR_BG_ALT` | `#0e1016` | Mantle | Darker panels, dropdowns |
| `COLOR_BG_SURFACE` | `#1d2029` | Surface0 | Raised elements, cards |
| `COLOR_FG` | `#cdc8bc` | Text | Primary text everywhere |
| `COLOR_FG_MUTED` | `#817c72` | Subtext0 | Secondary text, placeholders |
| `COLOR_ACCENT` | `#c9943e` | Amber gold | THE signature. Active states, focus, highlights |
| `COLOR_ACCENT_ALT` | `#6a9fb5` | Steel blue | Cool complement. Links, info states |
| `COLOR_SUCCESS` | `#7ab87f` | Sage green | Connected, active, healthy |
| `COLOR_WARN` | `#d4a843` | Gold | Warnings, attention needed |
| `COLOR_CRITICAL` | `#c45c5c` | Brick red | Errors, critical battery, disconnected |
| `COLOR_BORDER` | `#282c38` | Subtle | Borders, dividers, separators |

### Extended Palette

| Token | Hex | Role |
|-------|-----|------|
| `COLOR_TEAL` | `#6bb5a2` | Docker, containers |
| `COLOR_PINK` | `#c47a9e` | Git, branches |
| `COLOR_MAUVE` | `#a687c4` | Language runtimes |
| `COLOR_PEACH` | `#cf8e5e` | Warm accent variant |
| `COLOR_SKY` | `#6aadcf` | Network, cloud |
| `COLOR_OVERLAY0` | `#525866` | Disabled, inactive |
| `COLOR_OVERLAY1` | `#656b79` | Hover backgrounds |
| `COLOR_SUBTEXT1` | `#a8a299` | Muted text variant |
| `COLOR_CRUST` | `#0a0b10` | Deepest black |
| `COLOR_SURFACE1` | `#282c38` | Elevated surface |
| `COLOR_SURFACE2` | `#353a48` | Highest surface |

### Color Usage Rules

- **Active/focused** → `COLOR_ACCENT` (amber gold) — always
- **Hover** → `COLOR_OVERLAY1` background or `COLOR_ACCENT` at 20% opacity
- **Inactive/disabled** → `COLOR_OVERLAY0` or `COLOR_FG_MUTED`
- **Borders** → `COLOR_BORDER` at full opacity or `COLOR_ACCENT` at 35% for active
- **Backgrounds** → Layer from `CRUST` (deepest) → `BG_ALT` → `BG` → `BG_SURFACE` → `SURFACE1` → `SURFACE2`
- **Semantic colors** → SUCCESS (green), WARN (gold), CRITICAL (red) — never use these decoratively
- **Never** use pure white (`#ffffff`) or pure black (`#000000`)

---

## Iconography — Nerd Font Material Design

All icons come from **Nerd Fonts** (Material Design Icons subset). These render at mono width inside MesloLGS Nerd Font Mono, so they align perfectly with text.

### Icon Vocabulary

Use these exact icons for consistency across waybar, notifications, starship, and scripts.

#### System Status

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| WiFi connected | 󰤨 | U+F0928 | `nf-md-wifi` |
| WiFi disconnected | 󰤭 | U+F092D | `nf-md-wifi_off` |
| Ethernet | 󰈀 | U+F0200 | `nf-md-ethernet` |
| Bluetooth on | 󰂯 | U+F00AF | `nf-md-bluetooth` |
| Bluetooth off | 󰂲 | U+F00B2 | `nf-md-bluetooth_off` |
| Bluetooth connected | 󰂱 | U+F00B1 | `nf-md-bluetooth_connect` |
| Volume high | 󰕾 | U+F057E | `nf-md-volume_high` |
| Volume medium | 󰖀 | U+F0580 | `nf-md-volume_medium` |
| Volume low | 󰕿 | U+F057F | `nf-md-volume_low` |
| Volume muted | 󰝟 | U+F075F | `nf-md-volume_off` |
| Headphones | 󰋋 | U+F02CB | `nf-md-headphones` |
| Microphone | 󰍬 | U+F036C | `nf-md-microphone` |
| Microphone muted | 󰍭 | U+F036D | `nf-md-microphone_off` |

#### Battery

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| Battery full | 󰁹 | U+F0079 | `nf-md-battery` |
| Battery 80% | 󰂀 | U+F0080 | `nf-md-battery_80` |
| Battery 60% | 󰁾 | U+F007E | `nf-md-battery_60` |
| Battery 40% | 󰁻 | U+F007B | `nf-md-battery_40` |
| Battery 20% | 󰁺 | U+F007A | `nf-md-battery_20` |
| Battery charging | 󰂄 | U+F0084 | `nf-md-battery_charging` |
| Battery plugged | 󰚥 | U+F06A5 | `nf-md-power_plug` |

#### Workspace & Navigation

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| Workspace active | ● | U+25CF | Unicode filled circle |
| Workspace inactive | ○ | U+25CB | Unicode empty circle |
| Workspace filled | \uf111 | U+F111 | `nf-fa-circle` (waybar alt) |
| Workspace empty | \uf10c | U+F10C | `nf-fa-circle_o` (waybar alt) |
| Lock | 󰌾 | U+F033E | `nf-md-lock` |
| Unlock | 󰍁 | U+F0341 | `nf-md-lock_open` |

#### Notifications

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| Bell | 󰂚 | U+F009A | `nf-md-bell` |
| Bell active | 󰂜 | U+F009C | `nf-md-bell_ring` |
| Bell muted | 󰂛 | U+F009B | `nf-md-bell_off` |
| DND | 󰪑 | U+F0A91 | `nf-md-bell_cancel` |

#### Applications & Tools

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| Terminal | 󰆍 | U+F018D | `nf-md-console` |
| Browser | 󰊯 | U+F02AF | `nf-md-earth` |
| File manager | 󰉋 | U+F024B | `nf-md-folder` |
| Editor/code | 󰅩 | U+F0169 | `nf-md-code_tags` |
| Settings | 󰒓 | U+F0493 | `nf-md-cog` |
| Search | 󰍉 | U+F0349 | `nf-md-magnify` |
| Docker | 󰡨 | U+F0868 | `nf-md-docker` |
| Git branch | 󰘬 | U+F062C | `nf-md-source_branch` |
| Package | 󰏗 | U+F03D7 | `nf-md-package` |
| Download | 󰇚 | U+F01DA | `nf-md-download` |
| Upload | 󰕒 | U+F0552 | `nf-md-upload` |
| Refresh | 󰑐 | U+F0450 | `nf-md-refresh` |
| Trash | 󰩺 | U+F0A7A | `nf-md-delete` |
| Clipboard | 󰅌 | U+F014C | `nf-md-clipboard_text` |

#### Hardware & Display

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| Monitor | 󰍹 | U+F0379 | `nf-md-monitor` |
| Keyboard | 󰌌 | U+F030C | `nf-md-keyboard` |
| GPU | 󰢮 | U+F08AE | `nf-md-expansion_card` |
| CPU | 󰻠 | U+F0EE0 | `nf-md-cpu_64_bit` |
| Memory | 󰍛 | U+F035B | `nf-md-memory` |
| Disk | 󰋊 | U+F02CA | `nf-md-harddisk` |
| Brightness | 󰃟 | U+F00DF | `nf-md-brightness_6` |
| Night light | 󰖔 | U+F0594 | `nf-md-weather_night` |
| Camera | 󰄀 | U+F0100 | `nf-md-camera` |

#### Weather & Time

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| Clock | 󰥔 | U+F0954 | `nf-md-clock_outline` |
| Calendar | 󰃭 | U+F00ED | `nf-md-calendar` |
| Sun | 󰖙 | U+F0599 | `nf-md-weather_sunny` |
| Moon | 󰖔 | U+F0594 | `nf-md-weather_night` |
| Cloud | 󰖐 | U+F0590 | `nf-md-weather_cloudy` |
| Temperature | 󰔏 | U+F050F | `nf-md-thermometer` |

#### Prompt & Shell (Starship)

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| Git branch |  | U+E725 | `nf-dev-git_branch` |
| Node.js |  | U+E718 | `nf-dev-nodejs_small` |
| Python |  | U+E73C | `nf-dev-python` |
| Rust |  | U+E7A8 | `nf-dev-rust` |
| Go | 󰟓 | U+F07D3 | `nf-md-language_go` |
| Docker | 󰡨 | U+F0868 | `nf-md-docker` |
| Read-only | 󰌾 | U+F033E | `nf-md-lock` |
| Prompt success | ❯ | U+276F | Unicode (not Nerd Font) |
| Prompt error | ❯ | U+276F | Same glyph, red color |

#### Media

| Concept | Icon | Codepoint | Notes |
|---------|------|-----------|-------|
| Play | 󰐊 | U+F040A | `nf-md-play` |
| Pause | 󰏤 | U+F03E4 | `nf-md-pause` |
| Next | 󰒭 | U+F04AD | `nf-md-skip_next` |
| Previous | 󰒮 | U+F04AE | `nf-md-skip_previous` |
| Music | 󰎆 | U+F0386 | `nf-md-music` |
| Image | 󰋩 | U+F02E9 | `nf-md-image` |
| Wallpaper | 󰸉 | U+F0E09 | `nf-md-wallpaper` |

### Icon Rules

1. **One icon per concept** — pick from this table, don't invent alternatives
2. **Material Design only** — no mixing Font Awesome, Devicons, and MD in the same context (exception: Starship uses Devicons for language logos, which is fine)
3. **Test at target size** — every icon must be legible at the component's font size
4. **Space after icon** — always one space between icon and label text: `󰤨 WiFi`
5. **No icon + icon** — don't stack two icons adjacent without text between them
6. **Semantic only** — icons convey meaning, not decoration. No purely ornamental icons.

---

## Layout & Spacing

### Spacing Scale

| Token | Value | Usage |
|-------|-------|-------|
| `GAP` | 5px | Window gaps (Hyprland), module gaps (Waybar) |
| `RADIUS` | 10px | Corner radius on all rounded elements |
| `BORDER_SIZE` | 1px | Window borders, bar borders |
| `BAR_HEIGHT` | 38px | Waybar height |
| `NOTIF_WIDTH` | 380px | Notification card width |
| `NOTIF_MARGIN` | 10px | Notification offset from screen edge |

### Spacing Rules

- **Bar modules**: 12-16px horizontal padding, 4-6px vertical
- **Notification cards**: 16px internal padding
- **Tooltips**: 8px padding, smaller font
- **Popup TUIs**: 900x620px floating window (generous for terminal UIs)
- **Never less than 4px** padding on interactive elements

---

## Component Design Patterns

### Waybar
- Full-width dark bar, top of screen
- Workspaces left (dot indicators), clock center, status right
- Pills/segments with subtle background on hover
- Active workspace: amber dot + text glow
- Status icons change color semantically (green=connected, red=critical)

### Notifications (SwayNC)
- Top-right corner, 380px wide
- Cards float with subtle shadow and border
- Title: mono bold, body: sans regular
- Actions as pill buttons
- Critical notifications: red left border accent
- DND toggle in control center header

### Lock Screen (Hyprlock)
- Minimal: time + date centered, password field below
- Background: current wallpaper with heavy blur (3 passes)
- Password field: subtle border, amber accent on input
- No decorative elements — information only

### Launcher (Walker)
- Centered floating card with backdrop blur
- Large search input (20px), minimal chrome
- Results list with icon + name + description
- Selected item: subtle amber background highlight
- Footer with keybind hints (muted text)

### Terminal (Kitty)
- 9pt mono, 14px padding
- Tab bar: bottom, powerline style
- Active tab: amber text, inactive: muted
- Block cursor, no blink
- ANSI colors mapped to Ember palette

---

## GTK & System Theming

### Required Packages

| Package | Source | Purpose |
|---------|--------|---------|
| `ttf-ibm-plex` | pacman | Sans font for UI |
| `adw-gtk-theme` | AUR | GTK3/4 dark theme base |
| `bibata-cursor-theme` | AUR | Modern cursor theme |
| `papirus-icon-theme` | pacman | Clean icon theme (folders, apps) |

### GTK Settings

GTK should follow the Ember dark palette. Use `adw-gtk-theme` as the base with overrides via `gtk.css` for accent color. Set cursor theme to Bibata Modern Classic (dark with amber accent if available).

### Icon Theme

Papirus-Dark for application icons (file manager, settings, etc.). Pairs well with the Material Design Nerd Font icons used in the bar — both are geometric, clean, and consistent in weight.

---

## Adding New Components

When designing visuals for a new component:

1. **Check the icon table first** — reuse existing icons, don't invent new ones
2. **Use theme variables** — never hardcode hex colors
3. **Follow the font stack** — mono for data/labels, sans for body text only
4. **Match the spacing scale** — use existing tokens, don't introduce new sizes
5. **Test on both monitors** — 2.8K laptop (1.6x) and 4K external (1.5x)
6. **Respect the layer split** — colors in templates, behavior in stow

---

## Anti-Patterns

- **Purple gradients** — not in the Ember palette, never introduce them
- **Rounded everything** — 10px radius max, not pill-shaped (exception: workspace dots)
- **Transparency abuse** — subtle alpha for overlays, never fully transparent backgrounds
- **Icon salad** — more than 3 icons in a row without text is unreadable
- **Animated icons** — no spinning, pulsing, or bouncing icons
- **Shadows on dark** — very subtle only (0 2px 8px rgba(0,0,0,0.3)), never harsh
