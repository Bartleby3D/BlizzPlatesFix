local _, NS = ...

NS.UnitColor = NS.UnitColor or {}
local M = NS.UnitColor

local TAP_DENIED_R, TAP_DENIED_G, TAP_DENIED_B = 0.5, 0.5, 0.5
local DISCONNECTED_R, DISCONNECTED_G, DISCONNECTED_B = 0.5, 0.5, 0.5
local DEFAULT_THREAT_R, DEFAULT_THREAT_G, DEFAULT_THREAT_B = 1, 0.1, 0.1

local function IsDisplayPlayer(unit)
    return UnitIsPlayer(unit) or (UnitTreatAsPlayerForDisplay and UnitTreatAsPlayerForDisplay(unit))
end

local function GetClassColor(unit, fallbackR, fallbackG, fallbackB)
    local _, class = UnitClass(unit)
    if class then
        local c = C_ClassColor.GetClassColor(class)
        if c then
            return c.r, c.g, c.b
        end
    end
    return fallbackR or TAP_DENIED_R, fallbackG or TAP_DENIED_G, fallbackB or TAP_DENIED_B
end

local function GetCustomModeColor(unit, db, modeKey, colorKey, hostileKey, friendlyKey, neutralKey)
    if not db or db[modeKey] ~= 2 then return nil end

    local enemyNpcDB = NS.Config and NS.Config.GetTable and NS.Config.GetTable(NS.UNIT_TYPES.ENEMY_NPC)
    local friendlyNpcDB = NS.Config and NS.Config.GetTable and NS.Config.GetTable(NS.UNIT_TYPES.FRIENDLY_NPC)

    local c
    if enemyNpcDB and db == enemyNpcDB then
        local reaction = UnitReaction(unit, "player")
        if reaction == 4 then
            c = db[neutralKey] or db[colorKey]
        else
            c = db[hostileKey] or db[colorKey]
        end
    elseif friendlyNpcDB and db == friendlyNpcDB then
        local reaction = UnitReaction(unit, "player")
        if reaction == 4 then
            c = db[neutralKey] or db[colorKey]
        else
            c = db[friendlyKey] or db[colorKey]
        end
    else
        c = db[colorKey]
    end

    if not c then return 1, 1, 1 end
    return c.r, c.g, c.b
end

function M.GetTapDeniedColor(unit)
    if not unit or not UnitIsTapDenied then return nil end
    if UnitPlayerControlled(unit) then return nil end
    if UnitIsTapDenied(unit) then
        return TAP_DENIED_R, TAP_DENIED_G, TAP_DENIED_B
    end
    return nil
end

function M.GetDisconnectedColor(unit)
    if not unit or not UnitIsConnected then return nil end
    if not UnitIsPlayer(unit) then return nil end
    if UnitIsConnected(unit) == false then
        return DISCONNECTED_R, DISCONNECTED_G, DISCONNECTED_B
    end
    return nil
end

function M.GetThreatOverrideColor(unit, gdb)
    if not unit or not gdb then return nil end
    if UnitIsFriend("player", unit) then return nil end
    if IsDisplayPlayer(unit) then return nil end
    if not UnitCanAttack("player", unit) then return nil end

    local state = NS.Threat and NS.Threat.GetPlayerState and NS.Threat.GetPlayerState(unit)
    if state == nil or state == NS.Threat.STATE_NONE then
        return nil
    end

    if gdb.tankModeEnable then
        local c = (state == NS.Threat.STATE_ONME) and gdb.tankModePlayerAggroColor or gdb.tankModeOffTankColor
        if c then
            return c.r, c.g, c.b
        end
        return nil
    end

    return DEFAULT_THREAT_R, DEFAULT_THREAT_G, DEFAULT_THREAT_B
end

function M.GetBaseColor(unit, db, modeKey, colorKey, hostileKey, friendlyKey, neutralKey, fallbackR, fallbackG, fallbackB)
    if not unit or not db then return 1, 1, 1 end

    local r, g, b = GetCustomModeColor(unit, db, modeKey, colorKey, hostileKey, friendlyKey, neutralKey)
    if r ~= nil then
        return r, g, b
    end

    if db[modeKey] == 3 then
        return UnitSelectionColor(unit)
    end

    if IsDisplayPlayer(unit) then
        return GetClassColor(unit, fallbackR, fallbackG, fallbackB)
    end

    return UnitSelectionColor(unit)
end

function M.GetColor(unit, db, gdb, modeKey, colorKey, hostileKey, friendlyKey, neutralKey, fallbackR, fallbackG, fallbackB)
    local r, g, b = M.GetDisconnectedColor(unit)
    if r ~= nil then
        return r, g, b
    end

    r, g, b = M.GetTapDeniedColor(unit)
    if r ~= nil then
        return r, g, b
    end

    r, g, b = M.GetThreatOverrideColor(unit, gdb)
    if r ~= nil then
        return r, g, b
    end

    return M.GetBaseColor(unit, db, modeKey, colorKey, hostileKey, friendlyKey, neutralKey, fallbackR, fallbackG, fallbackB)
end
