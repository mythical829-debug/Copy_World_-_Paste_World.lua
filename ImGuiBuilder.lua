local CustomUI = {}
CustomUI.__index = CustomUI

local texCache = {}
local cachePath = "custom_ui_cache.png"

local function loadTextureFromURL(url)
    if texCache[url] then return texCache[url] end
    
    local res = MakeRequest(url, "GET")
    if not res or res.error or res.status ~= 200 then
        return nil
    end
    
    local body = res.content
    if not body then return nil end
    
    local f = io.open(cachePath, "wb")
    if f then
        f:write(body)
        f:close()
        local tex = ImGui.CreateTextureFromFile(cachePath)
        if tex then
            texCache[url] = tex
            return tex
        end
    end
    return nil
end

CustomUI.themes = {
    dark = { WindowBg = 0xFF1A1A2E, Text = 0xFFFFFFFF, Button = 0xFF303050, ButtonHovered = 0xFF404060, FrameBg = 0xFF222238 },
    neon = { WindowBg = 0xFF0A0A0A, Text = 0xFF00FFCC, Button = 0xFF00FFCC, ButtonHovered = 0xFF00AA88, FrameBg = 0xFF111111 }
}

function CustomUI.New(config)
    local self = setmetatable({}, CustomUI)
    self.title = config.title or "Custom UI"
    self.size = config.size or {400, 300}
    self.flags = config.flags or ImGui.WindowFlags.None
    self.visible = config.visible ~= false
    self.theme = config.theme or "dark"
    self.OnRender = config.OnRender or function(win) end
    self.bgUrl = config.backgroundImage
    self.bgTex = nil
    return self
end

function CustomUI:Render()
    if not self.visible then return end
    local theme = CustomUI.themes[self.theme] or self.theme
    
    ImGui.PushStyleColor(ImGui.Col.WindowBg, theme.WindowBg or 0xFF111111)
    ImGui.PushStyleColor(ImGui.Col.Text, theme.Text or 0xFFFFFFFF)
    ImGui.PushStyleColor(ImGui.Col.Button, theme.Button or 0xFF333333)
    ImGui.PushStyleColor(ImGui.Col.ButtonHovered, theme.ButtonHovered or 0xFF555555)
    ImGui.PushStyleColor(ImGui.Col.FrameBg, theme.FrameBg or 0xFF222222)
    
    ImGui.SetNextWindowSize(self.size[1], self.size[2], ImGui.Cond.FirstUseEver)
    ImGui.Begin(self.title, true, self.flags)
    
    if self.bgUrl and not self.bgTex then
        self.bgTex = loadTextureFromURL(self.bgUrl)
    end
    
    if self.bgTex then
        local p = ImGui.GetCursorScreenPos()
        local w, h = ImGui.GetWindowSize()
        ImGui.GetWindowDrawList():AddImage(self.bgTex, p.x, p.y, p.x + w, p.y + h, 0, 0, 1, 1)
    end
    
    self.OnRender(self)
    
    ImGui.End()
    ImGui.PopStyleColor(5)
end

function CustomUI:Show() self.visible = true end
function CustomUI:Hide() self.visible = false end
function CustomUI:SetTheme(t) self.theme = t end

function CustomUI:Text(text, color)
    if color then ImGui.PushStyleColor(ImGui.Col.Text, color) end
    ImGui.Text(text)
    if color then ImGui.PopStyleColor() end
end

function CustomUI:Button(label, w, h)
    return ImGui.Button(label, w or 0, h or 0)
end

function CustomUI:Checkbox(label, state)
    local changed, newstate = ImGui.Checkbox(label, state)
    return newstate
end

function CustomUI:SliderFloat(label, value, min, max)
    local changed, newval = ImGui.SliderFloat(label, value, min, max, "%.2f")
    return newval
end

function CustomUI:SliderInt(label, value, min, max)
    local changed, newval = ImGui.SliderInt(label, value, min, max)
    return newval
end

function CustomUI:Combo(label, current, items)
    local changed, newidx = ImGui.Combo(label, current, items)
    return newidx
end

function CustomUI:TrendChart(label, data, color, fillColor)
    local w, h = ImGui.GetContentRegionAvail()
    local draw = ImGui.GetWindowDrawList()
    local p0 = ImGui.GetCursorScreenPos()
    local maxVal = 1
    for _, v in ipairs(data) do
        if v > maxVal then maxVal = v end
    end
    
    local points = {}
    for i, v in ipairs(data) do
        local x = p0.x + ((i - 1) / (#data - 1)) * w
        local y = p0.y + h - (v / maxVal) * h
        table.insert(points, {x, y})
    end
    
    if fillColor then
        local poly = {{p0.x, p0.y + h}}
        for _, pt in ipairs(points) do table.insert(poly, pt) end
        table.insert(poly, {p0.x + w, p0.y + h})
        draw:AddConvexPolyFilled(poly, fillColor)
    end
    
    for i = 1, #points - 1 do
        draw:AddLine(points[i][1], points[i][2], points[i+1][1], points[i+1][2], color, 2.0)
    end
    
    ImGui.Dummy(w, h)
end

function CustomUI:BarChart(data, color)
    local w, h = ImGui.GetContentRegionAvail()
    local draw = ImGui.GetWindowDrawList()
    local p0 = ImGui.GetCursorScreenPos()
    local maxVal = 1
    for _, v in ipairs(data) do if v > maxVal then maxVal = v end end
    
    local barW = w / #data
    for i, v in ipairs(data) do
        local barH = (v / maxVal) * h
        local x = p0.x + (i - 1) * barW
        local y = p0.y + h - barH
        draw:AddRectFilled(x + 2, y, x + barW - 2, p0.y + h, color)
    end
    ImGui.Dummy(w, h)
end

return CustomUI
