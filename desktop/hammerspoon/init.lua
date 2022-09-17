-- One of: "nothing", "error", "warning", "info", "debug", "verbose"
hs.logger.defaultLogLevel = "info"
logger = hs.logger.new("init")
wf = hs.window.filter
hs.window.animationDuration = 0

defaultGrid = {6, 2}

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

function extend(copyTable, updateTable)
    local copy = hs.fnutils.copy(copyTable)
    for k, v in pairs(updateTable) do
        copy[k] = v
    end
    return copy
end

-- Configure preferred apps with:
-- - `bundleID` (required): string
-- - `commandLine` (optional): string, "{{app}}" is replaced with path to .app
-- - `menuItem` (optional): passed to hs.application:selectMenuItem(), overrides
--   `commandLine` if both are set
_app = {
    terminal = {
        bundleID = "com.googlecode.iterm2",
        commandLine = '/usr/bin/pkill -SIGUSR1 -fnu "$EUID" \'/create_window_on_signal.py$\'',
    },
    browser = {
        bundleID = "org.mozilla.firefox",
        commandLine = "{{app}}/Contents/MacOS/firefox --browser",
    },
    textEditor = {
        bundleID = "com.microsoft.VSCode",
        menuItem = {"File", "New Window"},
    },
    fileManager = {
        bundleID = "com.apple.finder",
        menuItem = {"File", "New Finder Window"},
    },
}

_operator = {
    AND = "and",
    OR = "or",
}

_criteria = {
    has_multiple_displays = function()
        return _screen2 and true or false
    end,
    on_secondary_display = function(ev)
        return ev.screen:getUUID() ~= _screen1:getUUID()
    end,
    is_initialising = function()
        return _initialising
    end,
}

_criteria.pinnable = {
    _operator.AND,
    _criteria.has_multiple_displays,
    {
        _operator.OR,
        event = wf.windowCreated,
        {
            _operator.AND,
            event = {wf.windowFocused, wf.windowUnfocused},
            _criteria.on_secondary_display,
        },
    },
}

_groups = {
    mail = {
        ["Mail"] = {},
        ["Calendar"] = {},
    },
    teams = {
        ["Microsoft Teams"] = {}
    },
    messenger = {
        ["Messenger"] = {},
        ["Messages"] = {},
    },
    skype = {
        ["Skype"] = {},
    },
    time = {
        ["Clockify Desktop"] = {},
    },
    todo = {
        ["Todoist"] = {},
    },
    util = {
        ["KeePassXC"] = {},
    },
    dev = {
        ["com.microsoft.VSCode"] = {},
        ["com.sublimemerge"] = {},
        ["org.jkiss.dbeaver.core.product"] = {},
    },
}

_apps = {}
for group, apps in pairs(_groups) do
    for app, settings in pairs(apps) do
        _apps[app] = extend(settings, {group = group})
    end
end
logger.d("_apps = " .. hs.inspect.inspect(_apps))

_layouts = {
    -- Ultrawide
    -- 1. <-- 23% --> <-- ** 54% ** --> <-- 23% -->
    --    - 3440px / 43 = 80px
    --    - 10x = 800px
    --    - 23x = 1840px
    ["1,1:3440.0x1440.0"] = {
        grid = {43, 2},
        place = {display = 1, wh = {10, 1}},
        group_places = {
            mail = {xy = {11, 1}, wh = {23, 2}},
            teams = {xy = {1, 1}},
            messenger = {xy = {1, 2}},
            skype = {xy = {1, 2}},
            time = {xy = {34, 1}},
            todo = {xy = {34, 2}},
            util = {xy = {34, 2}},
            dev = {xy = {11, 1}, wh = {23, 2}},
        },
    },
    ["*"] = {
        grid = {4, 2},
        place = {display = 1, wh = {2, 2}},
        group_places = {
            mail = {xy = {1, 1}, wh = {4, 2}},
            teams = {xy = {1, 1}},
            messenger = {xy = {3, 1}},
            skype = {xy = {1, 1}},
            time = {xy = {3, 1}},
            todo = {xy = {3, 1}},
            util = {xy = {3, 1}},
            dev = {xy = {1, 1}, wh = {4, 2}},
        },
    },
}

function normalisePlace(place, ev)
    local p = {
        display = place.display or ev.display,
        grid = place.grid or defaultGrid or {3, 1},
        xy = place.xy or {place.column1 or 0, place.row1 or 0},
        wh = place.wh or {place.columns or 0, place.rows or 0},
    }
    p.grid[1] = math.max(p.grid[1], p.xy[1] + p.wh[1] - 1)
    p.grid[2] = math.max(p.grid[2], p.xy[2] + p.wh[2] - 1)
    return p
end

function toPlace(place, ev)
    local p = normalisePlace(place, ev)
    if p.display ~= nil and p.display ~= ev.display then
        logger.d("Moving " .. ev.appName .. " to display " .. p.display)
        ev.window:moveToScreen(_screen[p.display])
    end
    local x, y = table.unpack(p.xy)
    local w, h = table.unpack(p.wh)
    local rect = hs.geometry(
        x > 0 and ((x - 1) / p.grid[1]) or nil,
        y > 0 and ((y - 1) / p.grid[2]) or nil,
        w > 0 and (w / p.grid[1]) or nil,
        h > 0 and (h / p.grid[2]) or nil
    )
    local unitRect, windowFrame = _screen[p.display or ev.display]:fromUnitRect(rect), ev.window:frame()
    logger.v("unitRect = " .. hs.inspect.inspect(unitRect))
    logger.v("windowFrame = " .. hs.inspect.inspect(windowFrame))
    for i, f in ipairs({"x", "y", "w", "h"}) do
        if math.floor(unitRect[f]) ~= math.floor(windowFrame[f]) then
            goto move
        end
    end
    do return end
    ::move::
    logger.d("Moving " .. ev.appName .. " to " .. hs.inspect.inspect(rect))
    ev.window:moveToUnit(rect)
end

function getPlace(ev)
    local app = _apps[ev.appName] or _apps[ev.appBundleId]
    if app ~= nil then
        logger.v("app = " .. hs.inspect.inspect(app))
    end
    local geometry, layout, place = table.concat({ev.screenGeometry.w, ev.screenGeometry.h}, "x")
    for i, layout_id in ipairs({
        #_screen .. "," .. ev.display .. ":" .. geometry,
        "*," .. ev.display .. ":" .. geometry,
        ev.display .. ":" .. geometry,
        #_screen .. ",*:" .. geometry,
        #_screen .. "," .. geometry,
        "*,*:" .. geometry,
        "*:" .. geometry,
        "*," .. geometry,
        geometry,
        "*,*:*",
        "*",
    }) do
        logger.v("Checking layout_id = " .. layout_id)
        layout = _layouts[layout_id]
        if layout and checkCriteria(layout.criteria, ev) then
            logger.v("layout_id = " .. layout_id)
            if app then
                place = layout.group_places and layout.group_places[app.group]
                if place and checkCriteria(layout.group_places.criteria, ev) and
                    checkCriteria(app.criteria, ev) then
                    if layout.place then
                        place = extend(layout.place, place)
                    end
                    break
                end
                place = nil
            end
        end
    end
    if place then
        place.grid = place.grid or layout.grid
        logger.v("place = " .. hs.inspect.inspect(place))
        return place
    end
end

_rule = {
    {
        criteria = {
            isMain = true,
            event = {wf.windowCreated, wf.windowFocused},
            function(ev)
                ev.place = getPlace(ev)
                return ev.place ~= nil
            end,
        },
        action = {
            function(ev)
                toPlace(ev.place, ev)
            end,
        },
    },
}

function initScreens()
    _screen1, _screen2 = hs.screen.primaryScreen(), nil
    _screen = {_screen1}
    for i, screen in pairs(hs.screen.allScreens()) do
        if screen:getUUID() ~= _screen1:getUUID() then
            _screen2 = _screen2 and _screen2 or screen
            _screen[#_screen + 1] = screen
        end
    end
end

function checkCriteria(criteria, ev)
    if criteria == nil then
        return true
    end
    logger.v("Checking criteria " .. hs.inspect.inspect(criteria) .. " against ev " .. hs.inspect.inspect(ev))
    local andResult, orResult, op = true, false
    for k, v in pairs(criteria) do
        local result
        if type(k) == "number" then
            if v == "AND" or v == _operator.AND then
                if andResult == false then
                    return false
                end
                op = _operator.AND
            elseif v == "OR" or v == _operator.OR then
                if orResult == true then
                    return true
                end
                op = _operator.OR
            elseif type(v) == "function" then
                result = v(ev)
            elseif type(v) == "table" then
                result = checkCriteria(v, ev)
            end
        elseif type(v) == "table" then
            result = hs.fnutils.contains(v, ev[k])
        else
            result = ev[k] == v
        end
        if result ~= nil then
            andResult = andResult and result
            orResult = orResult or result
            if op == _operator.AND and andResult == false then
                return false
            elseif op == _operator.OR and orResult == true then
                return true
            end
        end
    end
    return andResult
end

actionMap = {
    ["function"] = function(fn, ev)
        fn(ev)
    end,
    ["table"] = function(t, ev)
        local args = hs.fnutils.copy(t)
        args[1] = ev
        t[1](table.unpack(args))
    end,
}

function processEvent(window, appName, event)
    logger.d("Event received from " .. appName .. ": " .. event)
    if _rule == nil then
        return
    end
    local screen, app = window:screen(), window:application()
    local ev = {
        window = window,
        screen = screen,
        appName = appName,
        event = event,
        appTitle = app and app:title() or nil,
        appBundleId = app and app:bundleID() or nil,
        windowTitle = window:title(),
        isStandard = window:isStandard(),
        isMain = (app and app:mainWindow() == window) or nil,
        role = window:role(),
        subrole = window:subrole(),
        screenGeometry = screen and screen:fullFrame() or nil,
        display = screen and (screen:getUUID() == _screen1:getUUID()) and 1 or 2,
    }
    for i, rule in ipairs(_rule) do
        if rule.criteria ~= nil and not checkCriteria(rule.criteria, ev) then
            logger.v("_rule[" .. i .. "] criteria not met: " .. hs.inspect.inspect(rule.criteria))
        else
            logger.d("_rule[" .. i .. "] criteria met: " .. hs.inspect.inspect(rule.criteria))
            ev.rule = rule
            for j, action in ipairs(rule.action) do
                logger.v("_rule[" .. i .. "].action[" .. j .. "] = " .. hs.inspect.inspect(action))
                local _action = actionMap[type(action)]
                if _action ~= nil then
                    ev.action = action
                    _action(action, ev)
                else
                    logger.e("Invalid type '" .. type(action) .. "': _rule[" .. i .. "].action[" .. j .. "]")
                end
            end
        end
    end
end

function initWindowFilter()
    _initialising = true
    _filter = wf.new(nil)
    _filter:subscribe(wf.windowCreated, processEvent, true)
    _filter:subscribe({wf.windowFocused, wf.windowUnfocused}, processEvent)
    _initialising = false
end

function quote(string)
    return "'" .. string:gsub("'", "'\\''") .. "'"
end

function fileExists(path)
    return (hs.fs.displayName(path) ~= nil)
end

function scriptPath(script)
    return hs.configdir .. "/../../bin/" .. script
end

function homePath(path)
    local home = os.getenv("HOME")
    if home then
        return home .. path
    end
end

function getCommand(commandArray)
    local command = ""
    for i, arg in ipairs(commandArray) do
        command = command .. (i == 1 and "" or " ") .. quote(arg)
    end
    return command
end

function run(command, detach)
    local sh = 'eval "$(/usr/libexec/path_helper -s)" && {\n' .. command .. "\n} 2>&1"
    if detach then
        sh = "(" .. sh .. ') >>"$(mktemp /tmp/lk.hammerspoon.XXXXXX)" 2>&1 &'
    end
    logger.d("Running: " .. sh)
    local output, status, type, rc = hs.execute(sh)
    if not status then
        logger.e("Failed (" .. type .. " " .. rc .. "): " .. command)
        if output ~= "" then
            logger.e("Output:\n" .. output)
        end
    end
    -- status: true or nil
    -- type: "exit" or "signal"
    -- rc: exit code or signal number
    return status, type, rc
end

function open(bundleID, file, background)
    local command = {"/usr/bin/open"}
    if bundleID then
        table.insert(command, "-b")
        table.insert(command, bundleID)
    end
    if background then
        table.insert(command, "-g")
    end
    if file then
        table.insert(command, file)
    end
    run(getCommand(command))
end

function runInTerminal(path)
    open(_app.terminal.bundleID, path)
end

function openNewWindow(rules)
    local app, path = hs.application.get(rules.bundleID), hs.application.pathForBundleID(rules.bundleID)
    if app and rules.menuItem then
        if app:mainWindow() or app:activate() then
            logger.d("Calling selectMenuItem(" .. hs.inspect.inspect(rules.menuItem) .. ") on " .. app:bundleID())
            if app:selectMenuItem(rules.menuItem) then
                return
            end
        end
    end
    if app and path and rules.commandLine then
        local command = rules.commandLine:gsub("{{app}}", quote(path))
        if run(command) then
            return
        end
    end
    open(rules.bundleID)
end

function dumpWindows()
    hs.fnutils.each(
        hs.window.allWindows(),
        function(w)
            local window = {
                appTitle = w:application():title(),
                appBundleId = w:application():bundleID(),
                windowTitle = w:title(),
                isStandard = w:isStandard(),
                isMain = w:application():mainWindow() == w,
                role = w:role(),
                subrole = w:subrole(),
            }
            logger.i(hs.inspect.inspect(window))
        end
    )
end

initScreens()
initWindowFilter()

_screenwatcher = hs.screen.watcher.new(function()
    _filter:unsubscribeAll()
    initScreens()
    initWindowFilter()
    hs.notify.new(
        {
            title = "Hammerspoon",
            informativeText = "Screen layout change detected",
            withdrawAfter = 5,
        }
    ):send()
end)
_screenwatcher:start()

hs.hotkey.bind(
    {"cmd", "shift"},
    "9",
    function()
        run("/Applications/flameshot.app/Contents/MacOS/flameshot gui")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "9",
    function()
        run("/Applications/flameshot.app/Contents/MacOS/flameshot gui -p ~/Nextcloud/Inbox/Screenshots")
    end
)

hs.hotkey.bind(
    {"ctrl", "option"},
    "a",
    function()
        open(nil, "keepingyouawake:///activate", true)
    end
)

hs.hotkey.bind(
    {"ctrl", "option"},
    "s",
    function()
        open(nil, "keepingyouawake:///deactivate", true)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "b",
    function()
        open("com.apple.calculator")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "b",
    function()
        runInTerminal(scriptPath("build-lk-platform.sh"))
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "c",
    function()
        openNewWindow(_app.textEditor)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "c",
    function()
        run("/opt/lk-settings/bin/open-project.sh", true)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "d",
    function()
        open("org.jkiss.dbeaver.core.product")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "e",
    function()
        openNewWindow(_app.fileManager)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "g",
    function()
        run("/opt/lk-settings/bin/open-repo.sh", true)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "g",
    function()
        run("/opt/lk-settings/bin/open-repo.sh git -C {} cola", true)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "h",
    function()
        open("com.microsoft.VSCode", "/etc/hosts")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "m",
    function()
        open("com.apple.mail")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "n",
    function()
        run("/opt/lk-platform/bin/lk-note-open.sh")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "n",
    function()
        open("com.microsoft.VSCode", homePath("/Nextcloud/Notes"))
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "r",
    function()
        open("com.microsoft.VSCode", homePath("/.bashrc"))
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "s",
    function()
        runInTerminal(scriptPath("sync-files.sh"))
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "t",
    function()
        openNewWindow(_app.terminal)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "t",
    function()
        open("com.apple.Terminal")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "v",
    function()
        run("/opt/homebrew/bin/virt-manager", true)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "w",
    function()
        openNewWindow(_app.browser)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "x",
    function()
        _filter:unsubscribeAll()
        initWindowFilter()
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "x",
    function()
        hs.reload()
    end
)

hs.hotkey.bind(
    {"cmd", "alt"},
    "v",
    function()
        local paste = hs.pasteboard.getContents()
        if #paste > 128 then
            hs.notify.new(
                {
                    title = "Hammerspoon",
                    informativeText = "Clipboard text too long",
                    withdrawAfter = 2,
                }
            ):send()
            return
        end
        hs.eventtap.keyStrokes(paste)
    end
)

hs.notify.new(
    {
        title = "Hammerspoon",
        informativeText = "Config reloaded",
        withdrawAfter = 2,
    }
):send()
