# Theme engine — render templates, switch themes, list available themes.
# Recipes are prefixed `theme-` so `just --list` groups them visually under
# one namespace; Just has no native subcommands, this is the idiomatic
# substitute. Engine lives at theming/engine.sh.

# Apply current theme — render templates, emit theme.json, run reload hooks
[group: 'theme']
theme-apply:
    bash {{dotfiles}}/theming/engine.sh apply

# Switch to a different theme (e.g. just theme-switch ember)
[group: 'theme']
theme-switch name:
    bash {{dotfiles}}/theming/engine.sh switch {{name}}

# List available themes (active marked with *)
[group: 'theme']
theme-list:
    bash {{dotfiles}}/theming/engine.sh list
