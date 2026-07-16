# Arche Redesign — Shared Core + Platform Profiles

**Status:** implemented on the `redesign` branch (big-bang reorg per stark's call). Static-verified on macOS; Arch runtime validation pending before merge to main.
**Goal:** one linear, easy install that works across **Arch/Hyprland**, **macOS**, and a future **headless server**, with a single source of truth for packages and steps so drift like `cask mpv` can't recur.

**Delivered:** `core/` (lib + adapters + registry + runner + doctor + clean), `packages/*.reg` tool DSL, `profiles/{linux-hyprland,macos,server}/`, one `bootstrap.sh` (install/doctor/clean) and one `install.sh`, updated tests (registry lint) and Justfile. The scope below was the plan; §9 decisions were resolved as: big-bang, custom DSL, plus a `doctor` (repair) and `clean` command, all with plain-language output.

---

## 1. Why redesign

The repo already leans cross-platform (macOS reuses `lib.sh` + the theme engine), but the seams are informal, so problems accumulate:

- **Two divergent orchestrators.** `bootstrap.sh` (Linux) and `macos/bootstrap.sh` re-implement the same patterns — install loop, stow loop, login-shell setup, fisher — independently. Fisher setup and login-shell setup are near-verbatim copies.
- **`lib.sh` fuses portable and Linux-only code.** `log_*`, `stow_pkg`, `theme_render` are portable; `pkg_install`/`aur_install` (pacman/paru), `svc_enable` (systemctl), `link_system_*` (sudo/`/etc`), gsettings are Linux-only. macOS just avoids calling the Linux ones — a convention, not a boundary.
- **Two unrelated package formats with no shared truth:** `packages/*.sh` arrays vs `macos/Brewfile`. This is exactly how the `mpv` **cask** (deprecated, Gatekeeper-failing) drifted from the `mpv` **formula** the config actually needs.
- **Three hand-synced lists:** `bootstrap.sh`'s `scripts=()`, its `descriptions` map, and `just/scripts.just`.
- **`link_system_all` is a god-function:** it symlinks the *entire* `system/` tree in preflight, smearing feature ownership (NVIDIA, boot chain, SDDM, dms, security drop-ins all deployed up front) and forcing boot-chain crypttab seeding into step 00.
- **Imperative where declarative exists:** `03-gpu` edits `/etc/mkinitcpio.conf` with `sed` while `12-boot` uses a `.conf.d` drop-in.
- **Supply-chain inconsistency:** `shellcheck` is sha256-pinned, but `fnm`/`bun`/`fisher` are unpinned `curl | bash`.
- **Dead config still active:** `system/etc/*limine*` is symlinked though the bootloader is systemd-boot.

### Package-correctness findings (the "no more cask mpv" audit)

| Severity | Finding | Fix |
|---|---|---|
| **CRITICAL** | `macos/Brewfile:59` still declares `cask "mpv"` (renamed `stolendata-mpv`, disable date 2026-09-01, deprecated DSL errors *now*). | `brew "mpv"` (formula). **Already fixed in the pending `mpv-macos-tune` PR** — land that first. |
| **HIGH** | `tealdeer` (`base.sh`) and `tldr` (`apps.sh:30`) both own `/usr/bin/tldr` → `pacman -S` file conflict aborts 09-apps on a fresh install. `tldr` is redundant (tealdeer provides `tldr`). | Delete `tldr` from `apps.sh`. |
| MEDIUM | Homebrew `p7zip` is on the deprecation path → `sevenzip` (binary `7zz`, not drop-in). | Monitor; swap when a caller-audit confirms nothing uses `7z`/`7za`. |
| LOW | Doc drift: `packages/CLAUDE.md` lists `usbguard`, Plymouth splash, and `quickshell` that aren't actually installed. | Update docs to match reality. |
| LOW | Redundant Rust: pacman `rust` + rustup both present. | Pick one. |

**Prevention, not just fixes:** a unified registry + a `tests/` lint that checks channel correctness, cross-package file conflicts, and Homebrew deprecation is what stops the *next* one.

---

## 2. Target architecture — three layers

```
┌─────────────────────────────────────────────────────────────┐
│ CORE  (platform-agnostic — runs anywhere bash + stow exist)  │
│   logging · step-runner · stow · theme engine · shared       │
│   helpers (login-shell, fisher, checksummed curl-install)    │
│   package installer → dispatches to the active ADAPTER       │
└─────────────────────────────────────────────────────────────┘
                              │ selects by uname / os-release
        ┌─────────────────────┼─────────────────────┐
        ▼                     ▼                     ▼
┌───────────────┐    ┌───────────────┐    ┌───────────────┐
│ ADAPTER: arch │    │ ADAPTER: macos│    │ (adapter: …)  │
│ pacman/paru   │    │ brew formula/ │    │               │
│ systemctl     │    │ cask · launchd│    │               │
│ link /etc     │    │ dscl · no-op  │    │               │
└───────────────┘    └───────────────┘    └───────────────┘
        │                     │
        ▼                     ▼
┌──────────────────────────────────────────────────────────────┐
│ PROFILES  (ordered steps + package/stow/theme manifests)      │
│   linux-hyprland  ·  macos  ·  server(future)                 │
│   hardware/desktop specifics live here as DATA, not inline if │
└──────────────────────────────────────────────────────────────┘
```

**Rule of thumb for "what goes where":**
- Touches only `$HOME`, stow, or theme templates, and works on any OS → **core**.
- Wraps a package manager, init system, or `/etc` → **adapter** (one impl per OS).
- Names concrete packages, hardware, or desktop steps, or their order → **profile** (data).

---

## 3. Proposed repo structure

```
install.sh                 # single curl entry: detect OS → clone → exec bootstrap
bootstrap.sh               # single orchestrator: core + adapter + profile → run steps

core/
  lib.sh                   # portable primitives (log, stow_pkg, helpers, runner)
  runner.sh                # step-manifest executor (prompt/--yes, reboot-gate, summary)
  adapters/
    arch.sh                # pkg/svc/link/login-shell impls (pacman, systemd, /etc)
    macos.sh               # brew, launchd/no-op, dscl, ~/… ARCHE root
  registry.sh              # resolve a logical tool → {kind, name} for active adapter

theming/                   # UNCHANGED — already the correct shared boundary
  engine.sh · themes/ · templates/ · schema.sh

packages/                  # unified registry (see §5) — logical groups, per-platform map
stow/                      # unchanged layout; profiles select subsets
system/                    # Linux-only; deployed by feature-owned link steps (not a god-fn)
tools/                     # Linux-only binaries

profiles/
  linux-hyprland/
    profile.sh             # ordered steps + stow set + theme components + hw vars
    steps/                 # gpu, hyprland, boot, dms, legion … (moved from scripts/NN-*)
  macos/
    profile.sh             # brew list, chsh, platform.macos.conf, mpv-default
  server/                  # future: linux core − desktop/GPU/boot

just/                      # targets derived from the profile manifest (no parallel list)
tests/                     # + registry lint (channel/conflict/deprecation), manifest-sync
docs/                      # this file + decision records
```

> This is the **full** structure. §7 makes it incremental so nothing lands as one risky mega-move.

---

## 4. One linear, easy install

- **`install.sh`** (one curl line): detect Arch vs macOS → clone to the right root (`/opt/arche` + `users` group on Linux, `$HOME/arche` on macOS) → `exec bash bootstrap.sh --profile <auto>`.
- **`bootstrap.sh`**: source core → pick adapter by `uname` → load the profile → hand its **ordered step manifest** to `core/runner.sh`.
- **Step manifest** (one per profile) is the single source of truth. Each step declares: `id`, `description`, `run` (function/script), `layer` (system|user), `profiles`/`tags`, `needs-reboot?`, `hardware-cond?`. `bootstrap.sh`, `just`, the prompt descriptions, and `secondary-user` all read it — the three parallel lists collapse to one.
- **Non-interactive by default option:** `--yes` runs the whole thing; the interactive blockers (TPM2 enroll, reboot gate) move *out* of the linear path into explicit post-steps (`just tpm-enroll`, already exists).
- **Re-runnable & resumable:** `--from <id>` / `--only <id>`; every step stays idempotent (already strong today).
- **System vs per-user split becomes first-class** (the `secondary-user` recipe already encodes it): the system layer runs once with sudo; the user layer (stow, shell, theme, user services) runs per human.

---

## 5. Unified package registry (drift-proofing)

One logical registry; each tool maps to a per-platform provider **and install-kind**:

```
# packages/core-cli.sh   (illustrative shape — final format TBD)
tool ripgrep    arch=pacman:ripgrep         macos=brew:ripgrep
tool gh         arch=pacman:github-cli      macos=brew:gh            # name differs
tool tree-sitter arch=pacman:tree-sitter-cli macos=brew:tree-sitter  # name differs
tool mpv        arch=pacman:mpv             macos=brew:mpv           # NEVER cask
```

- **Shared groups** defined once (~28 tools overlap today); platform-only tools in their own groups.
- The **install-kind is explicit and reviewed** (`brew:` vs `cask:`) — the `cask mpv` class becomes impossible to introduce silently.
- **`tests/` lint** enforces: valid channel per platform, no two tools claiming the same file (`tealdeer`/`tldr`), and a Homebrew-deprecation check. CI catches the next drift before a human hits it.
- The adapter's `registry.sh` resolves `tool → {kind,name}` and calls the right backend, so profiles reference **logical tool names**, never raw package strings.

---

## 6. Best practices to adopt

1. **Single source of truth** for steps (manifest) and packages (registry) — no hand-synced parallel lists.
2. **Declarative over imperative:** move NVIDIA `MODULES` to a `mkinitcpio.conf.d` drop-in like HOOKS; drop the `sed`.
3. **Feature-owned system linking:** decompose `link_system_all` into per-step `link` calls driven by a `file → owning-step` manifest. Removes the crypttab-in-preflight coupling and the stale-limine leak.
4. **Pin/checksum every `curl | bash`** (fnm/bun/fisher) to match the shellcheck precedent.
5. **Delete dead config** (`system/etc/*limine*`) and fix doc drift.
6. **Hardware/host assumptions as profile data** (Legion bt services, NVIDIA, swap size, arche-denoise SDK path) — not inline `if lspci | grep`.
7. **Render theme once** at the end; keep a `--standalone` flag for per-`just`/secondary-user runs (drops the redundant mid-install `theme_render` calls).
8. **Generalize the mpv `platform.conf` selector** to the other portable-but-varying configs: tmux clipboard (`wl-copy`↔`pbcopy`) and the fish `ARCHE` root — via one `select_platform_file` helper instead of open-coded `ln -sfn`.
9. **Keep the theme engine untouched** — it's already the correct, tested shared boundary.

---

## 7. Phased migration (each phase is its own PR, independently shippable)

- **Phase 0 — quick wins (low risk):** land the `mpv-macos-tune` PR (fixes cask mpv); remove `tldr` from `apps.sh`; delete dead limine config; fix doc drift. Add the registry-lint skeleton.
- **Phase 1 — core/adapter split:** refactor `lib.sh` into `core/lib.sh` + `core/adapters/{arch,macos}.sh`; extract `set_login_shell`, `setup_fisher`, checksummed curl-installer. **No behavior change** — both bootstraps call the same helpers.
- **Phase 2 — one orchestrator:** introduce `core/runner.sh` + a per-profile step manifest; fold `macos/bootstrap.sh` and `bootstrap.sh` into one `bootstrap.sh --profile`. Kill the three parallel lists; derive `just` targets from the manifest.
- **Phase 3 — unified registry:** logical tool registry + per-platform provider map + conflict/deprecation lint. Migrate `packages/*.sh` and the Brewfile onto it.
- **Phase 4 — system linking + initramfs:** decompose `link_system_all`; unify initramfs on drop-ins.
- **Phase 5 — profiles + server:** move desktop/hardware steps under `profiles/linux-hyprland/`; add the `server` profile (linux core − desktop/GPU/boot).

Each phase keeps the tree installable; we validate with `just test` (+ the new lints) before merging.

---

## 8. Branch & merge cleanup (final, after implementation)

- Merge `mpv-macos-tune` → main (Phase 0).
- Land redesign phases as sequential PRs into main.
- After each merge: delete the merged branch locally **and** on origin.
- Current branch state: only `main` + `mpv-macos-tune` exist — no orphan branches yet, so "clean stale branches" = prune each phase branch as it merges.

---

## 9. Open decisions (need your call)

1. **Restructure aggressiveness** — full `profiles/`+`core/` reorg (cleaner long-term, moves many files) vs. incremental layering (adapters + manifests, minimal moves). Recommendation: phased (§7), which reaches the full structure without a big-bang move.
2. **macOS `ARCHE` root** — `$HOME/arche` (current) vs `~/.local/share/arche`. Affects `arche`/`dms` emit paths.
3. **Registry format** — a custom `tool …` DSL (readable, needs a tiny parser) vs staying with sourced bash arrays keyed by platform. Trade readability vs zero-parser simplicity.
