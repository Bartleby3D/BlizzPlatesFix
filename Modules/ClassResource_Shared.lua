local _, NS = ...

local CR = NS.ClassResourceInternal or {}
NS.ClassResourceInternal = CR

local EnumPowerType = _G.Enum and _G.Enum.PowerType or {}

CR.floor = math.floor
CR.max = math.max
CR.min = math.min
CR.abs = math.abs

CR.EMPTY_SLOT_ALPHA = 0.25

CR.STYLE_CUSTOM = 1
CR.STYLE_MODERN = 2

CR.POWER_COMBO_POINTS  = EnumPowerType.ComboPoints   or 4
CR.POWER_RUNES         = EnumPowerType.Runes         or 5
CR.POWER_SOUL_SHARDS   = EnumPowerType.SoulShards    or 7
CR.POWER_HOLY_POWER    = EnumPowerType.HolyPower     or 9
CR.POWER_CHI           = EnumPowerType.Chi           or 12
CR.POWER_ARCANE_CHARGE = EnumPowerType.ArcaneCharges or 16
CR.POWER_ESSENCE       = EnumPowerType.Essence       or 19

CR.SPECID_ARCANE_MAGE = 62
CR.SPECID_WINDWALKER_MONK = 269
CR.SPECID_BLOOD_DK = 250
CR.SPECID_FROST_DK = 251
CR.SPECID_UNHOLY_DK = 252
CR.CAT_FORM_ID = 1

CR.MODERN_SKINS = CR.MODERN_SKINS or {
    -- Modern atlas sets for non-rune resources.
    -- Required: bgAtlas, fillAtlas.
    -- Optional: baseWidth, baseHeight, insetX, insetY.
    -- Soul Shards and Essence use the same atlas pair for empty/full and partial recharge.
    -- Death Knight runes are configured separately in CR.MODERN_RUNE_SKINS.

    [CR.POWER_COMBO_POINTS] = {
        bgAtlas = "ComboPoints-PointBg",
        fillAtlas = "ComboPoints-ComboPoint",
        baseWidth = 15,
        baseHeight = 15,
        insetX = 0,
        insetY = 0,
    },

    [CR.POWER_CHI] = {
        bgAtlas = "widget-roguecp-bg",
        fillAtlas = "widget-roguecp-icon-blue",
        baseWidth = 15,
        baseHeight = 15,
        insetX = 0,
        insetY = 0,
    },

    [CR.POWER_HOLY_POWER] = {
        bgAtlas = "ClassOverlay-HolyPower3off",
        fillAtlas = "ClassOverlay-HolyPower3on",
        baseWidth = 15,
        baseHeight = 15,
        insetX = 0,
        insetY = 0,
    },

    [CR.POWER_ARCANE_CHARGE] = {
        bgAtlas = "UF-Arcane-BG",
        fillAtlas = "UF-Arcane-Icon",
        baseWidth = 10,
        baseHeight = 10,
        insetX = 0,
        insetY = 0,
    },

    [CR.POWER_SOUL_SHARDS] = {
        bgAtlas = "Warlock-EmptyShard",
        fillAtlas = "Warlock-ReadyShard",
        baseWidth = 12,
        baseHeight = 15,
        insetX = 0,
        insetY = 0,
    },

    [CR.POWER_ESSENCE] = {
        bgAtlas = "UF-Essence-BG-Active",
        fillAtlas = "UF-Essence-Icon",
        baseWidth = 15,
        baseHeight = 15,
        insetX = 0,
        insetY = 0,
    },

}

CR.MODERN_RUNE_SKINS = CR.MODERN_RUNE_SKINS or {
    -- Spec-based Modern atlas sets for Death Knight runes.
    [CR.SPECID_BLOOD_DK] = {
        bgAtlas = "DK-Rune-CD",
        fillAtlas = "DK-Blood-Rune-Ready",
        baseWidth = 15,
        baseHeight = 15,
        insetX = 0,
        insetY = 0,
        skinKey = "RUNES_BLOOD",
    },
    [CR.SPECID_FROST_DK] = {
        bgAtlas = "DK-Rune-CD",
        fillAtlas = "DK-Frost-Rune-Ready",
        baseWidth = 15,
        baseHeight = 15,
        insetX = 0,
        insetY = 0,
        skinKey = "RUNES_FROST",
    },
    [CR.SPECID_UNHOLY_DK] = {
        bgAtlas = "DK-Rune-CD",
        fillAtlas = "DK-Unholy-Rune-Ready",
        baseWidth = 15,
        baseHeight = 15,
        insetX = 0,
        insetY = 0,
        skinKey = "RUNES_UNHOLY",
    },
}

function CR.GetPlayerSpecID()
    local specIndex = GetSpecialization and GetSpecialization()
    if not specIndex or specIndex <= 0 then return nil end
    return GetSpecializationInfo and GetSpecializationInfo(specIndex)
end

function CR.GetModernSkinKey(powerType, skin)
    if powerType == CR.POWER_RUNES and skin and skin.skinKey then
        return skin.skinKey
    end
    return powerType
end

function CR.GetConfiguredStyle(gdb)
    local style = gdb and tonumber(gdb.classResourceStyle) or CR.STYLE_CUSTOM
    if style ~= CR.STYLE_MODERN then
        style = CR.STYLE_CUSTOM
    end
    return style
end

function CR.GetModernSkin(powerType)
    local skin

    if powerType == CR.POWER_RUNES then
        local specID = CR.GetPlayerSpecID and CR.GetPlayerSpecID()
        local runeSkins = CR.MODERN_RUNE_SKINS
        skin = runeSkins and specID and runeSkins[specID]
    else
        local skins = CR.MODERN_SKINS
        skin = skins and skins[powerType]
    end

    if not skin then return nil end
    if not skin.bgAtlas or not skin.fillAtlas then return nil end
    return skin
end

function CR.GetEffectiveRenderStyle(style, powerType)
    if style == CR.STYLE_MODERN and CR.GetModernSkin(powerType) then
        return CR.STYLE_MODERN
    end
    return CR.STYLE_CUSTOM
end

CR.State = CR.State or setmetatable({}, { __mode = "k" })

CR.COLORS = CR.COLORS or {
    [CR.POWER_COMBO_POINTS]  = { 0.95, 0.22, 0.22 },
    [CR.POWER_RUNES]         = { 0.79, 0.24, 0.24 },
    [CR.POWER_SOUL_SHARDS]   = { 0.48, 0.31, 0.82 },
    [CR.POWER_HOLY_POWER]    = { 0.91, 0.77, 0.29 },
    [CR.POWER_CHI]           = { 0.27, 0.78, 0.47 },
    [CR.POWER_ARCANE_CHARGE] = { 0.42, 0.36, 1.00 },
    [CR.POWER_ESSENCE]       = { 0.31, 0.66, 0.85 },
}

local _, PLAYER_CLASS = UnitClass("player")
CR.PLAYER_CLASS = PLAYER_CLASS

CR.CLASS_RESOURCE_PRIORITY = CR.CLASS_RESOURCE_PRIORITY or {
    ROGUE = CR.POWER_COMBO_POINTS,
    PALADIN = CR.POWER_HOLY_POWER,
    WARLOCK = CR.POWER_SOUL_SHARDS,
    DEATHKNIGHT = CR.POWER_RUNES,
    EVOKER = CR.POWER_ESSENCE,
}

CR.ActiveRuneFrame = nil
CR.ActiveRuneState = nil
CR.RuneTaskRegistered = false
CR.ActiveTimedFrame = nil
CR.ActiveTimedState = nil
CR.TimedTaskRegistered = false

CR.EssenceState = CR.EssenceState or {
    lastCurrent = nil,
    nextTick = nil,
}

CR.RUNE_REORDER_EPSILON = 0.15

CR.CachedSpecID = nil
CR.CachedRuneColor = CR.CachedRuneColor or { r = 0, g = 0, b = 0 }

function CR.ClearActiveRuneTarget(frame)
    if frame and CR.ActiveRuneFrame ~= frame then return end
    CR.ActiveRuneFrame = nil
    CR.ActiveRuneState = nil
    if NS.Engine and NS.Engine.EnableFastTask then
        NS.Engine.EnableFastTask("classresource_runes", false)
    end
end

function CR.ClearActiveTimedTarget(frame)
    if frame and CR.ActiveTimedFrame ~= frame then return end
    CR.ActiveTimedFrame = nil
    CR.ActiveTimedState = nil
    if NS.Engine and NS.Engine.EnableFastTask then
        NS.Engine.EnableFastTask("classresource_dynamic", false)
    end
end

function CR.GetState(frame)
    local st = CR.State[frame]
    if st then return st end

    st = {
        inited = false,
        slots = {},
        lastShown = false,
        lastWidth = nil,
        lastHeight = nil,
        lastSpacing = nil,
        lastOffX = nil,
        lastOffY = nil,
        lastResource = nil,
        lastCount = nil,
        lastMax = nil,
        lastShowEmpty = nil,
        lastInactiveAlpha = nil,
        lastReverseFill = nil,
        lastStyle = nil,
        lastRenderStyle = nil,
        lastSkinKey = nil,
        lastColorKey = nil,
        runeDisplayOrder = nil,
        runeSnapshot = nil,
        runeHasCooldown = false,
        essenceLastCurrent = nil,
        essenceNextTick = nil,
        dynamicActive = false,
    }

    CR.State[frame] = st
    return st
end

function CR.HideAll(frame, st)
    st = st or CR.GetState(frame)
    st.runeDisplayOrder = nil
    st.runeSnapshot = nil
    st.runeHasCooldown = false
    st.dynamicActive = false

    CR.ClearActiveRuneTarget(frame)
    CR.ClearActiveTimedTarget(frame)

    local holder = frame and frame.BPF_ClassResourceHolder
    if holder then holder:Hide() end

    for i = 1, #(st.slots or {}) do
        local slot = st.slots[i]
        if slot then
            slot:Hide()
            slot.visualState = nil
            slot.fillMode = nil
            slot.fillReverse = nil
        end
    end

    st.lastShown = false
    st.lastCount = nil
    st.lastMax = nil
    st.lastResource = nil
    st.lastReverseFill = nil
    st.lastStyle = nil
    st.lastRenderStyle = nil
    st.lastSkinKey = nil
    st.lastColorKey = nil
end
