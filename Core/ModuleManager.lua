local _, NS = ...
-- =============================================================
-- ModuleManager
--  - единая точка запуска модулей
--  - совместимость:
--      NS.Modules.Name = function(frame, unit, dbUnit, dbGlobal)
--    новый формат:
--      NS.Modules.Name = { Init=func, Update=func, Reset=func }
-- =============================================================

NS.Modules = NS.Modules or {}

local M = {}

local _bit = _G.bit or _G.bit32
local bor = _bit and _bit.bor
local band = _bit and _bit.band
if not (bor and band) then
    -- если нет bit-библиотеки — не фильтруем (запускаем всё)
    bor = function() return -1 end
    band = function() return -1 end
end

-- фиксированный порядок, чтобы избежать “случайных” зависимостей
M.ORDER = {
    "HpBar",
    "Icon",
    "FactionIcon",
    "QuestIcon",
    "RaidTargetIcon",
    "Auras",
    "NameText",
    "HpText",
    "Level",
    "CastBar",
    "CastTimer",
    "TargetIndicator",
    "Border",
    "Transparency",
    "Glow",
}

-- Маски причин для модулей.
-- Если модуль не указан — запускается всегда (NS.REASON_ALL).
M.REASONS = {
    -- Геометрия/конфиг
    HpBar = bor(bor(bor(bor(NS.REASON_PLATE or 1, NS.REASON_CONFIG or 128), NS.REASON_CVAR or 256), NS.REASON_HEALTH or 8), bor(NS.REASON_THREAT or 16, NS.REASON_CLASS or 32)),
    Icon = bor(bor(NS.REASON_PLATE or 1, NS.REASON_CONFIG or 128), NS.REASON_CLASS or 32),
    FactionIcon = bor(bor(NS.REASON_PLATE or 1, NS.REASON_CONFIG or 128), NS.REASON_CLASS or 32),
    QuestIcon = bor(bor(NS.REASON_PLATE or 1, NS.REASON_CONFIG or 128), NS.REASON_QUEST or 1024),
    RaidTargetIcon = bor(bor(NS.REASON_TARGET or 64, NS.REASON_PLATE or 1), NS.REASON_CONFIG or 128),
    NameText = bor(bor(bor(NS.REASON_PLATE or 1, NS.REASON_CONFIG or 128), NS.REASON_CLASS or 32), NS.REASON_TARGET or 64),
    HpText = bor(bor(bor(NS.REASON_PLATE or 1, NS.REASON_CONFIG or 128), NS.REASON_HEALTH or 8), NS.REASON_CLASS or 32),
    Level = bor(bor(bor(NS.REASON_PLATE or 1, NS.REASON_CONFIG or 128), NS.REASON_CLASS or 32), NS.REASON_TARGET or 64),

    -- Heavy modules with incremental state
    Auras = bor(bor(NS.REASON_AURA or 2, NS.REASON_PLATE or 1), NS.REASON_CONFIG or 128),
    CastBar = bor(bor(NS.REASON_CAST or 4, NS.REASON_PLATE or 1), NS.REASON_CONFIG or 128),
    CastTimer = bor(bor(NS.REASON_CAST or 4, NS.REASON_PLATE or 1), NS.REASON_CONFIG or 128),

    -- Target/selection visuals
    TargetIndicator = bor(bor(NS.REASON_TARGET or 64, NS.REASON_PLATE or 1), NS.REASON_CONFIG or 128),
    Border = bor(bor(NS.REASON_TARGET or 64, NS.REASON_PLATE or 1), NS.REASON_CONFIG or 128),
    Glow = bor(bor(NS.REASON_TARGET or 64, NS.REASON_PLATE or 1), NS.REASON_CONFIG or 128),

    -- Range transparency updated by Engine fast-task (REASON_RANGE)
    Transparency = bor(bor(NS.REASON_RANGE or 512, NS.REASON_PLATE or 1), NS.REASON_CONFIG or 128),
}

local function SafeCall(name, fn, ...)
    local ok, err = pcall(fn, ...)
    if not ok and NS.DEBUG then
        print("|cffff0000BlizzPlatesFix error in module:|r", name, err)
    end
end

local function ResolveModule(mod)
    if type(mod) == "function" then
        return nil, mod, nil
    elseif type(mod) == "table" then
        return mod.Init, mod.Update, mod.Reset
    end
end

function M.InitFrame(frame, unit, dbUnit, dbGlobal)
    if frame.BPF_ModInit then return end
    frame.BPF_ModInit = true

    for _, name in ipairs(M.ORDER) do
        local mod = NS.Modules[name]
        local initFn = ResolveModule(mod)
        if type(initFn) == "function" then
            SafeCall(name .. ":Init", initFn, frame, unit, dbUnit, dbGlobal)
        end
    end
end

function M.ResetFrame(frame)
    if not frame then return end
    frame.BPF_ModInit = nil

    for name, mod in pairs(NS.Modules) do
        local _, _, resetFn = ResolveModule(mod)
        if type(resetFn) == "function" then
            SafeCall(name .. ":Reset", resetFn, frame)
        end
    end
end

function M.RunAll(frame, unit, dbUnit, dbGlobal, reasonMask)
    if not frame or frame:IsForbidden() then return end

    -- гарантируем единоразовую инициализацию
    M.InitFrame(frame, unit, dbUnit, dbGlobal)

    local ran = frame.BPF_RanModules
    if not ran then
        ran = {}
        frame.BPF_RanModules = ran
    end
    for k in pairs(ran) do ran[k] = nil end

    for _, name in ipairs(M.ORDER) do
        local mod = NS.Modules[name]
        local _, updateFn = ResolveModule(mod)
        if type(updateFn) == "function" then
            local need = M.REASONS[name] or (NS.REASON_ALL or -1)
            if not reasonMask or need == (NS.REASON_ALL or -1) or band(reasonMask, need) ~= 0 then
                SafeCall(name, updateFn, frame, unit, dbUnit, dbGlobal)
            end
            ran[name] = true
        end
    end

    -- всё, что не в ORDER — тоже запускаем (чтобы новые модули не забывали)
    for name, mod in pairs(NS.Modules) do
        if not ran[name] then
            local _, updateFn = ResolveModule(mod)
            if type(updateFn) == "function" then
                local need = M.REASONS[name] or (NS.REASON_ALL or -1)
                if not reasonMask or need == (NS.REASON_ALL or -1) or band(reasonMask, need) ~= 0 then
                    SafeCall(name, updateFn, frame, unit, dbUnit, dbGlobal)
                end
            end
        end
    end
end

NS.ModuleManager = M
