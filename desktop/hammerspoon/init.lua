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

hs.loadSpoon("ReloadConfiguration")
spoon.ReloadConfiguration:start()

logger = hs.logger.new("init")

function quote(string)
    return "'" .. string:gsub("'", "'\\''") .. "'"
end

function scriptPath(script)
    return hs.configdir .. "/" .. script
end

function homePath(path)
    local home = os.getenv("HOME")
    if home then
        return home .. path
    end
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
    return status
end

function open(bundleID, file)
    if file then
        run(string.format("/usr/bin/open -b %s %s", bundleID, quote(file)))
    else
        run(string.format("/usr/bin/open -b %s", bundleID))
    end
end

function runInTerminal(path)
    open(apps.terminal.bundleID, path)
end

function openNewWindow(rules)
    local app = hs.application.get(rules.bundleID)
    if app and rules.menuItem then
        app:selectMenuItem(rules.menuItem)
    elseif app and rules.commandLine then
        local path = hs.application.pathForBundleID(rules.bundleID)
        if path then
            run(rules.commandLine:gsub("{{app}}", quote(path)))
        end
    else
        open(rules.bundleID)
    end
end

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "b",
    function()
        open("com.apple.calculator")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "c",
    function()
        openNewWindow(apps.textEditor)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "c",
    function()
        open("com.microsoft.VSCode", homePath("/Code/lk-platform/lk-platform.code-workspace"))
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
        openNewWindow(apps.fileManager)
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "g",
    function()
        open("com.sublimemerge")
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd", "shift"},
    "g",
    function()
        run("/opt/homebrew/bin/git-cola --prompt", true)
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
        run("/opt/lk-scripts/bin/lk-note-open.sh")
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
    {"ctrl", "cmd"},
    "s",
    function()
        runInTerminal(scriptPath("sync-files"))
    end
)

hs.hotkey.bind(
    {"ctrl", "cmd"},
    "t",
    function()
        openNewWindow(apps.terminal)
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
        run("/usr/local/bin/virt-manager", true)
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
    "x",
    function()
        hs.reload()
    end
)

hs.notify.new(
    {
        title = "Hammerspoon",
        informativeText = "Config reloaded",
        withdrawAfter = 2
    }
):send()
