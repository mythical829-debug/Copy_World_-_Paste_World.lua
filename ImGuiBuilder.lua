local CustomUI = {}
CustomUI.__index = CustomUI

local Vec2 = nil
if type(ImGui) == "table" then
    if type(ImGui.ImVec2) == "function" then Vec2 = ImGui.ImVec2
    elseif type(ImGui.Vec2) == "function" then Vec2 = ImGui.Vec2 end
end
if not Vec2 and type(_G.Vec2) == "function" then Vec2 = _G.Vec2 end
if not Vec2 and type(_G.ImVec2) == "function" then Vec2 = _G.ImVec2 end

CustomUI.Theme = {
    WindowBg = 0xFF0F0F11,
    ChildBg = 0xFF1A1A1E,
    PopupBg = 0xFF1A1A1E,
    TitleBg = 0xFF0F0F11,
    TitleBgActive = 0xFF0F0F11,
    TitleBgCollapsed = 0xFF0F0F11,
    Text = 0xFFE0E0E0,
    Button = 0xFF2A2A2E,
    ButtonHovered = 0xFF3D3D42,
    ButtonActive = 0xFF50505A,
    FrameBg = 0xFF1A1A1E,
    FrameBgHovered = 0xFF252529,
    FrameBgActive = 0xFF303035,
    Border = 0xFF2A2A2E,
    BorderShadow = 0x00000000,
    Separator = 0xFF2A2A2E,
    CheckMark = 0xFF00E5FF
}

local function num(value, fallback)
    local n = tonumber(value)
    return n == nil and fallback or n
end

local function easeOutCubic(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return 1 - (1 - t)^3
end

function CustomUI.New(config)
    config = config or {}
    local self = setmetatable({}, CustomUI)
    self.title = config.title or "Custom UI"
    self.size = config.size or {520, 380}
    self.visible = config.visible ~= false
    self.flags = config.flags or 0
    self.theme = config.theme or CustomUI.Theme
    self.OnRender = config.OnRender or function() end
    self.activeTab = config.activeTab or "main"
    self.animationDuration = num(config.animationDuration, 0.3)
    self.animation = 1
    self.lastTime = type(os.clock) == "function" and os.clock() or 0
    self.clampEnabled = config.clamp ~= false
    self.loadingStates = {}
    self.toggleStates = {}
    self.buttonStatus = "READY"
    return self
end

function CustomUI:RestartAnimation()
    self.animation = 0
    if type(os.clock) == "function" then self.lastTime = os.clock() end
end

function CustomUI:OpenTab(name)
    self.activeTab = tostring(name)
    self:RestartAnimation()
end

function CustomUI:GetTab()
    return self.activeTab
end

function CustomUI:UpdateAnimation()
    if self.animation >= 1 then return end
    local now = type(os.clock) == "function" and os.clock() or self.lastTime + 0.016
    local dt = now - self.lastTime
    self.lastTime = now
    if dt <= 0 then dt = 0.016 end
    if dt > 0.05 then dt = 0.05 end
    self.animation = self.animation + dt / math.max(0.05, self.animationDuration)
    if self.animation >= 1 then self.animation = 1 end
end

function CustomUI:GetAnimationOffset(distance)
    self:UpdateAnimation()
    return num(distance, 30) * (1 - easeOutCubic(self.animation))
end

function CustomUI:PushTheme()
    if type(ImGui.PushStyleColor) ~= "function" or type(ImGui.Col) ~= "table" then return 0 end
    local t, count = self.theme, 0
    local cols = {
        {ImGui.Col.WindowBg, t.WindowBg}, {ImGui.Col.ChildBg, t.ChildBg}, {ImGui.Col.PopupBg, t.PopupBg},
        {ImGui.Col.TitleBg, t.TitleBg}, {ImGui.Col.TitleBgActive, t.TitleBgActive}, {ImGui.Col.TitleBgCollapsed, t.TitleBgCollapsed},
        {ImGui.Col.Text, t.Text}, {ImGui.Col.FrameBg, t.FrameBg}, {ImGui.Col.FrameBgHovered, t.FrameBgHovered},
        {ImGui.Col.FrameBgActive, t.FrameBgActive}, {ImGui.Col.Border, t.Border}, {ImGui.Col.BorderShadow, t.BorderShadow},
        {ImGui.Col.Separator, t.Separator}, {ImGui.Col.SeparatorHovered, t.Separator}, {ImGui.Col.SeparatorActive, t.Separator},
        {ImGui.Col.Button, t.Button}, {ImGui.Col.ButtonHovered, t.ButtonHovered}, {ImGui.Col.ButtonActive, t.ButtonActive},
        {ImGui.Col.CheckMark, t.CheckMark}
    }
    for _, c in ipairs(cols) do
        if c[1] and c[2] and pcall(ImGui.PushStyleColor, c[1], c[2]) then count = count + 1 end
    end
    return count
end

function CustomUI:PopTheme(count)
    if count > 0 and type(ImGui.PopStyleColor) == "function" then pcall(ImGui.PopStyleColor, count) end
end

function CustomUI:Begin()
    local tCount = self:PushTheme()
    if type(ImGui.SetNextWindowSize) == "function" and Vec2 then
        pcall(ImGui.SetNextWindowSize, Vec2(num(self.size[1], 520), num(self.size[2], 380)), (ImGui.Cond and ImGui.Cond.FirstUseEver) or 1)
    elseif type(ImGui.SetNextWindowSize) == "function" then
        pcall(ImGui.SetNextWindowSize, num(self.size[1], 520), num(self.size[2], 380), 1)
    end
    if type(ImGui.Begin) ~= "function" then self:PopTheme(tCount) return false, false, tCount end
    local ok, opened = pcall(ImGui.Begin, self.title, true, self.flags)
    if not ok then ok, opened = pcall(ImGui.Begin, self.title, true) end
    return ok, opened ~= false, tCount
end

function CustomUI:End(tCount)
    if type(ImGui.End) == "function" then pcall(ImGui.End) end
    self:PopTheme(tCount)
end

function CustomUI:Text(text)
    if type(ImGui.Text) == "function" then pcall(ImGui.Text, tostring(text)) end
end

function CustomUI:ColoredText(text, color)
    local c = 0
    if color and type(ImGui.PushStyleColor) == "function" and type(ImGui.Col) == "table" and ImGui.Col.Text then
        if pcall(ImGui.PushStyleColor, ImGui.Col.Text, color) then c = 1 end
    end
    self:Text(text)
    if c > 0 and type(ImGui.PopStyleColor) == "function" then pcall(ImGui.PopStyleColor, c) end
end

function CustomUI:Separator() if type(ImGui.Separator) == "function" then pcall(ImGui.Separator) end end
function CustomUI:SameLine() if type(ImGui.SameLine) == "function" then pcall(ImGui.SameLine) end end
function CustomUI:Dummy(w, h)
    if type(ImGui.Dummy) == "function" and Vec2 then pcall(ImGui.Dummy, Vec2(num(w, 1), num(h, 1))) end
end

local BtnStyles = {
    {r=0, p={10,5}, b=1}, {r=4, p={12,6}, b=0}, {r=12, p={15,8}, b=0}, {r=0, p={8,4}, b=2}, {r=20, p={20,8}, b=1},
    {r=0, p={10,5}, b=0}, {r=6, p={14,7}, b=1}, {r=10, p={10,5}, b=2}, {r=0, p={12,6}, b=1}, {r=8, p={16,6}, b=0},
    {r=0, p={10,10}, b=1}, {r=4, p={8,8}, b=0}, {r=16, p={12,5}, b=1}, {r=0, p={6,12}, b=2}, {r=20, p={15,5}, b=0},
    {r=2, p={10,5}, b=2}, {r=2, p={14,7}, b=0}, {r=18, p={20,10}, b=1}, {r=0, p={20,5}, b=0}, {r=10, p={10,10}, b=2},
    {r=0, p={5,5}, b=1}, {r=4, p={18,4}, b=0}, {r=14, p={14,14}, b=0}, {r=0, p={16,8}, b=2}, {r=6, p={20,6}, b=1},
    {r=0, p={12,12}, b=0}, {r=8, p={12,6}, b=2}, {r=20, p={10,5}, b=2}, {r=0, p={10,5}, b=0}, {r=10, p={15,7}, b=1}
}

function CustomUI:Button(label, styleIdx, width, height)
    if type(ImGui.Button) ~= "function" then return false end
    local idx = math.max(1, math.min(30, tonumber(styleIdx) or 1))
    local s = BtnStyles[idx]
    local w, h = num(width, 120), num(height, 36)
    local sv = 0
    
    if type(ImGui.PushStyleVar) == "function" and type(ImGui.StyleVar) == "table" then
        if ImGui.StyleVar.FrameRounding and pcall(ImGui.PushStyleVar, ImGui.StyleVar.FrameRounding, s.r) then sv = sv + 1 end
        if ImGui.StyleVar.FramePadding and pcall(ImGui.PushStyleVar, ImGui.StyleVar.FramePadding, s.p[1], s.p[2]) then sv = sv + 1 end
        if ImGui.StyleVar.FrameBorderSize and pcall(ImGui.PushStyleVar, ImGui.StyleVar.FrameBorderSize, s.b) then sv = sv + 1 end
    end

    local clicked = false
    local ok, res = pcall(ImGui.Button, tostring(label), w, h)
    if not ok and Vec2 then
        ok, res = pcall(ImGui.Button, tostring(label), Vec2(w, h))
    end
    if ok then clicked = res == true end

    if sv > 0 and type(ImGui.PopStyleVar) == "function" then pcall(ImGui.PopStyleVar, sv) end
    if clicked then self.buttonStatus = "BUTTON " .. idx .. " CLICKED" end
    return clicked
end

local TogStyles = {
    {on="●", off="○", r=20, onC=0xFF00E5FF, offC=0xFF505050, p={2,2}},
    {on="[X]", off="[ ]", r=0, onC=0xFF00E5FF, offC=0xFF505050, p={6,4}},
    {on="ON", off="OFF", r=4, onC=0xFF00FF66, offC=0xFF555555, p={10,5}},
    {on="✓", off="×", r=4, onC=0xFF00FF66, offC=0xFFFF5555, p={8,4}},
    {on="Enable", off="Disable", r=8, onC=0xFF00E5FF, offC=0xFF505050, p={8,5}},
    {on=">", off="<", r=10, onC=0xFF00E5FF, offC=0xFF505050, p={10,4}},
    {on="▲", off="▼", r=0, onC=0xFF00E5FF, offC=0xFF505050, p={8,4}},
    {on="Start", off="Stop", r=20, onC=0xFF00FF66, offC=0xFFFF5555, p={12,6}},
    {on="I", off="O", r=0, onC=0xFF00E5FF, offC=0xFF505050, p={10,4}},
    {on="█", off="▒", r=0, onC=0xFF00E5FF, offC=0xFF505050, p={8,4}},
    {on="True", off="False", r=4, onC=0xFF00FF66, offC=0xFFFF5555, p={8,5}},
    {on=">>", off="<<", r=20, onC=0xFF00E5FF, offC=0xFF505050, p={10,4}},
    {on="✔", off="✖", r=10, onC=0xFF00FF66, offC=0xFFFF5555, p={8,4}},
    {on="+", off="-", r=20, onC=0xFF00E5FF, offC=0xFF505050, p={10,4}},
    {on="YES", off="NO", r=0, onC=0xFF00FF66, offC=0xFFFF5555, p={10,5}},
    {on="❖", off="◇", r=0, onC=0xFF00E5FF, offC=0xFF505050, p={8,4}},
    {on="❤", off="♡", r=20, onC=0xFFFF4D4D, offC=0xFF505050, p={8,4}},
    {on="▶", off="■", r=4, onC=0xFF00FF66, offC=0xFF505050, p={8,4}},
    {on="◉", off="◯", r=20, onC=0xFF00E5FF, offC=0xFF505050, p={4,2}},
    {on="L", off="R", r=0, onC=0xFF00E5FF, offC=0xFF505050, p={10,4}},
    {on="ON", off="OFF", r=20, onC=0xFF00FF66, offC=0xFF555555, p={12,5}},
    {on="ON", off="OFF", r=0, onC=0xFF00FF66, offC=0xFF555555, p={10,5}, b=2},
    {on="✓", off=" ", r=2, onC=0xFF00FF66, offC=0xFF555555, p={6,6}, b=1},
    {on="✔", off=".", r=0, onC=0xFF00FF66, offC=0xFF555555, p={8,4}},
    {on="▶", off="◁", r=0, onC=0xFF00FF66, offC=0xFF505050, p={6,4}},
    {on="✪", off="☆", r=20, onC=0xFF00E5FF, offC=0xFF505050, p={6,4}},
    {on="⚡", off="＿", r=4, onC=0xFFFFD700, offC=0xFF505050, p={8,4}},
    {on="◈", off="◇", r=8, onC=0xFF00E5FF, offC=0xFF505050, p={8,4}},
    {on="◼", off="◻", r=4, onC=0xFF00E5FF, offC=0xFF505050, p={6,4}},
    {on="♪", off="♫", r=20, onC=0xFF00E5FF, offC=0xFF505050, p={8,4}}
}

function CustomUI:Toggle(id, styleIdx, default, width, height)
    local key = tostring(id)
    if self.toggleStates[key] == nil then self.toggleStates[key] = default == true end
    local state = self.toggleStates[key]
    
    local idx = math.max(1, math.min(30, tonumber(styleIdx) or 1))
    local s = TogStyles[idx]
    local label = state and s.on or s.off
    local w, h = num(width, 80), num(height, 30)
    
    local c, sv = 0, 0
    if type(ImGui.PushStyleColor) == "function" and type(ImGui.Col) == "table" then
        local col = state and s.onC or s.offC
        local hCol = state and (s.onC + 0x11000000) or (s.offC + 0x11000000)
        local aCol = state and (s.onC - 0x11000000) or (s.offC - 0x11000000)
        if ImGui.Col.Button and pcall(ImGui.PushStyleColor, ImGui.Col.Button, col) then c = c + 1 end
        if ImGui.Col.ButtonHovered and pcall(ImGui.PushStyleColor, ImGui.Col.ButtonHovered, hCol) then c = c + 1 end
        if ImGui.Col.ButtonActive and pcall(ImGui.PushStyleColor, ImGui.Col.ButtonActive, aCol) then c = c + 1 end
    end
    
    if type(ImGui.PushStyleVar) == "function" and type(ImGui.StyleVar) == "table" then
        if ImGui.StyleVar.FrameRounding and pcall(ImGui.PushStyleVar, ImGui.StyleVar.FrameRounding, s.r) then sv = sv + 1 end
        if ImGui.StyleVar.FramePadding and pcall(ImGui.PushStyleVar, ImGui.StyleVar.FramePadding, s.p[1], s.p[2]) then sv = sv + 1 end
        if s.b and ImGui.StyleVar.FrameBorderSize and pcall(ImGui.PushStyleVar, ImGui.StyleVar.FrameBorderSize, s.b) then sv = sv + 1 end
    end

    local clicked = false
    local ok, res = pcall(ImGui.Button, label, w, h)
    if not ok and Vec2 then
        ok, res = pcall(ImGui.Button, label, Vec2(w, h))
    end
    if ok then clicked = res == true end

    if c > 0 and type(ImGui.PopStyleColor) == "function" then pcall(ImGui.PopStyleColor, c) end
    if sv > 0 and type(ImGui.PopStyleVar) == "function" then pcall(ImGui.PopStyleVar, sv) end

    if clicked then
        self.toggleStates[key] = not state
        state = self.toggleStates[key]
    end
    return state
end

local Loaders = {
    [1]={"|","/","-","\\"}, [2]={"◐","◓","◑","◒"}, [3]={"◴","◷","◶","◵"}, [4]={"◰","◳","◲","◱"}, [5]={".","..","...","...."},
    [6]={"·","••","•••","••••"}, [7]={"▁","▂","▃","▄","▅","▆","▇","█"}, [8]={"█","▇","▆","▅","▄","▃","▂","▁"}, [9]={"▉","▊","▋","▌","▍","▎","▏"}, [10]={"○","◔","◑","◕","●"},
    [11]={"●○○○","○●○○","○○●○","○○○●"}, [12]={"●○○","○●○","○○●"}, [13]={"[■   ]","[■■  ]","[■■■ ]","[■■■■]"}, [14]={"[■]","[■■]","[■■■]","[■■■■]"}, [15]={"<    >","<=   >","<==  >","<=== >"},
    [16]={"[    ]","[=   ]","[==  ]","[=== ]","[====]"}, [17]={"←","↖","↑","↗","→","↘","↓","↙"}, [18]={"↺","↻"}, [19]={"⠋","⠙","⠹","⠸","⠼","⠴","⠦","⠧","⠇","⠏"}, [20]={"⠋","⠙","⠚","⠒","⠂","⠂","⠒","⠲","⠴","⠦"},
    [21]={"▖","▘","▝","▗"}, [22]={"◢","◣","◤","◥"}, [23]={"✦","✧","✦","✧"}, [24]={"★","✦","✧","✦"}, [25]={"<","<<","<<<","<<<<"},
    [26]={">",">>",">>>",">>>>"}, [27]={"[●   ]","[ ●  ]","[  ● ]","[   ●]"}, [28]={"|","||","|||","||||"}, [29]={"◡","◠","◡","◠"}, [30]={"LOADING","LOADING.","LOADING..","LOADING..."}
}

function CustomUI:Loading(model, id)
    local idx = math.max(1, math.min(30, tonumber(model) or 1))
    local key = tostring(id or ("load_"..idx))
    if self.loadingStates[key] == nil then self.loadingStates[key] = {frame=1, last=0} end
    local st = self.loadingStates[key]
    local now = type(os.clock) == "function" and os.clock() or 0
    if now - st.last >= 0.12 then
        st.frame = st.frame + 1
        st.last = now
    end
    local frames = Loaders[idx]
    if st.frame > #frames then st.frame = 1 end
    self:Text(frames[st.frame])
    return frames[st.frame]
end

function CustomUI:LoadingText(model, text, id)
    self:Loading(model, id)
    self:SameLine()
    self:Text(tostring(text or "Loading") .. " " .. self.loadingStates[tostring(id or ("load_"..(tonumber(model) or 1)))].frame)
end

function CustomUI:PanelBegin(id, w, h)
    if type(ImGui.BeginChild) ~= "function" then return false end
    if Vec2 then 
        local ok = pcall(ImGui.BeginChild, tostring(id), Vec2(num(w,200), num(h,200)), true)
        if not ok then pcall(ImGui.BeginChild, tostring(id), Vec2(num(w,200), num(h,200)), true, 0) end
        return ok
    end
    return pcall(ImGui.BeginChild, tostring(id), num(w,200), num(h,200), true)
end

function CustomUI:PanelEnd()
    if type(ImGui.EndChild) == "function" then pcall(ImGui.EndChild) end
end

function CustomUI:Panel(title, w, h, draw)
    if not self:PanelBegin(title, w, h) then return end
    local off = self:GetAnimationOffset(28)
    if off > 0 then self:Dummy(1, off) end
    self:ColoredText("─ " .. tostring(title), self.theme.Text)
    self:Separator()
    if type(draw) == "function" then pcall(draw, self) end
    self:PanelEnd()
end

function CustomUI:Show() self.visible = true self:RestartAnimation() end
function CustomUI:Hide() self.visible = false end
function CustomUI:Render()
    if not self.visible then return end
    local ok, opened, tCount = self:Begin()
    if ok and opened then
        self:UpdateAnimation()
        pcall(self.OnRender, self)
    end
    self:End(tCount)
end

return CustomUI
