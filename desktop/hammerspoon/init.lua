-- One of: "nothing", "error", "warning", "info", "debug", "verbose"
hs.logger.defaultLogLevel = "verbose"

-- Configure your preferred apps here
apps = {
    terminal = {
        bundleID = "com.googlecode.iterm2",
        menuItem = {"Shell", "New Window"}
    },
    browser = {
        bundleID = "org.mozilla.firefox",
        commandLine = "{{app}}/Contents/MacOS/firefox --browser"
    }
}

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

logger = hs.logger.new("init")

function quote(string)
    return "'" .. string:gsub("'", "'\\''") .. "'"
end

function scriptPath(script)
    return hs.configdir .. "/" .. script
end

function runInTerminal(path)
    hs.execute(string.format("/usr/bin/open -b %s %s", apps.terminal.bundleID, quote(path)))
end

function openNewWindow(rules)
    local app = hs.application.get(rules.bundleID)
    if not app then
        hs.application.launchOrFocusByBundleID(rules.bundleID)
    elseif rules.menuItem then
        app:selectMenuItem(rules.menuItem)
    elseif rules.commandLine then
        local path = hs.application.pathForBundleID(rules.bundleID)
        if path then
            hs.execute(rules.commandLine:gsub("{{app}}", quote(path)))
        end
    end
end

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "t",
    function()
        openNewWindow(apps.terminal)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "w",
    function()
        openNewWindow(apps.browser)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "s",
    function()
        runInTerminal(scriptPath("sync-files"))
    end
)
