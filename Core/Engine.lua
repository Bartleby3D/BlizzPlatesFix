local _, NS = ...
-- =============================================================
-- ENGINE: единый цикл обновлений (очередь + периодические задачи)
-- Цель: централизовать расписание и не плодить UpdateFrame'ы в разных файлах.
-- =============================================================

NS.Engine = NS.Engine or {}

-- =============================================================
-- Update reasons (bitmask)
--   Используется для того, чтобы не гонять тяжелые модули на любых UNIT_*.
--   Маски доступны в ModuleManager/Dispatch.
-- =============================================================

local _bit = _G.bit or _G.bit32
local bor = _bit and _bit.bor
local band = _bit and _bit.band

-- В рознице WoW есть bit.*. Если по какой-то причине его нет —
-- деградируем на "всё обновлять" без масок.
if not (bor and band) then
    bor = function(a, b) return -1 end
    band = function(a, b) return -1 end
end

NS.REASON_PLATE  = NS.REASON_PLATE  or 1
NS.REASON_AURA   = NS.REASON_AURA   or 2
NS.REASON_CAST   = NS.REASON_CAST   or 4
NS.REASON_HEALTH = NS.REASON_HEALTH or 8
NS.REASON_THREAT = NS.REASON_THREAT or 16
NS.REASON_CLASS  = NS.REASON_CLASS  or 32
NS.REASON_TARGET = NS.REASON_TARGET or 64
NS.REASON_NAME   = NS.REASON_NAME   or 4096
NS.REASON_CONFIG = NS.REASON_CONFIG or 128
NS.REASON_CVAR   = NS.REASON_CVAR   or 256
NS.REASON_RANGE  = NS.REASON_RANGE  or 512
NS.REASON_QUEST  = NS.REASON_QUEST  or 1024
NS.REASON_POWER  = NS.REASON_POWER  or 2048
NS.REASON_ALL    = NS.REASON_ALL    or -1

-- (debug) последняя причина обновления по юниту
local LastReason = {} -- [unitToken] = string

-- Очередь обновлений (throttle)
-- PendingMask хранит агрегированную битмаску причин по юниту.
-- Queue обеспечивает справедливый FIFO-обход (без зависимости от pairs()).
local PendingMask = {}      -- [unitToken] = reasonMask
local Queue = {}            -- array of unitTokens
local QueueHead = 1
local QueueTail = 0
local InQueue = {}          -- [unitToken] = true
local queuedCount = 0

local QueueThrottle = {} -- [unitToken] = lastTimeQueued

local function IsNameplateUnit(unit)
    return type(unit) == "string" and unit:find("nameplate", 1, true) ~= nil
end

-- SafeCall доступен всем файлам (Events/Runner/Modules).
function NS.Engine.SafeCall(func, ...)
    if not func then return end

    local ok, err = pcall(func, ...)
    if not ok and NS.DEBUG then
        print("|cffff0000BlizzPlatesFix error:|r", err)
    end
end


-- =============================================================
-- Прямое обновление прозрачности по дистанции (без очереди/Runner/ModuleManager)
-- =============================================================
function NS.UpdateTransparencyRange()
    if not (NS.Config and NS.Config.GetTable) then return end
    if not (NS.Modules and NS.Modules.Transparency and NS.Modules.Transparency.Update) then return end

    local gdb = NS.Config.GetTable("Global")
    if not gdb then return end

    if gdb.transparencyEnabled ~= true then return end
    if gdb.transparencyMode ~= 2 then return end
    local a = gdb.transparencyAlpha
    if a == nil then a = 1 end
    if a >= 0.999 then return end

    local mod = NS.Modules.Transparency

    for unit, frame in pairs(NS.ActiveNamePlates) do
        if frame and not frame:IsForbidden() then
            -- Не трогаем widgets-only (интерактивные объекты), чтобы не сделать их полупрозрачными.
            if _G.UnitNameplateShowsWidgetsOnly and _G.UnitNameplateShowsWidgetsOnly(unit) then
                if mod.Reset then mod.Reset(frame) end
            else
                mod.Update(frame, unit, nil, gdb)
            end
        end
    end
end

-- Поставить юнит в очередь на обновление
function NS.Engine.QueueUnitUpdate(unit, reasonMask)
    if not IsNameplateUnit(unit) then return end

    reasonMask = reasonMask or NS.REASON_ALL

    local now = GetTime()
    local last = QueueThrottle[unit]
    if last and (now - last) < 0.05 then
        -- Уже недавно ставили в очередь: только объединяем причины.
        PendingMask[unit] = PendingMask[unit] and bor(PendingMask[unit], reasonMask) or reasonMask
        if not InQueue[unit] then
            QueueTail = QueueTail + 1
            Queue[QueueTail] = unit
            InQueue[unit] = true
            queuedCount = queuedCount + 1
        end
        return
    end
    QueueThrottle[unit] = now

    PendingMask[unit] = PendingMask[unit] and bor(PendingMask[unit], reasonMask) or reasonMask

    if not InQueue[unit] then
        QueueTail = QueueTail + 1
        Queue[QueueTail] = unit
        InQueue[unit] = true
        queuedCount = queuedCount + 1
    end
end

-- =============================================================
-- Публичный API обновлений
-- =============================================================

-- Единый вход: поставить юнит в очередь (и опционально обновить сразу).
-- reason: строка для отладки (можно nil)
-- immediate: если true, дергает UpdateAllModules сразу (без ожидания тика)
function NS.Engine.RequestUpdate(unit, reason, immediate, reasonMask)
    if reason and NS.DEBUG and IsNameplateUnit(unit) then
        LastReason[unit] = reason
    end

    NS.Engine.QueueUnitUpdate(unit, reasonMask)

    if immediate then
        NS.Engine.SafeCall(NS.UpdateAllModules, unit, reasonMask or NS.REASON_ALL)
    end
end

-- Поставить все активные в очередь (и опционально обновить сразу)
function NS.Engine.RequestUpdateAll(reason, immediate, reasonMask)
    if reason and NS.DEBUG then
        LastReason.__all = reason
    end

    NS.Engine.QueueAllActive(reasonMask)

    if immediate then
        NS.Engine.FlushAllNow()
    end
end

-- Debug accessor intentionally not exported in release builds.
-- LastReason is kept local for optional NS.DEBUG printing.

-- Поставить все активные неймплейты в очередь
function NS.Engine.QueueAllActive(reasonMask)
    if not NS.ActiveNamePlates then return end
    for unitToken in pairs(NS.ActiveNamePlates) do
        NS.Engine.QueueUnitUpdate(unitToken, reasonMask)
    end
end

-- Очистить юнит из очередей/троттлов (вызывается при NAME_PLATE_UNIT_REMOVED)
function NS.Engine.ClearUnitFromQueues(unit)
    if not unit then return end

    PendingMask[unit] = nil
    InQueue[unit] = nil
    QueueThrottle[unit] = nil
end

-- Разгрести очередь (частично). Возвращает число обработанных.
function NS.Engine.FlushPending(maxPerTick)
    if queuedCount <= 0 then return 0 end

    local processed = 0
    local limit = maxPerTick or 25

    while processed < limit and queuedCount > 0 do
        local unitToken = Queue[QueueHead]
        Queue[QueueHead] = nil
        QueueHead = QueueHead + 1
        queuedCount = queuedCount - 1

        if unitToken then
            InQueue[unitToken] = nil
            local mask = PendingMask[unitToken]
            PendingMask[unitToken] = nil

            if mask then
                NS.Engine.SafeCall(NS.UpdateAllModules, unitToken, mask or NS.REASON_ALL)
            end
        end

        processed = processed + 1
    end

    -- Компактация очереди, чтобы QueueHead не рос бесконечно.
    if QueueHead > 200 and QueueHead > (QueueTail / 2) then
        local newQ = {}
        local n = 0
        for i = QueueHead, QueueTail do
            local u = Queue[i]
            if u then
                n = n + 1
                newQ[n] = u
            end
        end
        Queue = newQ
        QueueHead = 1
        QueueTail = n
        queuedCount = n
        -- InQueue остаётся корректным, т.к. мы не меняем факты присутствия юнитов в очереди.
    end

    return processed
end

-- Немедленно обновить все активные (используется в ForceUpdateAll/настройках).
function NS.Engine.FlushAllNow()
    if not NS.ActiveNamePlates then return end
    for unitToken in pairs(NS.ActiveNamePlates) do
        NS.Engine.SafeCall(NS.UpdateAllModules, unitToken, NS.REASON_ALL)
    end
end

-- =============================================================
-- Fast задачи (регистрация/исполнение)
-- =============================================================

-- FastTasks[name] = { interval=number, elapsed=number, enabled=bool, func=function }
local FastTasks = {}

-- name: string
-- interval: number (seconds)
-- func: function() | function(task)
function NS.Engine.RegisterFastTask(name, interval, func)
    if type(name) ~= "string" or name == "" then return end
    if type(func) ~= "function" then return end
    interval = tonumber(interval) or 0.15
    if interval <= 0 then interval = 0.15 end

    FastTasks[name] = {
        interval = interval,
        elapsed  = 0,
        enabled  = true,
        func     = func,
    }
end

function NS.Engine.UnregisterFastTask(name)
    if type(name) ~= "string" or name == "" then return end
    FastTasks[name] = nil
end

function NS.Engine.EnableFastTask(name, enabled)
    local t = FastTasks[name]
    if not t then return end
    t.enabled = not not enabled
end

function NS.Engine.RunFastTasks(elapsed)
    for _, task in pairs(FastTasks) do
        if task.enabled and task.func then
            task.elapsed = task.elapsed + elapsed
            if task.elapsed >= task.interval then
                task.elapsed = task.elapsed - task.interval
                NS.Engine.SafeCall(task.func, task)
            end
        end
    end
end

-- =============================================================
-- Built-in fast задачи (можно отключать через EnableFastTask)
-- =============================================================


local function Fast_MouseoverGlow()
    NS.Engine.SafeCall(NS.UpdateMouseoverGlow)
end


local function Fast_TransparencyRange()
    -- Обновляем прозрачность по дистанции периодически.
    -- Важно: запускаем только когда включено и выбран режим "By distance".
    if not (NS.Config and NS.Config.GetTable) then return end
    local gdb = NS.Config.GetTable("Global")
    if not gdb then return end
    if gdb.transparencyEnabled ~= true then return end
    if gdb.transparencyMode ~= 2 then return end
    local a = gdb.transparencyAlpha
    if a == nil then a = 1 end
    if a >= 0.999 then return end

    NS.Engine.SafeCall(NS.UpdateTransparencyRange)
end



-- Регистрируем задачи по умолчанию
NS.Engine.RegisterFastTask("mouseover_glow",          0.15, Fast_MouseoverGlow)
NS.Engine.RegisterFastTask("transparency_range",     0.20, Fast_TransparencyRange)

-- =============================================================
-- ЕДИНЫЙ OnUpdate: очередь + fast задачи
-- =============================================================
local UpdateFrame = CreateFrame("Frame")

local elapsedQueue = 0
local QUEUE_INTERVAL = 0.05   -- разгребаем очередь

UpdateFrame:SetScript("OnUpdate", function(self, elapsed)
    if not (NS.Config and NS.Config.IsReady and NS.Config.IsReady()) then return end

    -- 1) Очередь обновлений
    elapsedQueue = elapsedQueue + elapsed
    if elapsedQueue >= QUEUE_INTERVAL then
        elapsedQueue = elapsedQueue - QUEUE_INTERVAL
        NS.Engine.FlushPending(25)
    end

    -- 2) Fast задачи
    NS.Engine.RunFastTasks(elapsed)
end)

-- =============================================================
-- Backward-compat: старые имена функций (используются в текущем коде)
-- =============================================================
NS.SafeCall = NS.Engine.SafeCall
NS.QueueUnitUpdate = NS.Engine.QueueUnitUpdate
NS.QueueAllActive = NS.Engine.QueueAllActive
NS.ClearUnitFromQueues = NS.Engine.ClearUnitFromQueues

-- Новый API
NS.RequestUpdate = NS.Engine.RequestUpdate
NS.RequestUpdateAll = NS.Engine.RequestUpdateAll

-- Notify preview module that Engine is ready (Modules load before Core/Engine.lua)
if NS.AurasPreview and NS.AurasPreview.OnEngineReady then
    NS.AurasPreview.OnEngineReady()
end
