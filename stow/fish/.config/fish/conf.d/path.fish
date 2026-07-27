# PATH and environment exports
# conf.d/ files are auto-sourced by fish before config.fish

# arche repo location. /opt/arche is the shared root on Linux (D014), reached
# per-user through the ~/arche symlink. macOS has no shared /opt root, so this
# config is stowed on both platforms and must find the repo wherever it is
# rather than hardcoding the Linux path — an ARCHE pointing at a directory that
# does not exist breaks every script that trusts it.
for _arche_root in /opt/arche $HOME/arche $HOME/projects/arche
    if test -d $_arche_root
        set -gx ARCHE $_arche_root
        break
    end
end
set -e _arche_root

set -gx BUN_INSTALL $HOME/.bun
set -gx CUDA_PATH /opt/cuda
set -gx PNPM_HOME $HOME/.local/share/pnpm

# fish_add_path is idempotent — only adds if dir exists and not already in PATH
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.local/bin/arche
fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/go/bin
fish_add_path $HOME/.cache/.bun/bin
fish_add_path $BUN_INSTALL/bin
fish_add_path $PNPM_HOME
fish_add_path /opt/cuda/bin
