function port --description 'Show what is listening on a given port'
    if test (count $argv) -ne 1
        echo "Usage: port <port_number>"
        return 1
    end
    ss -tlnp | grep $argv[1]
end
