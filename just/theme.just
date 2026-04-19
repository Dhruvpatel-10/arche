# Theme engine — render templates and switch themes.

# Apply theme (render templates + reload services)
[group: 'theme']
theme target="apply":
    bash {{dotfiles}}/scripts/theme.sh {{target}}

# Switch to a different theme (e.g. just switch ember)
[group: 'theme']
switch name:
    bash {{dotfiles}}/scripts/theme.sh switch {{name}}

# List available themes
[group: 'theme']
themes:
    bash {{dotfiles}}/scripts/theme.sh list

# Render all templates without reloading services
[group: 'theme']
render:
    bash {{dotfiles}}/scripts/theme.sh apply

# Re-render + reload all running services (rapid iteration)
[group: 'theme']
reload:
    bash {{dotfiles}}/scripts/theme.sh apply
