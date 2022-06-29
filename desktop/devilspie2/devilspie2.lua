path = require "pl.path"

scripts_window_close = {
    "on-close.lua",
}

scripts_window_focus = {
    "on-focus.lua",
}

scripts_window_blur = {
    "on-blur.lua",
}

-- Code below this line runs once per open window at startup, then each time a
-- window opens, so globals can safely be initialised here
if (not _G["script_dir"]) then
    script_dir = path.dirname(path.abspath(debug.getinfo(1, "S").source:sub(2)))
    dofile(script_dir .. "/core-lua")
    if path.exists(script_dir .. "/config-lua") then
        dofile(script_dir .. "/config-lua")
    else
        dofile(script_dir .. "/config-default-lua")
    end
end

-- "on-open.lua" effectively starts here
process_event("open")
