local CustomUI = {}
CustomUI.__index = CustomUI

local Vec2 = nil

if type(ImGui) == "table" then
    if type(ImGui.ImVec2) == "function" then
        Vec2 = ImGui.ImVec2
    elseif type(ImGui.Vec2) == "function" then
        Vec2 = ImGui.Vec2
    end
end

if not Vec2 and type(_G.Vec2) == "function" then
    Vec2 = _G.Vec2
end

if not Vec2 and type(_G.ImVec2) == "function" then
    Vec2 = _G.ImVec2
end

CustomUI.Theme = {
    WindowBg = 0xFF000000,
    ChildBg = 0xFF090909,
    PopupBg = 0xFF101010,

    TitleBg = 0xFF080808,
    TitleBgActive = 0xFF080808,
    TitleBgCollapsed = 0xFF080808,

    Text = 0xFFF2F2F2,

    Button = 0xFF18B92A,
    ButtonHovered = 0xFF2CDE42,
    ButtonActive = 0xFF0E8A1D,

    FrameBg = 0xFF111111,
    FrameBgHovered = 0xFF191919,
    FrameBgActive = 0xFF232323,

    Border = 0xFF465C31,
    BorderShadow = 0xFF000000,

    Separator = 0xFF465C31
}

local function num(value, fallback)
    local n = tonumber(value)
    if n == nil then
        return fallback
    end
    return n
end

local function xy(value)
    if not value then
        return nil, nil
    end

    local x
    local y

    pcall(function()
        x = value.x
        y = value.y
    end)

    if not tonumber(x) or not tonumber(y) then
        pcall(function()
            x = value[1]
            y = value[2]
        end)
    end

    x = tonumber(x)
    y = tonumber(y)

    if not x or not y then
        return nil, nil
    end

    if x ~= x or y ~= y then
        return nil, nil
    end

    return x, y
end

local function getScreenSize()
    if type(GetCamera) == "function" then
        local ok, camera = pcall(GetCamera)

        if ok and camera then
            local resolution

            pcall(function()
                resolution = camera.resolution
            end)

            local w, h = xy(resolution)

            if w and h and w > 0 and h > 0 then
                return w, h
            end
        end
    end

    if type(ImGui) == "table"
        and type(ImGui.GetIO) == "function" then

        local ok, io = pcall(ImGui.GetIO)

        if ok and io then
            local displaySize

            pcall(function()
                displaySize = io.DisplaySize
            end)

            local w, h = xy(displaySize)

            if w and h and w > 0 and h > 0 then
                return w, h
            end
        end
    end

    if type(GetScreenSize) == "function" then
        local ok, value = pcall(GetScreenSize)

        if ok then
            local w, h = xy(value)

            if w and h and w > 0 and h > 0 then
                return w, h
            end
        end
    end

    return nil, nil
end

local function safeSetWindowPos(x, y)
    if type(ImGui.SetWindowPos) ~= "function" then
        return false
    end

    if not x or not y then
        return false
    end

    if Vec2 then
        local ok = pcall(
            ImGui.SetWindowPos,
            Vec2(x, y)
        )

        if ok then
            return true
        end
    end

    return pcall(
        ImGui.SetWindowPos,
        x,
        y
    )
end

local function clampWindowPosition()
    if type(ImGui.GetWindowPos) ~= "function"
        or type(ImGui.GetWindowSize) ~= "function" then
        return
    end

    local sw, sh = getScreenSize()

    if not sw or not sh then
        return
    end

    local okPos, pos = pcall(ImGui.GetWindowPos)
    local okSize, size = pcall(ImGui.GetWindowSize)

    if not okPos or not okSize then
        return
    end

    if not pos or not size then
        return
    end

    local x, y = xy(pos)
    local w, h = xy(size)

    if not x or not y or not w or not h then
        return
    end

    if w <= 0 or h <= 0 then
        return
    end

    local margin = 2

    local maxX = math.max(
        margin,
        sw - w - margin
    )

    local maxY = math.max(
        margin,
        sh - h - margin
    )

    local newX = math.max(
        margin,
        math.min(x, maxX)
    )

    local newY = math.max(
        margin,
        math.min(y, maxY)
    )

    if math.abs(newX - x) > 1
        or math.abs(newY - y) > 1 then

        safeSetWindowPos(
            newX,
            newY
        )
    end
end

local function easeOutCubic(t)
    if t <= 0 then
        return 0
    end

    if t >= 1 then
        return 1
    end

    local u = 1 - t

    return 1 - u * u * u
end

function CustomUI.New(config)
    config = config or {}

    local self = setmetatable({}, CustomUI)

    self.title =
        config.title or
        "Custom UI"

    self.size =
        config.size or
        {520, 380}

    self.visible =
        config.visible ~= false

    self.flags =
        config.flags or 0

    self.theme =
        config.theme or
        CustomUI.Theme

    self.OnRender =
        config.OnRender or
        function()
        end

    self.activeTab =
        config.activeTab or
        "main"

    self.animationDuration =
        num(
            config.animationDuration,
            0.28
        )

    self.animation = 1

    self.lastTime =
        type(os.clock) == "function"
        and os.clock()
        or 0

    self.clampEnabled =
        config.clamp ~= false

    self.buttonStatus = "READY"

    self.loadingStates = {}

    self.toggleStates = {}

    return self
end

function CustomUI:RestartAnimation()
    self.animation = 0

    if type(os.clock) == "function" then
        self.lastTime = os.clock()
    end
end

function CustomUI:OpenTab(name)
    self.activeTab = tostring(name)
    self:RestartAnimation()
end

function CustomUI:GetTab()
    return self.activeTab
end

function CustomUI:UpdateAnimation()
    if self.animation >= 1 then
        self.animation = 1
        return
    end

    local now =
        type(os.clock) == "function"
        and os.clock()
        or self.lastTime + 0.016

    local dt =
        now - self.lastTime

    self.lastTime = now

    if dt <= 0 then
        dt = 0.016
    end

    if dt > 0.05 then
        dt = 0.05
    end

    local duration =
        math.max(
            0.05,
            self.animationDuration
        )

    self.animation =
        self.animation +
        dt / duration

    if self.animation >= 1 then
        self.animation = 1
    end
end

function CustomUI:GetAnimationOffset(distance)
    self:UpdateAnimation()

    local d =
        num(distance, 30)

    return d *
        (
            1 -
            easeOutCubic(
                self.animation
            )
        )
end

function CustomUI:PushTheme()
    if type(ImGui.PushStyleColor) ~= "function"
        or type(ImGui.Col) ~= "table" then
        return 0
    end

    local t = self.theme
    local count = 0

    local colors = {
        {ImGui.Col.WindowBg, t.WindowBg},
        {ImGui.Col.ChildBg, t.ChildBg},
        {ImGui.Col.PopupBg, t.PopupBg},

        {ImGui.Col.TitleBg, t.TitleBg},
        {ImGui.Col.TitleBgActive, t.TitleBgActive},
        {ImGui.Col.TitleBgCollapsed, t.TitleBgCollapsed},

        {ImGui.Col.Text, t.Text},

        {ImGui.Col.FrameBg, t.FrameBg},
        {ImGui.Col.FrameBgHovered, t.FrameBgHovered},
        {ImGui.Col.FrameBgActive, t.FrameBgActive},

        {ImGui.Col.Border, t.Border},
        {ImGui.Col.BorderShadow, t.BorderShadow},

        {ImGui.Col.Separator, t.Separator},
        {ImGui.Col.SeparatorHovered, t.Separator},
        {ImGui.Col.SeparatorActive, t.Separator}
    }

    for _, item in ipairs(colors) do
        if item[1] ~= nil
            and item[2] ~= nil then

            local ok = pcall(
                ImGui.PushStyleColor,
                item[1],
                item[2]
            )

            if ok then
                count = count + 1
            end
        end
    end

    return count
end

function CustomUI:PopTheme(count)
    if count <= 0 then
        return
    end

    if type(ImGui.PopStyleColor) == "function" then
        pcall(
            ImGui.PopStyleColor,
            count
        )
    end
end

function CustomUI:PushWindowStyle()
    if type(ImGui.PushStyleVar) ~= "function"
        or type(ImGui.StyleVar) ~= "table" then
        return 0
    end

    local count = 0

    local styles = {}

    if ImGui.StyleVar.WindowBorderSize ~= nil then
        table.insert(
            styles,
            {
                ImGui.StyleVar.WindowBorderSize,
                1
            }
        )
    end

    if ImGui.StyleVar.WindowRounding ~= nil then
        table.insert(
            styles,
            {
                ImGui.StyleVar.WindowRounding,
                6
            }
        )
    end

    for _, item in ipairs(styles) do
        local ok = pcall(
            ImGui.PushStyleVar,
            item[1],
            item[2]
        )

        if ok then
            count = count + 1
        end
    end

    return count
end

function CustomUI:PopWindowStyle(count)
    if count <= 0 then
        return
    end

    if type(ImGui.PopStyleVar) == "function" then
        pcall(
            ImGui.PopStyleVar,
            count
        )
    end
end

function CustomUI:PushButtonStyle()
    if type(ImGui.PushStyleColor) ~= "function"
        or type(ImGui.Col) ~= "table" then
        return 0
    end

    local t = self.theme
    local count = 0

    local colors = {
        {
            ImGui.Col.Button,
            t.Button
        },
        {
            ImGui.Col.ButtonHovered,
            t.ButtonHovered
        },
        {
            ImGui.Col.ButtonActive,
            t.ButtonActive
        }
    }

    for _, item in ipairs(colors) do
        if item[1] ~= nil
            and item[2] ~= nil then

            local ok = pcall(
                ImGui.PushStyleColor,
                item[1],
                item[2]
            )

            if ok then
                count = count + 1
            end
        end
    end

    return count
end

function CustomUI:PopButtonStyle(count)
    if count <= 0 then
        return
    end

    if type(ImGui.PopStyleColor) == "function" then
        pcall(
            ImGui.PopStyleColor,
            count
        )
    end
end

function CustomUI:Begin()
    local themeCount =
        self:PushTheme()

    local styleCount =
        self:PushWindowStyle()

    if type(ImGui.SetNextWindowSize) == "function"
        and Vec2 then

        pcall(
            ImGui.SetNextWindowSize,
            Vec2(
                num(self.size[1], 520),
                num(self.size[2], 380)
            ),
            (ImGui.Cond and ImGui.Cond.FirstUseEver)
            or 1
        )
    end

    if type(ImGui.Begin) ~= "function" then
        self:PopWindowStyle(styleCount)
        self:PopTheme(themeCount)

        return false, false, 0, 0
    end

    local ok
    local opened

    ok, opened =
        pcall(
            ImGui.Begin,
            self.title,
            true,
            self.flags
        )

    if not ok then
        ok, opened =
            pcall(
                ImGui.Begin,
                self.title,
                true
            )
    end

    if not ok then
        self:PopWindowStyle(styleCount)
        self:PopTheme(themeCount)

        return false, false, 0, 0
    end

    return true,
        opened ~= false,
        themeCount,
        styleCount
end

function CustomUI:End(themeCount, styleCount)
    if type(ImGui.End) == "function" then
        pcall(ImGui.End)
    end

    self:PopWindowStyle(styleCount)
    self:PopTheme(themeCount)
end

function CustomUI:Text(text)
    if type(ImGui.Text) == "function" then
        pcall(
            ImGui.Text,
            tostring(text)
        )
    end
end

function CustomUI:ColoredText(text, color)
    local count = 0

    if color
        and type(ImGui.PushStyleColor) == "function"
        and type(ImGui.Col) == "table"
        and ImGui.Col.Text ~= nil then

        local ok = pcall(
            ImGui.PushStyleColor,
            ImGui.Col.Text,
            color
        )

        if ok then
            count = 1
        end
    end

    self:Text(text)

    if count > 0
        and type(ImGui.PopStyleColor) == "function" then

        pcall(
            ImGui.PopStyleColor,
            count
        )
    end
end

function CustomUI:Separator()
    if type(ImGui.Separator) == "function" then
        pcall(ImGui.Separator)
    end
end

function CustomUI:SameLine()
    if type(ImGui.SameLine) == "function" then
        pcall(ImGui.SameLine)
    end
end

function CustomUI:Dummy(width, height)
    if type(ImGui.Dummy) == "function"
        and Vec2 then

        pcall(
            ImGui.Dummy,
            Vec2(
                num(width, 1),
                num(height, 1)
            )
        )
    end
end

function CustomUI:Button(label, width, height)
    if type(ImGui.Button) ~= "function" then
        return false
    end

    local w = num(width, 120)
    local h = num(height, 36)

    local colors =
        self:PushButtonStyle()

    local clicked = false

    if Vec2 then
        local ok, result = pcall(
            ImGui.Button,
            tostring(label),
            Vec2(w, h)
        )

        if ok then
            clicked = result == true
        end
    else
        local ok, result = pcall(
            ImGui.Button,
            tostring(label),
            w,
            h
        )

        if ok then
            clicked = result == true
        end
    end

    self:PopButtonStyle(colors)

    if clicked then
        self.buttonStatus = "CLICKED"
    end

    return clicked
end

local IconModels = {
    [1]  = {"←", 4},
    [2]  = {"→", 4},
    [3]  = {"↑", 4},
    [4]  = {"↓", 4},
    [5]  = {"＋", 8},
    [6]  = {"×", 8},
    [7]  = {"✓", 12},
    [8]  = {"!", 10},
    [9]  = {"?", 10},
    [10] = {"★", 12},
    [11] = {"☆", 12},
    [12] = {"◆", 10},
    [13] = {"◇", 10},
    [14] = {"●", 20},
    [15] = {"○", 20},
    [16] = {"■", 8},
    [17] = {"□", 8},
    [18] = {"▲", 8},
    [19] = {"▼", 8},
    [20] = {"◀", 8},
    [21] = {"▶", 8},
    [22] = {"⌂", 10},
    [23] = {"⚙", 8},
    [24] = {"☰", 8},
    [25] = {"☷", 8},
    [26] = {"♢", 10},
    [27] = {"♥", 12},
    [28] = {"⚡", 8},
    [29] = {"♟", 8},
    [30] = {"∞", 8}
}

function CustomUI:IconButton(model, size)
    local index = tonumber(model) or 1

    if index < 1 then
        index = 1
    end

    if index > 30 then
        index = 30
    end

    local data = IconModels[index]

    local label = data[1]
    local rounding = data[2]

    local s = num(size, 44)

    local colors =
        self:PushButtonStyle()

    local roundingCount = 0

    if type(ImGui.PushStyleVar) == "function"
        and type(ImGui.StyleVar) == "table"
        and ImGui.StyleVar.FrameRounding ~= nil then

        local ok = pcall(
            ImGui.PushStyleVar,
            ImGui.StyleVar.FrameRounding,
            rounding
        )

        if ok then
            roundingCount = 1
        end
    end

    local clicked = false

    if Vec2 then
        local ok, result = pcall(
            ImGui.Button,
            label,
            Vec2(s, s)
        )

        if ok then
            clicked = result == true
        end
    end

    if roundingCount > 0
        and type(ImGui.PopStyleVar) == "function" then

        pcall(
            ImGui.PopStyleVar,
            roundingCount
        )
    end

    self:PopButtonStyle(colors)

    if clicked then
        self.buttonStatus =
            "ICON " .. tostring(index)
    end

    return clicked
end

local ToggleModels = {
    [1]  = {"● ON", "○ OFF", 20},
    [2]  = {"ON ●", "OFF ○", 20},
    [3]  = {"[ ON ]", "[ OFF ]", 6},
    [4]  = {"< ON >", "< OFF >", 10},
    [5]  = {"━━●", "●━━", 20},
    [6]  = {"◉ ON", "○ OFF", 20},
    [7]  = {"●━━", "━━○", 20},
    [8]  = {"ON ◆", "OFF ◇", 8},
    [9]  = {"✓ ON", "× OFF", 8},
    [10] = {"ON ■", "OFF □", 8}
}

function CustomUI:Toggle(id, model, default, width, height)
    local key = tostring(id)

    if self.toggleStates[key] == nil then
        self.toggleStates[key] =
            default == true
    end

    local state =
        self.toggleStates[key]

    local index =
        tonumber(model) or 1

    if index < 1 then
        index = 1
    end

    if index > 10 then
        index = 10
    end

    local data =
        ToggleModels[index]

    local label

    if state then
        label = data[1]
    else
        label = data[2]
    end

    local colors = 0

    if type(ImGui.PushStyleColor) == "function"
        and type(ImGui.Col) == "table" then

        local t = self.theme

        local onColor =
            state
            and 0xFF18B92A
            or 0xFF303030

        local hoverColor =
            state
            and 0xFF2CDE42
            or 0xFF454545

        local activeColor =
            state
            and 0xFF0E8A1D
            or 0xFF202020

        local list = {
            {
                ImGui.Col.Button,
                onColor
            },
            {
                ImGui.Col.ButtonHovered,
                hoverColor
            },
            {
                ImGui.Col.ButtonActive,
                activeColor
            }
        }

        for _, item in ipairs(list) do
            if item[1] ~= nil then
                local ok = pcall(
                    ImGui.PushStyleColor,
                    item[1],
                    item[2]
                )

                if ok then
                    colors =
                        colors + 1
                end
            end
        end
    end

    local w =
        num(width, 92)

    local h =
        num(height, 34)

    local clicked = false

    if Vec2 then
        local ok, result = pcall(
            ImGui.Button,
            label,
            Vec2(w, h)
        )

        if ok then
            clicked =
                result == true
        end
    else
        local ok, result = pcall(
            ImGui.Button,
            label,
            w,
            h
        )

        if ok then
            clicked =
                result == true
        end
    end

    self:PopButtonStyle(colors)

    if clicked then
        self.toggleStates[key] = not state
        state = self.toggleStates[key]
    end

    return state
end

local LoadingModels = {
    [1]  = {"|", "/", "-", "\\"},
    [2]  = {"◐", "◓", "◑", "◒"},
    [3]  = {"◴", "◷", "◶", "◵"},
    [4]  = {"◰", "◳", "◲", "◱"},
    [5]  = {".", "..", "...", "...."},
    [6]  = {"·", "••", "•••", "••••"},
    [7]  = {"▁", "▂", "▃", "▄", "▅", "▆", "▇", "█"},
    [8]  = {"█", "▇", "▆", "▅", "▄", "▃", "▂", "▁"},
    [9]  = {"▉", "▊", "▋", "▌", "▍", "▎", "▏"},
    [10] = {"○", "◔", "◑", "◕", "●"},
    [11] = {"●○○○", "○●○○", "○○●○", "○○○●"},
    [12] = {"●○○", "○●○", "○○●"},
    [13] = {"[■   ]", "[■■  ]", "[■■■ ]", "[■■■■]"},
    [14] = {"[■]", "[■■]", "[■■■]", "[■■■■]"},
    [15] = {"<    >", "<=   >", "<==  >", "<=== >"},
    [16] = {"[    ]", "[=   ]", "[==  ]", "[=== ]", "[====]"},
    [17] = {"←", "↖", "↑", "↗", "→", "↘", "↓", "↙"},
    [18] = {"↺", "↻"},
    [19] = {"⠋", "⠙", "⠹", "⠸", "⠼", "⠴", "⠦", "⠧", "⠇", "⠏"},
    [20] = {"⠋", "⠙", "⠚", "⠒", "⠂", "⠂", "⠒", "⠲", "⠴", "⠦"},
    [21] = {"▖", "▘", "▝", "▗"},
    [22] = {"◢", "◣", "◤", "◥"},
    [23] = {"✦", "✧", "✦", "✧"},
    [24] = {"★", "✦", "✧", "✦"},
    [25] = {"<", "<<", "<<<", "<<<<"},
    [26] = {">", ">>", ">>>", ">>>>"},
    [27] = {"[●   ]", "[ ●  ]", "[  ● ]", "[   ●]"},
    [28] = {"|", "||", "|||", "||||"},
    [29] = {"◡", "◠", "◡", "◠"},
    [30] = {"LOADING", "LOADING.", "LOADING..", "LOADING..."}
}

function CustomUI:Loading(model, id)
    local index =
        tonumber(model) or 1

    if index < 1 then
        index = 1
    end

    if index > 30 then
        index = 30
    end

    local key =
        tostring(id or ("loading_" .. index))

    if self.loadingStates[key] == nil then
        self.loadingStates[key] = {
            frame = 1,
            last = 0
        }
    end

    local state =
        self.loadingStates[key]

    local now =
        type(os.clock) == "function"
        and os.clock()
        or 0

    if now - state.last >= 0.12 then
        state.frame =
            state.frame + 1

        state.last = now
    end

    local frames =
        LoadingModels[index]

    if state.frame > #frames then
        state.frame = 1
    end

    self:Text(
        frames[state.frame]
    )

    return frames[state.frame]
end

function CustomUI:LoadingText(model, text, id)
    local value =
        self:Loading(model, id)

    self:SameLine()

    self:Text(
        tostring(text or "Loading") ..
        " " ..
        tostring(value)
    )
end

function CustomUI:PanelBegin(id, width, height)
    if type(ImGui.BeginChild) ~= "function" then
        return false
    end

    local w =
        math.max(
            100,
            num(width, 200)
        )

    local h =
        math.max(
            80,
            num(height, 200)
        )

    local ok = false

    if Vec2 then
        ok = pcall(
            ImGui.BeginChild,
            tostring(id),
            Vec2(w, h),
            true
        )

        if not ok then
            ok = pcall(
                ImGui.BeginChild,
                tostring(id),
                Vec2(w, h),
                true,
                0
            )
        end
    end

    if not ok then
        ok = pcall(
            ImGui.BeginChild,
            tostring(id),
            w,
            h,
            true
        )
    end

    return ok
end

function CustomUI:PanelEnd()
    if type(ImGui.EndChild) == "function" then
        pcall(ImGui.EndChild)
    end
end

function CustomUI:PanelTitle(title)
    self:ColoredText(
        "─ " .. tostring(title),
        self.theme.Text
    )

    self:Separator()
end

function CustomUI:Panel(title, width, height, draw)
    if not self:PanelBegin(
        title,
        width,
        height
    ) then
        return
    end

    local offset =
        self:GetAnimationOffset(28)

    if offset > 0 then
        self:Dummy(1, offset)
    end

    self:PanelTitle(title)

    if type(draw) == "function" then
        pcall(
            draw,
            self
        )
    end

    self:PanelEnd()
end

function CustomUI:Show()
    self.visible = true
    self:RestartAnimation()
end

function CustomUI:Hide()
    self.visible = false
end

function CustomUI:IsVisible()
    return self.visible
end

function CustomUI:SetSize(width, height)
    self.size[1] =
        num(width, self.size[1])

    self.size[2] =
        num(height, self.size[2])
end

function CustomUI:SetTitle(title)
    self.title =
        tostring(title)
end

function CustomUI:Render()
    if not self.visible then
        return
    end

    local ok
    local opened
    local themeCount
    local styleCount

    ok,
    opened,
    themeCount,
    styleCount =
        self:Begin()

    if not ok then
        return
    end

    if opened then
        self:UpdateAnimation()

        pcall(
            self.OnRender,
            self
        )

        if self.clampEnabled then
            clampWindowPosition()
        end
    end

    self:End(
        themeCount,
        styleCount
    )
end

return CustomUI
