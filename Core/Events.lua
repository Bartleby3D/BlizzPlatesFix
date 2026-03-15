local AddonName, NS = ...

-- Events.lua: только подписки + передача в Dispatch
-- Логика обработки (что обновлять и как) находится в Core/Dispatch.lua

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("ADDON_LOADED")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_ADDED")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
EventFrame:RegisterEvent("PLAYER_REGEN_ENABLED")
EventFrame:RegisterEvent("PLAYER_REGEN_DISABLED")
EventFrame:RegisterEvent("PLAYER_TARGET_CHANGED")
EventFrame:RegisterEvent("RAID_TARGET_UPDATE")
EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")

EventFrame:RegisterEvent("UNIT_HEALTH")
EventFrame:RegisterEvent("UNIT_MAXHEALTH")
EventFrame:RegisterEvent("UNIT_THREAT_LIST_UPDATE")
EventFrame:RegisterEvent("UNIT_THREAT_SITUATION_UPDATE")
EventFrame:RegisterEvent("UNIT_CLASSIFICATION_CHANGED")
EventFrame:RegisterEvent("UNIT_AURA")
EventFrame:RegisterEvent("UNIT_TARGET")

-- Cast events
EventFrame:RegisterEvent("UNIT_SPELLCAST_START")
EventFrame:RegisterEvent("UNIT_SPELLCAST_STOP")
EventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED")
EventFrame:RegisterEvent("UNIT_SPELLCAST_FAILED_QUIET")
EventFrame:RegisterEvent("UNIT_SPELLCAST_INTERRUPTIBLE")
EventFrame:RegisterEvent("UNIT_SPELLCAST_NOT_INTERRUPTIBLE")
EventFrame:RegisterEvent("UNIT_SPELLCAST_DELAYED")
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_START")
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_UPDATE")
EventFrame:RegisterEvent("UNIT_SPELLCAST_CHANNEL_STOP")
EventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_START")
EventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_UPDATE")
EventFrame:RegisterEvent("UNIT_SPELLCAST_EMPOWER_STOP")

EventFrame:RegisterEvent("CVAR_UPDATE")

EventFrame:SetScript("OnEvent", function(self, event, ...)
    local arg1 = ...
    if NS.Dispatch and NS.Dispatch.HandleEvent then
        NS.Dispatch.HandleEvent(event, ...)
        return
    end

    -- Fallback (не должен происходить при корректном порядке файлов)
    if event == "ADDON_LOADED" and arg1 == AddonName then
        if NS.DB and NS.DB.Init then
            NS.DB.Init()
        elseif NS.Config and NS.Config.EnsureDB then
            NS.Config.EnsureDB()
        end
        NS.SafeCall(NS.ApplySystemCVars)
    end
end)