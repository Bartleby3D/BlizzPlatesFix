local _, NS = ...

-- Spell IDs для проверки дистанции (Твой список)
local SPELLS = {
    ["WARRIOR"] = {
        enemy  = 355,    -- Taunt (30m)
        friend = 147833, -- Intervene (25m)
    },
    ["PALADIN"] = {
        enemy  = 62124,  -- Hand of Reckoning (30m)
        friend = 19750,  -- Flash of Light (40m)
    },
    ["HUNTER"] = {
        enemy  = 185350, -- Arcane Shot (40m)
        friend = 34477,  -- Misdirection (40m)
    },
    ["ROGUE"] = {
        enemy  = 185565, -- Poisoned Knife (30m)
        friend = nil,
    },
    ["PRIEST"] = {
        enemy  = 585,    -- Smite (40m)
        friend = 2061,   -- Flash Heal (40m)
    },
    ["DEATHKNIGHT"] = {
        enemy  = 47541,  -- Death Coil (30m)
        friend = nil,
    },
    ["SHAMAN"] = {
        enemy  = 188196, -- Lightning Bolt (40m)
        friend = 8004,   -- Healing Surge (40m)
    },
    ["MAGE"] = {
        enemy  = 116,    -- Frostbolt (40m)
        friend = 475,    -- Remove Curse (40m)
    },
    ["WARLOCK"] = {
        enemy  = 686,    -- Shadow Bolt (40m)
        friend = 5697,   -- Unending Breath (40m)
    },
    ["MONK"] = {
        enemy  = 117952, -- Crackling Jade Lightning (40m)
        friend = 116670, -- Vivify (40m)
    },
    ["DRUID"] = {
        enemy  = 5176,   -- Wrath (40m)
        friend = 8936,   -- Regrowth (40m)
    },
    ["DEMONHUNTER"] = {
        enemy  = 185123, -- Throw Glaive (30m)
        friend = nil,
    },
    ["EVOKER"] = {
        enemy  = 361469, -- Living Flame (25-30m)
        friend = 361469, -- Living Flame (25-30m)
    },
}

local _, playerClass = UnitClass("player")

-- Кэш на фрейм (weak keys)
local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        lastAlpha = nil,

        -- range cache
        lastRangeCheckT = 0,
        lastOutOfRange = false,
        lastRangeUnit = nil,
        lastSpellID = nil,
    }
    State[frame] = st
    return st
end

local RANGE_TTL = 0.20
local ALPHA_EPS = 0.005 -- допуск для float

-- ВАЖНО: сравниваем не только с lastAlpha, но и с реальным frame:GetAlpha()
local function ApplyAlpha(frame, st, alpha)
    local current = frame:GetAlpha() or 1
    if st.lastAlpha ~= alpha or math.abs(current - alpha) > ALPHA_EPS then
        frame:SetAlpha(alpha)
        st.lastAlpha = alpha
    end
end

local function IsOutOfRange(unit, st)
    local classSpells = SPELLS[playerClass]
    if not classSpells then return false end

    local isEnemy = UnitCanAttack("player", unit)
    local spellID = isEnemy and classSpells.enemy or classSpells.friend
    if not spellID then return false end
    if not IsPlayerSpell(spellID) then return false end

    local now = GetTime()
    if st.lastRangeUnit == unit and st.lastSpellID == spellID and (now - st.lastRangeCheckT) < RANGE_TTL then
        return st.lastOutOfRange
    end

    st.lastRangeUnit = unit
    st.lastSpellID = spellID
    st.lastRangeCheckT = now

    local inRange = C_Spell.IsSpellInRange(spellID, unit)

    -- 0/false = точно далеко
    -- nil = обычно "невозможно проверить" => считаем "не далеко"
    local out = (inRange == 0 or inRange == false) and true or false
    st.lastOutOfRange = out
    return out
end

-- ВНИМАНИЕ: Используем gdb (Глобальные настройки)
local function UpdateTransparency(frame, unit, db, gdb)
    if not frame or frame:IsForbidden() or not unit then return end
    if not gdb then return end -- Настройки прозрачности глобальные

    local st = GetState(frame)

    -- выключено
    if not gdb.transparencyEnabled then
        ApplyAlpha(frame, st, 1)
        return
    end

    -- цель всегда яркая
    if UnitIsUnit(unit, "target") then
        ApplyAlpha(frame, st, 1)
        return
    end

    local mode = gdb.transparencyMode or 1
    local aSetting = gdb.transparencyAlpha or 0.5
    if aSetting < 0 then aSetting = 0 end
    if aSetting > 1 then aSetting = 1 end

    local alpha = 1

    if mode == 1 then
        alpha = aSetting
    else
        alpha = IsOutOfRange(unit, st) and aSetting or 1
    end

    ApplyAlpha(frame, st, alpha)
end

NS.Modules.Transparency = {
    Update = function(frame, unit, db, gdb)
        UpdateTransparency(frame, unit, db, gdb)
    end,
    Reset = function(frame)
        local st = GetState(frame)
        ApplyAlpha(frame, st, 1)
    end
}