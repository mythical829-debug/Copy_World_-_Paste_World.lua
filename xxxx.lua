-- ====================================================================
-- IMGUI UI BUILDER CORE LIBRARY
-- Simpan file ini di GitHub Anda (Contoh: uibuilder.lua)
-- ====================================================================

local UIBuilder = {}

-- State internal library
UIBuilder.project = { widgets = {} }
UIBuilder.selected = nil

-- Fungsi internal untuk render preview canvas
local function RenderCanvas(imgui)
    imgui.Begin("Canvas / Preview")
    for _, widget in ipairs(UIBuilder.project.widgets) do
        if widget.width and widget.width > 0 then
            imgui.SetNextItemWidth(widget.width)
        end

        if widget.type == "Text" then
            imgui.TextColored(widget.color[1], widget.color[2], widget.color[3], widget.color[4], widget.label)
        elseif widget.type == "Button" then
            imgui.Button(widget.label, widget.width or 0, widget.height or 0)
        elseif widget.type == "InputText" then
            local changed, newValue = imgui.InputText(widget.label, widget.value, 256)
            if changed then widget.value = newValue end
        end
    end
    imgui.End()
end

-- Fungsi internal untuk render daftar hierarchy
local function RenderHierarchy(imgui)
    imgui.Begin("Hierarchy")
    if imgui.Button("+ Text") then
        table.insert(UIBuilder.project.widgets, { type = "Text", label = "Teks Baru", color = {1, 1, 1, 1} })
    end
    imgui.SameLine()
    if imgui.Button("+ Button") then
        table.insert(UIBuilder.project.widgets, { type = "Button", label = "Tombol Baru", width = 100, height = 25 })
    end

    imgui.Separator()

    for i, widget in ipairs(UIBuilder.project.widgets) do
        local isSelected = (UIBuilder.selected == widget)
        if imgui.Selectable(string.format("[%d] %s: %s", i, widget.type, widget.label), isSelected) then
            UIBuilder.selected = widget
        end
    end
    imgui.End()
end

-- Fungsi internal untuk properti inspector
local function RenderInspector(imgui)
    imgui.Begin("Inspector")
    if UIBuilder.selected then
        imgui.Text("Tipe Widget: " .. UIBuilder.selected.type)
        imgui.Separator()

        if UIBuilder.selected.label then
            local changed, newLabel = imgui.InputText("Label/Text", UIBuilder.selected.label, 256)
            if changed then UIBuilder.selected.label = newLabel end
        end

        if UIBuilder.selected.type == "Text" then
            local changed, r, g, b, a = imgui.ColorEdit4("Warna Teks", UIBuilder.selected.color[1], UIBuilder.selected.color[2], UIBuilder.selected.color[3], UIBuilder.selected.color[4])
            if changed then UIBuilder.selected.color = {r, g, b, a} end
        end

        if UIBuilder.selected.type == "Button" then
            local changedW, newW = imgui.DragFloat("Width", UIBuilder.selected.width or 0, 1.0, 0, 500)
            if changedW then UIBuilder.selected.width = newW end
            local changedH, newH = imgui.DragFloat("Height", UIBuilder.selected.height or 0, 1.0, 0, 500)
            if changedH then UIBuilder.selected.height = newH end
        end
    else
        imgui.Text("Pilih widget di Hierarchy.")
    end
    imgui.End()
end

-- API UTAMA: Fungsi ini yang akan dipanggil di render loop game Anda
function UIBuilder.Draw(imgui)
    RenderCanvas(imgui)
    RenderHierarchy(imgui)
    RenderInspector(imgui)
end

-- Return library sebagai object table agar bisa di-load string
return UIBuilder
