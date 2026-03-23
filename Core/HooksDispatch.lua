local _, NS = ...
NS.HooksDispatch = NS.HooksDispatch or {}

-- Троттл для хуков CompactUnitFrame (иначе hover/частые апдейты могут спамить очередь)
-- Ключуем по unitToken и типу hook-а отдельно, чтобы health/name/aura не глушили друг друга.
local HookThrottle = {} -- [unitToken] = { [hookKey] = lastTime }

function NS.HooksDispatch.HandleCompactUpdate(frame, hookKey, reasonMask)
    if not frame or frame:IsForbidden() then return end

    local unit = frame.unit
    if not unit or not unit:find("nameplate") then return end

    if not NS.ActiveNamePlates or not NS.ActiveNamePlates[unit] then return end

    local key = hookKey or "generic"
    local now = GetTime()
    local unitThrottle = HookThrottle[unit]
    if not unitThrottle then
        unitThrottle = {}
        HookThrottle[unit] = unitThrottle
    end

    local last = unitThrottle[key]
    if last and (now - last) < 0.25 then
        return
    end
    unitThrottle[key] = now

    if NS.RequestUpdate then
        NS.RequestUpdate(unit, "hook:" .. key, false, reasonMask)
    elseif NS.QueueUnitUpdate then
        NS.QueueUnitUpdate(unit, reasonMask)
    end
end

function NS.HooksDispatch.ClearHookThrottle(unit)
    HookThrottle[unit] = nil
end
