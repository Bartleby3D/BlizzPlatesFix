local _, NS = ...

-- ============================================================================
-- Auras Preview (Test Mode)
-- Показывает тестовые иконки BUFF/DEBUFF/CC над неймплейтами для настройки.
-- ВАЖНО: превью хранится в ПРОФИЛЕ типа существа (Unit DB):
--   buffsPreview / debuffsPreview / ccPreview
-- Это позволяет включать превью только для настраиваемой категории существ,
-- не захламляя экран всеми неймплейтами подряд.
-- ============================================================================

NS.AurasPreview = NS.AurasPreview or {}

local FALLBACK_ICON = "Interface\\Icons\\INV_Misc_QuestionMark"

local function GetSpellTex(spellID)
    if not spellID then return nil end
    if C_Spell and C_Spell.GetSpellTexture then
        return C_Spell.GetSpellTexture(spellID)
    end
    if GetSpellTexture then
        return GetSpellTexture(spellID)
    end
    return nil
end


-- В превью показываем фиксированное число иконок (без "вспышек"),
-- чтобы при кручении ползунков иконки не "прыгали".

-- Состояние превью-иконок, чтобы можно было переиспользовать и
-- перезапускать таймеры без зависимости от внешних событий.
local PreviewState = {
    buffs   = nil,
    debuffs = nil,
    cc      = nil,
    _expanded = false,
}

-- "Наростание" в превью: часть иконок показывается постоянно,
-- остальные появляются на короткое время, чтобы было видно направление роста.
local GROW_PERIOD = 6.0
local GROW_WINDOW = 1.5
local function IsExpanded()
    local t = GetTime() % GROW_PERIOD
    return t < GROW_WINDOW
end

local function MakeEntry(spellID, duration, stacks, forcePandemic)
    local tex = GetSpellTex(spellID) or FALLBACK_ICON
    duration = tonumber(duration) or 0
    stacks = tonumber(stacks) or 0
    local now = GetTime()

    local start = now
    if duration > 1 then
        if forcePandemic then
            -- Ставим ауру сразу в последние 20% длительности,
            -- чтобы Pandemic Glow был виден моментально.
            start = now - (duration * 0.8)
        else
            start = now - math.random(0, math.floor(duration - 1))
        end
    end

    return {
        icon = tex,
        duration = duration,
        start = start,
        stacks = stacks,
        forcePandemic = forcePandemic and true or false,
    }
end

local function EnsureState()
    if PreviewState.buffs and PreviewState.debuffs and PreviewState.cc then return end

    -- BUFF
    PreviewState.buffs = {
        MakeEntry(21562, 120, 3),        -- Power Word: Fortitude
        MakeEntry(6673, 120, 2),         -- Battle Shout
        MakeEntry(104773, 12, 0, true),  -- Unending Resolve
        MakeEntry(1022, 10, 4),          -- Blessing of Protection
        MakeEntry(12472, 20, 0),         -- Icy Veins
    }

    -- DEBUFF
    PreviewState.debuffs = {
        MakeEntry(57723, 12, 2),         -- Sated/Exhaustion (fallback если нет)
        MakeEntry(25771, 18, 3),         -- Forbearance
        MakeEntry(34914, 12, 0, true),   -- Vampiric Touch
        MakeEntry(6788, 18, 5),          -- Weakened Soul
        MakeEntry(188389, 8, 0),         -- Flame Shock (id может отличаться)
    }

    -- CC
    PreviewState.cc = {
        MakeEntry(3355, 8, 2, true),     -- Freezing Trap
        MakeEntry(853, 6, 0),            -- Hammer of Justice
        MakeEntry(118, 8, 3),            -- Polymorph
    }
end

local function RotateExpired(list)
    if not list then return false end
    local now = GetTime()
    local changed = false
    for i = 1, #list do
        local a = list[i]
        local dur = tonumber(a.duration) or 0
        local start = tonumber(a.start) or now
        if dur > 0 and (now - start) >= dur then
            if dur >= 10 then
                a.duration = math.random(6, math.min(30, math.floor(dur)))
                dur = tonumber(a.duration) or dur
            end

            if a.forcePandemic and dur > 1 then
                a.start = now - (dur * 0.8)
            else
                a.start = now
            end

            changed = true
        end
    end
    return changed
end


function NS.AurasPreview.IsBuffsEnabled(db)
    return (db and db.buffsEnable and db.buffsPreview) and true or false
end

function NS.AurasPreview.IsDebuffsEnabled(db)
    return (db and db.debuffsEnable and db.debuffsPreview) and true or false
end

function NS.AurasPreview.IsCCEnabled(db)
    return (db and db.ccEnable and db.ccPreview) and true or false
end


function NS.AurasPreview.IsEnabled(db)
    return (NS.AurasPreview.IsBuffsEnabled(db) or NS.AurasPreview.IsDebuffsEnabled(db) or NS.AurasPreview.IsCCEnabled(db))
end

-- Полное отключение превью во всех профилях существ.
-- Нужно, например, при закрытии меню настроек, чтобы превью не оставалось висеть в мире.
function NS.AurasPreview.DisableAll()
    if not (NS.Config and NS.Config.Get and NS.Config.Set and NS.UNIT_TYPES) then return end

    local changed = false
    for _, unitType in pairs(NS.UNIT_TYPES) do
        if NS.Config.Get("buffsPreview", unitType) then
            NS.Config.Set("buffsPreview", false, unitType)
            changed = true
        end
        if NS.Config.Get("debuffsPreview", unitType) then
            NS.Config.Set("debuffsPreview", false, unitType)
            changed = true
        end
        if NS.Config.Get("ccPreview", unitType) then
            NS.Config.Set("ccPreview", false, unitType)
            changed = true
        end
    end

    if changed then
        -- Форсим перерисовку, чтобы тестовые иконки сразу исчезли.
        if NS.RequestUpdateAll then
            NS.RequestUpdateAll("preview_disable", true)
        elseif NS.Engine and NS.Engine.QueueAllActive then
            NS.Engine.QueueAllActive()
            if NS.Engine.FlushAllNow then
                NS.Engine.FlushAllNow()
            end
        end
    end
end

-- Возвращает тестовые списки аур.
-- Формат элемента: { icon=texturePath, duration=number, remaining=number, stacks=number }
function NS.AurasPreview.GetLists(unit)
    EnsureState()
    RotateExpired(PreviewState.buffs)
    RotateExpired(PreviewState.debuffs)
    RotateExpired(PreviewState.cc)

    local expanded = IsExpanded()
    PreviewState._expanded = expanded

    -- базовое количество: чтобы постоянно было видно 2-3, а остальные были "приглушены"
    local buffsBase = math.min(3, #PreviewState.buffs)
    local debuffsBase = math.min(3, #PreviewState.debuffs)
    local ccBase = math.min(2, #PreviewState.cc)

    local function Mark(list, base)
        for i = 1, #list do
            list[i].inactive = (not expanded) and (i > base) or false
        end
    end

    Mark(PreviewState.buffs, buffsBase)
    Mark(PreviewState.debuffs, debuffsBase)
    Mark(PreviewState.cc, ccBase)

    return PreviewState.buffs, PreviewState.debuffs, PreviewState.cc
end

-- Периодически обновляем активные неймплейты, чтобы было видно "наростание" в превью.
local function PreviewTick()
    if not NS.ActiveNamePlates then return end

    -- Определяем, есть ли хотя бы один активный неймплейт с включенным превью.
    local anyPreview = false
    for unitToken in pairs(NS.ActiveNamePlates) do
        local dbUnit = NS.GetUnitConfig and select(1, NS.GetUnitConfig(unitToken))
        if NS.AurasPreview.IsEnabled(dbUnit) then
            anyPreview = true
            break
        end
    end
    if not anyPreview then return end

    -- Обновляем состояние (перезапуск таймеров) и перерисовываем ТОЛЬКО те неймплейты,
    -- для которых включено превью.
    EnsureState()
    local b = RotateExpired(PreviewState.buffs)
    local d = RotateExpired(PreviewState.debuffs)
    local c = RotateExpired(PreviewState.cc)

    local expandedNow = IsExpanded()
    local visChanged = (PreviewState._expanded ~= expandedNow)
    PreviewState._expanded = expandedNow

    if (b or d or c or visChanged) and NS.Engine and NS.Engine.QueueUnitUpdate then
        for unitToken in pairs(NS.ActiveNamePlates) do
            local dbUnit = NS.GetUnitConfig and select(1, NS.GetUnitConfig(unitToken))
            if NS.AurasPreview.IsEnabled(dbUnit) then
                NS.Engine.QueueUnitUpdate(unitToken)
            end
        end
    end
end

local _registered = false
function NS.AurasPreview.OnEngineReady()
    if _registered then return end
    if not (NS.Engine and NS.Engine.RegisterFastTask) then return end
    -- сигнатура RegisterFastTask(name, interval, func)
    NS.Engine.RegisterFastTask("AurasPreviewTick", 0.50, PreviewTick)
    _registered = true
end

-- если Engine уже есть (на всякий случай)
NS.AurasPreview.OnEngineReady()
