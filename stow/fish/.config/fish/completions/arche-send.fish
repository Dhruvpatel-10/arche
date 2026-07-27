# Completions for arche-send (and the 'send' wrapper). Host names come from the
# per-user arche-ssh inventory via its side-effect-free 'names' subcommand.

for cmd in arche-send send
    complete -c $cmd -r -F
    complete -c $cmd -l host -d 'Server from the arche-ssh inventory' -x -a '(arche-ssh names)'
    complete -c $cmd -l to -d 'Subdirectory under ~/remote-data' -x
    complete -c $cmd -l dest -d 'Exact remote directory to send into' -x
    complete -c $cmd -l delete -d 'Mirror: drop remote files missing locally'
    complete -c $cmd -l move -d 'Remove each local file once it has landed'
    complete -c $cmd -l dry -d 'Preview only; change nothing'
    complete -c $cmd -l where -d 'Print the remote directory and exit'
    complete -c $cmd -s h -l help -d 'Show usage'
end
