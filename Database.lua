local _, NS = ...
NS.DB = NS.DB or {}

-- Типы профилей (константы для удобства)
NS.UNIT_TYPES = {
    FRIENDLY_PLAYER = "FriendlyPlayer",
    FRIENDLY_NPC    = "FriendlyNPC",
    ENEMY_PLAYER    = "EnemyPlayer",
    ENEMY_NPC       = "EnemyNPC",
}

local function CopyValue(v)
    if type(v) ~= "table" then return v end
    local t = {}
    for k, v2 in pairs(v) do t[k] = CopyValue(v2) end
    return t
end

-- 1. Глобальные настройки (Движок, CVars, общие правила)
NS.DB.globalDefaults = {
    -- Движок
    globalFont = "Friz Quadrata TT",
    globalScale = 1.0,
    globalX = 0,
    globalY = -10,

    -- Minimap
    showMinimapIcon = true,
    -- CVars (Системные)
    nameplateMaxDistance = 60,
    nameplateSelectedScale = 1.2,
    nameplateOccludedAlphaMult = 0.4,
    nameplateMinScale = 1,

    -- Прозрачность (логика)
    transparencyEnabled = false,
    transparencyMode = 1,
    transparencyAlpha = 0.5,
    transparencyRange = 40, -- yards

    -- Иконки (глобальные правила фильтрации)
    classifEnabled = true,
    classifHideAllies = true,
    classifShowBossRareOnly = false,
    classifScale = 1.2,
    classifX = -70,
    classifY = 0,
    classifAlpha = 1,
    classifAnchor = "HpBar",
    classifMirror = true,
    
    
    -- Иконка фракции (Alliance/Horde)
    factionIconEnabled = true,
    factionIconOnlyPlayers = true,
    factionIconSize = 20,
    factionIconX = -73,
    factionIconY = 0,
    factionIconAlpha = 1,
    factionIconAnchor = "HpBar",
    factionIconStyle = 2,

    -- Quest objective icon
    questIconEnabled = true,
    questIconSize = 20,
    questIconX = -77,
    questIconY = 0,
    questIconAlpha = 1,
    questIconAnchor = "HpBar",

    -- Raid target icon
    raidTargetIconEnabled = true,
    raidTargetIconSize = 20,
    raidTargetIconX = 0,
    raidTargetIconY = 5,
    raidTargetIconAlpha = 1,
    raidTargetIconAnchor = "Name",

    -- Доп эффекты
    hideAbsorbGlow = true,
    hideHealPrediction = true,
    hideCastShield = true,

    classResourceEnabled = false,
    classResourceStyle = 1,
    classResourceOnlyInCombat = false,
    classResourceHideOnTransport = false,
    classResourceAnchorMode = 1,

    classResourceShowEmpty = true,
    classResourceReverseFill = false,
    classResourceWidth = 16,
    classResourceHeight = 8,
    classResourceSpacing = 2,
    classResourceOffsetX = 0,
    classResourceOffsetY = 0,
    classResourceInactiveAlpha = 0.3,

    classResourceModernScale = 1,
    classResourceModernSpacing = 0,
    classResourceModernOffsetX = 0,
    classResourceModernOffsetY = 0,
    classResourceModernInactiveAlpha = 0.3,

    rpSupportEnabled = false,
    tankModeEnable = false,
    tankModePlayerAggroColor = {r=1, g=0.65, b=0.15},
    tankModeOffTankColor = {r=1, g=0.1, b=0.1},
    -- Combat: immediate full refresh on entering combat (can cause CPU spike in mass pulls)
    forceUpdateAllOnCombat = true,

    -- UI: копирование профилей существ (состояние выпадающих списков)
    copyProfileSource = NS.UNIT_TYPES.FRIENDLY_PLAYER,
    copyProfileDest   = NS.UNIT_TYPES.ENEMY_PLAYER,
    copySec_HPBAR = false,
    copySec_NAME = false,
    copySec_GUILD = false,
    copySec_HPTEXT = false,
    copySec_LEVEL = false,
    copySec_TARGET = false,
    copySec_CASTBAR = false,
    copySec_BUFFS = false,
    copySec_DEBUFFS = false,
    copySec_CC = false,

    -- UI: профили (состояние выпадающих списков)
    profileCopySource = "Default",
    profileDeleteTarget = "Default",

}

-- 2. Настройки для каждого типа существ (Визуал)
-- Мы унифицировали имена переменных (например, просто healthColor, а не healthEnemyColor)
NS.DB.unitDefaults = {
    -- Активация вкладки
    enabled = true, 

    -- Геометрия
    plateWidth = 140,
    plateHeight = 8,

    -- Полоса здоровья (master-toggle для подвкладки)
    hpBarEnable = true,

    -- Полоса здоровья
    -- 1=Авто (игроки: класс, NPC: реакция), 2=Свой цвет, 3=Реакция (включая игроков)
    healthColorMode = 1,
    healthColor = {r=1, g=1, b=1}, -- Свой цвет (для вкладок без деления)

    -- Свой цвет (разделение для NPC)
    healthColorNeutral  = {r=1, g=1, b=1}, -- Нейтрал (атакуемый/неатакуемый)
    healthColorHostile  = {r=1, g=1, b=1}, -- Враждебный (EnemyNPC)
    healthColorFriendly = {r=1, g=1, b=1}, -- Союзник (FriendlyNPC)

    -- Имя
    nameEnable = true,
    nameDisableTargetScale = true,
    nameShowPlayerTitle = false,
    fontScale = 8,
    fontOutline = "SHADOW",
    textX = 0, textY = 5,
    textAlign = "CENTER",
    nameWordWrap = true,
    nameWrapWidth = 135,
    -- 1=Авто (игроки: класс, NPC: реакция), 2=Свой цвет, 3=Реакция (включая игроков)
    nameColorMode = 1,
    nameColor = {r=1, g=1, b=1}, -- Свой цвет (для вкладок без деления)

    -- Свой цвет (разделение для NPC)
    nameColorNeutral  = {r=1, g=1, b=1}, -- Нейтрал (атакуемый/неатакуемый)
    nameColorHostile  = {r=1, g=1, b=1}, -- Враждебный (EnemyNPC)
    nameColorFriendly = {r=1, g=1, b=1}, -- Союзник (FriendlyNPC)

    -- Friendly players: instance-only names mode (party/raid via Blizzard CVars)
    friendlyInstanceNamesEnable = false,
    friendlyInstanceNamesClassColor = true,
    friendlyInstanceNamesFontSize = 10,
    friendlyInstanceNamesFontOutline = "SHADOW",

    -- Текст гильдии
    guildTextEnable = false,
    guildTextMode = "UNDER_NAME",
    guildTextFontSize = 7,
    guildTextOutline = "SHADOW",
    guildTextX = 0, guildTextY = -2,
    guildTextAlign = "CENTER",
    guildTextWidth = 135,
    guildTextColor = {r=0.2, g=0.85, b=0.35},

    -- Текст ХП
    hpTextEnable = true,
    hpDisplayMode = "PERCENT",
    hpFontSize = 10,
    hpColorMode = 2, -- 1=Градиент, 2=Свой цвет
    hpColor = {r=1, g=1, b=1},
    hpFontOutline = "SHADOW",
    hpOffsetX = 0, hpOffsetY = 0.5,
    hpTextAlign = "RIGHT",

    -- Уровень
    levelEnable = true,
    levelFontSize = 10,
    levelFontOutline = "SHADOW",
    levelX = -2, levelY = 0.5,
    levelAnchor = "RIGHT",
    levelColorMode = 1, -- 1=Сложность, 2=Свой цвет
    levelColor = {r=1, g=1, b=1},

    -- Индикаторы (Target)
    -- Мастер-переключатель всей подвкладки "Индикация цели" (рамка + стрелка + символы + mouseover glow)
    targetIndicatorEnable = true,

    targetBorderEnabled = true,
    targetBorderColor = {r=0, g=1, b=0.95},
    
    targetIndicatorArrowEnable = false,
    targetIndicatorArrowAnim = false,
    targetIndicatorArrowSize = 30,
    targetIndicatorArrowX = 0, targetIndicatorArrowY = 20,
    targetIndicatorArrowColor = {r = 1, g = 1, b = 1},

    targetIndicatorSymbolEnable = false,
    targetIndicatorSymbolIndex = 1,
    targetIndicatorSymbolOutline = "OUTLINE",
    targetIndicatorSymbolSize = 15,
    targetIndicatorSymbolX = 5, targetIndicatorSymbolY = 0,
    targetIndicatorSymbolColor = {r = 1, g = 1, b = 1},
    
    mouseoverGlowEnable = true,
    mouseoverGlowAlpha = 0.5,
    mouseoverGlowColor = {r = 1, g = 1, b = 1},

    -- Кастбар
    cbEnabled = true,
    cbBarEnabled = true, -- отдельная галочка: только полоса применения
    cbWidth = 142, cbHeight = 8,
    cbX = 0, cbY = -1,
    cbIconEnabled = false, cbIconSize = 20, cbIconX = -3, cbIconY = 7,
    cbIconBorderEnable = false, cbIconBorderThickness = 2, cbIconBorderColor = {r=0, g=0, b=0, a=1},
    cbTextEnabled = true, cbTextJustify = "LEFT", cbTextOutline = "SHADOW", cbFontSize = 9,
    cbTextX = -3, cbTextY = 0.5, cbTextMaxLength = 0, cbTextColor = {r=1, g=1, b=1},
    cbTimerEnabled = false, cbTimerFormat = "%.0f", cbTimerOutline = "SHADOW", 
    cbTimerColor = {r=1, g=1, b=1}, cbTimerFontSize = 15, cbTimerX = 0, cbTimerY = 0,
    cbTargetEnabled = true, cbTargetJustify = "LEFT",
    cbTargetOutline = "SHADOW", cbTargetFontSize = 9, cbTargetX = -7, cbTargetY = -10,
    cbTargetMaxLength = 20, cbTargetMode = "CLASS", cbTargetColor = {r=1, g=1, b=1},

    -- Ауры
    aurasEnable = true,
    -- Превью аур (хранится в профиле типа существа, чтобы не захламлять все неймплейты)
    buffsPreview = false,
    debuffsPreview = false,
    ccPreview = false,
    buffsEnable = true,
    buffsSize = 20, buffsX = -5, buffsY = -15, buffsAlign = "RIGHT",
    buffsSpacing = 5, buffsIconHeight = 20, buffsTimerEdge = false, buffsTimerEnable = true, buffsStacksEnable = true,
    -- Враги: показывать только снимаемые/воруемые баффы (Purge/Spellsteal)
    -- Враги: подсветка баффов, которые можно снять/украсть (Purge/Spellsteal и аналоги)
    buffsPurgeGlow = false,
    -- Aura filters (single choice).
    -- Friendly RAID modes use Blizzard RAID filters. Friendly/Enemy IMPORTANT modes use Blizzard nameplate-important sets.
    buffsFriendlyFilterMode = "ALL", -- ALL|MINE|MINE_IMPORTANT|MINE_RAID|RAID|RAID_IN_COMBAT|BIG_DEFENSIVE|EXTERNAL_DEFENSIVE|BIG_OR_EXTERNAL_DEFENSIVE
    debuffsFriendlyFilterMode = "ALL", -- ALL|DISPEL|IMPORTANT|RAID|RAID_IN_COMBAT|IMPORTANT_AND_DISPEL|IMPORTANT_OR_DISPEL|RAID_AND_DISPEL|RAID_OR_DISPEL
    buffsEnemyFilterMode = "ALL", -- ALL|IMPORTANT|PURGE|IMPORTANT_AND_PURGE|IMPORTANT_OR_PURGE|BIG_DEFENSIVE|EXTERNAL_DEFENSIVE|BIG_OR_EXTERNAL_DEFENSIVE
    debuffsEnemyFilterMode = "ALL", -- ALL|IMPORTANT|MINE|MINE_AND_IMPORTANT


    
    buffsBorderEnable = true,
    buffsBorderThickness = 2,
    buffsBorderColor = {r=0, g=0, b=0, a=1},
    debuffsEnable = true,
    debuffsSize = 20, debuffsX = 0, debuffsY = 20, debuffsAlign = "CENTER",
    debuffsSpacing = 5, debuffsIconHeight = 20, debuffsTimerEdge = false, debuffsTimerEnable = true, debuffsStacksEnable = true,
    debuffsBorderEnable = true,
    debuffsBorderThickness = 2,
    debuffsBorderColor = {r=0, g=0, b=0, a=1},
    debuffsDispelGlow = false,
    ccEnable = true,
    ccSize = 25, ccX = 5, ccY = -15, ccAlign = "LEFT",
    ccSpacing = 5, ccIconHeight = 25, ccTimerEdge = false, ccTimerEnable = true, ccStacksEnable = true,
    ccBorderEnable = true,
    ccBorderThickness = 2,
    ccBorderColor = {r=0, g=0, b=0, a=1},
    ccOnlyMine = false,
    buffsPandemic = true,
    debuffsPandemic = true,
    ccPandemic = true,
    buffsNonTargetAlphaEnable = false,
    buffsNonTargetAlpha = 0.5,
    buffsNonTargetScaleEnable = false,
    buffsNonTargetScale = 0.85,
    debuffsNonTargetAlphaEnable = false,
    debuffsNonTargetAlpha = 0.5,
    debuffsNonTargetScaleEnable = false,
    debuffsNonTargetScale = 0.85,
    ccNonTargetAlphaEnable = false,
    ccNonTargetAlpha = 0.5,
    ccNonTargetScaleEnable = false,
    ccNonTargetScale = 0.85,
    -- Ауры: таймер/стаки (отдельно для BUFF/DEBUFF/CC)
    buffsTimeFontSize = 15, buffsTimeX = 0, buffsTimeY = 0, buffsTimeColor = {r=1, g=1, b=1},
    buffsStackFontSize = 10, buffsStackX = 2, buffsStackY = -2, buffsStackColor = {r=1, g=1, b=1},

    debuffsTimeFontSize = 15, debuffsTimeX = 0, debuffsTimeY = 0, debuffsTimeColor = {r=1, g=1, b=1},
    debuffsStackFontSize = 10, debuffsStackX = 2, debuffsStackY = -2, debuffsStackColor = {r=1, g=1, b=1},

    ccTimeFontSize = 15, ccTimeX = 0, ccTimeY = 0, ccTimeColor = {r=1, g=1, b=1},
    ccStackFontSize = 10, ccStackX = 2, ccStackY = -2, ccStackColor = {r=1, g=1, b=1},
}

local function IsFriendlyUnitType(unitType)
    return unitType == NS.UNIT_TYPES.FRIENDLY_PLAYER or unitType == NS.UNIT_TYPES.FRIENDLY_NPC
end

function NS.DB.NormalizeAuraFilterSettings(unitType, unitDB)
    if type(unitDB) ~= "table" then return end

    local function normalizeKey(key, valid)
        local value = unitDB[key]
        if value == nil then return end
        if not valid[value] then
            unitDB[key] = CopyValue(NS.DB.unitDefaults[key])
        end
    end

    normalizeKey("buffsFriendlyFilterMode", {
        ALL = true, MINE = true, MINE_IMPORTANT = true, MINE_RAID = true,
        RAID = true, RAID_IN_COMBAT = true, BIG_DEFENSIVE = true,
        EXTERNAL_DEFENSIVE = true, BIG_OR_EXTERNAL_DEFENSIVE = true,
    })

    normalizeKey("debuffsFriendlyFilterMode", {
        ALL = true, DISPEL = true, IMPORTANT = true, RAID = true,
        RAID_IN_COMBAT = true, IMPORTANT_AND_DISPEL = true,
        IMPORTANT_OR_DISPEL = true, RAID_AND_DISPEL = true,
        RAID_OR_DISPEL = true,
    })

    normalizeKey("buffsEnemyFilterMode", {
        ALL = true, IMPORTANT = true, PURGE = true, IMPORTANT_AND_PURGE = true,
        IMPORTANT_OR_PURGE = true, BIG_DEFENSIVE = true, EXTERNAL_DEFENSIVE = true,
        BIG_OR_EXTERNAL_DEFENSIVE = true,
    })

    normalizeKey("debuffsEnemyFilterMode", {
        ALL = true, IMPORTANT = true, MINE = true, MINE_AND_IMPORTANT = true,
    })

    if unitDB.ccOnlyMine == nil then
        unitDB.ccOnlyMine = CopyValue(NS.DB.unitDefaults.ccOnlyMine)
    elseif type(unitDB.ccOnlyMine) ~= "boolean" then
        unitDB.ccOnlyMine = false
    end
end

function NS.DB.Init()
    BlizzPlatesFixDB = BlizzPlatesFixDB or {}

    -- Profile containers (character-bound)
    BlizzPlatesFixDB.profileKeys = BlizzPlatesFixDB.profileKeys or {}
    BlizzPlatesFixDB.profiles = BlizzPlatesFixDB.profiles or {}

    -- Ensure Default exists
    BlizzPlatesFixDB.profiles["Default"] = BlizzPlatesFixDB.profiles["Default"] or { Global = {}, Units = {} }

    -- Ensure current character is bound to an existing profile
    local ck = NS.Config and NS.Config.GetCharKey and NS.Config.GetCharKey()
    if ck then
        local p = BlizzPlatesFixDB.profileKeys[ck] or "Default"
        if not BlizzPlatesFixDB.profiles[p] then p = "Default" end
        BlizzPlatesFixDB.profileKeys[ck] = p
    end

    -- Fill defaults for every profile
    for _, prof in pairs(BlizzPlatesFixDB.profiles) do
        prof.Global = prof.Global or {}
        for k, v in pairs(NS.DB.globalDefaults) do
            if prof.Global[k] == nil then
                prof.Global[k] = CopyValue(v)
            end
        end

        prof.Units = prof.Units or {}
        for _, unitType in pairs(NS.UNIT_TYPES) do
            prof.Units[unitType] = prof.Units[unitType] or {}
            for k, v in pairs(NS.DB.unitDefaults) do
                if prof.Units[unitType][k] == nil then
                    prof.Units[unitType][k] = CopyValue(v)
                end
            end
            NS.DB.NormalizeAuraFilterSettings(unitType, prof.Units[unitType])
        end
    end

    -- Bind legacy aliases to the active profile.
    -- Some helpers (e.g. CopySection/CopySections) still read BlizzPlatesFixDB.Global/Units.
    do
        local activeName = "Default"
        if NS.Config and NS.Config.GetActiveProfileName then
            activeName = NS.Config.GetActiveProfileName() or "Default"
        else
            local ck2 = NS.Config and NS.Config.GetCharKey and NS.Config.GetCharKey()
            if ck2 and type(BlizzPlatesFixDB.profileKeys) == "table" then
                activeName = BlizzPlatesFixDB.profileKeys[ck2] or "Default"
            end
        end

        local active = (type(BlizzPlatesFixDB.profiles) == "table") and BlizzPlatesFixDB.profiles[activeName] or nil
        if not active then active = BlizzPlatesFixDB.profiles["Default"] end
        if active then
            BlizzPlatesFixDB.Global = active.Global
            BlizzPlatesFixDB.Units  = active.Units
        end
    end
end


-- =====================================================================
-- Копирование профилей существ (по разделам)
-- =====================================================================

-- Правила копирования по разделам.
-- Примечание: для Полосы здоровья и Имени намеренно НЕ копируем настройки цвета
-- (по запросу пользователя: "Цвет полосы здоровья" и "Цвет имени").
NS.DB.CopySectionRules = {
    HPBAR = {
        mode = "keys",
        keys = { "hpBarEnable", "plateWidth", "plateHeight" },
    },
    NAME = {
        mode = "keys",
        keys = {
            "nameEnable",
            "nameDisableTargetScale",
            "nameShowPlayerTitle",
            "fontScale", "fontOutline",
            "textX", "textY", "textAlign",
            "nameWordWrap", "nameWrapWidth",
            "friendlyInstanceNamesEnable", "friendlyInstanceNamesClassColor",
            "friendlyInstanceNamesFontSize", "friendlyInstanceNamesFontOutline",
        },
    },
    GUILD = {
        mode = "keys",
        keys = {
            "guildTextEnable", "guildTextMode",
            "guildTextFontSize", "guildTextOutline",
            "guildTextX", "guildTextY", "guildTextAlign",
            "guildTextWidth", "guildTextColor",
        },
    },
    HPTEXT = {
        mode = "keys",
        keys = {
            "hpTextEnable",
            "hpDisplayMode",
            "hpFontSize",
            "hpColorMode", "hpColor",
            "hpFontOutline",
            "hpOffsetX", "hpOffsetY",
            "hpTextAlign",
        },
    },
    LEVEL = {
        mode = "keys",
        keys = {
            "levelEnable",
            "levelFontSize", "levelFontOutline",
            "levelX", "levelY", "levelAnchor",
            "levelColorMode", "levelColor",
        },
    },
    TARGET = {
        mode = "keys",
        keys = {
            "targetIndicatorEnable",
            "targetBorderEnabled", "targetBorderColor",
            "targetIndicatorArrowEnable", "targetIndicatorArrowAnim", "targetIndicatorArrowSize", "targetIndicatorArrowX", "targetIndicatorArrowY", "targetIndicatorArrowColor",
            "targetIndicatorSymbolEnable", "targetIndicatorSymbolIndex", "targetIndicatorSymbolOutline", "targetIndicatorSymbolSize", "targetIndicatorSymbolX", "targetIndicatorSymbolY", "targetIndicatorSymbolColor",
            "mouseoverGlowEnable", "mouseoverGlowAlpha", "mouseoverGlowColor",
        },
    },
    CASTBAR = {
        mode = "prefix",
        prefix = "cb",
    },
    BUFFS = {
        mode = "prefix",
        prefix = "buffs",
    },
    DEBUFFS = {
        mode = "prefix",
        prefix = "debuffs",
    },
    CC = {
        mode = "prefix",
        prefix = "cc",
    },
}

-- Динамические исключения для аур: чтобы при копировании между Friendly/Enemy
-- не перетирать настройки и фильтры, которые актуальны только для одной стороны.
local function BuildDynIgnore(sectionKey, fromType, toType)
    local fromFriendly = IsFriendlyUnitType(fromType)
    local toFriendly = IsFriendlyUnitType(toType)
    local crossSide = (fromFriendly ~= toFriendly)

    if sectionKey == "BUFFS" then
        local dynIgnore = { buffsPreview = true } -- настройки превью не копируем

        if crossSide then
            -- Между FRIENDLY/ENEMY не копируем никакие buff filter modes
            -- и enemy-only опции, чтобы не затирать релевантные настройки назначения.
            dynIgnore.buffsFriendlyFilterMode = true
            dynIgnore.buffsEnemyFilterMode = true
            dynIgnore.buffsPurgeGlow = true
        elseif toFriendly then
            -- FRIENDLY -> FRIENDLY: копируем только friendly-mode.
            dynIgnore.buffsEnemyFilterMode = true
            dynIgnore.buffsPurgeGlow = true
        else
            -- ENEMY -> ENEMY: копируем только enemy-mode.
            dynIgnore.buffsFriendlyFilterMode = true
        end

        return dynIgnore
    elseif sectionKey == "DEBUFFS" then
        local dynIgnore = { debuffsPreview = true } -- настройки превью не копируем

        if crossSide then
            -- Между FRIENDLY/ENEMY не копируем никакие debuff filter modes
            -- и side-only опции, чтобы не затирать релевантные настройки назначения.
            dynIgnore.debuffsFriendlyFilterMode = true
            dynIgnore.debuffsEnemyFilterMode = true
            dynIgnore.debuffsDispelGlow = true
        elseif toFriendly then
            -- FRIENDLY -> FRIENDLY: копируем только friendly-mode.
            dynIgnore.debuffsEnemyFilterMode = true
        else
            -- ENEMY -> ENEMY: копируем только enemy-mode.
            dynIgnore.debuffsFriendlyFilterMode = true
            dynIgnore.debuffsDispelGlow = true
        end

        return dynIgnore
    elseif sectionKey == "CC" then
        local dynIgnore = { ccPreview = true } -- настройки превью не копируем

        -- ccOnlyMine релевантен только для ENEMY и не должен приходить из FRIENDLY.
        if crossSide or toFriendly then
            dynIgnore.ccOnlyMine = true
        end

        return dynIgnore
    end

    return nil
end

-- Копирует выбранный раздел из одного типа существа в другой.
-- sectionKey: "HPBAR"|"NAME"|"GUILD"|"HPTEXT"|"LEVEL"|"TARGET"|"CASTBAR"|"BUFFS"|"DEBUFFS"|"CC"
function NS.DB.CopySection(fromType, toType, sectionKey)
    if not BlizzPlatesFixDB or not BlizzPlatesFixDB.Units then return false, "db_not_ready" end
    if not fromType or not toType or fromType == toType then return false, "bad_types" end
    local source = BlizzPlatesFixDB.Units[fromType]
    local dest = BlizzPlatesFixDB.Units[toType]
    if not source or not dest then return false, "missing_profile" end

    local rule = NS.DB.CopySectionRules and NS.DB.CopySectionRules[sectionKey]
    if not rule then return false, "bad_section" end

    local dynIgnore = BuildDynIgnore(sectionKey, fromType, toType)

    if rule.mode == "keys" and rule.keys then
        for _, k in ipairs(rule.keys) do
            if source[k] ~= nil then
                dest[k] = CopyValue(source[k])
            end
        end
    elseif rule.mode == "prefix" and rule.prefix then
        local p = rule.prefix
        for k, v in pairs(source) do
            if type(k) == "string" and k:sub(1, #p) == p then
                if not (dynIgnore and dynIgnore[k]) then
                    dest[k] = CopyValue(v)
                end
            end
        end
    else
        return false, "bad_rule"
    end

    NS.DB.NormalizeAuraFilterSettings(toType, dest)

    -- Принудительное обновление неймплейтов после копирования
    if NS.RequestUpdateAll then
        NS.RequestUpdateAll("copy_section:" .. tostring(sectionKey), true)
    elseif NS.ForceUpdateAll then
        NS.ForceUpdateAll()
    end

    return true
end

-- Копирует несколько разделов за один раз и вызывает обновление только один раз.
-- sectionKeys: массив из "HPBAR"|"NAME"|"GUILD"|...
function NS.DB.CopySections(fromType, toType, sectionKeys)
    if type(sectionKeys) ~= "table" then
        return NS.DB.CopySection(fromType, toType, tostring(sectionKeys))
    end
    if not BlizzPlatesFixDB or not BlizzPlatesFixDB.Units then return false, "db_not_ready" end
    if not fromType or not toType or fromType == toType then return false, "bad_types" end
    local source = BlizzPlatesFixDB.Units[fromType]
    local dest = BlizzPlatesFixDB.Units[toType]
    if not source or not dest then return false, "missing_profile" end

    local any = false
    for _, sectionKey in ipairs(sectionKeys) do
        local rule = NS.DB.CopySectionRules and NS.DB.CopySectionRules[sectionKey]
        if rule then
            local dynIgnore = BuildDynIgnore(sectionKey, fromType, toType)

            if rule.mode == "keys" and rule.keys then
                for _, k in ipairs(rule.keys) do
                    if source[k] ~= nil then
                        dest[k] = CopyValue(source[k])
                        any = true
                    end
                end
            elseif rule.mode == "prefix" and rule.prefix then
                local pfx = rule.prefix
                for k, v in pairs(source) do
                    if type(k) == "string" and k:sub(1, #pfx) == pfx then
                        if not (dynIgnore and dynIgnore[k]) then
                            dest[k] = CopyValue(v)
                            any = true
                        end
                    end
                end
            end
        end
    end

    NS.DB.NormalizeAuraFilterSettings(toType, dest)

    if any then
        if NS.RequestUpdateAll then
            NS.RequestUpdateAll("copy_sections", true)
        elseif NS.ForceUpdateAll then
            NS.ForceUpdateAll()
        end
    end

    return any
end

-- Функция копирования профиля (из одной вкладки в другую)
function NS.DB.CopyProfile(fromType, toType)
    if not BlizzPlatesFixDB.Units[fromType] or not BlizzPlatesFixDB.Units[toType] then return end
    
    local source = BlizzPlatesFixDB.Units[fromType]
    local dest = BlizzPlatesFixDB.Units[toType]
    
    -- Ключи, которые НЕ копируем (имя, цвет полос - как ты просил)
    local ignore = {
        enabled = true,
        healthColorMode = true, healthColor = true,
        healthColorNeutral = true, healthColorHostile = true, healthColorFriendly = true,
        nameColorMode = true, nameColor = true,
        nameColorNeutral = true, nameColorHostile = true, nameColorFriendly = true,
    }

    for k, v in pairs(source) do
        if not ignore[k] then
            dest[k] = CopyValue(v)
        end
    end

    NS.DB.NormalizeAuraFilterSettings(toType, dest)

    if NS.ForceUpdateAll then NS.ForceUpdateAll() end
end
