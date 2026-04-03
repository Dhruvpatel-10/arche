## Secret Files — DO NOT READ

The following files contain API keys and secrets. Never read, display, log, or include their contents in any output:

- `stow/fish/.config/fish/local.fish` — live secrets (gitignored)
- `stow/fish/.config/fish/local.fish.template` — template with placeholder values only
- `~/.config/fish/local.fish` — rendered secrets on live system
- Any file matching `*.key`, `*.pem`, `*.env`, `credentials.*`, `*.secret`

### Rules

1. **Never read** these files with Read, cat, head, tail, grep, or any tool
2. **Never search** inside these files (no grep/ripgrep into them)
3. If a user asks to debug fish config, skip local.fish — tell them to check it manually
4. If editing `config.fish`, do not modify the `source $local_config` line
5. When creating new secret entries, only edit `local.fish.template` with `YOUR_KEY_HERE` placeholders — never real values
6. The `.gitignore` blocks `local.fish` from commits. Never modify this protection.
