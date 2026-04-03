# PATH and environment exports
# conf.d/ files are auto-sourced by fish before config.fish

set -gx BUN_INSTALL $HOME/.bun
set -gx CUDA_PATH /opt/cuda
set -gx PNPM_HOME $HOME/.local/share/pnpm

# fish_add_path is idempotent — only adds if dir exists and not already in PATH
fish_add_path $HOME/.local/bin
fish_add_path $HOME/.cargo/bin
fish_add_path $HOME/go/bin
fish_add_path $HOME/.cache/.bun/bin
fish_add_path $BUN_INSTALL/bin
fish_add_path $PNPM_HOME
fish_add_path /opt/cuda/bin
