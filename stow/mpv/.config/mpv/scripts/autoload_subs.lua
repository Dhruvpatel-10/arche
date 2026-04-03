local mp = require 'mp'
local utils = require 'mp.utils'

function load_subs()
    local path = mp.get_property("path")
    if not path then return end

    local dir, filename = utils.split_path(path)
    local sub_dir = utils.join_path(dir, "sub")

    -- Get a list of all files in the 'sub' directory
    local files = utils.readdir(sub_dir, "files")
    if not files then return end

    -- Add all subtitle files
    for _, file in ipairs(files) do
        if file:match("%.srt$") or file:match("%.ass$") or file:match("%.vtt$") then
            local sub_path = utils.join_path(sub_dir, file)
            mp.msg.info("Adding subtitle: " .. sub_path)
            mp.commandv("sub-add", sub_path)
        end
    end
end

mp.register_event("file-loaded", load_subs)

