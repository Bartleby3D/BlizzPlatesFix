local _, NS = ...

-- =============================================================
-- CONFIG: единственная точка доступа к SavedVariables (BlizzPlatesFixDB)
-- =============================================================

NS.Config = NS.Config or {}

-- =============================================================
-- Combat-safe config writes:
--  - In combat we DO NOT mutate SavedVariables tables used by nameplate updates.
--  - We store pending changes and commit them on PLAYER_REGEN_ENABLED.
--  - UI reads (Config.Get/GetColor) see pending values while in combat.
-- =============================================================

local _bit = _G.bit or _G.bit32
local _bor = _bit and _bit.bor

local function _CtxKey(context)
    if context == nil or context == "Global" then return "Global" end
    return tostring(context)
end

-- Pending changes while in combat
local _PendingVals   = {} -- [ctx][key] = value
local _PendingColors = {} -- [ctx][key] = { r=, g=, b=, a= }
local _PendingGlobalTouched = false

local function _HasPending()
    for _, t in pairs(_PendingVals) do
        if next(t) ~= nil then return true end
    end
    for _, t in pairs(_PendingColors) do
        if next(t) ~= nil then return true end
    end
    return false
end

function NS.Config.HasPending()
    return _HasPending()
end

-- Apply pending changes to the active profile (out of combat only).
-- Returns true if something was committed.
function NS.Config.CommitPending()
    if not _HasPending() then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    if not BlizzPlatesFixDB then return false end

    -- values
    for ctx, kv in pairs(_PendingVals) do
        local t = NS.Config.GetTable(ctx)
        if t and type(kv) == "table" then
            for k, v in pairs(kv) do
                t[k] = v
            end
        end
        _PendingVals[ctx] = nil
    end

    -- colors
    for ctx, kc in pairs(_PendingColors) do
        local t = NS.Config.GetTable(ctx)
        if t and type(kc) == "table" then
            for k, c in pairs(kc) do
                if type(c) == "table" then
                    local cur = t[k]
                    if type(cur) ~= "table" then cur = {} end
                    cur.r, cur.g, cur.b, cur.a = c.r, c.g, c.b, (c.a or 1)
                    t[k] = cur
                end
            end
        end
        _PendingColors[ctx] = nil
    end

    -- global CVars (apply once)
    if _PendingGlobalTouched and NS.ApplySystemCVars then
        NS.SafeCall(NS.ApplySystemCVars)
    end
    _PendingGlobalTouched = false

    -- single refresh
    if NS.RequestUpdateAll then
        local mask = (NS.REASON_CONFIG or 128)
        if _bor then mask = _bor(mask, (NS.REASON_CVAR or 256)) end
        NS.RequestUpdateAll("commit_pending", true, mask)
    elseif NS.ForceUpdateAll then
        NS.ForceUpdateAll()
    end

    return true
end

-- Profile helpers (character-bound profiles)
function NS.Config.GetCharKey()
    local name = UnitName and UnitName("player")
    if not name then return nil end
    local realm = (GetNormalizedRealmName and GetNormalizedRealmName()) or (GetRealmName and GetRealmName()) or ""
    if realm and realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

function NS.Config.GetActiveProfileName()
    if not BlizzPlatesFixDB or type(BlizzPlatesFixDB.profileKeys) ~= "table" or type(BlizzPlatesFixDB.profiles) ~= "table" then
        return "Default"
    end
    local ck = NS.Config.GetCharKey and NS.Config.GetCharKey() or nil
    local p = (ck and BlizzPlatesFixDB.profileKeys[ck]) or "Default"
    if not BlizzPlatesFixDB.profiles[p] then p = "Default" end
    return p
end

function NS.Config.SetActiveProfileName(profileName)
    if not BlizzPlatesFixDB or not profileName then return end
    if type(BlizzPlatesFixDB.profileKeys) ~= "table" then BlizzPlatesFixDB.profileKeys = {} end
    if type(BlizzPlatesFixDB.profiles) ~= "table" then BlizzPlatesFixDB.profiles = {} end
    if not BlizzPlatesFixDB.profiles[profileName] then return end
    local ck = NS.Config.GetCharKey and NS.Config.GetCharKey()
    if not ck then return end
    BlizzPlatesFixDB.profileKeys[ck] = profileName
end


-- Гарантируем наличие корневых таблиц. Не заполняет defaults (это делает NS.DB.Init()).
function NS.Config.EnsureDB()
    BlizzPlatesFixDB = BlizzPlatesFixDB or {}

    -- Ensure profile containers
    BlizzPlatesFixDB.profileKeys = BlizzPlatesFixDB.profileKeys or {}
    BlizzPlatesFixDB.profiles = BlizzPlatesFixDB.profiles or {}

    -- If this is a legacy DB (Global/Units at root), migrate it into Default profile (by reference).
    if not BlizzPlatesFixDB.profiles["Default"] then
        local legacyGlobal = (type(BlizzPlatesFixDB.Global) == "table") and BlizzPlatesFixDB.Global or nil
        local legacyUnits = (type(BlizzPlatesFixDB.Units) == "table") and BlizzPlatesFixDB.Units or nil
        BlizzPlatesFixDB.profiles["Default"] = { Global = legacyGlobal or {}, Units = legacyUnits or {} }
    end

    -- Bind current character to a profile if needed
    local ck = NS.Config.GetCharKey and NS.Config.GetCharKey()
    if ck and not BlizzPlatesFixDB.profileKeys[ck] then
        BlizzPlatesFixDB.profileKeys[ck] = "Default"
    end

    -- Keep legacy keys for backward compatibility (older versions may read them).
    BlizzPlatesFixDB.Global = BlizzPlatesFixDB.Global or {}
    BlizzPlatesFixDB.Units = BlizzPlatesFixDB.Units or {}

    return BlizzPlatesFixDB
end

function NS.Config.IsReady()
    return BlizzPlatesFixDB ~= nil
end

-- Возвращает таблицу контекста: Global или конкретный unitType.
-- context: "Global" | unitType string (например NS.UNIT_TYPES.ENEMY_NPC)
function NS.Config.GetTable(context)
    if not BlizzPlatesFixDB then return nil end

    local profName = (NS.Config.GetActiveProfileName and NS.Config.GetActiveProfileName()) or "Default"
    local prof = (BlizzPlatesFixDB.profiles and BlizzPlatesFixDB.profiles[profName]) or nil
    if not prof then return nil end

    if context == nil or context == "Global" then
        return prof.Global
    end
    return (prof.Units and prof.Units[context]) or nil
end

-- Утилиты более высокого уровня (на будущее):
function NS.Config.GetGlobalTable()
    return NS.Config.GetTable("Global")
end

function NS.Config.GetUnitTypeTable(unitType)
    if not unitType then return nil end
    return NS.Config.GetTable(unitType)
end

-- Получить значение
function NS.Config.Get(key, context)
    if key == nil then return nil end

    -- In combat: show pending value (UI), but do not mutate live tables.
    if InCombatLockdown and InCombatLockdown() then
        local ctx = _CtxKey(context)
        local pv = _PendingVals[ctx]
        if pv and pv[key] ~= nil then
            return pv[key]
        end
    end

    local t = NS.Config.GetTable(context)
    if not t then return nil end
    return t[key]
end


-- Установить значение
function NS.Config.Set(key, value, context)
    if key == nil then return end
    if not BlizzPlatesFixDB then return end

    -- In combat: defer writes + refresh until leaving combat.
    if InCombatLockdown and InCombatLockdown() then
        local ctx = _CtxKey(context)
        _PendingVals[ctx] = _PendingVals[ctx] or {}
        _PendingVals[ctx][key] = value
        if ctx == "Global" then
            _PendingGlobalTouched = true
        end
        return
    end

    local t = NS.Config.GetTable(context)
    if not t then return end

    if t[key] == value then return end
    t[key] = value

    if NS.RequestUpdateAll then
        local mask = (NS.REASON_CONFIG or 128)
        if _bor then mask = _bor(mask, (NS.REASON_CVAR or 256)) end
        NS.RequestUpdateAll("config_set:" .. key, true, mask)
    elseif NS.ForceUpdateAll then
        NS.ForceUpdateAll()
    end

    if (context == nil or context == "Global") and NS.ApplySystemCVars then
        NS.ApplySystemCVars()
    end
end


function NS.Config.GetColor(key, context)
    if InCombatLockdown and InCombatLockdown() then
        local ctx = _CtxKey(context)
        local pc = _PendingColors[ctx]
        if pc and pc[key] then
            local c = pc[key]
            return c.r or 1, c.g or 1, c.b or 1, (c.a or 1)
        end
    end

    local val = NS.Config.Get(key, context)
    if not val then return 1, 1, 1, 1 end
    return val.r, val.g, val.b, (val.a or 1)
end


function NS.Config.SetColor(key, r, g, b, a, context)
    if key == nil then return end
    if not BlizzPlatesFixDB then return end

    if InCombatLockdown and InCombatLockdown() then
        local ctx = _CtxKey(context)
        _PendingColors[ctx] = _PendingColors[ctx] or {}
        _PendingColors[ctx][key] = { r = r, g = g, b = b, a = (a or 1) }
        if ctx == "Global" then
            _PendingGlobalTouched = true
        end
        return
    end

    local t = NS.Config.GetTable(context)
    if not t then return end

    local cur = t[key]
    if type(cur) == "table" and cur.r == r and cur.g == g and cur.b == b and (cur.a or 1) == (a or 1) then
        return
    end

    local c = t[key] or {}
    c.r, c.g, c.b, c.a = r, g, b, a
    t[key] = c

    if NS.RequestUpdateAll then
        local mask = (NS.REASON_CONFIG or 128)
        NS.RequestUpdateAll("config_color:" .. key, true, mask)
    elseif NS.ForceUpdateAll then
        NS.ForceUpdateAll()
    end
end
