dofile(script_dir .. "/defaults-lua")

is_blur = true
dofile(script_dir .. "/windows-lua")

if not (last_closed_window_xid and last_closed_window_xid == get_window_xid()) then
    -- log_window("blur")
    -- log_window_full("blur")

    if get_class_instance_name() then
        local window = windows[get_class_instance_name()]

        if window then
            if window.log then
                log_window_full("blur")
            end

            if window.apply_on_blur then
                if window.blurred_opacity ~= nil then
                    window = extend_copy(window, {opacity = window.blurred_opacity})
                end
                do_actions(window)
            elseif window.blurred_opacity ~= nil then
                set_window_opacity(window.blurred_opacity)
            end
        end
    end
end
