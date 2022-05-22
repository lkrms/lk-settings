-- One of: "nothing", "error", "warning", "info", "debug", "verbose"
hs.logger.defaultLogLevel = "debug"
logger = hs.logger.new("init")
wf = hs.window.filter
hs.window.animationDuration = 0

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

-- Configure your preferred apps with:
-- - `bundleID` (required): string
-- - `commandLine` (optional): string, "{{app}}" is replaced with path to .app
-- - `menuItem` (optional): passed to hs.application:selectMenuItem(), overrides
--   `commandLine` if both are set
_app = {
    terminal = {
        bundleID = "com.googlecode.iterm2",
        commandLine = '/usr/bin/pkill -SIGUSR1 -fnu "$EUID" \'/create_window_on_signal.py$\''
    },
    browser = {
        bundleID = "org.mozilla.firefox",
        commandLine = "{{app}}/Contents/MacOS/firefox --browser"
    },
    textEditor = {
        bundleID = "com.microsoft.VSCode",
        menuItem = {"File", "New Window"}
    },
    fileManager = {
        bundleID = "com.apple.finder",
        menuItem = {"File", "New Finder Window"}
    }
}

_place = {
    top3_1 = {x = 0, y = 0, w = 1 / 3, h = 0.5},
    top3_2 = {x = 1 / 3, y = 0, w = 1 / 3, h = 0.5},
    top3_3 = {x = 2 / 3, y = 0, w = 1 / 3, h = 0.5},
    bottom3_1 = {x = 0, y = 0.5, w = 1 / 3, h = 0.5},
    bottom3_2 = {x = 1 / 3, y = 0.5, w = 1 / 3, h = 0.5},
    bottom3_3 = {x = 2 / 3, y = 0.5, w = 1 / 3, h = 0.5}
}

_operator = {
    AND = "and",
    OR = "or"
}

_criteria = {
    multihead = function()
        return _screen2 and true or false
    end,
    primary = function(ev)
        return ev.window:screen():getUUID() == _screen1:getUUID()
    end,
    notPrimary = function(ev)
        return ev.window:screen():getUUID() ~= _screen1:getUUID()
    end,
    loading = function()
        return _loading
    end
}

_criteria.sticky = {
    _operator.AND,
    _criteria.multihead,
    {
        _operator.OR,
        event = wf.windowCreated,
        {
            _operator.AND,
            event = {wf.windowFocused, wf.windowUnfocused},
            _criteria.notPrimary
        }
    }
}

_criteria.tacky = {
    _operator.AND,
    _criteria.multihead,
    {
        _operator.OR,
        _criteria.notPrimary,
        _criteria.loading
    },
    event = {wf.windowCreated, wf.windowFocused, wf.windowUnfocused}
}

_criteria.dev = {
    appBundleId = {
        "com.microsoft.VSCode",
        "com.sublimemerge",
        "org.jkiss.dbeaver.core.product"
    }
}

_action = {
    moveTo = function(ev, screen, rect)
        if screen and _screen[screen] ~= nil then
            logger.d("Moving " .. ev.appName .. " to screen " .. screen)
            ev.window:moveToScreen(_screen[screen])
        end
        if rect then
            logger.d("Moving " .. ev.appName .. " to " .. hs.inspect.inspect(rect))
            ev.window:moveToUnit(rect)
        end
    end
}

_rule = {
    -- Move dev apps to the primary display
    {
        criteria = {
            _criteria.multihead,
            _criteria.notPrimary,
            _criteria.dev,
            event = wf.windowCreated
        },
        action = {{_action.moveTo, 1}}
    },
    {
        criteria = {_criteria.multihead, appName = {"Mail"}},
        action = {{_action.moveTo, 1, hs.layout.left50}}
    },
    {
        criteria = {_criteria.tacky, appName = {"Microsoft Teams"}},
        action = {{_action.moveTo, 2, _place.top3_1}}
    },
    {
        criteria = {_criteria.sticky, appName = {"Messenger"}},
        action = {{_action.moveTo, 2, _place.top3_2}}
    },
    {
        criteria = {_criteria.sticky, appName = {"Calendar", "Skype"}},
        action = {{_action.moveTo, 2, _place.top3_3}}
    },
    {
        criteria = {_criteria.sticky, appName = {"KeePassXC"}},
        action = {{_action.moveTo, 2, _place.bottom3_1}}
    },
    {
        criteria = {_criteria.sticky, appName = {"Todoist"}},
        action = {{_action.moveTo, 2, _place.bottom3_2}}
    },
    {
        criteria = {_criteria.sticky, appName = {"Messages"}},
        action = {{_action.moveTo, 2, _place.bottom3_3}}
    }
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

function processCriteria(criteria, ev)
    logger.v("Checking criteria " .. hs.inspect.inspect(criteria) .. " against ev " .. hs.inspect.inspect(ev))
    local andResult, orResult, op = true, false
    for k, v in pairs(criteria) do
        local result
        if type(k) == "number" then
            if v == _operator.AND then
                if andResult == false then
                    return false
                end
                op = _operator.AND
            elseif v == _operator.OR then
                if orResult == true then
                    return true
                end
                op = _operator.OR
            elseif type(v) == "function" then
                result = v(ev)
            elseif type(v) == "table" then
                result = processCriteria(v, ev)
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
    end
}

function processEvent(window, appName, event)
    logger.d("Event received from " .. appName .. ": " .. event)
    if _rule == nil then
        return
    end
    local ev = {
        window = window,
        appName = appName,
        event = event,
        appTitle = window:application():title(),
        appBundleId = window:application():bundleID(),
        windowTitle = window:title(),
        isStandard = window:isStandard(),
        role = window:role(),
        subrole = window:subrole()
    }
    for i, rule in ipairs(_rule) do
        if rule.criteria ~= nil and not processCriteria(rule.criteria, ev) then
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
    _loading = true
    _filter = wf.new(nil)
    _filter:subscribe(wf.windowCreated, processEvent, true)
    _filter:subscribe({wf.windowFocused, wf.windowUnfocused}, processEvent)
    _loading = false
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
                role = w:role(),
                subrole = w:subrole()
            }
            logger.i(hs.inspect.inspect(window))
        end
    )
end

initScreens()
initWindowFilter()

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
        hs.eventtap.keyStrokes(hs.pasteboard.getContents())
    end
)

hs.notify.new(
    {
        title = "Hammerspoon",
        informativeText = "Config reloaded",
        withdrawAfter = 2
    }
):send()
