scripts_window_close = {
    "on-close.lua"
}

scripts_window_focus = {
    "on-focus.lua"
}

scripts_window_blur = {
    "on-blur.lua"
}

-- Code below this line runs once per open window at startup, then each time a
-- window opens, so globals can safely be initialised here
if (not _G["do_actions"]) then
    local script_path, script_basename
    script_path = debug.getinfo(1, "S").source
    script_dir, script_basename = string.match(script_path, "@(.*)/([^/]*)")
    dofile(script_dir .. "/shared-lua")
end

-- "on-open.lua" effectively starts here
dofile(script_dir .. "/defaults-lua")

is_open = true
dofile(script_dir .. "/windows-lua")

-- log_window("open")
-- log_window_full("open")

if (get_class_instance_name()) then
    local window = windows[get_class_instance_name()]

    if window then
        if window.log then
            log_window_full("open")
        end

        do_actions(window)
    end
end
