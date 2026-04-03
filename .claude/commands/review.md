---
disable-model-invocation: false
---

Review the current state of the arche repo before committing. Catch issues early.

## Steps

1. **Staged changes**
   `git -C $HOME/arche diff --staged`
   Summarize what's changing and why.

2. **Unstaged changes**
   `git -C $HOME/arche diff`
   Note anything relevant that isn't staged.

3. **Untracked files**
   `git -C $HOME/arche status --short`
   Flag any untracked files that look like they should (or should not) be in the repo.

4. **Run these checks against staged diff:**

   **Hardcoded paths** (should use $HOME):
   `git -C $HOME/arche diff --staged | grep -n '/home/stark'`

   **Potential secrets:**
   `git -C $HOME/arche diff --staged | grep -iE '(api_key|apikey|password|secret|token|auth)\s*='`

   **Fedora/Ubuntu residue:**
   `git -C $HOME/arche diff --staged | grep -iE '\b(apt|dnf|yum|brew)\b'`

   **Generated files accidentally staged:**
   `git -C $HOME/arche diff --staged --name-only | grep -E '\.zcompdump|watch-later|\.bak\.'`

   **Wrong shell in scripts:**
   `git -C $HOME/arche diff --staged | grep -E '^\\+#!/' | grep -v bash`

5. **Report**
   - List everything that looks good
   - List any issues found, with file and line
   - Give a clear verdict: **safe to commit** / **fix before committing**
