---
argument-hint: "[type(scope): message]"
---

Commit staged changes in the arche repo following project conventions.

## Steps

1. **Show what's staged**
   `git -C $HOME/arche diff --staged --stat`
   If nothing staged, report and stop.

2. **Secrets check — ABORT if triggered**
   `git -C $HOME/arche diff --staged -- . ':!*.md' | grep -iE "(api_key|apikey|password|secret|token|auth_token)\s*=" && echo "ABORT: possible secret in staged diff"`
   Refuse to commit if any match is found. Tell the user which file triggered it.

3. **Validate no forbidden files are staged**
   - `zsh/.config/zsh/core/envs.zsh` — never commit this file
   - `zsh/.config/zsh/local.zsh` — never commit this file
   - `*/.zcompdump` — generated, should not be committed
   - `*/watch-later/*` — should not be committed

4. **Determine commit message**
   If `$ARGUMENTS` is provided, use it as-is.
   Otherwise infer from the staged diff — follow conventional commits:
   - `feat:` — new config, new tool integration, new stow package
   - `fix:` — bug in script, broken symlink, incorrect path
   - `chore:` — cleanup, removing junk, updating comments
   - `docs:` — README, documentation only
   - `refactor:` — restructuring without behavior change
   Format: `type(scope): short description` — lowercase, no period, ≤72 chars.
   Scope is optional — use the stow package name when relevant (e.g. `zsh`, `mpv`, `hypr`).

5. **Commit**
   `git -C $HOME/arche commit -m "<message>"`

6. **Confirm**
   `git -C $HOME/arche log --oneline -3`
