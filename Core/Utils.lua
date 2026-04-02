local _, NS = ...
local LSM = LibStub("LibSharedMedia-3.0")
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT

-- 1. РЕГИСТРАЦИЯ
local MY_FONT_NAME = "Roboto Condensed"
local MY_FONT_PATH = [[Interface\AddOns\BlizzPlatesFix\Fonts\RobotoCondensed-Bold.ttf]]

LSM:Register("font", MY_FONT_NAME, MY_FONT_PATH)

-- =============================================================
-- ВСПОМОГАТЕЛЬНЫЕ ФУНКЦИИ
-- =============================================================

-- Получение списка шрифтов
function NS.GetFontList()
    local list = LSM:List("font")
    
    local found = false
    for _, name in ipairs(list) do
        if name == MY_FONT_NAME then 
            found = true 
            break 
        end
    end
    
    if not found then
        table.insert(list, 1, MY_FONT_NAME)
    end
    
    return list
end

local FontCache = {}
function NS.GetFontPath(fontName)
    if not fontName or fontName == "" then return STANDARD_TEXT_FONT end
    if FontCache[fontName] then return FontCache[fontName] end

    local path
    if fontName == MY_FONT_NAME then
        path = MY_FONT_PATH
    else
        path = LSM:Fetch("font", fontName)
    end

    path = path or STANDARD_TEXT_FONT
    FontCache[fontName] = path
    return path
end

-- =============================================================
-- SECRET-SAFE HELPERS (12.0+)
-- =============================================================
-- Some API fields (including aura booleans/strings) can be "secret".
-- Any direct boolean test/comparison on a secret value can error in tainted execution.
-- Use canaccessvalue() to safely read them.
local _canaccessvalue = _G.canaccessvalue
local function SafeBool(v)
    if _canaccessvalue and v ~= nil and _canaccessvalue(v) then
        return (v and true or false)
    end
    return false
end

local function SafeValue(v)
    if _canaccessvalue and v ~= nil and _canaccessvalue(v) then
        return v
    end
    return nil
end

NS.SafeBool = SafeBool
NS.SafeValue = SafeValue

local function PixelRoundNearest(value)
    if value == nil then return 0 end
    if value >= 0 then
        return math.floor(value + 0.5)
    end
    return math.ceil(value - 0.5)
end

local function GetPixelToUIUnitFactor()
    local _, physicalHeight = GetPhysicalScreenSize()
    if not physicalHeight or physicalHeight <= 0 then
        return 1
    end
    return 768.0 / physicalHeight
end

local function GetNearestPixelSize(uiUnitSize, layoutScale, minPixels)
    uiUnitSize = tonumber(uiUnitSize) or 0
    layoutScale = tonumber(layoutScale) or 1
    if layoutScale == 0 then
        return uiUnitSize
    end
    if uiUnitSize == 0 and (not minPixels or minPixels == 0) then
        return 0
    end

    local uiUnitFactor = GetPixelToUIUnitFactor()
    local numPixels = PixelRoundNearest((uiUnitSize * layoutScale) / uiUnitFactor)
    if minPixels then
        if uiUnitSize < 0 then
            if numPixels > -minPixels then
                numPixels = -minPixels
            end
        else
            if numPixels < minPixels then
                numPixels = minPixels
            end
        end
    end

    return numPixels * uiUnitFactor / layoutScale
end

function NS.PixelSnapValue(region, value, minPixels)
    if not region or not region.GetEffectiveScale then
        return tonumber(value) or 0
    end
    return GetNearestPixelSize(value, region:GetEffectiveScale(), minPixels)
end

function NS.PixelSnapSetSize(region, width, height, minWidthPixels, minHeightPixels)
    if not region then return end
    region:SetSize(
        NS.PixelSnapValue(region, width, minWidthPixels),
        NS.PixelSnapValue(region, height, minHeightPixels)
    )
end

function NS.PixelSnapSetPoint(region, point, relativeTo, relativePoint, offsetX, offsetY, minOffsetXPixels, minOffsetYPixels)
    if not region then return end
    region:SetPoint(
        point,
        relativeTo,
        relativePoint,
        NS.PixelSnapValue(region, offsetX, minOffsetXPixels),
        NS.PixelSnapValue(region, offsetY, minOffsetYPixels)
    )
end


-- ГЛАВНАЯ НОВАЯ ФУНКЦИЯ: Определение типа конфига для юнита
function NS.GetUnitConfig(unit)
    if not unit then return nil, nil end
    
    local unitType
    if UnitIsPlayer(unit) then
        if UnitIsFriend("player", unit) then
            unitType = NS.UNIT_TYPES.FRIENDLY_PLAYER
        else
            unitType = NS.UNIT_TYPES.ENEMY_PLAYER
        end
    else
        local reaction = UnitReaction(unit, "player")
        if reaction == 4 then
            if UnitCanAttack("player", unit) then
                unitType = NS.UNIT_TYPES.ENEMY_NPC
            else
                unitType = NS.UNIT_TYPES.FRIENDLY_NPC
            end
        else
            if UnitIsFriend("player", unit) then
                unitType = NS.UNIT_TYPES.FRIENDLY_NPC
            else
                unitType = NS.UNIT_TYPES.ENEMY_NPC
            end
        end
    end

    local udb = NS.Config and NS.Config.GetTable and NS.Config.GetTable(unitType)
    local gdb = NS.Config and NS.Config.GetTable and NS.Config.GetTable("Global")
    
    return udb, gdb
end

function NS.IsSimplifiedNotTarget(frame, unit)
    if frame and frame.IsSimplified and frame:IsSimplified() then
        if frame.IsTarget and frame:IsTarget() then
            return false
        end
        if unit and UnitIsUnit and UnitIsUnit(unit, "target") then
            return false
        end
        return true
    end
    return false
end

local SimplifiedHiddenModules = {
    NameText = true,
    GuildText = true,
    HpText = true,
    Level = true,
    Icon = true,
}

function NS.ShouldHideModuleOnSimplified(moduleName, frame, unit)
    if not moduleName or not SimplifiedHiddenModules[moduleName] then
        return false
    end
    return NS.IsSimplifiedNotTarget(frame, unit)
end


function NS.GetStatusIconAnchorInfo(frame, anchorMode)
    if anchorMode == "Name" then
        local nameText = frame and frame.BPF_NameTextFS
        if nameText then
            return "BOTTOM", nameText, "TOP", "Name"
        end

        local nameAnchor = frame and frame.BPF_NameTextWrapper
        if nameAnchor then
            return "BOTTOM", nameAnchor, "TOP", "Name"
        end
    end

    local hb = frame and (frame.healthBar or frame)
    return "CENTER", hb, "CENTER", "HpBar"
end

function NS.ApplyStatusIconAnchor(region, frame, anchorMode, offX, offY)
    if not region or not frame then return "HpBar" end
    local point, relTo, relPoint, resolved = NS.GetStatusIconAnchorInfo(frame, anchorMode)
    if not relTo then return resolved or "HpBar" end
    region:ClearAllPoints()
    region:SetPoint(point, relTo, relPoint, offX or 0, offY or 0)
    return resolved
end
