local Gui = load(MakeRequest(
    "https://raw.githubusercontent.com/404Store/Lua-ImGui-Builder/refs/heads/main/imgui",
    "GET"
).content)()

local _MythNotifs = {}
local _MythPending = {}
local _MythNotifId = 0

local TYPES = {
    success = { icon = ":check-circle:", color = 0xFF66CC66, title = "SUCCESS" },
    info    = { icon = ":info-circle:",  color = 0xFF66AAFF, title = "INFO" },
    warn    = { icon = ":exclamation-triangle:", color = 0xFFFFAA00, title = "WARNING" },
    error   = { icon = ":times-circle:", color = 0xFFFF5555, title = "ERROR" },
    system  = { icon = ":cog:",          color = 0xFFCC88FF, title = "SYSTEM" },
    chat    = { icon = ":comments:",     color = 0xFF88CC88, title = "CHAT" },
}

local function applyAlpha(color, alpha)
    local b = color % 256
    local g = math.floor(color / 256) % 256
    local r = math.floor(color / 65536) % 256
    local a = math.floor(color / 16777216) % 256
    local na = math.floor(a * alpha)
    return na * 16777216 + r * 65536 + g * 256 + b
end

local function clamp01(v)
    if v < 0 then return 0 elseif v > 1 then return 1 end
    return v
end

local function shiftCursor(win, dx)
    if dx <= 0 then return end
    pcall(function()
        local cx = select(1, win:GetCursorPos())
        win:SetCursorPosX(cx + dx)
    end)
end

local function PlayClickSound()
    SendVariantList({
        [0] = "OnAddNotification",
        [3] = "audio/keypad_hit.wav",
        [4] = 0
    })
end

local function spawnNotif(typeKey, message, life)
    local t = TYPES[typeKey] or TYPES.info
    _MythNotifId = _MythNotifId + 1
    _MythNotifs[#_MythNotifs + 1] = {
        id = _MythNotifId,
        icon = t.icon,
        color = t.color,
        title = t.title,
        message = message or "",
        life = life or 5.0,
        maxLife = life or 5.0,
        phase = "in",
        phaseT = 0,
        slideX = 320,
        alpha = 0,
    }
    pcall(LogToConsole, "[Mythical Notif] [" .. t.title .. "] " .. tostring(message or ""))
    PlayClickSound()
    if #_MythNotifs > 6 then
        for i = 1, #_MythNotifs do
            if _MythNotifs[i].phase ~= "out" then
                _MythNotifs[i].phase = "out"
                _MythNotifs[i].phaseT = 0
                break
            end
        end
    end
end

local function updateNotifications(dt)
    for i = #_MythPending, 1, -1 do
        local p = _MythPending[i]
        if type(p) == "table" and type(p.delay) == "number" then
            p.delay = p.delay - dt
            if p.delay <= 0 then
                spawnNotif(p.typeKey, p.message, p.life)
                table.remove(_MythPending, i)
            end
        else
            table.remove(_MythPending, i)
        end
    end

    local i = 1
    while i <= #_MythNotifs do
        local n = _MythNotifs[i]
        if type(n) == "table" and type(n.life) == "number" then
            n.phaseT = n.phaseT + dt
            if n.phase == "in" then
                local p = clamp01(n.phaseT / 0.35)
                local e = 1 - ((1 - p) ^ 3)
                n.slideX = 320 * (1 - e)
                n.alpha = p
                if p >= 1 then
                    n.phase = "idle"
                    n.phaseT = 0
                    n.slideX = 0
                    n.alpha = 1
                end
            elseif n.phase == "idle" then
                n.life = n.life - dt
                if n.life <= 0 then
                    n.phase = "out"
                    n.phaseT = 0
                end
            else
                local p = clamp01(n.phaseT / 0.3)
                n.alpha = 1 - p
                n.slideX = 260 * (p * p)
                if p >= 1 then
                    table.remove(_MythNotifs, i)
                    i = i - 1
                end
            end
            i = i + 1
        else
            table.remove(_MythNotifs, i)
        end
    end
end

local function wflag(name, num)
    local ok, v = pcall(function() return ImGui.WindowFlags[name] end)
    if ok and type(v) == "number" then return v end
    return num
end

local OVERLAY_FLAGS = wflag("NoTitleBar", 1) + wflag("NoResize", 2) + wflag("NoMove", 4)
    + wflag("NoCollapse", 32) + wflag("AlwaysAutoResize", 64) + wflag("NoSavedSettings", 256)

local function pinWindow(x, y)
    local ok = pcall(ImGui.SetNextWindowPos, x, y)
    if not ok then
        ok = pcall(function() ImGui.SetNextWindowPos({ x = x, y = y }) end)
    end
    if not ok then
        pcall(function() ImGui.SetNextWindowPos(ImVec2(x, y)) end)
    end
end

local OverlayWin = Gui.New({
    title = "Mythical Auth Notifications",
    size = {380, 120},
    pos = {12, 12},
    flags = OVERLAY_FLAGS,
    theme = {
        WindowBg = 0xE6000000, ChildBg = 0xE60A0A0A, Border = 0xFFFF0000,
        Text = 0xFFDDDDDD, Button = 0xFF7A7A7A, ButtonHovered = 0xFF979797, ButtonActive = 0xFF5E5E5E,
        FrameBg = 0xFF1C1C1C, FrameBgHovered = 0xFF282828, FrameBgActive = 0xFF333333,
        Separator = 0xFFFF0000, PlotHistogram = 0xFF8A8A8A,
    },
    style = "flat",
    OnRender = function(win)
        win:Text(":bell: NOTIFICATIONS")
        win:Separator()
        win:Spacing(2)
        for idx = 1, #_MythNotifs do
            local n = _MythNotifs[idx]
            local a = n.alpha
            local col = applyAlpha(n.color, a)
            local dim = applyAlpha(0xFFD0D0D0, a)
            local faint = applyAlpha(0xFF888888, a)
            local slide = math.max(0, n.slideX)

            shiftCursor(win, slide)
            win:Text(n.icon .. "  " .. n.title, col)
            win:SameLine(250)
            shiftCursor(win, slide)
            win:Text(string.format("%.1fs", math.max(0, n.life)), faint)

            shiftCursor(win, slide)
            win:Text(n.message, dim)

            shiftCursor(win, slide)
            local frac = clamp01(n.life / n.maxLife)
            win:PushColors({ PlotHistogram = col })
            win:ProgressBar(frac, 330, 7, "")
            win:PopColors()

            win:Spacing(2)
            win:Separator()
            win:Spacing(1)
        end
    end
})

local SERVER_URL = "https://k1wj97vqjwe0-d.space-z.ai"
local PRESET_API_KEY = ""

local BASE_SLEEP = (type(Sleep) == "function") and Sleep or function(ms) end
local REAL_RUNTHREAD = (type(RunThread) == "function") and RunThread or function() end
local REAL_ADDHOOK = (type(AddHook) == "function") and AddHook or function() end
local REAL_REMOVEHOOK = (type(RemoveHook) == "function") and RemoveHook or function() end
local REAL_RUNDELAYED = (type(RunDelayed) == "function") and RunDelayed or function() end
local unpackFn = unpack or table.unpack

local liveLog = {}
local LIVE_LOG_MAX = 250
local liveTagColors = {
    INFO = 0xFFAAAAAA, AUTH = 0xFF66FF66, SERVER = 0xFF00AAFF, SYSTEM = 0xFF66AAFF,
    NETWORK = 0xFF88CCFF, SCRIPT = 0xFF66CCAA, ERROR = 0xFFFF5555, WARN = 0xFFFFAA00,
    SAVE = 0xFF88FF88, AI = 0xFFCC88FF, SCAN = 0xFF00FFCC, CHAT = 0xFF88CC88,
    RESTART = 0xFF66FFCC,
}

local function pushLog(tag, msg)
    tag = tostring(tag or "INFO")
    msg = tostring(msg or "")
    local sT, tTime = pcall(os.date, "%H:%M:%S")
    liveLog[#liveLog + 1] = {
        t = (sT and tTime) or "??:??:??",
        tag = tag,
        m = msg,
        c = liveTagColors[tag] or 0xFFAAAAAA
    }
    if #liveLog > LIVE_LOG_MAX then
        table.remove(liveLog, 1)
    end
    pcall(LogToConsole, "[Mythical] [" .. tag .. "] " .. msg)
end

local function apiRequest(path, method, body)
    method = method or "GET"
    local url = SERVER_URL .. path
    if PRESET_API_KEY ~= "" and not url:find("apiKey=", 1, true) then
        url = url .. (url:find("?", 1, true) and "&" or "?") .. "apiKey=" .. PRESET_API_KEY
    end
    local ok, res = pcall(MakeRequest, url, method, {}, body or "")
    if not ok or not res then return nil end
    return res
end

local function apiPost(path, body)
    return apiRequest(path, "POST", body)
end

local function apiGet(path)
    return apiRequest(path, "GET")
end

local function jsonField(json, field)
    if not json then return nil end
    local v = json:match('"' .. field .. '"%s*:%s*"([^"]*)"')
    if v then return v end
    local n = json:match('"' .. field .. '"%s*:%s*([%-%d%.]+)')
    if n then return tonumber(n) end
    local b = json:match('"' .. field .. '"%s*:%s*(true)')
    if b then return true end
    local f = json:match('"' .. field .. '"%s*:%s*(false)')
    if f then return false end
    return nil
end

local function jsonString(json, field)
    if not json then return nil end
    local pos = select(2, json:find('"' .. field .. '"%s*:%s*"'))
    if not pos then return nil end
    local out = {}
    local i = pos + 1
    local len = #json
    while i <= len do
        local c = json:sub(i, i)
        if c == '\\' then
            local n = json:sub(i + 1, i + 1)
            if n == 'n' then out[#out + 1] = '\n'
            elseif n == 't' then out[#out + 1] = '\t'
            elseif n == 'r' then out[#out + 1] = '\r'
            elseif n == '"' then out[#out + 1] = '"'
            elseif n == '\\' then out[#out + 1] = '\\'
            elseif n == '/' then out[#out + 1] = '/'
            elseif n == 'u' then
                local code = tonumber(json:sub(i + 2, i + 5), 16)
                if code then
                    if utf8 and utf8.char then
                        out[#out + 1] = utf8.char(code)
                    elseif code < 256 then
                        out[#out + 1] = string.char(code)
                    else
                        out[#out + 1] = '?'
                    end
                end
                i = i + 4
            else
                out[#out + 1] = n
            end
            i = i + 2
        elseif c == '"' then
            return table.concat(out)
        else
            out[#out + 1] = c
            i = i + 1
        end
    end
    return nil
end

local function getServerMessage(content)
    if type(content) ~= "string" then return "unknown" end
    local msg = jsonString(content, "reason") or jsonString(content, "message") or jsonString(content, "error") or jsonString(content, "msg")
    if msg then return msg end
    local err = content:match('"error"%s*:%s*"([^"]*)"')
    if err then return err end
    local mess = content:match('"message"%s*:%s*"([^"]*)"')
    if mess then return mess end
    return "unknown"
end

local function findJsonArray(text, key)
    if not text then return nil end
    local keyPos = text:find('"' .. key .. '"', 1, true)
    if not keyPos then return nil end
    local colonPos = text:find(":", keyPos + #key + 2, true)
    if not colonPos then return nil end
    local i = colonPos + 1
    while i <= #text and text:sub(i, i) == " " do i = i + 1 end
    if text:sub(i, i) ~= "[" then return nil end
    local depth = 0
    local inStr = false
    local j = i
    while j <= #text do
        local c = text:sub(j, j)
        if inStr then
            if c == '\\' then
                j = j + 1
            elseif c == '"' then
                inStr = false
            end
        else
            if c == '"' then
                inStr = true
            elseif c == '[' then
                depth = depth + 1
            elseif c == ']' then
                depth = depth - 1
                if depth == 0 then
                    return text:sub(i + 1, j - 1)
                end
            end
        end
        j = j + 1
    end
    return nil
end

local function extractJsonObjects(text)
    local objects = {}
    if not text then return objects end
    local i = 1
    local len = #text
    while i <= len do
        local bs = text:find("{", i, true)
        if not bs then break end
        local depth = 0
        local inStr = false
        local j = bs
        local found = false
        while j <= len do
            local c = text:sub(j, j)
            if inStr then
                if c == '\\' then
                    j = j + 1
                elseif c == '"' then
                    inStr = false
                end
            else
                if c == '"' then
                    inStr = true
                elseif c == '{' then
                    depth = depth + 1
                elseif c == '}' then
                    depth = depth - 1
                    if depth == 0 then
                        found = true
                        break
                    end
                end
            end
            j = j + 1
        end
        if found then
            table.insert(objects, text:sub(bs, j))
            i = j + 1
        else
            break
        end
    end
    return objects
end

local function escapeJson(s)
    s = tostring(s or "")
    s = s:gsub('\\', '\\\\'):gsub('"', '\\"'):gsub('\n', '\\n'):gsub('\r', '\\r')
    return '"' .. s .. '"'
end

local function unescapeJson(s)
    if not s then return nil end
    s = s:gsub('\\n', '\n')
    s = s:gsub('\\t', '\t')
    s = s:gsub('\\r', '\r')
    s = s:gsub('\\"', '"')
    s = s:gsub('\\/', '/')
    s = s:gsub('\\\\', '\\')
    return s
end

local function repairDoubleEncoded(code)
    if type(code) ~= "string" then return code end
    local head = code:sub(1, 64)
    if not head:find("\\\\%d%d%d") then return code end
    local repaired = unescapeJson(code)
    local loader = loadstring or load
    if type(loader) ~= "function" then return code end
    local okR, chunkR = pcall(loader, repaired)
    if okR and chunkR then
        return repaired
    end
    return code
end

local function extractScriptBody(content)
    if type(content) ~= "string" or content == "" then return nil end
    local trimmed = content:match("^%s*(.-)%s*$") or content
    local first = trimmed:sub(1, 1)
    if first == "<" then return nil end
    if first == "{" then
        local code = jsonString(trimmed, "code") or jsonString(trimmed, "content")
            or jsonString(trimmed, "script") or jsonString(trimmed, "source")
            or jsonString(trimmed, "body") or jsonString(trimmed, "lua")
            or jsonString(trimmed, "data") or jsonString(trimmed, "file")
            or jsonString(trimmed, "raw") or jsonString(trimmed, "text")
        if code and code ~= "" then
            return repairDoubleEncoded(code)
        end
        local url = jsonString(trimmed, "url") or jsonString(trimmed, "link")
            or jsonString(trimmed, "rawUrl") or jsonString(trimmed, "sourceUrl")
        if url and url:find("^https?://") then
            return url
        end
        local loader = loadstring or load
        if type(loader) == "function" then
            local okC, chunk = pcall(loader, trimmed)
            if okC and chunk then
                return trimmed
            end
        end
        return nil
    end
    if trimmed:find('"error"', 1, true) and #trimmed < 200 then
        return nil
    end
    return repairDoubleEncoded(trimmed)
end

local function fetchPublicIP()
    local ip = nil
    local sReq, res = pcall(MakeRequest, "https://api.ipify.org", "GET")
    if sReq and res and type(res.content) == "string" then
        local c = res.content:gsub("%s+", "")
        if c ~= "" and #c <= 45 and not c:find("<", 1, true) then
            ip = c
        end
    end
    if not ip then
        local sReq2, res2 = pcall(MakeRequest, "https://icanhazip.com", "GET")
        if sReq2 and res2 and type(res2.content) == "string" then
            local c = res2.content:gsub("%s+", "")
            if c ~= "" and #c <= 45 and not c:find("<", 1, true) then
                ip = c
            end
        end
    end
    return ip
end

local function getSystemInfo()
    local os_name = "Unknown"
    local sJit, j = pcall(function() return jit end)
    if sJit and j and j.os and j.arch then
        if j.os == "Windows" then
            os_name = "Windows"
        elseif j.os == "Linux" then
            local is_android = os.getenv("ANDROID_ROOT") or os.getenv("ANDROID_DATA")
            os_name = is_android and "Android" or "Linux"
        elseif j.os == "OSX" or j.os == "BSD" then
            os_name = "Mac/iOS/BSD"
        else
            os_name = j.os
        end
        return os_name
    end
    local sPack, p = pcall(function() return package end)
    if sPack and p and p.config then
        local sep = p.config:sub(1,1)
        if sep == "\\" then os_name = "Windows"
        else
            os_name = os.getenv("ANDROID_ROOT") and "Android" or "Linux/Mac"
        end
    end
    return os_name
end

local detectedOS = getSystemInfo()
local isAndroid = detectedOS == "Android"
local isWindows = detectedOS == "Windows"
local PATH_SEP = isWindows and "\\" or "/"
local projectBasePath = isAndroid and "/storage/emulated/0/Android/media/com.rtsoft.growtopia/scripts/FolderProject" or "FolderProject"
local MANIFEST_NAME = "_manifest.txt"
local manifestPath = projectBasePath .. PATH_SEP .. MANIFEST_NAME

local UI_CFG = {}

if isAndroid then
    UI_CFG.MainW = 1420
    UI_CFG.MainH = 700
    UI_CFG.MainX = 30
    UI_CFG.MainY = 40
    UI_CFG.NavBtnW = 150
    UI_CFG.NavBtnH = 62
    UI_CFG.NavVisible = 6
    UI_CFG.NavArrowW = 46
    UI_CFG.NavGap = 6
    UI_CFG.BackW = 200
    UI_CFG.BackH = 38
else
    UI_CFG.MainW = 1560
    UI_CFG.MainH = 780
    UI_CFG.MainX = 30
    UI_CFG.MainY = 40
    UI_CFG.NavBtnW = 170
    UI_CFG.NavBtnH = 84
    UI_CFG.NavVisible = 8
    UI_CFG.NavArrowW = 56
    UI_CFG.NavGap = 8
    UI_CFG.BackW = 220
    UI_CFG.BackH = 44
end

UI_CFG.NavW = UI_CFG.NavArrowW * 2 + UI_CFG.NavGap * (UI_CFG.NavVisible + 1) + UI_CFG.NavBtnW * UI_CFG.NavVisible
UI_CFG.NavH = UI_CFG.NavBtnH + 16
UI_CFG.NavX = math.max(10, UI_CFG.MainX + math.floor((UI_CFG.MainW - UI_CFG.NavW) / 2))
UI_CFG.NavY = UI_CFG.MainY

local UI_THEME = {
    WindowBg = 0xFF000000, ChildBg = 0xFF0D0D0D, Border = 0xFFFF0000,
    Text = 0xFFE6E6E6, Button = 0xFF7A7A7A, ButtonHovered = 0xFF979797, ButtonActive = 0xFF5E5E5E,
    FrameBg = 0xFF1C1C1C, FrameBgHovered = 0xFF282828, FrameBgActive = 0xFF333333,
    TitleBg = 0xFF000000, TitleBgActive = 0xFF0D0D0D, TitleBgCollapsed = 0xFF000000,
    Separator = 0xFFFF0000, SeparatorHovered = 0xFFFF4040, SeparatorActive = 0xFFFF6060,
    PlotHistogram = 0xFF8A8A8A,
}

local UI_STYLE = {
    WindowBorderSize = 2,
    FrameBorderSize = 1,
    WindowRounding = 8,
    ChildRounding = 6,
    FrameRounding = 4,
    PopupRounding = 6,
    GrabRounding = 4,
    WindowPadding = {10, 10},
    FramePadding = {8, 6},
    ItemSpacing = {6, 6},
}

local currentFeature = "menu"
local projectSubView = "tree"
local serverSubView = "server"
local navScroll = 1
local scriptPage = 1
local searchFolder = ""
local aiInput = ""
local aiOutput = ""
local activeFileName = ""
local activeFileFolder = ""
local editorContent = ""
local bugReportText = ""

local isLoggedIn = false
local currentLoginUI = 1
local isRegistering = false
local loginUsername = ""
local loginPassword = ""
local regUsername = ""
local regPassword = ""
local regConfirmPass = ""
local accountData = {
    username = "Guest", password = "None", loginTime = "N/A", timeZone = "N/A",
    ip = "Loading...", os = "Unknown", apiKey = ""
}

local scriptList = {}
local runningServerScripts = {}

local categories = {"All", "Farming", "Scanner", "Utility", "Fishing"}
local filterCatIdx = 0
local searchScriptName = ""

local alerts = {}
local seenNotifs = {}

local folders = {}
local runningFiles = {}
local selectedFileKey = ""
local newFolderName = ""
local newDocName = ""
local newDocCode = ""
local openCreateFolderModal = false

local publicChatMsgs = {}
local chatInput = ""
local viewProfileData = nil
local openProfileModal = false

local aiModelName = "AI Model V 1.0"
local tokenUsedToday = 0
local tokenDailyLimit = 0

local scriptsFetchTime = 0
local scriptsFetching = false
local scriptsFailCount = 0
local lastScriptsRaw = nil

local alertsFetchTime = 0
local alertsFailCount = 0
local alertsFetching = false
local lastAlertsRaw = nil

local chatFetchTime = 0
local chatFetching = false
local chatFailCount = 0
local lastChatRaw = nil

local tokenFetchTime = 0
local tokenFetching = false
local aiSending = false

local serverInfo = { online = false, ping = 0, region = "Asia", lastCheck = 0, checking = false }
local restartInfo = { lastRestartId = nil, currentRestartId = nil, seen = false, sawRestarting = false, sawOffline = false }
local restartPopup = { active = false, timer = 0, reason = "", forceClose = false }
local restartDetected = false

local userMonitor = {
    fetchTime = 0, fetching = false, users = {}, lastUpdate = "-", liveDot = 0, fetchedOnce = false,
}

local function formatLastSeen(user)
    local ls = user.lastSeen
    if ls == nil then return "-" end
    if type(ls) == "string" then
        if ls ~= "" then return ls end
        return "-"
    end
    if type(ls) == "number" then
        if ls > 1000000000 then
            local diff = os.time() - ls
            if diff < 0 then diff = 0 end
            if diff < 60 then return diff .. "s ago" end
            if diff < 3600 then return math.floor(diff / 60) .. "m ago" end
            if diff < 86400 then return math.floor(diff / 3600) .. "h ago" end
            return math.floor(diff / 86400) .. "d ago"
        end
        if ls < 60 then return math.floor(ls) .. "s ago" end
        if ls < 3600 then return math.floor(ls / 60) .. "m ago" end
        return math.floor(ls / 3600) .. "h ago"
    end
    return "-"
end

local function parseUserFromObject(obj)
    local name = jsonString(obj, "username") or jsonString(obj, "user")
        or jsonString(obj, "name") or jsonString(obj, "player")
    if not name or name == "" then return nil end
    local ping = jsonField(obj, "ping") or jsonField(obj, "latency")
    local online = jsonField(obj, "online")
    if online == nil then online = jsonField(obj, "isOnline") end
    local lastSeen = jsonField(obj, "lastSeen") or jsonField(obj, "lastseen")
        or jsonField(obj, "lastActive") or jsonField(obj, "lastSeenAgo")
    if type(online) ~= "boolean" then online = true end
    return { username = name, ping = (type(ping) == "number") and ping or nil, online = online, lastSeen = lastSeen }
end

local function parseUsersResponse(content)
    if type(content) ~= "string" or content == "" then return nil end
    local arr = findJsonArray(content, "users") or findJsonArray(content, "onlineUsers")
    or findJsonArray(content, "data") or findJsonArray(content, "accounts")
    if not arr then return nil end
    local users = {}
    for _, obj in ipairs(extractJsonObjects(arr)) do
        local u = parseUserFromObject(obj)
        if u then users[#users + 1] = u end
    end
    if #users == 0 then return nil end
    return users
end

local function fetchUserMonitorData()
    if userMonitor.fetching then return end
    userMonitor.fetching = true
    pcall(REAL_RUNTHREAD, function()
        local users = nil
        local res = apiGet("/api/loader/users")
        if res and res.content and res.content ~= "" then
            users = parseUsersResponse(res.content)
        end
        if not users then
            local res2 = apiGet("/api/loader/users/online")
            if res2 and res2.content and res2.content ~= "" then
                users = parseUsersResponse(res2.content)
            end
        end
        if not users then
            local res3 = apiGet("/api/loader/heartbeat")
            if res3 and res3.content and res3.content ~= "" then
                users = parseUsersResponse(res3.content)
                if not users then
                    local onlineCount = jsonField(res3.content, "onlineUsers") or jsonField(res3.content, "online") or jsonField(res3.content, "usersOnline")
                    if type(onlineCount) == "number" then
                        users = {}
                        for i = 1, math.min(onlineCount, 50) do
                            users[i] = { username = "User_" .. i, ping = nil, online = true, lastSeen = nil }
                        end
                    end
                end
            end
        end
        if users then
            userMonitor.users = users
            local sT, tT = pcall(os.date, "%H:%M:%S")
            userMonitor.lastUpdate = (sT and tT) or "-"
            userMonitor.fetchedOnce = true
        end
        userMonitor.fetching = false
    end)
end

local function showRestartPopup(reason)
    restartPopup.active = true
    restartPopup.timer = 5.0
    restartPopup.reason = tostring(reason or "Server successfully restarted.")
    restartDetected = true
    pushLog("RESTART", "SERVER RESTART detected — " .. restartPopup.reason)
    spawnNotif("system", "Server Restart: " .. restartPopup.reason, 5.0)
end

local function processRestartResponse(content)
    local rid = jsonField(content, "restartId")
    local status = jsonField(content, "status")
    if type(rid) == "number" then
        restartInfo.currentRestartId = rid
        if restartInfo.lastRestartId == nil then
            restartInfo.lastRestartId = rid
            restartInfo.seen = true
        elseif rid ~= restartInfo.lastRestartId then
            local wasDown = restartInfo.sawRestarting or restartInfo.sawOffline
            restartInfo.lastRestartId = rid
            restartInfo.sawRestarting = false
            restartInfo.sawOffline = false
            showRestartPopup(wasDown and "Server successfully restarted." or "restartId changed: " .. tostring(rid))
        end
    end
    if status == "restarting" and not restartInfo.sawRestarting then
        restartInfo.sawRestarting = true
        pushLog("RESTART", "Status: restarting — server is restarting...")
    end
end

local function checkServerConnection()
    if serverInfo.checking then return end
    serverInfo.checking = true
    pcall(REAL_RUNTHREAD, function()
        local wasOnline = serverInfo.online
        local t0 = os.clock()
        local ok, res = pcall(MakeRequest, SERVER_URL, "GET")
        local ms = math.floor((os.clock() - t0) * 1000)
        if ok and res then
            serverInfo.online = true
            serverInfo.ping = ms
            if res.content and #res.content < 500 then
                local region = jsonField(res.content, "region")
                if region and type(region) == "string" and #region > 0 and #region <= 20 then
                    serverInfo.region = region
                end
                processRestartResponse(res.content)
            end
            if not wasOnline then
                if restartInfo.sawRestarting or restartInfo.sawOffline then
                    pushLog("SERVER", "Server back online after restart (" .. ms .. " ms)")
                    restartInfo.sawOffline = false
                else
                    pushLog("SERVER", "Connection established (" .. ms .. " ms)")
                end
            end
        else
            serverInfo.online = false
            serverInfo.ping = 0
            if wasOnline then
                if restartInfo.sawRestarting then
                    restartInfo.sawOffline = true
                    pushLog("RESTART", "Server temporarily down (restart in progress)")
                else
                    pushLog("ERROR", "Server unreachable")
                end
            else
                restartInfo.sawOffline = true
            end
        end
        serverInfo.checking = false
    end)
end

local function refreshTokenStatus()
    if PRESET_API_KEY == "" or tokenFetching then return end
    tokenFetching = true
    pcall(REAL_RUNTHREAD, function()
        local ping = math.floor((os.clock() * 1000) % 200) + 20
        local t0 = os.clock()
        local res = apiPost("/api/loader/heartbeat", '{"ping":' .. ping .. ',"os":"' .. accountData.os .. '","ip":' .. escapeJson(accountData.ip) .. '}')
        if res and res.content then
            serverInfo.online = true
            serverInfo.ping = math.floor((os.clock() - t0) * 1000)
            processRestartResponse(res.content)
            local model = jsonField(res.content, "model")
            if model then aiModelName = model end
            local used = jsonField(res.content, "tokensUsed") or jsonField(res.content, "used")
            if used then tokenUsedToday = tonumber(used) or tokenUsedToday end
            local limit = jsonField(res.content, "tokenLimit") or jsonField(res.content, "limit")
            if limit then tokenDailyLimit = tonumber(limit) or tokenDailyLimit end
            local region = jsonField(res.content, "region")
            if region and type(region) == "string" and #region > 0 and #region <= 20 then
                serverInfo.region = region
            end
        elseif res == nil then
            serverInfo.online = false
            serverInfo.ping = 0
        end
        tokenFetching = false
    end)
end

local function toggleServerScriptId(sid)
    if not sid or sid == "" then return end
    pcall(REAL_RUNTHREAD, function()
        apiPost("/api/loader/scripts/" .. tostring(sid) .. "/toggle", "")
    end)
end

local function scriptSid(scr)
    return tostring(scr and (scr.id or scr.name) or "")
end

local savedRunThread, savedAddHook = nil, nil
local hookSwapOwner = nil

local function installGlobalHookSwap(state)
    if hookSwapOwner ~= nil then return end
    hookSwapOwner = state
    savedRunThread, savedAddHook = RunThread, AddHook
    RunThread = function(fn, ...)
        local n = select("#", ...)
        local args = {...}
        state.bgThreads = (state.bgThreads or 0) + 1
        return savedRunThread(function()
            local okT, errT = pcall(fn, unpackFn(args, 1, n))
            state.bgThreads = math.max(0, (state.bgThreads or 1) - 1)
            if not okT and not state.stop then
                pcall(LogToConsole, "[Mythical] BG thread error: " .. tostring(errT))
            end
        end)
    end
    AddHook = function(hookName, label, cb)
        local wrapped = function(...)
            if state.stop then return nil end
            return cb(...)
        end
        local okH, res = pcall(savedAddHook, hookName, label, wrapped)
        if okH and res ~= false then
            state.hookLabels = state.hookLabels or {}
            table.insert(state.hookLabels, label)
        end
        if okH then return res end
        return nil
    end
end

local function restoreGlobalHookSwap(state)
    if hookSwapOwner ~= state then return end
    RunThread = savedRunThread
    AddHook = savedAddHook
    savedRunThread, savedAddHook = nil, nil
    hookSwapOwner = nil
end

local function buildScriptEnv(state)
    local env = setmetatable({}, { __index = _G })
    env.Sleep = function(ms)
        if state.stop then error("SCRIPT_STOPPED", 0) end
        return BASE_SLEEP(ms)
    end
    env.RunThread = function(fn, ...)
        local n = select("#", ...)
        local args = {...}
        state.bgThreads = (state.bgThreads or 0) + 1
        return REAL_RUNTHREAD(function()
            local okT, errT = pcall(fn, unpackFn(args, 1, n))
            state.bgThreads = math.max(0, (state.bgThreads or 1) - 1)
            if not okT and not state.stop then
                pcall(LogToConsole, "[Mythical] BG thread error: " .. tostring(errT))
            end
        end)
    end
    env.AddHook = function(hookName, label, cb)
        local wrapped = function(...)
            if state.stop then return nil end
            return cb(...)
        end
        local okH, res = pcall(REAL_ADDHOOK, hookName, label, wrapped)
        if okH and res ~= false then
            state.hookLabels = state.hookLabels or {}
            table.insert(state.hookLabels, label)
        end
        if okH then return res end
        return nil
    end
    return env
end

local function compileWithEnv(code, name, state)
    local env = buildScriptEnv(state)
    local chunk, err
    if type(setfenv) == "function" and type(loadstring) == "function" then
        local okC, c, e = pcall(loadstring, code, name)
        if okC then
            chunk, err = c, e
            if chunk then pcall(setfenv, chunk, env) end
        else
            err = tostring(c)
        end
    elseif type(load) == "function" then
        local okC, c, e = pcall(load, code, name, "t", env)
        if okC then
            chunk, err = c, e
        else
            err = tostring(c)
        end
    elseif type(loadstring) == "function" then
        local okC, c, e = pcall(loadstring, code, name)
        if okC then
            chunk, err = c, e
        else
            err = tostring(c)
        end
    else
        err = "load function not available"
    end
    return chunk, err
end

local function removeStateHooks(state)
    if state.hookLabels then
        for _, label in ipairs(state.hookLabels) do
            pcall(REAL_REMOVEHOOK, label)
        end
        state.hookLabels = nil
    end
end

local function escalateStopCheck(state, displayName)
    pcall(REAL_RUNDELAYED, 3000, function()
        pcall(function()
            if state.stop and (state.mainRunning or (state.bgThreads or 0) > 0) then
                pushLog("WARN", "Stop Warning: " .. tostring(displayName) .. " not responding to stop (loop without Sleep).")
            end
        end)
    end)
end

local function stopServerScriptBySid(sid, name)
    if not sid or sid == "" then return end
    local state = runningServerScripts[sid]
    if state then
        state.stop = true
        removeStateHooks(state)
        runningServerScripts[sid] = nil
        for _, s in ipairs(scriptList) do
            if scriptSid(s) == sid then s.running = false end
        end
        escalateStopCheck(state, name or state.name or sid)
        pushLog("SCRIPT", tostring(name or state.name or sid) .. " stopped & hooks cleaned!")
    else
        pushLog("WARN", tostring(name or sid) .. " is not running!")
    end
end

local function stopServerScript(scr)
    if not scr then return end
    local sid = scriptSid(scr)
    stopServerScriptBySid(sid, tostring(scr.name))
    toggleServerScriptId(sid)
end

local function looksLikeHttpError(s)
    if type(s) ~= "string" then return true end
    local head = s:sub(1, 160):gsub("^%s+", "")
    if head:find("^404") or head:find("^400") or head:find("^429") then return true end
    if head:find("<!DOCTYPE", 1, true) or head:find("<html", 1, true) then return true end
    if head:find('"error"', 1, true) and #s < 300 then return true end
    return false
end

local function fetchRawGithub(u)
    if type(u) ~= "string" then return nil end
    u = u:gsub("^%s+", ""):gsub("%s+$", "")
    if not u:find("^https?://") then return nil end
    local okU, resU = pcall(MakeRequest, u, "GET")
    if okU and resU and type(resU.content) == "string" and resU.content ~= "" then
        if looksLikeHttpError(resU.content) then
            pushLog("NETWORK", "Raw link error (404/HTML): " .. u)
            return nil
        end
        return resU.content:gsub("^\239\187\191", "")
    end
    return nil
end

local function runServerScript(scr)
    if not scr then return false end
    local sid = scriptSid(scr)
    if sid == "" then
        pushLog("ERROR", "Script Error: Script has no id from server!")
        return false
    end
    if runningServerScripts[sid] then
        pushLog("WARN", tostring(scr.name) .. " is already running!")
        return false
    end
    local state = {
        stop = false, runTime = 0, name = tostring(scr.name or sid), sid = sid, id = scr.id,
        bgThreads = 0, hookLabels = nil, mainRunning = false, phase = "fetch", globalRun = true
    }
    runningServerScripts[sid] = state
    scr.running = true
    toggleServerScriptId(sid)
    pushLog("NETWORK", "Fetching: Retrieving script content '" .. tostring(scr.name) .. "' from server...")
    pcall(REAL_RUNTHREAD, function()
        local code = nil
        local sourceUrl = scr.url
        if sourceUrl then
            code = fetchRawGithub(sourceUrl)
            if not code then
                pushLog("NETWORK", "Direct link failed for '" .. tostring(scr.name) .. "', falling back to server endpoint...")
            end
        end
        if not code or code == "" then
            local res = apiGet("/api/loader/scripts/" .. sid)
            if res and res.content then
                local extracted = extractScriptBody(res.content)
                if extracted and extracted ~= "" then
                    if extracted:find("^%s*https?://") then
                        code = fetchRawGithub(extracted)
                    else
                        code = extracted
                    end
                end
            end
        end
        if not code or code == "" then
            runningServerScripts[sid] = nil
            scr.running = false
            toggleServerScriptId(sid)
            pushLog("ERROR", "Server did not send script content for '" .. tostring(scr.name) .. "'!")
            return
        end
        scr.code = code
        local chunk, err
        local loader = loadstring or load
        if type(loader) == "function" then
            local okC, c, e = pcall(loader, code, "@" .. tostring(scr.name or sid))
            if okC then
                chunk, err = c, e
            else
                err = tostring(c)
            end
        else
            err = "load function not available"
        end
        if not chunk then
            runningServerScripts[sid] = nil
            scr.running = false
            toggleServerScriptId(sid)
            pushLog("ERROR", "Compile Error: " .. tostring(err))
            return
        end
        installGlobalHookSwap(state)
        pushLog("SCRIPT", tostring(scr.name) .. " fetched from server & started!")
        state.mainRunning = true
        state.phase = "main"
        local ok, runErr = pcall(chunk)
        state.mainRunning = false
        state.phase = "ran"
        restoreGlobalHookSwap(state)
        if state.stop then
            return
        end
        if not ok then
            runningServerScripts[sid] = nil
            scr.running = false
            toggleServerScriptId(sid)
            pushLog("ERROR", "Runtime Error: " .. tostring(runErr))
            return
        end
        if (state.bgThreads > 0) or (state.hookLabels and #state.hookLabels > 0) then
            pushLog("SCRIPT", tostring(scr.name) .. " is running in background, press STOP to stop.")
        else
            runningServerScripts[sid] = nil
            scr.running = false
            toggleServerScriptId(sid)
            pushLog("SCRIPT", tostring(scr.name) .. " finished execution.")
        end
    end)
    return true
end

local function rgba(r, g, b, a)
    a = a or 255
    local rr = math.min(255, math.max(0, math.floor(r)))
    local gg = math.min(255, math.max(0, math.floor(g)))
    local bb = math.min(255, math.max(0, math.floor(b)))
    return a * 0x1000000 + rr * 0x10000 + gg * 0x100 + bb
end

local function getStatusColor(status)
    if status == "Active" then return 0xFF00FF00
    elseif status == "Wait For Update" then return 0xFFFFFF00
    elseif status == "Bug Wait Fix" then return 0xFFFF0000
    elseif status == "Offline" then return 0xFFAAAAAA
    end
    return 0xFFFFFFFF
end

local function sanitizeName(name, defaultName)
    local clean = tostring(name or "")
    clean = clean:gsub("[^%w%.%-_]", "_")
    clean = clean:gsub("%.%.+", ".")
    clean = clean:gsub("^%.+", "")
    clean = clean:gsub("%.+$", "")
    if clean == "" then clean = defaultName end
    return clean
end

local function sanitizeFolderPath(path, defaultName)
    local p = tostring(path or "")
    if p == "" then return defaultName and "" or "" end
    local segs = {}
    for seg in p:gmatch("[^/]+") do
        segs[#segs + 1] = sanitizeName(seg, "NewFolder")
    end
    if #segs == 0 then return "" end
    return table.concat(segs, "/")
end

local function upsertFolderEntry(folderName, fileName)
    for _, f in ipairs(folders) do
        if f.name == folderName then
            local exists = false
            for _, ef in ipairs(f.files) do
                if ef == fileName then exists = true end
            end
            if not exists then table.insert(f.files, fileName) end
            f.count = #f.files
            return f
        end
    end
    local entry = {name = folderName, count = 1, files = {fileName}}
    table.insert(folders, entry)
    return entry
end

local function createDir(path)
    if isWindows then
        local cur = ""
        for seg in tostring(path):gmatch("[^\\/]+") do
            if cur == "" then
                cur = seg
            else
                cur = cur .. "\\" .. seg
            end
            os.execute('mkdir "' .. cur .. '" >nul 2>&1')
        end
    else
        os.execute('mkdir -p "' .. path .. '" >/dev/null 2>&1')
    end
end

local folderAccessPath = ""
local savedAccountPath = ""
local savedAccountAutoLogin = false

local function isWritablePath(path)
    if type(path) ~= "string" or path == "" then return false end
    local testPath = path .. PATH_SEP .. ".mythical_write_test"
    local ok = false
    pcall(function()
        local fh = io.open(testPath, "w")
        if fh then
            fh:write("1")
            fh:close()
            os.remove(testPath)
            ok = true
        end
    end)
    return ok
end

local function setupFolderAccessPath()
    local localAppData = os.getenv("LOCALAPPDATA") or ""
    local userProfile = os.getenv("USERPROFILE") or os.getenv("HOME") or ""
    if isWindows then
        local candidates = {}
        if localAppData ~= "" then
            candidates[#candidates + 1] = localAppData
        end
        if userProfile ~= "" then
            candidates[#candidates + 1] = userProfile .. "\\AppData\\Local"
            candidates[#candidates + 1] = userProfile .. "\\AppData\\Roaming"
        end
        local chosen = candidates[1] or (userProfile ~= "" and userProfile or "C:\\Users\\Public")
        for _, base in ipairs(candidates) do
            local pth = base .. "\\Growtopia\\scripts\\FolderAcces"
            pcall(createDir, base .. "\\Growtopia")
            pcall(createDir, base .. "\\Growtopia\\scripts")
            pcall(createDir, pth)
            if isWritablePath(pth) then
                chosen = base
                folderAccessPath = pth
                break
            end
        end
        if folderAccessPath == "" then
            folderAccessPath = chosen .. "\\Growtopia\\scripts\\FolderAcces"
            pcall(createDir, chosen .. "\\Growtopia")
            pcall(createDir, chosen .. "\\Growtopia\\scripts")
            pcall(createDir, folderAccessPath)
        end
    else
        folderAccessPath = "/storage/emulated/0/Android/media/com.rtsoft.growtopia/script/FolderAcces"
        pcall(createDir, folderAccessPath)
    end
    savedAccountPath = folderAccessPath .. PATH_SEP .. "saved_account.dat"
end

local function encodeSavedValue(value)
    value = tostring(value or "")
    local out = {}
    for i = 1, #value do
        out[#out + 1] = string.format("%02X", (string.byte(value, i) + 17) % 256)
    end
    return table.concat(out)
end

local function decodeSavedValue(value)
    if type(value) ~= "string" then return "" end
    local out = {}
    for hex in value:gmatch("%x%x") do
        local n = tonumber(hex, 16)
        if n then out[#out + 1] = string.char((n - 17) % 256) end
    end
    return table.concat(out)
end

local function saveAccountCredentials(username, password)
    if type(username) ~= "string" or username == "" then return false end
    if type(password) ~= "string" or password == "" then return false end
    if savedAccountPath == "" then setupFolderAccessPath() end
    local ok = false
    pcall(function()
        local fh = io.open(savedAccountPath, "w")
        if not fh then error("saved account open failed") end
        fh:write("version=1\n")
        fh:write("username=" .. encodeSavedValue(username) .. "\n")
        fh:write("password=" .. encodeSavedValue(password) .. "\n")
        fh:close()
        ok = true
    end)
    if ok then pushLog("SAVE", "Login account saved locally.") end
    return ok
end

local function loadSavedAccountCredentials()
    if savedAccountPath == "" then setupFolderAccessPath() end
    local username, password
    pcall(function()
        local fh = io.open(savedAccountPath, "r")
        if not fh then return end
        for line in fh:lines() do
            local k, v = line:match("^([^=]+)=(.*)$")
            if k == "username" then
                username = decodeSavedValue(v)
            elseif k == "password" then
                password = decodeSavedValue(v)
            end
        end
        fh:close()
    end)
    if username and username ~= "" and password and password ~= "" then
        return username, password
    end
    return nil, nil
end

local function clearSavedAccountCredentials()
    if savedAccountPath == "" then setupFolderAccessPath() end
    pcall(os.remove, savedAccountPath)
    pushLog("SAVE", "Local saved account removed.")
end

setupFolderAccessPath()

local function fileExistsOnDisk(folderName, fileName)
    local ok = false
    pcall(function()
        local basePath
        if folderName == nil or folderName == "" then
            basePath = projectBasePath
        else
            basePath = projectBasePath .. PATH_SEP .. folderName
        end
        local fh = io.open(basePath .. PATH_SEP .. fileName, "r")
        if fh then fh:close() ok = true end
    end)
    return ok
end

local function collectDiskBackedEntries()
    local entries = {}
    for _, f in ipairs(folders) do
        for _, fname in ipairs(f.files) do
            if fileExistsOnDisk(f.name, fname) then
                table.insert(entries, f.name .. "/" .. fname)
            end
        end
    end
    return entries
end

local function writeManifest()
    pcall(function()
        local fh = io.open(manifestPath, "w")
        if not fh then error("manifest open failed") end
        fh:write(table.concat(collectDiskBackedEntries(), "\n"))
        fh:close()
    end)
end

local function readManifestEntries()
    local entries = {}
    pcall(function()
        local fh = io.open(manifestPath, "r")
        if not fh then return end
        local content = fh:read("*a") or ""
        fh:close()
        for line in content:gmatch("[^\r\n]+") do
            line = line:gsub("^[%s%c]+", ""):gsub("[%s%c]+$", "")
            if line ~= "" then table.insert(entries, line) end
        end
    end)
    return entries
end

local function joinProjectPath(folder, file)
    if folder == nil then folder = "" end
    if folder == "" then
        return projectBasePath .. PATH_SEP .. file
    end
    return projectBasePath .. PATH_SEP .. folder .. PATH_SEP .. file
end

local function makeFileKey(folder, file)
    if folder == nil then folder = "" end
    if folder == "" then return file end
    return folder .. "/" .. file
end

local function writeProjectFile(folderName, fileName, content)
    folderName = sanitizeFolderPath(folderName, "")
    fileName = sanitizeName(fileName, "script.txt")
    local folderDir = projectBasePath .. PATH_SEP .. folderName
    pcall(createDir, projectBasePath)
    if folderName ~= "" then
        pcall(createDir, folderDir)
    end
    local ok = pcall(function()
        local f = io.open(joinProjectPath(folderName, fileName), "w")
        if not f then error("cannot open file") end
        f:write(content or "")
        f:close()
    end)
    if not ok then return false end
    if not fileExistsOnDisk(folderName, fileName) then return false end
    upsertFolderEntry(folderName, fileName)
    writeManifest()
    return true
end

local function readProjectFile(folderName, fileName)
    local result = nil
    pcall(function()
        local f = io.open(joinProjectPath(folderName, fileName), "r")
        if f then
            result = f:read("*a")
            f:close()
        end
    end)
    return result
end

local function openFileInEditor(folderName, fileName)
    activeFileFolder = folderName or ""
    activeFileName = fileName
    local content = readProjectFile(activeFileFolder, activeFileName)
    if content and content ~= "" then
        editorContent = content
    else
        editorContent = "local bothax = require('bothax')\n\nfunction main()\n  print('Starting script " .. fileName .. "')\n  while true do\n    Sleep(100)\n  end\nend\n\nmain()\n"
    end
    projectSubView = "editor"
end

local function runScriptFile(folderName, fileName)
    local key = makeFileKey(folderName, fileName)
    if runningFiles[key] then
        pushLog("WARN", fileName .. " is already running!")
        return false
    end
    local content = readProjectFile(folderName, fileName)
    if not content or content == "" then
        pushLog("ERROR", "File Error: " .. fileName .. " is empty or not found!")
        return false
    end
    local state = {
        stop = false, name = fileName, bgThreads = 0, hookLabels = nil,
        mainRunning = false, phase = "fetch"
    }
    local chunk, err = compileWithEnv(content, "@" .. key, state)
    if not chunk then
        pushLog("ERROR", "Compile Error: " .. tostring(err))
        return false
    end
    runningFiles[key] = state
    local okThread = pcall(REAL_RUNTHREAD, function()
        state.mainRunning = true
        state.phase = "main"
        local ok, runErr = pcall(chunk)
        state.mainRunning = false
        state.phase = "ran"
        if state.stop then
            return
        end
        if not ok then
            runningFiles[key] = nil
            pushLog("ERROR", "Runtime Error: " .. tostring(runErr))
            return
        end
        if (state.bgThreads > 0) or (state.hookLabels and #state.hookLabels > 0) then
            pushLog("SCRIPT", fileName .. " is running in background, press STOP to stop.")
        else
            runningFiles[key] = nil
            pushLog("SCRIPT", fileName .. " finished execution.")
        end
    end)
    if not okThread then
        runningFiles[key] = nil
        pushLog("ERROR", "Thread Error: Failed to run " .. fileName .. "!")
        return false
    end
    pushLog("SCRIPT", fileName .. " started!")
    return true
end

local function stopScriptFile(folderName, fileName)
    local key = makeFileKey(folderName, fileName)
    local state = runningFiles[key]
    if state then
        state.stop = true
        removeStateHooks(state)
        runningFiles[key] = nil
        escalateStopCheck(state, fileName)
        pushLog("SCRIPT", fileName .. " stopped & hooks cleaned!")
    else
        pushLog("WARN", fileName .. " is not running!")
    end
end

local function parseListingLines(text, dirsOnly)
    local entries = {}
    for line in text:gmatch("[^\r\n]+") do
        line = line:gsub("[%s%c]+$", "")
        local name = line
        if isWindows then
            if name ~= "" and name ~= "." and name ~= ".." then
                table.insert(entries, name)
            end
        else
            local isDir = name:sub(-1) == "/"
            if isDir then name = name:sub(1, -2) end
            if name ~= "" and name ~= "." and name ~= ".." and isDir == dirsOnly then
                table.insert(entries, name)
            end
        end
    end
    return entries
end

local function listDiskEntries(path, dirsOnly)
    local entries = {}
    if type(io) == "table" and type(io.popen) == "function" then
        pcall(function()
            local cmd
            if isWindows then
                if dirsOnly then
                    cmd = 'dir /b /ad "' .. path .. '" 2>nul'
                else
                    cmd = 'dir /b /a-d "' .. path .. '" 2>nul'
                end
            else
                cmd = 'ls -1p "' .. path .. '" 2>/dev/null'
            end
            local h = io.popen(cmd)
            if h then
                local out = h:read("*a")
                h:close()
                if out and out ~= "" then
                    entries = parseListingLines(out, dirsOnly)
                end
            end
        end)
    end
    if #entries == 0 then
        pcall(function()
            local tmpPath = projectBasePath .. PATH_SEP .. ".ls_tmp"
            local cmd
            if isWindows then
                if dirsOnly then
                    cmd = 'dir /b /ad "' .. path .. '" > "' .. tmpPath .. '" 2>nul'
                else
                    cmd = 'dir /b /a-d "' .. path .. '" > "' .. tmpPath .. '" 2>nul'
                end
            else
                cmd = 'ls -1p "' .. path .. '" > "' .. tmpPath .. '" 2>/dev/null'
            end
            os.execute(cmd)
            local fh = io.open(tmpPath, "r")
            if fh then
                local out = fh:read("*a")
                fh:close()
                if out and out ~= "" then
                    entries = parseListingLines(out, dirsOnly)
                end
            end
            if isWindows then
                os.execute('del /f /q "' .. tmpPath .. '" >nul 2>&1')
            else
                os.execute('rm -f "' .. tmpPath .. '" >/dev/null 2>&1')
            end
        end)
    end
    return entries
end

local TREE_MAX_DEPTH = 10

local projectTree = nil
local treeExpanded = {}
local selectedTreePath = ""
local projectTreeDirty = false

local function sortByName(a, b)
    return string.lower(a) < string.lower(b)
end

local function scanTreeLevel(rel, depth)
    local basePath
    if rel == "" then
        basePath = projectBasePath
    else
        basePath = projectBasePath .. PATH_SEP .. rel
    end
    local dirs = listDiskEntries(basePath, true)
    local files = listDiskEntries(basePath, false)
    table.sort(dirs, sortByName)
    table.sort(files, sortByName)
    local children = {}
    if depth < TREE_MAX_DEPTH then
        for _, d in ipairs(dirs) do
            local childRel
            if rel == "" then
                childRel = d
            else
                childRel = rel .. "/" .. d
            end
            children[#children + 1] = {
                name = d,
                path = childRel,
                isDir = true,
                children = scanTreeLevel(childRel, depth + 1)
            }
        end
    end
    for _, f in ipairs(files) do
        local childRel
        if rel == "" then
            childRel = f
        else
            childRel = rel .. "/" .. f
        end
        children[#children + 1] = {
            name = f,
            path = childRel,
            isDir = false,
            children = {}
        }
    end
    return children
end

local function buildProjectTree()
    pcall(createDir, projectBasePath)
    projectTree = {
        name = "FolderProject",
        path = "",
        isDir = true,
        children = scanTreeLevel("", 0)
    }
end

local function treeMatches(node, q)
    if q == "" then return true end
    if string.find(string.lower(node.name), string.lower(q), 1, true) then return true end
    for _, c in ipairs(node.children or {}) do
        if treeMatches(c, q) then return true end
    end
    return false
end

local function countTreeNodes(node)
    local d, f = 0, 0
    if node.isDir then
        d = 1
        for _, c in ipairs(node.children or {}) do
            local cd, cf = countTreeNodes(c)
            d = d + cd
            f = f + cf
        end
    else
        f = 1
    end
    return d, f
end

local TREE_VLINE = "│   "
local TREE_BLANK = "    "
local TREE_TEE = "├── "
local TREE_ELL = "└── "

local function renderTreeChildren(win, children, stack, force)
    local visible = {}
    for _, c in ipairs(children) do
        if treeMatches(c, searchFolder) then
            visible[#visible + 1] = c
        end
    end
    for i, node in ipairs(visible) do
        local isLast = (i == #visible)
        local prefix = ""
        for _, h in ipairs(stack) do
            prefix = prefix .. (h and TREE_VLINE or TREE_BLANK)
        end
        local branch = isLast and TREE_ELL or TREE_TEE
        local exp = node.isDir and (treeExpanded[node.path] or force)
        local arrow = node.isDir and (exp and "▼ " or "▶ ") or ""
        local icon
        if node.isDir then
            icon = ":folder: "
        else
            icon = (runningFiles[node.path] and ":toggle-on: " or ":file: ")
        end
        local label = prefix .. branch .. arrow .. icon .. node.name
        local nodeId = "##tree" .. node.path
        if node.isDir then
            if win:Selectable(label .. nodeId, false) then
                treeExpanded[node.path] = not treeExpanded[node.path]
            end
            if exp and node.children and #node.children > 0 then
                local childStack = {}
                for _, v in ipairs(stack) do
                    childStack[#childStack + 1] = v
                end
                childStack[#childStack + 1] = not isLast
                renderTreeChildren(win, node.children, childStack, force)
            end
        else
            if win:Selectable(label .. nodeId, selectedTreePath == node.path) then
                selectedTreePath = node.path
            end
        end
    end
end

local function renderTreeRoot(win)
    local force = searchFolder ~= ""
    local exp = treeExpanded[""] or force
    local arrow = exp and "▼ " or "▶ "
    local label = arrow .. ":folder: FolderProject"
    if win:Selectable(label .. "##treeroot", false) then
        treeExpanded[""] = not treeExpanded[""]
    end
    if exp and projectTree and projectTree.children and #projectTree.children > 0 then
        renderTreeChildren(win, projectTree.children, {}, force)
    end
end

local function loadProjectFoldersFromDisk()
    pcall(createDir, projectBasePath)
    local seen = {}
    local loaded = 0
    local manifestEntries = readManifestEntries()
    for _, entry in ipairs(manifestEntries) do
        local folderName, fileName = entry:match("^([^/]+)/([^/]+)$")
        if folderName and fileName and folderName ~= "" and fileName ~= ""
            and not folderName:find("%.%.") and not fileName:find("%.%.")
            and fileExistsOnDisk(folderName, fileName) then
            local key = folderName .. "/" .. fileName
            if not seen[key] then
                seen[key] = true
                upsertFolderEntry(folderName, fileName)
                loaded = loaded + 1
            end
        end
    end
    local dirNames = listDiskEntries(projectBasePath, true)
    for _, folderName in ipairs(dirNames) do
        if folderName ~= "" and folderName ~= "." and folderName ~= ".." and not folderName:find("%.%.") then
            local fileNames = listDiskEntries(projectBasePath .. PATH_SEP .. folderName, false)
            for _, fname in ipairs(fileNames) do
                if fname ~= "" and fname ~= "." and fname ~= ".." and not fname:find("%.%.") then
                    local key = folderName .. "/" .. fname
                    if not seen[key] then
                        seen[key] = true
                        upsertFolderEntry(folderName, fname)
                        loaded = loaded + 1
                    end
                end
            end
        end
    end
    writeManifest()
    return loaded
end

pcall(LogToConsole, "[Mythical] OS: " .. detectedOS .. " | Storage: " .. projectBasePath)
local startupLoadedCount = loadProjectFoldersFromDisk()
pcall(LogToConsole, "[Mythical] Project files loaded: " .. tostring(startupLoadedCount))
pushLog("SYSTEM", "System initialized successfully")
pushLog("SYSTEM", "Configuration loaded | OS: " .. detectedOS)
pushLog("INFO", "Storage: " .. projectBasePath)
pushLog("INFO", "Project files loaded: " .. tostring(startupLoadedCount))

local navItems = {
    { id = "accounts", label = "ACCOUNTS", icon = ":user-shield:" },
    { id = "scripts",  label = "SCRIPTS",  icon = ":list:" },
    { id = "alert",    label = "ALERT",    icon = ":exclamation-triangle:" },
    { id = "ai",       label = "AI",       icon = ":robot:" },
    { id = "project",  label = "PROJECT",  icon = ":folder:" },
    { id = "chat",     label = "CHAT",     icon = ":comments:" },
    { id = "server",   label = "SERVER",   icon = ":server:" },
    { id = "live",     label = "LIVE",     icon = ":toggle-on:" },
}

local FeatureWin = nil

local function featureLabel(id)
    for _, it in ipairs(navItems) do
        if it.id == id then return it.label end
    end
    return ""
end

local function openFeature(id)
    currentFeature = id
    pcall(function() FeatureWin:SetTitle("Mythical - " .. featureLabel(id)) end)
end

local AuthWin = Gui.New({
    title = "Bothax Authentication",
    size = {500, 460},
    theme = UI_THEME,
    style = UI_STYLE,
    OnRender = function(win)
        if currentLoginUI == 1 then
            win:SeparatorText(":lock: Login Account")
            loginUsername = win:InputText("##LoginUser", "Username", loginUsername)
            loginPassword = win:InputText("##LoginPass", "Password", loginPassword)
            win:Spacing(4)
            local loginLabel = isRegistering and ":spinner: Logging in..." or ":sign-in-alt: LOGIN NOW"
            if win:Button(loginLabel, nil, -1, 50) then
                if isRegistering then
                    pushLog("AUTH", "Please wait: Login in progress...")
                else
                    isRegistering = true
                    pushLog("AUTH", "Connecting to server for login '" .. loginUsername .. "'...")
                    isLoggedIn = true
                    accountData.username = (loginUsername ~= "" and loginUsername) or "UserDemo"
                    accountData.password = (loginPassword ~= "" and loginPassword) or "PassDemo"
                    local sTime, tTime = pcall(os.date, "%Y-%m-%d %H:%M:%S")
                    accountData.loginTime = sTime and tTime or "N/A"
                    local sTZ, tTZ = pcall(os.date, "%Z")
                    if sTZ and type(tTZ) == "string" and tTZ ~= "" then
                        accountData.timeZone = tTZ
                    else
                        accountData.timeZone = "GMT+7"
                    end
                    local o = getSystemInfo()
                    accountData.os = o
                    pcall(REAL_RUNTHREAD, function()
                        local realIp = fetchPublicIP()
                        accountData.ip = realIp or "127.0.0.1"
                        local body = '{"username":' .. escapeJson(loginUsername) .. ',"password":' .. escapeJson(loginPassword) .. ',"os":"' .. accountData.os .. '","ip":' .. escapeJson(accountData.ip) .. '}'
                        local t0 = os.clock()
                        local res = apiPost("/api/loader/login", body)
                        serverInfo.ping = math.floor((os.clock() - t0) * 1000)
                        isRegistering = false
                        if res and res.content then
                            serverInfo.online = true
                            processRestartResponse(res.content)
                            local ok = jsonField(res.content, "success")
                            local key = jsonField(res.content, "apiKey")
                            if ok and key then
                                PRESET_API_KEY = key
                                accountData.apiKey = key
                                saveAccountCredentials(loginUsername, loginPassword)
                                pushLog("AUTH", "User authentication successful")
                                pushLog("AUTH", "API Key received from server & automatically set.")
                                pushLog("NETWORK", "Ping: " .. serverInfo.ping .. " ms")
                                spawnNotif("success", "Login successful! Welcome " .. loginUsername .. ".", 4.0)
                                pcall(REAL_RUNTHREAD, function()
                                    local prevOnline = serverInfo.online
                                    while isLoggedIn and PRESET_API_KEY ~= "" do
                                        local ping = math.floor((os.clock() * 1000) % 200) + 20
                                        local hbT0 = os.clock()
                                        local hbOk, hbRes = pcall(apiPost, "/api/loader/heartbeat", '{"ping":' .. ping .. ',"os":"' .. accountData.os .. '","ip":' .. escapeJson(accountData.ip) .. '}')
                                        serverInfo.online = hbOk and hbRes ~= nil
                                        serverInfo.ping = math.floor((os.clock() - hbT0) * 1000)
                                        if hbOk and hbRes and hbRes.content then
                                            processRestartResponse(hbRes.content)
                                        end
                                        if serverInfo.online ~= prevOnline then
                                            if serverInfo.online then
                                                pushLog("SERVER", "Connection established (" .. serverInfo.ping .. " ms)")
                                            else
                                                pushLog("ERROR", "Connection lost")
                                            end
                                        end
                                        prevOnline = serverInfo.online
                                        BASE_SLEEP(60000)
                                    end
                                end)
                            else
                                local reason = getServerMessage(res.content)
                                pushLog("ERROR", "Login server failed: " .. tostring(reason))
                                spawnNotif("error", "Login failed: " .. tostring(reason), 5.0)
                            end
                        else
                            serverInfo.online = false
                            serverInfo.ping = 0
                            pushLog("ERROR", "Login server failed: Could not reach server.")
                            spawnNotif("error", "Could not connect to server. Check connection.", 5.0)
                        end
                        currentFeature = "menu"
                    end)
                end
            end
            win:Spacing(2)
            if win:Button(":user-plus: Register Account", nil, -1, 50) then
                currentLoginUI = 2
            end
        else
            win:SeparatorText(":user-plus: Register Account")
            regUsername = win:InputText("##RegUser", "Username", regUsername)
            regPassword = win:InputText("##RegPass", "Password", regPassword)
            regConfirmPass = win:InputText("##RegConfPass", "Confirm Password", regConfirmPass)
            win:Spacing(4)
            local regLabel = isRegistering and ":spinner: Registering..." or ":check: Confirm Register"
            if win:Button(regLabel, nil, -1, 40) then
                if isRegistering then
                    pushLog("AUTH", "Please wait: Registration in progress...")
                elseif regPassword == regConfirmPass and regUsername ~= "" then
                    isRegistering = true
                    pushLog("AUTH", "Registering account '" .. regUsername .. "' to server...")
                    pcall(REAL_RUNTHREAD, function()
                        local realIp = fetchPublicIP()
                        if realIp then accountData.ip = realIp end
                        local body = '{"username":' .. escapeJson(regUsername) .. ',"password":' .. escapeJson(regPassword) .. ',"os":"' .. getSystemInfo() .. '","ip":' .. escapeJson(realIp or "127.0.0.1") .. '}'
                        local res = apiPost("/api/loader/register", body)
                        isRegistering = false
                        if res and res.content then
                            local ok = jsonField(res.content, "success")
                            local key = jsonField(res.content, "apiKey")
                            if ok and key then
                                PRESET_API_KEY = key
                                accountData.apiKey = key
                                loginUsername = regUsername
                                loginPassword = regPassword
                                saveAccountCredentials(regUsername, regPassword)
                                regUsername = ""
                                regPassword = ""
                                regConfirmPass = ""
                                pushLog("AUTH", "Register successful! API Key automatically set.")
                                spawnNotif("success", "Registration successful! Please login.", 4.0)
                                currentLoginUI = 1
                            else
                                local regReason = getServerMessage(res.content)
                                pushLog("ERROR", "Register failed: " .. tostring(regReason) .. ". Try another username.")
                                spawnNotif("error", "Register failed: " .. tostring(regReason), 5.0)
                            end
                        else
                            pushLog("ERROR", "Register failed: Could not reach server (" .. SERVER_URL .. ").")
                            spawnNotif("error", "Could not connect to server. Try again later.", 5.0)
                        end
                    end)
                else
                    pushLog("WARN", "Register Failed: Make sure passwords match and username is not empty.")
                    spawnNotif("warn", "Passwords do not match or username empty.", 4.0)
                end
            end
            win:Spacing(2)
            if win:Button(":arrow-left: Back to Login", nil, -1, 30) then
                currentLoginUI = 1
            end
        end
    end
})

local function autoLoginSavedAccount()
    if savedAccountAutoLogin then return end
    local savedUsername, savedPassword = loadSavedAccountCredentials()
    if not savedUsername or not savedPassword then return end
    savedAccountAutoLogin = true
    loginUsername = savedUsername
    loginPassword = savedPassword
    currentLoginUI = 1
    isRegistering = true
    pushLog("AUTH", "Saved account found: attempting auto-login...")
    pcall(REAL_RUNTHREAD, function()
        local realIp = fetchPublicIP()
        accountData.ip = realIp or "127.0.0.1"
        accountData.os = getSystemInfo()
        local sTime, tTime = pcall(os.date, "%Y-%m-%d %H:%M:%S")
        accountData.loginTime = sTime and tTime or "N/A"
        local sTZ, tTZ = pcall(os.date, "%Z")
        accountData.timeZone = (sTZ and type(tTZ) == "string" and tTZ ~= "") and tTZ or "GMT+7"
        local body = '{"username":' .. escapeJson(savedUsername) .. ',"password":' .. escapeJson(savedPassword) .. ',"os":"' .. accountData.os .. '","ip":' .. escapeJson(accountData.ip) .. '}'
        local t0 = os.clock()
        local res = apiPost("/api/loader/login", body)
        serverInfo.ping = math.floor((os.clock() - t0) * 1000)
        isRegistering = false
        if res and res.content then
            serverInfo.online = true
            processRestartResponse(res.content)
            local ok = jsonField(res.content, "success")
            local key = jsonField(res.content, "apiKey")
            if ok and key then
                isLoggedIn = true
                accountData.username = savedUsername
                accountData.password = savedPassword
                PRESET_API_KEY = key
                accountData.apiKey = key
                saveAccountCredentials(savedUsername, savedPassword)
                pushLog("AUTH", "Auto-login successful: " .. savedUsername)
                pushLog("AUTH", "API Key received from server & automatically set.")
                spawnNotif("success", "Auto-login successful! Welcome " .. savedUsername .. ".", 4.0)
                pcall(REAL_RUNTHREAD, function()
                    local prevOnline = serverInfo.online
                    while isLoggedIn and PRESET_API_KEY ~= "" do
                        local ping = math.floor((os.clock() * 1000) % 200) + 20
                        local hbT0 = os.clock()
                        local hbOk, hbRes = pcall(apiPost, "/api/loader/heartbeat", '{"ping":' .. ping .. ',"os":"' .. accountData.os .. '","ip":' .. escapeJson(accountData.ip) .. '}')
                        serverInfo.online = hbOk and hbRes ~= nil
                        serverInfo.ping = math.floor((os.clock() - hbT0) * 1000)
                        if hbOk and hbRes and hbRes.content then
                            processRestartResponse(hbRes.content)
                        end
                        if serverInfo.online ~= prevOnline then
                            if serverInfo.online then
                                pushLog("SERVER", "Connection established (" .. serverInfo.ping .. " ms)")
                            else
                                pushLog("ERROR", "Connection lost")
                            end
                        end
                        prevOnline = serverInfo.online
                        BASE_SLEEP(60000)
                    end
                end)
                currentFeature = "menu"
            else
                local reason = getServerMessage(res.content)
                pushLog("ERROR", "Auto-login failed: " .. tostring(reason))
                spawnNotif("warn", "Auto-login failed. Please login manually.", 5.0)
            end
        else
            serverInfo.online = false
            serverInfo.ping = 0
            pushLog("ERROR", "Auto-login failed: Could not reach server.")
            spawnNotif("warn", "Auto-login could not connect. Please login manually.", 5.0)
        end
    end)
end

autoLoginSavedAccount()

local RestartWin = Gui.New({
    title = "Mythical Restart Status",
    size = {400, 200},
    pos = {750, 250},
    flags = OVERLAY_FLAGS,
    theme = {
        WindowBg = 0xE60A0A0A, ChildBg = 0xE60A0A0A, Border = 0xFFFF0000,
        Text = 0xFFDDDDDD, Button = 0xFF7A7A7A, ButtonHovered = 0xFF979797, ButtonActive = 0xFF5E5E5E,
        Separator = 0xFFFF0000, FrameBg = 0xFF1C1C1C, FrameBgHovered = 0xFF282828, FrameBgActive = 0xFF333333,
    },
    style = UI_STYLE,
    OnRender = function(win)
        win:SeparatorText(":sync: SERVER RESTART")
        win:TextWrapped(restartPopup.reason)
        win:Spacing(2)
        win:Text("Server      :check: Restarting...")
        win:Text("Connection  :sync: Reconnecting...")
        win:Spacing(2)
        win:Text("Auto close in " .. string.format("%.1f", math.max(0, restartPopup.timer)) .. " seconds...", 0xFFAAAAAA)
        win:Spacing(2)
        if win:Button(":times: Close##closeRestartWin", nil, -1, 30) then
            restartPopup.active = false
        end
    end
})

local function renderAccountsFeature(win)
    win:SeparatorText(":user-shield: Account Dashboard")
    if (os.time() - serverInfo.lastCheck) > 60 and not serverInfo.checking then
        serverInfo.lastCheck = os.time()
        checkServerConnection()
    end
    win:Spacing(2)
    local sessionActive = isLoggedIn and PRESET_API_KEY ~= ""
    local statusColor = sessionActive and 0xFF00FF00 or 0xFFAAAAAA
    local serverColor = serverInfo.online and 0xFF00FF00 or 0xFF888888
    local keyColor = accountData.apiKey ~= "" and 0xFF00FF00 or 0xFFAAAAAA
    win:Card(":user: USER", 200, 190, function()
        win:Spacing(1)
        win:Text("Username", 0xFFAAAAAA)
        win:TextWrapped(accountData.username)
        win:Spacing(1)
        win:Text(isAndroid and ":mobile: Mobile" or ":desktop: Desktop", 0xFF88CCFF)
    end)
    win:SameLine(0, 8)
    win:Card(":toggle-on: STATUS", 200, 190, function()
        win:Spacing(1)
        win:Text("Account", 0xFFAAAAAA)
        win:Text(sessionActive and ":circle: Active" or ":circle: Offline", statusColor)
        win:Spacing(1)
        win:Text("Session", 0xFFAAAAAA)
        win:Text(sessionActive and "Active" or "Offline", statusColor)
    end)
    win:SameLine(0, 8)
    win:Card(":mobile: DEVICE", 200, 190, function()
        win:Spacing(1)
        win:Text("Platform", 0xFFAAAAAA)
        win:TextWrapped(accountData.os)
        win:Spacing(1)
        win:Text("IP", 0xFFAAAAAA)
        win:TextWrapped(accountData.ip)
    end)
    win:SameLine(0, 8)
    win:Card(":key: API KEY", 285, 190, function()
        win:Spacing(1)
        win:Text("Key", 0xFFAAAAAA)
        win:Text(accountData.apiKey ~= "" and "••••••••••" or "-")
        win:Spacing(1)
        win:Text(accountData.apiKey ~= "" and ":circle: Active" or ":circle: Not Set", keyColor)
    end)
    win:Spacing(2)
    win:Card(":clock: SESSION", 450, 250, function()
        win:Spacing(1)
        win:Text("Login       : " .. accountData.loginTime)
        win:Text("Timezone    : " .. accountData.timeZone)
        win:Text("Session     : " .. (sessionActive and "Active" or "Offline"))
        win:Text("API Key     : " .. (accountData.apiKey ~= "" and accountData.apiKey:sub(1, 12) .. "..." or "None"))
    end)
    win:SameLine(0, 8)
    win:Card(":globe: CONNECTION", 450, 250, function()
        win:Spacing(1)
        win:Text("Server      : ")
        win:SameLine(0, 2)
        win:Text(serverInfo.online and ":circle: Online" or ":circle: Offline", serverColor)
        win:Text("Ping        : " .. (serverInfo.online and (serverInfo.ping .. " ms") or "-"))
        win:Text("Region      : " .. serverInfo.region)
        win:Text("Public IP   : " .. accountData.ip)
    end)
    win:Spacing(4)
    pcall(function()
        local cx = select(1, win:GetCursorPos())
        local aw = select(1, win:GetContentRegionAvail())
        win:SetCursorPosX(cx + aw - 170)
    end)
    if win:Button(":sign-out-alt: LOGOUT", nil, 170, 40) then
        local keyToSend = PRESET_API_KEY
        pcall(REAL_RUNTHREAD, function()
            if keyToSend ~= "" then
                pcall(MakeRequest, SERVER_URL .. "/api/loader/logout?apiKey=" .. keyToSend, "POST", {}, "")
            end
        end)
        isLoggedIn = false
        PRESET_API_KEY = ""
        accountData.apiKey = ""
        currentLoginUI = 1
        currentFeature = "menu"
        isRegistering = false
        serverInfo.online = false
        serverInfo.ping = 0
        pushLog("AUTH", "Logout: You have been logged out.")
        spawnNotif("info", "You have been logged out.", 3.0)
    end
end

local function renderScriptsFeature(win)
    local interval = 120 + math.min(scriptsFailCount, 4) * 30
    if (os.time() - scriptsFetchTime) > interval and not scriptsFetching then
        scriptsFetchTime = os.time()
        scriptsFetching = true
        pcall(REAL_RUNTHREAD, function()
            local res = apiGet("/api/loader/scripts")
            if res and res.content and res.content ~= "" then
                if res.content ~= lastScriptsRaw then
                    lastScriptsRaw = res.content
                    local arr = findJsonArray(res.content, "scripts")
                    if arr then
                        local newScripts = {}
                        for _, obj in ipairs(extractJsonObjects(arr)) do
                            local idNum = obj:match('"id"%s*:%s*(%d+)')
                            local id = jsonString(obj, "id") or jsonString(obj, "_id") or (idNum and tonumber(idNum))
                            local name = jsonString(obj, "name") or jsonString(obj, "title")
                            local dev = jsonString(obj, "dev") or jsonString(obj, "developer") or "-"
                            local cat = jsonString(obj, "category") or jsonString(obj, "cat") or "Utility"
                            local status = jsonString(obj, "status") or "Offline"
                            local date = jsonString(obj, "date") or "-"
                            local surl = jsonString(obj, "url") or jsonString(obj, "link")
                                or jsonString(obj, "rawUrl") or jsonString(obj, "sourceUrl")
                                or jsonString(obj, "github") or jsonString(obj, "raw")
                                or jsonString(obj, "source") or jsonString(obj, "file")
                                or jsonString(obj, "code") or jsonString(obj, "content")
                            if surl and not surl:find("^%s*https?://") then surl = nil end
                            if name then
                                table.insert(newScripts, {
                                    id = id, name = name, dev = dev, date = date, cat = cat,
                                    status = status, running = false, runTime = 0, url = surl
                                })
                            end
                        end
                        if #newScripts > 0 then
                            for _, ns in ipairs(newScripts) do
                                if runningServerScripts[scriptSid(ns)] then ns.running = true end
                            end
                            scriptList = newScripts
                            pushLog("SERVER", "Scripts from server: " .. #newScripts)
                        end
                    end
                end
                scriptsFailCount = 0
            else
                scriptsFailCount = scriptsFailCount + 1
                pushLog("ERROR", "Failed to fetch /api/loader/scripts")
            end
            scriptsFetching = false
        end)
    end
    local runningCount = 0
    for _sid, _st in pairs(runningServerScripts) do
        runningCount = runningCount + 1
    end
    win:SeparatorText(":list: Available Scripts")
    win:Text("Total: " .. #scriptList .. "  |  Running: " .. runningCount)
    win:SameLine(0, 10)
    if win:Button(":sync: Refresh##refreshScripts", nil, 150, 30) then
        scriptsFetchTime = 0
    end
    win:SameLine(0, 10)
    win:Text("Category:")
    win:SameLine(0, 5)
    filterCatIdx = win:Combo("##FilterCat", filterCatIdx, categories)
    win:SameLine(0, 10)
    win:Text("Search:")
    win:SameLine(0, 5)
    searchScriptName = win:InputText("##SearchScriptName", "name...", searchScriptName)
    win:Spacing(2)
    local filtered = {}
    for _, script in ipairs(scriptList) do
        local matchCat = (filterCatIdx == 0) or (script.cat == categories[filterCatIdx + 1])
        local sName = string.lower(tostring(script.name))
        local sSearch = string.lower(tostring(searchScriptName))
        local matchSearch = (searchScriptName == "") or (string.find(sName, sSearch) ~= nil)
        if matchCat and matchSearch then
            filtered[#filtered + 1] = script
        end
    end
    local perPage = 5
    local totalPages = math.max(1, math.ceil(#filtered / perPage))
    if scriptPage > totalPages then scriptPage = totalPages end
    if scriptPage < 1 then scriptPage = 1 end
    local startIdx = (scriptPage - 1) * perPage + 1
    local endIdx = math.min(startIdx + perPage - 1, #filtered)
    win:PushColors({ ChildBg = 0xFF0A0A0A, Border = 0xFF5A5A5A })
    win:BeginChild("ScriptsPage", 0, -62, true)
    if #filtered == 0 then
        win:TextWrapped("No scripts available. Wait for server data or press Refresh.")
    else
        for i = startIdx, endIdx do
            local scr = filtered[i]
            local runState = runningServerScripts[scriptSid(scr)]
            scr.running = runState ~= nil
            local dispName = tostring(scr.name)
            if #dispName > 42 then dispName = dispName:sub(1, 42) .. "..." end
            if runState then
                win:Text("[" .. i .. "] :toggle-on: " .. dispName, 0xFF88FF88)
            else
                win:Text("[" .. i .. "] :toggle-off: " .. dispName, 0xFFE6E6E6)
            end
            pcall(function()
                local cx = select(1, win:GetCursorPos())
                local aw = select(1, win:GetContentRegionAvail())
                win:SetCursorPosX(cx + aw - 210)
            end)
            if win:Button(":play: START##pgsrun" .. i, nil, 106, 30) then
                runServerScript(scr)
            end
            win:SameLine(0, 6)
            if win:Button(":stop: STOP##pgsstop" .. i, nil, 92, 30) then
                stopServerScript(scr)
            end
            win:Text("Dev: " .. tostring(scr.dev) .. "   Date: " .. tostring(scr.date) .. "   Cat: " .. tostring(scr.cat) .. "   Status: ", 0xFFAAAAAA)
            win:SameLine(0, 4)
            win:Text(tostring(scr.status), getStatusColor(scr.status))
            win:Separator()
        end
    end
    win:EndChild()
    win:PopColors()
    win:Spacing(2)
    if win:Button(":arrow-left: BACK##scriptsPageBack", nil, 130, 36) then
        if scriptPage > 1 then scriptPage = scriptPage - 1 end
    end
    win:SameLine(0, 12)
    win:Text("Page " .. scriptPage .. " / " .. totalPages .. "   (Total: " .. #filtered .. " scripts)", 0xFFAAAAAA)
    win:SameLine(0, 12)
    if win:Button(":arrow-right: NEXT##scriptsPageNext", nil, 130, 36) then
        if scriptPage < totalPages then scriptPage = scriptPage + 1 end
    end
end

local function renderAlertFeature(win)
    local interval = 120 + math.min(alertsFailCount, 4) * 60
    if (os.time() - alertsFetchTime) > interval and not alertsFetching then
        alertsFetchTime = os.time()
        alertsFetching = true
        pcall(REAL_RUNTHREAD, function()
            local res = apiGet("/api/loader/alerts")
            if res and res.content and res.content ~= "" then
                if res.content ~= lastAlertsRaw then
                    lastAlertsRaw = res.content
                    local arr = findJsonArray(res.content, "alerts")
                    if arr then
                        local newAlerts = {}
                        for _, obj in ipairs(extractJsonObjects(arr)) do
                            local m = jsonString(obj, "message") or jsonString(obj, "text")
                                or jsonString(obj, "msg") or jsonString(obj, "title")
                            if m then table.insert(newAlerts, m) end
                        end
                        if #newAlerts > 0 then alerts = newAlerts end
                    end
                end
                alertsFailCount = 0
            else
                alertsFailCount = alertsFailCount + 1
            end
            alertsFetching = false
        end)
    end
    win:SeparatorText(":bullhorn: Announcements & Bug Fix Info")
    win:BeginChild("AlertsList", 0, 350, true)
    for _, alert in ipairs(alerts) do
        win:TextWrapped(alert)
        win:Separator()
    end
    win:EndChild()
    win:Spacing(4)
    win:SeparatorText(":bug: Bug Report / Suggestion")
    bugReportText = win:InputText("##BugReport", "Write bug or suggestion here...", bugReportText)
    win:SameLine()
    if win:Button(":paper-plane: Send Report", nil, 200, 0) then
        if bugReportText ~= "" then
            local report = bugReportText
            bugReportText = ""
            pushLog("INFO", "Report Sent: Thank you for your report!")
            pcall(REAL_RUNTHREAD, function()
                local body = '{"message":' .. escapeJson(report) .. ',"username":' .. escapeJson(accountData.username) .. ',"os":"' .. accountData.os .. '"}'
                local res = apiPost("/api/loader/bug-report", body)
                if res and res.content then
                    local ok = jsonField(res.content, "success")
                    if not ok then
                        local reason = jsonField(res.content, "reason") or "unknown"
                        pushLog("ERROR", "Report Failed: " .. tostring(reason))
                    end
                end
            end)
        else
            pushLog("WARN", "Empty Report: Write something before sending!")
        end
    end
    win:SameLine()
    if win:Button(":trash: Clear Message", nil, 200, 0) then
        bugReportText = ""
        pushLog("INFO", "Field Cleared: Message field has been cleared.")
    end
end

local function renderAiFeature(win)
    win:SeparatorText(":robot: AI Code Assistant")
    local ping = 0
    local status, client = pcall(GetClient)
    if status and client then ping = client.ping or 0 end
    if (os.time() - tokenFetchTime) > 120 and not tokenFetching then
        tokenFetchTime = os.time()
        refreshTokenStatus()
    end
    win:Text("AI Model: " .. aiModelName .. " | Token Used : " .. tostring(tokenUsedToday) .. " / " .. tostring(tokenDailyLimit) .. " | Ping : " .. ping .. "ms")
    win:Text("Storage Path : " .. projectBasePath .. PATH_SEP, 0xFFAAAAAA)
    win:Spacing(4)
    win:PushColors({ ChildBg = 0xFF0A0A0A, Border = 0xFF5A5A5A })
    win:BeginChild("AIChatLog", 0, 400, true)
    win:TextWrapped(aiOutput)
    win:EndChild()
    win:PopColors()
    aiInput = win:InputText("##PromptInput", "Type message / code command to AI...", aiInput)
    win:SameLine()
    if win:Button(":paper-plane: Send", nil, 100, 0) then
        local prompt = aiInput
        if prompt ~= "" then
            if aiSending then
                pushLog("AI", "Please wait: AI is still processing previous request.")
            else
                aiSending = true
                pushLog("AI", "AI Processing: Request sent to AI...")
                aiOutput = aiOutput .. "\n\nUser: " .. prompt
                aiInput = ""
                pcall(REAL_RUNTHREAD, function()
                    local body = '{"prompt":' .. escapeJson(prompt) .. ',"username":' .. escapeJson(accountData.username) .. '}'
                    local res = apiPost("/api/loader/ai/chat", body)
                    if res and res.content then
                        local ok = jsonField(res.content, "success")
                        if ok then
                            local output = jsonString(res.content, "output")
                            local model = jsonField(res.content, "model")
                            if model then aiModelName = model end
                            local used = jsonField(res.content, "used") or jsonField(res.content, "tokensUsed")
                            if used then tokenUsedToday = tonumber(used) or tokenUsedToday end
                            local limit = jsonField(res.content, "limit") or jsonField(res.content, "tokenLimit")
                            if limit then tokenDailyLimit = tonumber(limit) or tokenDailyLimit end
                            if output then
                                aiOutput = aiOutput .. "\n\n// AI (" .. aiModelName .. "):\n" .. output
                            end
                        else
                            local reason = jsonField(res.content, "reason") or "unknown"
                            aiOutput = aiOutput .. "\n\n// [AI Error] " .. tostring(reason)
                        end
                    else
                        aiOutput = aiOutput .. "\n\n// [AI Error] Could not reach server."
                    end
                    aiSending = false
                end)
            end
        end
    end
    win:Spacing(2)
    if win:Button(":copy: Copy Output", nil, 210, 0) then
        Gui:SetClipboard(aiOutput)
        pushLog("INFO", "Copied! AI output copied to clipboard")
    end
    win:SameLine()
    if win:Button(":paste: Paste Text", nil, 210, 0) then
        local clipText = Gui:GetClipboard()
        if clipText and clipText ~= "" then
            aiInput = (aiInput == "" and clipText) or (aiInput .. "\n" .. clipText)
            pushLog("INFO", "Pasted! Text from clipboard pasted")
        else
            pushLog("WARN", "Clipboard Empty: No text to paste")
        end
    end
    win:SameLine()
    if win:Button(":folder-plus: Create Folder", nil, 220, 0) then
        newDocCode = aiOutput
        openCreateFolderModal = true
    end
    win:SameLine()
    if win:Button(":trash: Clear All Chat##clearAiChat", nil, 220, 0) then
        aiOutput = ""
        pushLog("INFO", "Cleared: All AI & User chat logs cleared.")
    end
    if openCreateFolderModal then
        win:OpenPopup("Create Folder Project##CreateFolderPopup")
        openCreateFolderModal = false
    end
    win:Modal("Create Folder Project##CreateFolderPopup", function()
        win:SeparatorText(":folder-plus: Create Folder & Docs")
        win:Text("Save Location: " .. projectBasePath .. PATH_SEP, 0xFF88CCFF)
        win:Spacing(2)
        newFolderName = win:InputText("##NewFolderName", "Folder Name...", newFolderName)
        win:Spacing(2)
        newDocName = win:InputText("##NewDocName", "Docs Name (e.g. script.txt)...", newDocName)
        win:Spacing(2)
        newDocCode = win:InputTextMultiline("##NewDocCode", newDocCode, 400, 200, 99999)
        win:Spacing(2)
        if win:Button(":save: Save To Project Folder", nil, -1, 38) then
            if newFolderName == "" or newDocName == "" then
                pushLog("WARN", "Save Failed: Folder name and docs name required!")
            else
                local folderName = sanitizeFolderPath(newFolderName, "")
                local fileName = sanitizeName(newDocName, "script.txt")
                if not fileName:find("%.") then fileName = fileName .. ".txt" end
                local saved = writeProjectFile(folderName, fileName, newDocCode)
                if saved then
                    pushLog("SAVE", "Saved: " .. joinProjectPath(folderName, fileName))
                    selectedFileKey = makeFileKey(folderName, fileName)
                    selectedTreePath = selectedFileKey
                    newFolderName = ""
                    newDocName = ""
                    newDocCode = ""
                    projectTreeDirty = true
                    win:ClosePopup()
                else
                    pushLog("ERROR", "Save Failed: Could not write file to storage!")
                end
            end
        end
        win:Spacing(2)
        if win:Button(":times: Close##closeCreateFolder", nil, -1, 38) then
            win:ClosePopup()
        end
    end)
end

local function renderProjectFeature(win)
    if projectSubView == "editor" then
        win:SeparatorText(":code: Code Editor - " .. activeFileName)
        if win:Button(":arrow-left: Back to Folder", nil, 200, 35) then projectSubView = "tree" end
        win:SameLine()
        if win:Button(":save: Save File Edit", nil, 200, 35) then
            if activeFileFolder ~= "" then
                if writeProjectFile(activeFileFolder, activeFileName, editorContent) then
                    pushLog("SAVE", "File Saved: " .. joinProjectPath(activeFileFolder, activeFileName))
                    projectTreeDirty = true
                else
                    pushLog("ERROR", "Save Failed: Could not write file to storage!")
                end
            elseif activeFileName ~= "" then
                local okRoot = pcall(function()
                    local f = io.open(joinProjectPath("", activeFileName), "w")
                    if not f then error("cannot open file") end
                    f:write(editorContent or "")
                    f:close()
                end)
                if okRoot then
                    pushLog("SAVE", "File Saved: " .. joinProjectPath("", activeFileName))
                    projectTreeDirty = true
                else
                    pushLog("ERROR", "Save Failed: Could not write file to storage!")
                end
            else
                pushLog("SAVE", "File Saved: Changes have been saved.")
            end
        end
        win:Spacing(2)
        local _, lineCount = editorContent:gsub("\n", "\n")
        lineCount = lineCount + 1
        win:BeginChild("LineNumbers", 40, -1, true)
        for i = 1, lineCount do win:Text(i) end
        win:EndChild()
        win:SameLine()
        win:PushColors({ FrameBg = 0xFF1E1E1E, Text = 0xFFD4D4D4, Border = 0xFF5A5A5A })
        editorContent = win:InputTextMultiline("##CodeEditor", editorContent, -1, -1, 99999)
        win:PopColors()
        return
    end
    win:SeparatorText(":folder: Project Folder AI Code")
    if not projectTree or projectTreeDirty then
        buildProjectTree()
        projectTreeDirty = false
    end
    local totalDirs, totalFiles = countTreeNodes(projectTree)
    win:Text(":folder: " .. totalDirs .. " folders   :file: " .. totalFiles .. " files", 0xFFAAAAAA)
    win:SameLine(0, 10)
    win:Text(":hdd: " .. projectBasePath, 0xFF777777)
    win:Spacing(3)
    local selFolder, selFile = "", ""
    if selectedTreePath ~= "" then
        selFolder, selFile = selectedTreePath:match("^(.-)/([^/]+)$")
        if not selFolder then
            selFolder, selFile = "", selectedTreePath
        end
    end
    local selRunning = selectedTreePath ~= "" and runningFiles[selectedTreePath] ~= nil
    if win:Button(":plus: NEW DOCS", nil, 185, 40) then
        newFolderName = selFolder
        newDocName = ""
        newDocCode = aiOutput
        openCreateFolderModal = true
        currentFeature = "ai"
    end
    win:SameLine(0, 6)
    if win:Button(":play: START", nil, 185, 40) then
        if selFile ~= "" then
            runScriptFile(selFolder, selFile)
        else
            pushLog("WARN", "Select a file in tree first!")
        end
    end
    win:SameLine(0, 6)
    if win:Button(":stop: STOP", nil, 185, 40) then
        if selFile ~= "" then
            stopScriptFile(selFolder, selFile)
        else
            pushLog("WARN", "Select a file in tree first!")
        end
    end
    win:SameLine(0, 6)
    if win:Button(":book-open: READ FILE", nil, 185, 40) then
        if selFile ~= "" then
            openFileInEditor(selFolder, selFile)
        else
            pushLog("WARN", "Select a file in tree first!")
        end
    end
    win:Spacing(2)
    if selFile ~= "" then
        win:Text(":mouse-pointer: Selected: " .. selectedTreePath .. (selRunning and "   :toggle-on: Running" or "   :toggle-off: Stopped"), selRunning and 0xFF88CCFF or 0xFFAAAAAA)
    else
        win:Text(":mouse-pointer: Selected: -", 0xFF777777)
    end
    win:Spacing(2)
    searchFolder = win:InputText("##SearchFolder", "Search folder/file...", searchFolder)
    win:SameLine(0, 6)
    if win:Button(":sync: Refresh##treeRefresh", nil, 150, 38) then
        buildProjectTree()
        pushLog("SYSTEM", "Project tree reloaded from storage.")
    end
    win:Spacing(3)
    win:PushColors({ ChildBg = 0xFF0A0A0A, Border = 0xFF5A5A5A })
    win:BeginChild("ProjectTreeView", 0, 0, true)
    if searchFolder ~= "" and projectTree and not treeMatches(projectTree, searchFolder) then
        win:TextWrapped(":info: No results for '" .. searchFolder .. "'.")
    else
        renderTreeRoot(win)
    end
    win:EndChild()
    win:PopColors()
end

local function renderChatFeature(win)
    local interval = 60 + math.min(chatFailCount, 4) * 30
    if (os.time() - chatFetchTime) > interval and not chatFetching then
        chatFetchTime = os.time()
        chatFetching = true
        pcall(REAL_RUNTHREAD, function()
            local res = apiGet("/api/loader/chat")
            if res and res.content and res.content ~= "" then
                if res.content ~= lastChatRaw then
                    lastChatRaw = res.content
                    local arr = findJsonArray(res.content, "messages") or findJsonArray(res.content, "chat")
                    if arr then
                        local msgs = {}
                        for _, obj in ipairs(extractJsonObjects(arr)) do
                            local user = jsonString(obj, "user") or jsonString(obj, "username") or jsonString(obj, "name")
                            local t = jsonString(obj, "time") or jsonString(obj, "timestamp")
                            local m = jsonString(obj, "msg") or jsonString(obj, "message") or jsonString(obj, "text")
                            local jd = jsonString(obj, "joinDate")
                            local o = jsonString(obj, "os")
                            if user and m then
                                table.insert(msgs, { user = user, time = t or "?", msg = m, joinDate = jd or "-", os = o or "-" })
                            end
                        end
                        if #msgs > 0 then publicChatMsgs = msgs end
                    end
                end
                chatFailCount = 0
            else
                chatFailCount = chatFailCount + 1
            end
            chatFetching = false
        end)
    end
    win:SeparatorText(":comments: Public Chat Room")
    win:Spacing(2)
    win:BeginChild("ChatBox", 0, -40, true)
    for i, msg in ipairs(publicChatMsgs) do
        win:TextWrapped("[" .. msg.time .. "] ")
        win:SameLine(0, 0)
        if win:Button(msg.user .. "##usr" .. i) then
            viewProfileData = msg
            openProfileModal = true
        end
        win:SameLine(0, 5)
        win:Text(": " .. msg.msg)
        win:Separator()
    end
    win:EndChild()
    chatInput = win:InputText("##ChatInput", "Type message...", chatInput)
    win:SameLine()
    if win:Button(":paper-plane: Send", nil, 120, 0) then
        if chatInput ~= "" then
            local msgText = chatInput
            local sTime, tTime = pcall(os.date, "%H:%M")
            table.insert(publicChatMsgs, {
                user = accountData.username,
                time = sTime and tTime or "N/A",
                msg = msgText,
                joinDate = accountData.loginTime,
                os = accountData.os
            })
            chatInput = ""
            pcall(REAL_RUNTHREAD, function()
                local body = '{"user":' .. escapeJson(accountData.username) .. ',"message":' .. escapeJson(msgText) .. ',"os":"' .. accountData.os .. '"}'
                apiPost("/api/loader/chat", body)
            end)
        end
    end
    win:SameLine()
    if win:Button(":sync: Refresh##refreshChat", nil, 180, 0) then
        chatFetchTime = 0
    end
    if openProfileModal then
        win:OpenPopup("Profile Member##ProfilePopup")
        openProfileModal = false
    end
    win:Modal("Profile Member##ProfilePopup", function()
        win:SeparatorText(":user: Profile Member")
        if viewProfileData then
            win:Text("Member Name   : " .. viewProfileData.user)
            win:Text("Join Date     : " .. viewProfileData.joinDate)
            win:Text("Time Zone     : " .. accountData.timeZone)
            win:Text("Device        : " .. viewProfileData.os)
        end
        win:Spacing(4)
        if win:Button("Close##closeProf") then
            win:ClosePopup()
        end
    end)
end

local function renderLiveFeature(win)
    win:SeparatorText(":toggle-on: LIVE STATUS")
    win:Text("Entries: " .. #liveLog .. " / " .. LIVE_LOG_MAX, 0xFFAAAAAA)
    win:SameLine(0, 10)
    if win:Button(":trash: Clear Log##clearLive", nil, 170, 30) then
        liveLog = {}
        pushLog("SYSTEM", "Log cleared.")
    end
    win:Spacing(2)
    win:PushColors({ ChildBg = 0xFF0A0A0A, Border = 0xFF5A5A5A })
    win:BeginChild("LiveStatusLog", 0, 0, true)
    if #liveLog == 0 then
        win:TextWrapped("No logs yet.")
    else
        for i = 1, #liveLog do
            local e = liveLog[i]
            win:Text(e.t, 0xFF777777)
            win:SameLine(110)
            win:Text("[" .. e.tag .. "]", e.c)
            win:SameLine(240)
            win:Text(e.m)
        end
    end
    win:EndChild()
    win:PopColors()
end

local function renderServerFeature(win)
    if serverSubView == "users" then
        if (os.time() - userMonitor.fetchTime) >= 120 and not userMonitor.fetching then
            userMonitor.fetchTime = os.time()
            fetchUserMonitorData()
        end
        win:Text(":users: USER ACTIVITY", 0xFFE0E0E0)
        win:SameLine(0, 10)
        local liveAlpha = 0.5 + 0.5 * math.sin(userMonitor.liveDot * math.pi * 2)
        local srvOnline = serverInfo.online
        win:Text(":circle:", srvOnline and rgba(0 * liveAlpha, 255 * liveAlpha, 0) or 0xFF666666)
        win:SameLine(0, 10)
        if win:Button(":arrow-left: Back to Server##umBack", nil, 200, 0) then
            serverSubView = "server"
        end
        win:Spacing(3)
        local totalUsers = #userMonitor.users
        local onlineCount = 0
        for _, u in ipairs(userMonitor.users) do
            if u.online then onlineCount = onlineCount + 1 end
        end
        local offlineCount = totalUsers - onlineCount
        win:Card(":users: TOTAL USERS", 315, 90, function()
            win:Spacing(1)
            win:Text(tostring(totalUsers), 0xFF88CCFF)
        end)
        win:SameLine(0, 8)
        win:Card(":toggle-on: ONLINE", 315, 90, function()
            win:Spacing(1)
            win:Text(tostring(onlineCount), 0xFF00FF00)
        end)
        win:SameLine(0, 8)
        win:Card(":toggle-off: OFFLINE", 315, 90, function()
            win:Spacing(1)
            win:Text(tostring(offlineCount), 0xFFAAAAAA)
        end)
        win:Spacing(3)
        win:Card(":toggle-on: ONLINE USERS", 478, 390, function()
            if onlineCount == 0 then
                win:TextWrapped(userMonitor.fetchedOnce and "No users online." or "Waiting for data from server...")
            else
                for _, u in ipairs(userMonitor.users) do
                    if u.online then
                        win:Text(":circle: " .. u.username, 0xFF88FF88)
                        win:SameLine(220)
                        win:Text(u.ping and (u.ping .. "ms") or "-", 0xFFAAAAAA)
                    end
                end
            end
        end)
        win:SameLine(0, 8)
        win:Card(":toggle-off: OFFLINE USERS", 478, 390, function()
            if offlineCount == 0 then
                win:TextWrapped(userMonitor.fetchedOnce and "No users offline." or "Waiting for data from server...")
            else
                for _, u in ipairs(userMonitor.users) do
                    if not u.online then
                        win:Text(":circle: " .. u.username, 0xFF999999)
                        win:SameLine(220)
                        win:Text(formatLastSeen(u), 0xFF777777)
                    end
                end
            end
        end)
        win:Spacing(3)
        win:PushColors({ ChildBg = 0xFF0A0A0A, Border = 0xFF5A5A5A })
        win:BeginChild("UserMonitorFooter", 0, 0, true)
        win:Text(":sync: AUTO REFRESH: 120s", 0xFFAAAAAA)
        win:SameLine(0, 10)
        win:Text("SERVER: " .. (srvOnline and ":circle: ONLINE" or ":circle: OFFLINE"), srvOnline and 0xFF00FF00 or 0xFF888888)
        win:SameLine(0, 10)
        win:Text("LAST UPDATE: " .. userMonitor.lastUpdate, 0xFFAAAAAA)
        win:EndChild()
        win:PopColors()
        return
    end
    win:SeparatorText(":server: Server Status")
    if (os.time() - serverInfo.lastCheck) > 60 and not serverInfo.checking then
        serverInfo.lastCheck = os.time()
        checkServerConnection()
    end
    win:Spacing(2)
    local okColor = 0xFF00FF00
    local badColor = 0xFF888888
    local srvColor = serverInfo.online and okColor or badColor
    local apiColor = (serverInfo.online and PRESET_API_KEY ~= "") and okColor or badColor
    win:Card(":globe: SERVER", 478, 150, function()
        win:Text("Status      : ")
        win:SameLine(0, 2)
        win:Text(serverInfo.online and ":check: Online" or ":times: Offline", srvColor)
        win:Text("Ping        : " .. (serverInfo.online and (serverInfo.ping .. " ms") or "-"))
        win:Text("Region      : " .. serverInfo.region)
    end)
    win:SameLine(0, 8)
    win:Card(":plug: API", 478, 150, function()
        win:Text("API         : ")
        win:SameLine(0, 2)
        win:Text(serverInfo.online and ":check: Connected" or ":times: Disconnected", apiColor)
        win:Text("Key         : " .. (PRESET_API_KEY ~= "" and ":check: Active" or ":times: None"))
        win:Text("Heartbeat   : " .. (serverInfo.online and ":check: Running" or ":times: Stopped"))
    end)
    win:Spacing(2)
    win:Card(":sync: RESTART WATCH", 480, 235, function()
        win:Text("restartId (server)  : " .. tostring(restartInfo.currentRestartId or "-"))
        win:Text("lastRestartId (loader): " .. tostring(restartInfo.lastRestartId or "-"))
        win:Text("Saw restarting      : " .. (restartInfo.sawRestarting and "Yes" or "No"))
        win:Text("Saw offline         : " .. (restartInfo.sawOffline and "Yes" or "No"))
        win:Spacing(1)
        if restartDetected then
            win:Text(":check: Last restart has been displayed", 0xFF00FF00)
        else
            win:Text("No restart detected yet.", 0xFFAAAAAA)
        end
    end)
    win:SameLine(0, 8)
    if win:Button(":user-friends: USER MONITOR", nil, 480, 235) then
        serverSubView = "users"
    end
    win:Spacing(2)
    if win:Button(":sync: Check Now##checkApi", nil, 180, 30) then
        serverInfo.lastCheck = 0
        pushLog("SERVER", "Manual check Server status...")
    end
end

local NavWin = Gui.New({
    title = "Mythical Navigation",
    size = {UI_CFG.NavW, UI_CFG.NavH},
    pos = {UI_CFG.NavX, UI_CFG.NavY},
    flags = wflag("NoTitleBar", 1) + wflag("NoResize", 2) + wflag("NoMove", 4)
        + wflag("NoCollapse", 32) + wflag("AlwaysAutoResize", 64) + wflag("NoSavedSettings", 256),
    theme = UI_THEME,
    style = UI_STYLE,
    OnRender = function(win)
        if win:Button(":chevron-left:##navPrev", nil, UI_CFG.NavArrowW, UI_CFG.NavBtnH) then
            if navScroll > 1 then navScroll = navScroll - 1 end
        end
        win:SameLine(0, UI_CFG.NavGap)
        local lastIdx = math.min(#navItems, navScroll + UI_CFG.NavVisible - 1)
        for i = navScroll, lastIdx do
            local it = navItems[i]
            if win:Button(it.icon .. "\n" .. it.label .. "##nav" .. it.id, nil, UI_CFG.NavBtnW, UI_CFG.NavBtnH) then
                openFeature(it.id)
            end
            win:SameLine(0, UI_CFG.NavGap)
        end
        if win:Button(":chevron-right:##navNext", nil, UI_CFG.NavArrowW, UI_CFG.NavBtnH) then
            if navScroll + UI_CFG.NavVisible <= #navItems then navScroll = navScroll + 1 end
        end
    end
})

FeatureWin = Gui.New({
    title = "Mythical - Loader </>",
    size = {UI_CFG.MainW, UI_CFG.MainH},
    pos = {UI_CFG.MainX, UI_CFG.MainY},
    flags = wflag("NoResize", 2) + wflag("NoCollapse", 32),
    theme = UI_THEME,
    style = UI_STYLE,
    OnRender = function(win)
        if win:Button(":arrow-left: Back To Menu##backToMenuBtn", nil, UI_CFG.BackW, UI_CFG.BackH) then
            currentFeature = "menu"
        end
        win:SameLine(0, 12)
        win:Text(":house: " .. featureLabel(currentFeature), 0xFFFF6060)
        win:SameLine(0, 12)
        win:Text("|", 0xFF8A8A8A)
        win:SameLine(0, 12)
        win:Text(accountData.username .. " (" .. detectedOS .. ")", 0xFFAAAAAA)
        win:Separator()
        win:Spacing(2)
        if currentFeature == "accounts" then
            renderAccountsFeature(win)
        elseif currentFeature == "scripts" then
            renderScriptsFeature(win)
        elseif currentFeature == "alert" then
            renderAlertFeature(win)
        elseif currentFeature == "ai" then
            renderAiFeature(win)
        elseif currentFeature == "project" then
            renderProjectFeature(win)
        elseif currentFeature == "chat" then
            renderChatFeature(win)
        elseif currentFeature == "server" then
            renderServerFeature(win)
        elseif currentFeature == "live" then
            renderLiveFeature(win)
        end
    end
})

local globalNotifFetchTime = 0
local globalNotifFetching = false

local function fetchDynamicNotifications()
    if globalNotifFetching then return end
    globalNotifFetching = true
    pcall(REAL_RUNTHREAD, function()
        local res = apiGet("/api/loader/chat")
        if res and res.content then
            local arr = findJsonArray(res.content, "messages") or findJsonArray(res.content, "chat")
            if arr then
                for _, obj in ipairs(extractJsonObjects(arr)) do
                    local user = jsonString(obj, "user") or jsonString(obj, "username") or "System"
                    local m = jsonString(obj, "msg") or jsonString(obj, "message") or jsonString(obj, "text")
                    if user and m then
                        local key = user .. ":" .. m
                        if not seenNotifs[key] then
                            seenNotifs[key] = true
                            spawnNotif("chat", user .. ": " .. m, 6.0)
                        end
                    end
                end
            end
        end
        local res2 = apiGet("/api/loader/alerts")
        if res2 and res2.content then
            local arr2 = findJsonArray(res2.content, "alerts")
            if arr2 then
                for _, obj in ipairs(extractJsonObjects(arr2)) do
                    local m = jsonString(obj, "message") or jsonString(obj, "text") or jsonString(obj, "msg") or jsonString(obj, "title")
                    if m and not seenNotifs["alert:"..m] then
                        seenNotifs["alert:"..m] = true
                        spawnNotif("system", m, 6.0)
                    end
                end
            end
        end
        globalNotifFetching = false
    end)
end

AddHook("OnDraw", "RenderBothaxUI", function(dt)
    globalDt = tonumber(dt) or 0.016

    updateNotifications(globalDt)

    userMonitor.liveDot = (userMonitor.liveDot + globalDt) % 1.0

    for _, state in pairs(runningServerScripts) do
        state.runTime = (state.runTime or 0) + (tonumber(globalDt) or 0.016)
    end

    for sid, st in pairs(runningServerScripts) do
        if st.phase == "ran" and not st.mainRunning and not st.stop
            and (st.bgThreads or 0) <= 0 and (not st.hookLabels or #st.hookLabels == 0) then
            runningServerScripts[sid] = nil
            for _, s in ipairs(scriptList) do
                if scriptSid(s) == sid then s.running = false end
            end
            pushLog("SCRIPT", tostring(st.name) .. " finished execution.")
        end
    end
    for key, st in pairs(runningFiles) do
        if st.phase == "ran" and not st.mainRunning and not st.stop
            and (st.bgThreads or 0) <= 0 and (not st.hookLabels or #st.hookLabels == 0) then
            runningFiles[key] = nil
            pushLog("SCRIPT", tostring(st.name or key) .. " finished execution.")
        end
    end

    if restartPopup.active then
        restartPopup.timer = restartPopup.timer - globalDt
        if restartPopup.timer <= 0 then
            restartPopup.active = false
            restartPopup.forceClose = true
            pushLog("RESTART", "Restart popup closed automatically, loader back to normal.")
        end
    end

    if (os.time() - globalNotifFetchTime) > 60 then
        globalNotifFetchTime = os.time()
        fetchDynamicNotifications()
    end

    if not isLoggedIn then
        AuthWin:Render()
    else
        if currentFeature == "menu" then
            pinWindow(UI_CFG.NavX, UI_CFG.NavY)
            NavWin:Render()
        else
            FeatureWin:Render()
        end
    end

    if #_MythNotifs > 0 or #_MythPending > 0 then
        pinWindow(12, 12)
        OverlayWin:Render()
    end

    if restartPopup.active then
        pinWindow(750, 250)
        RestartWin:Render()
    end
end)
