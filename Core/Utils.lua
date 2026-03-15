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


local UnitConfigCache = {}
function NS.ClearUnitConfigCache(unit)
    if unit then
        UnitConfigCache[unit] = nil
        return
    end
    for k in pairs(UnitConfigCache) do UnitConfigCache[k] = nil end
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

-- Enemy BUFF highlight should describe the aura, not the player's current capabilities.
-- I.e. if the user enables the option, show "purge/spellsteal-able" buffs even if the
-- current character/spec can't actually remove them.
function NS.IsEnemyBuffPurgeable(aura)
    if not aura then return false end

    -- Prefer explicit signals if present.
    if SafeBool(aura.isStealable) then
        return true
    end

    -- Fallback: magic buffs are typically purgeable.
    local dispelName = SafeValue(aura.dispelName)
    if dispelName == "Magic" then
        return true
    end

    return false
end

-- Returns true if the plate is in simplified mode and is NOT the current target.
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
