local AddonName, NS = ...

-- Minimap icon (LibDataBroker-1.1 + LibDBIcon-1.0)
-- Uses SavedVariables: BlizzPlatesFixDB.minimap = { hide = bool, minimapPos = number }

local function EnsureMinimapDB()
    BlizzPlatesFixDB = BlizzPlatesFixDB or {}
    BlizzPlatesFixDB.minimap = BlizzPlatesFixDB.minimap or { hide = false }
end

function NS.InitMinimapIcon()
    if NS._minimapIconInit then return end
    NS._minimapIconInit = true

    if not LibStub then return end
    local okLDB, LDB = pcall(LibStub, "LibDataBroker-1.1")
    local okIcon, DBIcon = pcall(LibStub, "LibDBIcon-1.0")
    if not okLDB or not okIcon or not LDB or not DBIcon then return end

    EnsureMinimapDB()

    -- Respect global option "showMinimapIcon"
    local show = true
    if NS.Config and NS.Config.Get then
        local v = NS.Config.Get("showMinimapIcon", "Global")
        if v ~= nil then show = v end
    end
    BlizzPlatesFixDB.minimap.hide = not show

    if not NS.LDB then
        NS.LDB = LDB:NewDataObject("BlizzPlatesFix", {
            type = "launcher",
            text = "BlizzPlatesFix",
            icon = "Interface\\AddOns\\BlizzPlatesFix\\Media\\BPFIcon.tga",
        })

        function NS.LDB:OnClick(button)
            -- Left/Right click: toggle GUI
            if NS.ToggleGUI then
                NS.ToggleGUI()
            end
        end

        function NS.LDB:OnTooltipShow()
            if not self or not self.AddLine then return end
            self:AddLine("BlizzPlatesFix")
            self:AddLine("Left Click: Toggle", 1, 1, 1)
            self:AddLine("Right Click: Toggle", 1, 1, 1)
        end
    end

    DBIcon:Register("BlizzPlatesFix", NS.LDB, BlizzPlatesFixDB.minimap)

    if BlizzPlatesFixDB.minimap.hide then
        DBIcon:Hide("BlizzPlatesFix")
    end
end

function NS.SetMinimapIconShown(shown)
    if not LibStub then return end
    local okIcon, DBIcon = pcall(LibStub, "LibDBIcon-1.0")
    if not okIcon or not DBIcon then return end

    EnsureMinimapDB()
    BlizzPlatesFixDB.minimap.hide = not shown
    if shown then
        DBIcon:Show("BlizzPlatesFix")
    else
        DBIcon:Hide("BlizzPlatesFix")
    end
end
