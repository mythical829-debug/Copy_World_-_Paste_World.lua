local CustomUI = {}
CustomUI.__index = CustomUI

local Vec2 = nil
if type(ImGui) == "table" then
    if type(ImGui.ImVec2) == "function" then Vec2 = ImGui.ImVec2
    elseif type(ImGui.Vec2) == "function" then Vec2 = ImGui.Vec2 end
end
if not Vec2 and type(_G.Vec2) == "function" then Vec2 = _G.Vec2 end
if not Vec2 and type(_G.ImVec2) == "function" then Vec2 = _G.ImVec2 end

CustomUI.Themes = {
    dark = {
        WindowBg = 0xFF0A0A0A, ChildBg = 0xFF121212, PopupBg = 0xFF121212,
        TitleBg = 0xFF000000, TitleBgActive = 0xFF000000, TitleBgCollapsed = 0xFF000000,
        Text = 0xFFE0E0E0, Button = 0xFF808080, ButtonHovered = 0xFFA0A0A0, ButtonActive = 0xFF606060,
        FrameBg = 0xFF1A1A1A, FrameBgHovered = 0xFF2A2A2A, FrameBgActive = 0xFF3A3A3A,
        Border = 0xFFFF0000, BorderShadow = 0x00000000, Separator = 0xFF808080, CheckMark = 0xFFFF0000,
        Header = 0xFFFF3030, HeaderHovered = 0xFFFF5050, HeaderActive = 0xFFCC0000
    }
}
CustomUI.Theme = CustomUI.Themes.dark

local function safeNum(val, fallback)
    local n = tonumber(val)
    if n == nil or n ~= n or n < 0 then return fallback end
    return n
end

local function easeOutCubic(t)
    if t <= 0 then return 0 end
    if t >= 1 then return 1 end
    return 1 - (1 - t)^3
end

local function getDisplaySize()
    if type(ImGui.GetIO) == "function" then
        local ok, io = pcall(ImGui.GetIO)
        if ok and io and type(io.DisplaySize) == "table" then
            return safeNum(io.DisplaySize.x, 1920), safeNum(io.DisplaySize.y, 1080)
        end
    end
    return 1920, 1080
end

function CustomUI.New(config)
    config = config or {}
    local self = setmetatable({}, CustomUI)
    self.title = config.title or "Custom UI"
    self.size = config.size or {500, 400}
    self.visible = config.visible ~= false
    self.opened = true
    self.flags = config.flags or 0
    
    if type(config.theme) == "string" then
        self.theme = CustomUI.Themes[config.theme] or CustomUI.Theme
    elseif type(config.theme) == "table" then
        self.theme = config.theme
    else
        self.theme = CustomUI.Theme
    end

    self.OnRender = config.OnRender or function() end
    self.activeTab = config.activeTab or "tab1"
    self.animationDuration = 0.2
    self.animation = 1
    self.lastTime = type(os.clock) == "function" and os.clock() or 0
    self.clampEnabled = config.clamp ~= false
    self.toggleStates = {}
    self.searchQueries = {}
    self.selectStates = {}
    self.buttonStatus = "READY"
    return self
end

function CustomUI:RestartAnimation() self.animation = 0 if type(os.clock) == "function" then self.lastTime = os.clock() end end
function CustomUI:SetActiveTab(name) if self.activeTab ~= name then self.activeTab = tostring(name) self:RestartAnimation() end end
function CustomUI:GetTab() return self.activeTab end

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
    local off = distance * (1 - easeOutCubic(self.animation))
    return safeNum(off, 0) 
end

function CustomUI:PushTheme()
    if type(ImGui.PushStyleColor) ~= "function" or type(ImGui.Col) ~= "table" then return 0 end
    local t, count = self.theme, 0
    if type(t) ~= "table" then return 0 end
    local cols = {
        {ImGui.Col.WindowBg, t.WindowBg}, {ImGui.Col.ChildBg, t.ChildBg}, {ImGui.Col.PopupBg, t.PopupBg},
        {ImGui.Col.TitleBg, t.TitleBg}, {ImGui.Col.TitleBgActive, t.TitleBgActive}, {ImGui.Col.TitleBgCollapsed, t.TitleBgCollapsed},
        {ImGui.Col.Text, t.Text}, {ImGui.Col.FrameBg, t.FrameBg}, {ImGui.Col.FrameBgHovered, t.FrameBgHovered},
        {ImGui.Col.FrameBgActive, t.FrameBgActive}, {ImGui.Col.Border, t.Border}, {ImGui.Col.BorderShadow, t.BorderShadow},
        {ImGui.Col.Separator, t.Separator}, {ImGui.Col.SeparatorHovered, t.Separator}, {ImGui.Col.SeparatorActive, t.Separator},
        {ImGui.Col.Button, t.Button}, {ImGui.Col.ButtonHovered, t.ButtonHovered}, {ImGui.Col.ButtonActive, t.ButtonActive},
        {ImGui.Col.CheckMark, t.CheckMark}, {ImGui.Col.Header, t.Header}, {ImGui.Col.HeaderHovered, t.HeaderHovered}, {ImGui.Col.HeaderActive, t.HeaderActive}
    }
    for _, c in ipairs(cols) do 
        if c[1] and c[2] then
            if pcall(ImGui.PushStyleColor, c[1], c[2]) then count = count + 1 end
        end 
    end
    return count
end

function CustomUI:PopTheme(count) if count > 0 and type(ImGui.PopStyleColor) == "function" then pcall(ImGui.PopStyleColor, count) end end

function CustomUI:Begin()
    local tCount = self:PushTheme()
    local sv = 0
    if type(ImGui.PushStyleVar) == "function" and type(ImGui.StyleVar) == "table" then
        if ImGui.StyleVar.WindowBorderSize and pcall(ImGui.PushStyleVar, ImGui.StyleVar.WindowBorderSize, 2) then sv = sv + 1 end
        if ImGui.StyleVar.FrameBorderSize and pcall(ImGui.PushStyleVar, ImGui.StyleVar.FrameBorderSize, 1) then sv = sv + 1 end
        if ImGui.StyleVar.FrameRounding and pcall(ImGui.PushStyleVar, ImGui.StyleVar.FrameRounding, 4) then sv = sv + 1 end
        if Vec2 and ImGui.StyleVar.WindowPadding and pcall(ImGui.PushStyleVar, ImGui.StyleVar.WindowPadding, Vec2(15, 15)) then sv = sv + 1 end
        if Vec2 and ImGui.StyleVar.ItemSpacing and pcall(ImGui.PushStyleVar, ImGui.StyleVar.ItemSpacing, Vec2(8, 6)) then sv = sv + 1 end
    end
    
    if type(ImGui.SetNextWindowSize) == "function" and Vec2 then
        pcall(ImGui.SetNextWindowSize, Vec2(safeNum(self.size[1], 520), safeNum(self.size[2], 380)), (ImGui.Cond and ImGui.Cond.FirstUseEver) or 1)
    end
    
    if type(ImGui.Begin) ~= "function" then 
        if sv > 0 and type(ImGui.PopStyleVar) == "function" then pcall(ImGui.PopStyleVar, sv) end
        self:PopTheme(tCount) 
        return false, false, tCount, sv 
    end
    
    local winId = self.title .. "##MythicalUI"
    local ok, opened = pcall(ImGui.Begin, winId, self.opened, self.flags)
    if not ok then ok, opened = pcall(ImGui.Begin, winId, self.opened) end
    if not opened then self.opened = false end
    return ok, opened ~= false, tCount, sv
end

function CustomUI:End(tCount, sv)
    if type(ImGui.End) == "function" then pcall(ImGui.End) end
    if sv > 0 and type(ImGui.PopStyleVar) == "function" then pcall(ImGui.PopStyleVar, sv) end
    self:PopTheme(tCount)
end

function CustomUI:Text(text) if type(ImGui.Text) == "function" then pcall(ImGui.Text, tostring(text)) end end

function CustomUI:ColoredText(text, color)
    local c = 0
    if color and type(ImGui.PushStyleColor) == "function" and type(ImGui.Col) == "table" and ImGui.Col.Text then
        if pcall(ImGui.PushStyleColor, ImGui.Col.Text, color) then c = 1 end
    end
    self:Text(text)
    if c > 0 and type(ImGui.PopStyleColor) == "function" then pcall(ImGui.PopStyleColor, c) end
end

function CustomUI:Header(text)
    self:ColoredText(text, 0xFFFF3030)
    self:Separator()
    self:Dummy(1, 4)
end

function CustomUI:Separator() if type(ImGui.Separator) == "function" then pcall(ImGui.Separator) end end
function CustomUI:SameLine() if type(ImGui.SameLine) == "function" then pcall(ImGui.SameLine) end end
function CustomUI:Dummy(w, h) 
    if type(ImGui.Dummy) == "function" and Vec2 then pcall(ImGui.Dummy, Vec2(safeNum(w, 1), safeNum(h, 1))) end 
end

function CustomUI:TabBar(tabs, w, h)
    if not self.activeTab then self.activeTab = tabs[1].id end
    for i, tab in ipairs(tabs) do
        local isActive = self.activeTab == tab.id
        local c = 0
        if type(ImGui.PushStyleColor) == "function" and type(ImGui.Col) == "table" then
            local col = isActive and 0xFFA0A0A0 or 0xFF404040
            if ImGui.Col.Button and pcall(ImGui.PushStyleColor, ImGui.Col.Button, col) then c = c + 1 end
        end
        local ok, res = pcall(ImGui.Button, tab.label, safeNum(w, 100), safeNum(h, 30))
        if not ok and Vec2 then ok, res = pcall(ImGui.Button, tab.label, Vec2(safeNum(w, 100), safeNum(h, 30))) end
        if ok and res then self:SetActiveTab(tab.id) end
        if c > 0 and type(ImGui.PopStyleColor) == "function" then pcall(ImGui.PopStyleColor, c) end
        if i < #tabs then self:SameLine() end
    end
    self:Separator()
end

function CustomUI:BeginTabContent()
    self:Dummy(1, 5)
    local offset = self:GetAnimationOffset(50)
    if offset > 0.1 then
        self:Dummy(offset, 1)
        self:SameLine()
    end
end

function CustomUI:EndTabContent() end

function CustomUI:Button(label, w, h)
    if type(ImGui.Button) ~= "function" then return false end
    local ok, res = pcall(ImGui.Button, tostring(label), safeNum(w, 120), safeNum(h, 36))
    if not ok and Vec2 then ok, res = pcall(ImGui.Button, tostring(label), Vec2(safeNum(w, 120), safeNum(h, 36))) end
    return ok and res == true
end

function CustomUI:Toggle(id, label, default, w, h)
    local key = tostring(id)
    if self.toggleStates[key] == nil then self.toggleStates[key] = default == true end
    local state = self.toggleStates[key]
    local c = 0
    if type(ImGui.PushStyleColor) == "function" and type(ImGui.Col) == "table" then
        local col = state and 0xFF30FF30 or 0xFF404040
        if ImGui.Col.Button and pcall(ImGui.PushStyleColor, ImGui.Col.Button, col) then c = c + 1 end
    end
    local ok, res = pcall(ImGui.Button, label, safeNum(w, 80), safeNum(h, 30))
    if not ok and Vec2 then ok, res = pcall(ImGui.Button, label, Vec2(safeNum(w, 80), safeNum(h, 30))) end
    if c > 0 and type(ImGui.PopStyleColor) == "function" then pcall(ImGui.PopStyleColor, c) end
    if ok and res then self.toggleStates[key] = not state state = self.toggleStates[key] end
    return state
end

function CustomUI:Checkbox(label, default)
    local key = "chk_" .. tostring(label)
    if self.toggleStates[key] == nil then self.toggleStates[key] = default == true end
    local state = self.toggleStates[key]
    if type(ImGui.Checkbox) == "function" then
        local ok, res, newstate = pcall(ImGui.Checkbox, label, state)
        if ok and res then
            state = newstate
            self.toggleStates[key] = state
        end
    end
    return state
end

function CustomUI:Select(id, label, items, current, w, h)
    local key = tostring(id)
    if self.selectStates[key] == nil then self.selectStates[key] = safeNum(current, 0) end
    local state = self.selectStates[key]
    
    if type(ImGui.Combo) == "function" then
        local items_str = table.concat(items, "\0") .. "\0"
        local ok, res, newstate = pcall(ImGui.Combo, label, state, items_str, #items)
        if ok and res then
            state = newstate
            self.selectStates[key] = state
        end
    elseif type(ImGui.ListBox) == "function" then
        local items_str = table.concat(items, "\0") .. "\0"
        local ok, res, newstate = pcall(ImGui.ListBox, label, state, items_str, #items, safeNum(h, 5))
        if ok and res then
            state = newstate
            self.selectStates[key] = state
        end
    end
    return state
end

function CustomUI:SearchBar(id)
    local key = "search_" .. tostring(id)
    if self.searchQueries[key] == nil then self.searchQueries[key] = "" end
    if type(ImGui.InputText) == "function" then
        local ok, val = pcall(ImGui.InputText, "##" .. key, self.searchQueries[key], 200)
        if ok and type(val) == "string" then
            self.searchQueries[key] = val
        end
    end
    self:Dummy(1, 4)
    self:Separator()
end

function CustomUI:CollapsingHeader(label)
    if type(ImGui.CollapsingHeader) == "function" then
        local ok, res = pcall(ImGui.CollapsingHeader, tostring(label))
        return ok and res == true
    end
    return true
end

function CustomUI:FeatureList(id, features)
    local key = "search_" .. tostring(id)
    local query = (self.searchQueries[key] or ""):lower()
    for _, item in ipairs(features) do
        local text = tostring(item)
        if query == "" or text:lower():find(query) then
            self:Text(text)
            self:Dummy(1, 4)
        end
    end
end

-- Frame / Bingkai Presisi (AutoSize Pas)
function CustomUI:BeginFrame(title)
    if type(ImGui.BeginChild) == "function" and Vec2 then
        local auto_resize_flag = 64
        if type(ImGui.WindowFlags) == "table" and ImGui.WindowFlags.AlwaysAutoResize then
            auto_resize_flag = ImGui.WindowFlags.AlwaysAutoResize
        end
        
        -- Vec2(0,0) + Flag AlwaysAutoResize membuat bingkai PRECISE mengikuti ukuran konten
        local ok = pcall(ImGui.BeginChild, tostring(title), Vec2(0, 0), true, auto_resize_flag)
        if ok then
            self:ColoredText(tostring(title), 0xFFFF5050)
            self:Separator()
            self:Dummy(1, 4)
            return true
        end
    end
    return false
end

function CustomUI:EndFrame()
    if type(ImGui.EndChild) == "function" then
        pcall(ImGui.EndChild)
    end
end

function CustomUI:ClampWindowToViewport()
    if not self.clampEnabled then return end
    if type(ImGui.GetWindowPos) ~= "function" or type(ImGui.GetWindowSize) ~= "function" then return end
    local sw, sh = getDisplaySize()
    local okPos, pos = pcall(ImGui.GetWindowPos)
    local okSize, size = pcall(ImGui.GetWindowSize)
    if not okPos or not okSize or type(pos) ~= "table" or type(size) ~= "table" then return end
    local px, py = safeNum(pos.x, 0), safeNum(pos.y, 0)
    local pw, ph = safeNum(size.x, 0), safeNum(size.y, 0)
    local newX, newY = px, py
    if px < 0 then newX = 0 end
    if py < 0 then newY = 0 end
    if px + pw > sw then newX = sw - pw end
    if py + ph > sh then newY = sh - ph end
    if newX ~= px or newY ~= py then
        if type(ImGui.SetWindowPos) == "function" and Vec2 then
            pcall(ImGui.SetWindowPos, Vec2(newX, newY))
        end
    end
end

function CustomUI:Show() self.visible = true self:RestartAnimation() end
function CustomUI:Hide() self.visible = false end

function CustomUI:Render()
    if not self.visible then return end
    if not self.opened then self.opened = true end 
    local ok, opened, tCount, sv = self:Begin()
    if ok and opened then
        self:UpdateAnimation()
        pcall(self.OnRender, self)
        self:ClampWindowToViewport()
    end
    self:End(tCount, sv)
end

return CustomUI
