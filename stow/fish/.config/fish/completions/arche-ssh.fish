# Completions for arche-ssh — host names come from the per-user inventory
# (~/.config/arche/ssh-hosts) via the side-effect-free 'names' subcommand.

complete -c arche-ssh -f

complete -c arche-ssh -n __fish_use_subcommand -a '(arche-ssh names)' -d 'ssh host'
complete -c arche-ssh -n __fish_use_subcommand -a list -d 'Show host inventory'
complete -c arche-ssh -n __fish_use_subcommand -a edit -d 'Edit host inventory'
complete -c arche-ssh -n __fish_use_subcommand -a help -d 'Show usage'
