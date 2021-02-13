dofile(script_dir .. "/defaults-lua")

is_focus = true
dofile(script_dir .. "/windows-lua")

-- log_window("focus")
-- log_window_full("focus")

if (get_class_instance_name()) then
    local window = windows[get_class_instance_name()]

    if window then
        if window.log then
            log_window_full("focus")
        end

        local apply_on_focus = window.apply_on_focus

        if type(apply_on_focus) == "number" then
            if on_display(apply_on_focus) then
                apply_on_focus = true
            else
                apply_on_focus = false
            end
        end

        if apply_on_focus then
            if window.blurred_opacity ~= nil and window.opacity == nil then
                window = extend_copy(window, {opacity = 1})
            end
            do_actions(window)
        elseif window.blurred_opacity ~= nil then
            set_window_opacity(window.opacity or 1)
        end
    end
end
