local _, NS = ...
NS.HooksDispatch = NS.HooksDispatch or {}

-- Троттл для хуков CompactUnitFrame (иначе hover/частые апдейты могут спамить очередь)
local HookThrottle = {} -- [unitToken] = lastTime

function NS.HooksDispatch.HandleCompactUpdate(frame)
    if not frame or frame:IsForbidden() then return end

    local unit = frame.unit
    if not unit or not unit:find("nameplate") then return end

    if not NS.ActiveNamePlates or not NS.ActiveNamePlates[unit] then return end

    local now = GetTime()
    local last = HookThrottle[unit]
    if last and (now - last) < 0.25 then
        return
    end
    HookThrottle[unit] = now

    if NS.RequestUpdate then
        NS.RequestUpdate(unit, "hook", false)
    elseif NS.QueueUnitUpdate then
        NS.QueueUnitUpdate(unit)
    end
end

function NS.HooksDispatch.ClearHookThrottle(unit)
    HookThrottle[unit] = nil
end
