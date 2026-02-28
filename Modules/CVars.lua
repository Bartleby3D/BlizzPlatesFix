local _, NS = ...

-- DB key -> CVar name
local cvarMap = {
    nameplateMaxDistance            = "nameplateMaxDistance",
    nameplateSelectedScale          = "nameplateSelectedScale",
    nameplateOccludedAlphaMult      = "nameplateOccludedAlphaMult",
    nameplateMinScale               = "nameplateMinScale",
}

local function NormalizeForCompare(v)
    -- GetCVar возвращает строку
    if v == nil then return nil end
    if type(v) == "boolean" then
        return v and "1" or "0"
    end
    if type(v) == "number" then
        -- чтобы 1 и 1.0 не дергались
        return tostring(v)
    end
    return tostring(v)
end

local function SetCVarIfChanged(cvarName, newValue)
    if not cvarName or newValue == nil then return end

    local newStr = NormalizeForCompare(newValue)
    if not newStr then return end

    local cur = GetCVar(cvarName) -- string
    if cur ~= newStr then
        SetCVar(cvarName, newStr)
    end
end

function NS.ApplySystemCVars()
    if InCombatLockdown and InCombatLockdown() then
        return
    end
    -- Берем глобальные настройки через API
    local gdb = NS.Config.GetTable("Global")
    if not gdb then return end

    -- 1) обычные CVars из списка
    for dbKey, cvarName in pairs(cvarMap) do
        local v = gdb[dbKey]
        if v ~= nil then
            SetCVarIfChanged(cvarName, v)
        end
    end

    -- 2) nameplateMinAlphaDistance: используем для прозрачности (как у тебя)
    if gdb.transparencyEnabled then
        -- Делаем так, чтобы неймплейты не исчезали из-за min alpha distance
        SetCVarIfChanged("nameplateMinAlphaDistance", -10000)
    else
        local def = C_CVar.GetCVarDefault("nameplateMinAlphaDistance")
        if def ~= nil then
            SetCVarIfChanged("nameplateMinAlphaDistance", def)
        end
    end
end