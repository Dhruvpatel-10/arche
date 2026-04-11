## Secret Files — DO NOT READ

The following files contain API keys and secrets. Never read, display, log, or include their contents in any output:

- `secrets.sh` — all secrets (NextDNS ID, etc.) — gitignored
- `stow/bash/.bash/local.bash` — live bash secrets (gitignored)
- `stow/bash/.bash/local.bash.template` — template with placeholder values only
- `~/.bash/local.bash` — rendered bash secrets on live system
- Any file matching `*.key`, `*.pem`, `*.env`, `credentials.*`, `*.secret`

### Rules

1. **Never read** these files with Read, cat, head, tail, grep, or any tool
2. **Never search** inside these files (no grep/ripgrep into them)
3. If a user asks to debug bash config, skip `local.bash` — tell them to check it manually
4. If editing `.bashrc`, do not modify the line that sources `~/.bash/local.bash`
5. When creating new secret entries, only edit `local.bash.template` with `YOUR_KEY_HERE` placeholders — never real values
6. The `.gitignore` blocks `local.bash` from commits. Never modify this protection.
7. Do NOT rely on leading-space to hide a command from bash history — `bash-preexec` rewrites `HISTCONTROL=ignorespace` to `ignoredups` (see D016). Always put secrets in files, never in command lines.
