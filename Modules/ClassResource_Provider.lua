local _, NS = ...

local CR = NS.ClassResourceInternal
if not CR then return end

local floor = CR.floor
local max = CR.max
local abs = CR.abs

local function GetPowerDisplayMod(powerType)
    local displayMod = UnitPowerDisplayMod and UnitPowerDisplayMod(powerType) or 1
    if type(displayMod) ~= "number" or displayMod <= 0 then
        return 1
    end
    return displayMod
end

function CR.GetPlayerResource(st)
    if not UnitExists("player") then return nil end

    local specID = CR.GetPlayerSpecID and CR.GetPlayerSpecID()
    local powerType

    if CR.PLAYER_CLASS == "DRUID" then
        local formID = GetShapeshiftFormID and GetShapeshiftFormID()
        if formID == CR.CAT_FORM_ID then
            local maxCombo = UnitPowerMax("player", CR.POWER_COMBO_POINTS) or 0
            if maxCombo > 0 then powerType = CR.POWER_COMBO_POINTS end
        end
    elseif CR.PLAYER_CLASS == "MONK" then
        if specID == CR.SPECID_WINDWALKER_MONK then
            local maxChi = UnitPowerMax("player", CR.POWER_CHI) or 0
            if maxChi > 0 then powerType = CR.POWER_CHI end
        end
    elseif CR.PLAYER_CLASS == "MAGE" then
        if specID == CR.SPECID_ARCANE_MAGE then
            local maxArcane = UnitPowerMax("player", CR.POWER_ARCANE_CHARGE) or 0
            if maxArcane > 0 then powerType = CR.POWER_ARCANE_CHARGE end
        end
    else
        powerType = CR.CLASS_RESOURCE_PRIORITY[CR.PLAYER_CLASS]
    end

    if not powerType then return nil end

    local maxPower = UnitPowerMax("player", powerType)
    if not maxPower or maxPower <= 0 then return nil end

    if powerType == CR.POWER_RUNES then
        return powerType, 0, maxPower, 0, 1
    end

    local current = UnitPower("player", powerType) or 0
    local partial = 0

    if powerType == CR.POWER_ESSENCE then
        local now = GetTime()
        local regenRate = GetPowerRegenForPowerType and GetPowerRegenForPowerType(powerType) or 0
        local tickDuration = (type(regenRate) == "number" and regenRate > 0) and (1 / regenRate) or nil

        if current >= maxPower then
            CR.EssenceState.nextTick = nil
        elseif tickDuration and tickDuration > 0 then
            if CR.EssenceState.lastCurrent == nil then
                CR.EssenceState.lastCurrent = current
            end

            local prevCurrent = CR.EssenceState.lastCurrent
            local prevNextTick = CR.EssenceState.nextTick

            if current > prevCurrent then
                local gained = current - prevCurrent
                if prevNextTick and gained > 0 then
                    local candidate = prevNextTick + (gained * tickDuration)
                    if candidate <= now then
                        candidate = now + tickDuration
                    end
                    CR.EssenceState.nextTick = (current < maxPower) and candidate or nil
                else
                    CR.EssenceState.nextTick = (current < maxPower) and (now + tickDuration) or nil
                end
            elseif not prevNextTick then
                -- Do not reset the in-flight recharge timer on spend.
                -- Keep the current next-tick prediction if one already exists,
                -- and only start a new timer when we have no timer at all.
                CR.EssenceState.nextTick = now + tickDuration
            else
                CR.EssenceState.nextTick = prevNextTick
            end

            if CR.EssenceState.nextTick then
                local remaining = max(0, CR.EssenceState.nextTick - now)
                partial = 1 - (remaining / tickDuration)
                if partial < 0 then
                    partial = 0
                elseif partial > 0.999 then
                    partial = 0.999
                end
            end
        end

        CR.EssenceState.lastCurrent = current
        if st then
            st.essenceLastCurrent = CR.EssenceState.lastCurrent
            st.essenceNextTick = CR.EssenceState.nextTick
        end

        return powerType, current, maxPower, partial, 1
    end

    local displayMod = GetPowerDisplayMod(powerType)
    if displayMod > 1 then
        local exactCurrent = UnitPower("player", powerType, true) or 0
        local exactMax = UnitPowerMax("player", powerType, true) or (maxPower * displayMod)

        if exactMax > 0 then
            local normalizedMax = floor(exactMax / displayMod)
            if normalizedMax > 0 then
                maxPower = normalizedMax
            end

            current = floor(exactCurrent / displayMod)
            if current < 0 then
                current = 0
            elseif current > maxPower then
                current = maxPower
            end

            if current < maxPower then
                partial = (exactCurrent - (current * displayMod)) / displayMod
                if partial < 0 then
                    partial = 0
                elseif partial > 0.999 then
                    partial = 0.999
                end
            end
        end
    end

    return powerType, current, maxPower, partial, displayMod
end

function CR.GetColor(powerType)
    local c = CR.COLORS[powerType]
    if c then return c[1], c[2], c[3] end
    return 1, 1, 1
end

function CR.NeedsDynamicPolling(powerType, current, maxPower, partialProgress)
    if not powerType or powerType == CR.POWER_RUNES or not maxPower or maxPower <= 0 then
        return false
    end

    if powerType == CR.POWER_ESSENCE then
        -- Keep Essence on the timed fast-task even at full resource.
        -- This matches the rune fix approach: the bar stays "awake" so the first spend
        -- after a fully-recovered state is picked up immediately without waiting for a
        -- separate event-path wake-up.
        return true
    end

    if powerType == CR.POWER_SOUL_SHARDS then
        return true
    end

    if powerType == CR.POWER_ARCANE_CHARGE
        or powerType == CR.POWER_COMBO_POINTS
        or powerType == CR.POWER_HOLY_POWER
        or powerType == CR.POWER_CHI then
        return true
    end

    return false
end

function CR.CollectRuneSnapshot(count)
    local snapshot = {}
    local now = GetTime()

    for i = 1, count do
        local start, duration, runeReady = GetRuneCooldown(i)
        local ready = runeReady or (duration == 0)
        local remaining = 0
        local progress = ready and 1 or 0

        if not ready and start and duration and duration > 0 then
            remaining = max(0, (start + duration) - now)
            progress = (now - start) / duration
            if progress < 0 then
                progress = 0
            elseif progress > 1 then
                progress = 1
            end
        end

        snapshot[i] = {
            index = i,
            ready = ready,
            remaining = remaining,
            progress = progress,
        }
    end

    return snapshot
end

function CR.BuildRuneOrder(st, snapshot)
    local prevPos = {}
    if st and st.runeDisplayOrder then
        for pos = 1, #st.runeDisplayOrder do
            local prev = st.runeDisplayOrder[pos]
            if prev and prev.index then
                prevPos[prev.index] = pos
            end
        end
    end

    local entries = {}
    for i = 1, #snapshot do
        local info = snapshot[i]
        entries[i] = {
            index = info.index,
            ready = info.ready,
            remaining = info.remaining,
            progress = info.progress,
            prevPos = prevPos[info.index] or i,
        }
    end

    table.sort(entries, function(a, b)
        if a.ready ~= b.ready then
            return a.ready and not b.ready
        end

        if not a.ready and not b.ready then
            local diff = a.remaining - b.remaining
            if abs(diff) > CR.RUNE_REORDER_EPSILON then
                return diff < 0
            end
        end

        if a.prevPos ~= b.prevPos then
            return a.prevPos < b.prevPos
        end

        return a.index < b.index
    end)

    return entries
end

function CR.GetRuneColor()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or specIndex <= 0 then
        return CR.COLORS[CR.POWER_RUNES][1], CR.COLORS[CR.POWER_RUNES][2], CR.COLORS[CR.POWER_RUNES][3]
    end

    local specID = GetSpecializationInfo(specIndex)
    if CR.CachedSpecID == specID then
        return CR.CachedRuneColor.r, CR.CachedRuneColor.g, CR.CachedRuneColor.b
    end

    CR.CachedSpecID = specID
    if specID == CR.SPECID_BLOOD_DK then
        CR.CachedRuneColor.r, CR.CachedRuneColor.g, CR.CachedRuneColor.b = 0.78, 0.16, 0.16
    elseif specID == CR.SPECID_FROST_DK then
        CR.CachedRuneColor.r, CR.CachedRuneColor.g, CR.CachedRuneColor.b = 0.24, 0.72, 1.00
    elseif specID == CR.SPECID_UNHOLY_DK then
        CR.CachedRuneColor.r, CR.CachedRuneColor.g, CR.CachedRuneColor.b = 0.26, 0.76, 0.28
    else
        CR.CachedRuneColor.r = CR.COLORS[CR.POWER_RUNES][1]
        CR.CachedRuneColor.g = CR.COLORS[CR.POWER_RUNES][2]
        CR.CachedRuneColor.b = CR.COLORS[CR.POWER_RUNES][3]
    end

    return CR.CachedRuneColor.r, CR.CachedRuneColor.g, CR.CachedRuneColor.b
end
