local _, NS = ...

-- ============================================================================
-- AURAS DATA LAYER (Retail 12.0+)
-- ============================================================================
-- Responsibilities:
--   1) Process UNIT_AURA refreshData incrementally (added/updated/removed)
--   2) Keep a per-frame cache (auraInstanceID -> aura table)
--   3) Provide ordered auraInstanceID lists (HELPFUL/HARMFUL/CC)
--
-- Notes:
--   * This layer is intentionally UI-agnostic.
--   * It can optionally notify a per-frame callback when the ordered lists are rebuilt.

NS.AurasData = NS.AurasData or {}

local wipe_tbl = wipe or (table and table.wipe)

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if not st then
        st = {
            unit = nil,
            auraData = {},
            helpfulIDs = nil,
            harmfulIDs = nil,
            ccIDs = nil,
            dirty = true,
            hasFull = false,
            callback = nil, -- function(frame, unit, st)
        }
        State[frame] = st
    end
    return st
end

local function ResetState(st)
    st.unit = nil
    if wipe_tbl and st.auraData then
        wipe_tbl(st.auraData)
    else
        st.auraData = {}
    end
    st.helpfulIDs = nil
    st.harmfulIDs = nil
    st.ccIDs = nil
    st.dirty = true
    st.hasFull = false
end

local function GetSortRule()
    if not Enum or not Enum.UnitAuraSortRule then return nil end
    -- Prefer stable rules that exist across versions.
    return Enum.UnitAuraSortRule.ExpirationOnly
        or Enum.UnitAuraSortRule.Duration
        or Enum.UnitAuraSortRule.Default
end

function NS.AurasData.Reset(frame)
    if not frame then return end
    local st = State[frame]
    if not st then return end
    ResetState(st)
end

function NS.AurasData.SetCallback(frame, cb)
    if not frame then return end
    local st = GetState(frame)
    st.callback = cb
end

-- Returns: changed, needFull
function NS.AurasData.ApplyRefresh(frame, unit, refreshData)
    if not frame or not unit then return false, false end
    local st = GetState(frame)

    if st.unit ~= unit then
        ResetState(st)
        st.unit = unit
    end

 -- Если нет данных об обновлении, но кэш уже собран — ничего не делаем (сохраняем производительность)
    if not refreshData then
        if st.hasFull then
            return false, false
        else
            st.dirty = true
            return true, true
        end
    end

    if refreshData.isFullUpdate then
        if wipe_tbl and st.auraData then
            wipe_tbl(st.auraData)
        else
            st.auraData = {}
        end
        st.dirty = true
        st.hasFull = false
        return true, true
    end

    local changed = false

    if refreshData.addedAuras then
        for _, aura in ipairs(refreshData.addedAuras) do
            local id = aura and aura.auraInstanceID
            if id then
                st.auraData[id] = aura
                changed = true
            end
        end
    end

    if refreshData.updatedAuraInstanceIDs and C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        for _, id in ipairs(refreshData.updatedAuraInstanceIDs) do
            if id then
                local aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, id)
                if aura then
                    st.auraData[id] = aura
                    changed = true
                else
                    if st.auraData[id] ~= nil then
                        st.auraData[id] = nil
                        changed = true
                    end
                end
            end
        end
    end

    if refreshData.removedAuraInstanceIDs then
        for _, id in ipairs(refreshData.removedAuraInstanceIDs) do
            if id and st.auraData[id] ~= nil then
                st.auraData[id] = nil
                changed = true
            end
        end
    end

    if changed then
        st.dirty = true
    end

    return changed, false
end

function NS.AurasData.FullRefresh(frame, unit)
    if not frame or not unit then return end
    local st = GetState(frame)

    if st.unit ~= unit then
        ResetState(st)
        st.unit = unit
    end

    if wipe_tbl and st.auraData then
        wipe_tbl(st.auraData)
    else
        st.auraData = {}
    end

    if not (C_UnitAuras and C_UnitAuras.GetUnitAuras) then
        st.dirty = true
        st.hasFull = true
        return
    end

    local helpful = C_UnitAuras.GetUnitAuras(unit, "HELPFUL")
    if helpful then
        for _, aura in ipairs(helpful) do
            local id = aura and aura.auraInstanceID
            if id then
                st.auraData[id] = aura
            end
        end
    end

    local harmful = C_UnitAuras.GetUnitAuras(unit, "HARMFUL")
    if harmful then
        for _, aura in ipairs(harmful) do
            local id = aura and aura.auraInstanceID
            if id then
                st.auraData[id] = aura
            end
        end
    end

    st.dirty = true
    st.hasFull = true
end

function NS.AurasData.EnsureFull(frame, unit)
    if not frame or not unit then return end
    local st = GetState(frame)
    if st.unit ~= unit then
        ResetState(st)
        st.unit = unit
    end
    if not st.hasFull then
        NS.AurasData.FullRefresh(frame, unit)
    end
end

function NS.AurasData.RebuildOrder(frame, unit)
    if not frame or not unit then return end
    local st = GetState(frame)

    if st.unit ~= unit then
        ResetState(st)
        st.unit = unit
    end

    if not st.dirty then return end

    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then
        st.helpfulIDs = nil
        st.harmfulIDs = nil
        st.ccIDs = nil
        st.dirty = false
        return
    end

    local sortRule = GetSortRule()
    st.helpfulIDs = C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HELPFUL", nil, sortRule)
    st.harmfulIDs = C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HARMFUL", nil, sortRule)
    st.ccIDs = C_UnitAuras.GetUnitAuraInstanceIDs(unit, "HARMFUL|CROWD_CONTROL", nil, sortRule)

    st.dirty = false

    if st.callback then
        -- pcall to prevent breaking the whole addon on callback errors
        pcall(st.callback, frame, unit, st)
    end
end

function NS.AurasData.GetIDs(frame, kind)
    if not frame then return nil end
    local st = GetState(frame)
    if kind == "BUFF" then return st.helpfulIDs end
    if kind == "DEBUFF" then return st.harmfulIDs end
    if kind == "CC" then return st.ccIDs end
    return nil
end

function NS.AurasData.GetAura(frame, unit, auraInstanceID)
    if not frame or not unit or not auraInstanceID then return nil end
    local st = GetState(frame)
    local aura = st.auraData[auraInstanceID]
    if aura then return aura end

    if C_UnitAuras and C_UnitAuras.GetAuraDataByAuraInstanceID then
        aura = C_UnitAuras.GetAuraDataByAuraInstanceID(unit, auraInstanceID)
        if aura then
            st.auraData[auraInstanceID] = aura
            return aura
        end
    end
    return nil
end

