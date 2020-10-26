dofile(script_dir .. "/defaults-lua")

is_close = true
dofile(script_dir .. "/windows-lua")

-- Exceptions will be thrown if either of the following are uncommented.

-- log_window("close")
-- log_window_full("close")

last_closed_window_xid = get_window_xid()
