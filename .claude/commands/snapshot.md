---
argument-hint: "[description]"
disable-model-invocation: true
---

Take a btrfs snapshot before risky work.

Run: `snapper create --description "$ARGUMENTS"`

Then confirm: `snapper list | tail -5`

If no description provided, use "manual-snapshot-$(date +%Y%m%d-%H%M)".
