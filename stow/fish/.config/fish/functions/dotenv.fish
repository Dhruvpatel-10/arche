function dotenv --description 'Load .env file into shell environment'
    set -l envfile .env
    if test (count $argv) -ge 1
        set envfile $argv[1]
    end
    if not test -f $envfile
        echo "File not found: $envfile"
        return 1
    end
    for line in (grep -v '^#' $envfile | grep -v '^\s*$')
        set -l kv (string split -m1 '=' $line)
        if test (count $kv) -eq 2
            set -gx $kv[1] $kv[2]
        end
    end
    echo "Loaded $envfile"
end
