#!/usr/bin/env bash
# carapace — context-aware completions for 1000+ CLI tools.
# Vendored binary lives at tools/bin/carapace, symlinked to ~/.local/bin/arche/carapace.
# Bridge to native bash completions for anything carapace doesn't cover.

if command -v carapace &>/dev/null; then
    export CARAPACE_BRIDGES='bash,fish,zsh'
    source <(carapace _carapace bash)
fi
