local AddonName, NS = ...

-- =============================================================
-- Dispatch: единая точка маршрутизации событий -> update API
-- Events.lua должен быть максимально “тонким” (подписки + вызов Dispatch)
-- =============================================================

-- CVars, на которые есть смысл реагировать глобальным обновлением
local ImportantCVars = {
    nameplateMaxDistance = true,
    nameplateSelectedScale = true,
    nameplateOccludedAlphaMult = true,
    nameplateMinScale = true,
    nameplateMinAlphaDistance = true, -- меняется в ApplySystemCVars
}

local Dispatch = {}

-- Карта событий -> reasonMask (bitmask)
local EventMasks = {
    UNIT_AURA = NS.REASON_AURA,
    UNIT_HEALTH = NS.REASON_HEALTH,
    UNIT_MAXHEALTH = NS.REASON_HEALTH,
    UNIT_THREAT_LIST_UPDATE = NS.REASON_THREAT,
    UNIT_THREAT_SITUATION_UPDATE = NS.REASON_THREAT,
    UNIT_CLASSIFICATION_CHANGED = NS.REASON_CLASS,
    UNIT_TARGET = NS.REASON_TARGET,
    UNIT_POWER_UPDATE = NS.REASON_POWER,
    UNIT_POWER_FREQUENT = NS.REASON_POWER,

    UNIT_SPELLCAST_START = NS.REASON_CAST,
    UNIT_SPELLCAST_STOP = NS.REASON_CAST,
    UNIT_SPELLCAST_FAILED = NS.REASON_CAST,
    UNIT_SPELLCAST_FAILED_QUIET = NS.REASON_CAST,
    UNIT_SPELLCAST_INTERRUPTIBLE = NS.REASON_CAST,
    UNIT_SPELLCAST_NOT_INTERRUPTIBLE = NS.REASON_CAST,
    UNIT_SPELLCAST_DELAYED = NS.REASON_CAST,
    UNIT_SPELLCAST_CHANNEL_START = NS.REASON_CAST,
    UNIT_SPELLCAST_CHANNEL_UPDATE = NS.REASON_CAST,
    UNIT_SPELLCAST_CHANNEL_STOP = NS.REASON_CAST,
    UNIT_SPELLCAST_EMPOWER_START = NS.REASON_CAST,
    UNIT_SPELLCAST_EMPOWER_UPDATE = NS.REASON_CAST,
    UNIT_SPELLCAST_EMPOWER_STOP = NS.REASON_CAST,
}

local function RequestUnitUpdate(unit, reason, immediate, reasonMask)
    if not unit then return end

    if NS.RequestUpdate then
        NS.RequestUpdate(unit, reason, immediate, reasonMask)
    else
        NS.QueueUnitUpdate(unit)
        if immediate then
            NS.SafeCall(NS.UpdateAllModules, unit)
        end
    end
end

local function RequestAllUpdate(reason, immediate, reasonMask)
    if NS.RequestUpdateAll then
        NS.RequestUpdateAll(reason, immediate, reasonMask)
    else
        NS.QueueAllActive()
        if immediate then
            NS.SafeCall(NS.ForceUpdateAll)
        end
    end
end

function Dispatch.HandleEvent(event, arg1, arg2, ...)

    if event == "UNIT_POWER_UPDATE" or event == "UNIT_POWER_FREQUENT" then
        if arg1 == "player" then
            local targetPlate = C_NamePlate.GetNamePlateForUnit("target")
            local targetUnit = targetPlate and targetPlate.namePlateUnitToken
            if targetUnit then
                RequestUnitUpdate(targetUnit, event, false, NS.REASON_POWER or 2048)
            end
        end
        return
    end

    if event == "UPDATE_SHAPESHIFT_FORM" or event == "PLAYER_SPECIALIZATION_CHANGED" then
        RequestAllUpdate(event, true, NS.REASON_POWER or 2048)
        return
    end

    if event == "RUNE_POWER_UPDATE" then
        local targetPlate = C_NamePlate.GetNamePlateForUnit("target")
        local targetUnit = targetPlate and targetPlate.namePlateUnitToken
        if targetUnit then
            RequestUnitUpdate(targetUnit, event, false, NS.REASON_POWER or 2048)
        end
        return
    end

    if event == "PLAYER_MOUNT_DISPLAY_CHANGED" then
        RequestAllUpdate(event, true, NS.REASON_POWER or 2048)
        return
    end

    if event == "UNIT_ENTERED_VEHICLE" or event == "UNIT_EXITED_VEHICLE" then
        if arg1 == "player" then
            RequestAllUpdate(event, true, NS.REASON_POWER or 2048)
        end
        return
    end

    -- Hot path: avoid string operations for UNIT_* events.
    -- All unit events we care about are listed in EventMasks.
    if EventMasks[event] then
        if type(arg1) ~= "string" or not arg1:find("nameplate", 1, true) then
            return
        end
    end

    if event == "ADDON_LOADED" and arg1 == AddonName then
        if NS.DB and NS.DB.Init then
            NS.DB.Init()
        elseif NS.Config and NS.Config.EnsureDB then
            NS.Config.EnsureDB()
        end

        NS.SafeCall(NS.ApplySystemCVars)

        NS.SafeCall(NS.InitMinimapIcon)

        RequestAllUpdate("addon_loaded", false)
        return
    end

    -- Nameplates
    if event == "NAME_PLATE_UNIT_ADDED" then
        NS.AddActivePlate(arg1)
        -- быстрый апдейт для устранения “переходных” состояний на реюзе
        RequestUnitUpdate(arg1, "plate_added", true, NS.REASON_ALL)
        return
    end

    if event == "NAME_PLATE_UNIT_REMOVED" then
        NS.RemoveActivePlate(arg1)

        -- очистка очередей/кэшей
        NS.ClearUnitFromQueues(arg1)
        if NS.ClearHookThrottle then
            NS.ClearHookThrottle(arg1)
        end
        if NS.PendingAuraUpdates then
            NS.PendingAuraUpdates[arg1] = nil
        end
        if NS.QuestIcon_ClearCache then
            NS.QuestIcon_ClearCache(arg1)
        end
        return
    end

    -- Глобальные
    if event == "PLAYER_REGEN_DISABLED" then
        -- При входе в бой Blizzard может пересобрать/переинициализировать неймплейты.
        -- По умолчанию делаем немедленный полный апдейт; можно отключить в Global: forceUpdateAllOnCombat=false.
        local immediate = true
        if NS.Config and NS.Config.Get then
            local v = NS.Config.Get("forceUpdateAllOnCombat", "Global")
            if v == false then immediate = false end
        end
        RequestAllUpdate(event, immediate, NS.REASON_ALL)
        return
    end

    if event == "PLAYER_REGEN_ENABLED" then
        -- Apply deferred settings safely out of combat.
        if NS.Config and NS.Config.CommitPending then
            NS.Config.CommitPending()
        end
        if NS.Profiles and NS.Profiles.CommitPending then
            NS.Profiles.CommitPending()
        end
        if NS.FriendlyInstanceNames and NS.FriendlyInstanceNames.UpdateState then
            NS.SafeCall(NS.FriendlyInstanceNames.UpdateState, event)
        end
        RequestAllUpdate(event, false, NS.REASON_ALL)
        return
    end

    if event == "PLAYER_TARGET_CHANGED" then
        RequestAllUpdate(event, false, NS.REASON_ALL)
        return
    end

    if event == "RAID_TARGET_UPDATE" then
        RequestAllUpdate(event, true, NS.REASON_TARGET or 64)
        return
    end

    if event == "QUEST_LOG_UPDATE" or event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA" then
        if NS.QuestIcon_ClearCache then
            NS.QuestIcon_ClearCache()
        end
        if (event == "PLAYER_ENTERING_WORLD" or event == "ZONE_CHANGED_NEW_AREA") and NS.FriendlyInstanceNames and NS.FriendlyInstanceNames.UpdateState then
            NS.SafeCall(NS.FriendlyInstanceNames.UpdateState, event)
        end
        RequestAllUpdate(event, false, NS.REASON_QUEST or 1024)
        return
    end

    -- CVars
    if event == "CVAR_UPDATE" then
        if NS.FriendlyInstanceNames and NS.FriendlyInstanceNames.OnCVarUpdate then
            NS.SafeCall(NS.FriendlyInstanceNames.OnCVarUpdate, arg1)
        end
        if arg1 and ImportantCVars[arg1] then
            RequestAllUpdate("cvar:" .. arg1, false, NS.REASON_ALL)
        end
        return
    end

    -- UNIT_AURA: store refreshData for incremental processing (Retail)
    if event == "UNIT_AURA" then
        local unit = arg1
        local refreshData = arg2
        if unit and type(refreshData) == "table" then
            NS.PendingAuraUpdates = NS.PendingAuraUpdates or {}
            local cur = NS.PendingAuraUpdates[unit]
            if not cur then
                -- store as-is, but add dedupe sets lazily when merging happens
                NS.PendingAuraUpdates[unit] = refreshData
            else
                if refreshData.isFullUpdate then
                    cur.isFullUpdate = true
                    cur.addedAuras = nil
                    cur.updatedAuraInstanceIDs = nil
                    cur.removedAuraInstanceIDs = nil
                    cur._updSet = nil
                    cur._remSet = nil
                elseif not cur.isFullUpdate then
                    if refreshData.addedAuras then
                        cur.addedAuras = cur.addedAuras or {}
                        for _, a in ipairs(refreshData.addedAuras) do
                            cur.addedAuras[#cur.addedAuras + 1] = a
                        end
                    end
                    if refreshData.updatedAuraInstanceIDs then
                        cur.updatedAuraInstanceIDs = cur.updatedAuraInstanceIDs or {}
                        cur._updSet = cur._updSet or {}
                        for _, id in ipairs(refreshData.updatedAuraInstanceIDs) do
                            if id and not cur._updSet[id] then
                                cur._updSet[id] = true
                                cur.updatedAuraInstanceIDs[#cur.updatedAuraInstanceIDs + 1] = id
                            end
                        end
                    end
                    if refreshData.removedAuraInstanceIDs then
                        cur.removedAuraInstanceIDs = cur.removedAuraInstanceIDs or {}
                        cur._remSet = cur._remSet or {}
                        for _, id in ipairs(refreshData.removedAuraInstanceIDs) do
                            if id and not cur._remSet[id] then
                                cur._remSet[id] = true
                                cur.removedAuraInstanceIDs[#cur.removedAuraInstanceIDs + 1] = id
                            end
                        end
                    end
                end
            end
        end
    end
    -- Unit events (arg1 = unit)
    if arg1 then
        local mask = EventMasks[event] or NS.REASON_ALL
        RequestUnitUpdate(arg1, event, false, mask)
    end
end

NS.Dispatch = Dispatch
