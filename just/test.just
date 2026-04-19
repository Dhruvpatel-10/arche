# Test targets — lint, stow integrity, integration.

# Run lint checks (CI-safe, no root needed)
[group: 'test']
test:
    bash {{dotfiles}}/tests/run.sh lint

# Verify stow symlink integrity
[group: 'test']
test-stow:
    bash {{dotfiles}}/tests/run.sh stow

# Pre-install safety gate (blocks bootstrap on failure)
[group: 'test']
gate:
    bash {{dotfiles}}/tests/run.sh gate

# Run all tests (lint + stow + integration — needs live system)
[group: 'test']
test-all:
    bash {{dotfiles}}/tests/run.sh all
