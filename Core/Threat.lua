local _, NS = ...

NS.Threat = NS.Threat or {}

NS.Threat.STATE_NONE = 0
NS.Threat.STATE_OFFTANK = 1
NS.Threat.STATE_ONME = 2

local _canaccessvalue = _G.canaccessvalue

local function ReadThreatStatus(unit)
    if not unit then return nil end
    local status = UnitThreatSituation("player", unit)
    if status == nil then
        return nil
    end

    if _canaccessvalue and not _canaccessvalue(status) then
        return nil
    end

    local n = tonumber(status)
    if n == nil then
        n = tonumber(tostring(status))
    end
    return n
end

function NS.Threat.GetPlayerStatus(unit)
    return ReadThreatStatus(unit)
end

function NS.Threat.GetPlayerState(unit)
    local status = ReadThreatStatus(unit)
    if status == nil then
        return NS.Threat.STATE_NONE, nil
    end

    if status >= 2 then
        return NS.Threat.STATE_ONME, status
    end

    return NS.Threat.STATE_OFFTANK, status
end
