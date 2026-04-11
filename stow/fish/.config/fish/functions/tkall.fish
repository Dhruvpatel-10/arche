function tkall --description 'Kill all tmux sessions'
    for sess in (tmux ls 2>/dev/null | cut -d: -f1)
        tmux kill-session -t $sess
    end
end
