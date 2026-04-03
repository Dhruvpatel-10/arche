# Starship prompt — config rendered by theme.sh to ~/.config/starship/

if command -q starship
    set -gx STARSHIP_CONFIG "$HOME/.config/starship/starship.toml"
    starship init fish | source
end
