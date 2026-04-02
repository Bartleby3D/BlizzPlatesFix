local _, NS = ...

-- ============================================================================
-- 1. PANDEMIC TIMER COLOR
-- ============================================================================

local State = setmetatable({}, { __mode = "k" })
local StopAuraHighlight
local TrackPandemicIcon
local UntrackPandemicIcon
local ApplyAuraHighlightLayout

local function HideAuraIcon(icon)
    if not icon then return end
    if StopAuraHighlight then
        StopAuraHighlight(icon)
    end
    icon:Hide()
end

local function GetState(frame)
    if not State[frame] then
        -- ДОБАВЛЕН ТРЕТИЙ ПУЛ: cc
        State[frame] = {
            buffs = {},
            debuffs = {},
            cc = {},
        }
    end
    return State[frame]
end

local function HideAuraPools(frame)
    local st = GetState(frame)
    for _, icon in ipairs(st.buffs) do HideAuraIcon(icon) end
    for _, icon in ipairs(st.debuffs) do HideAuraIcon(icon) end
    for _, icon in ipairs(st.cc) do HideAuraIcon(icon) end
end

local PixelSnapValue = NS.PixelSnapValue
local PixelSnapSetSize = NS.PixelSnapSetSize
local PixelSnapSetPoint = NS.PixelSnapSetPoint

-- ==========================================================================
-- IMPORTANT AURAS (Blizzard nameplate filters)
-- ==========================================================================
-- Goal: for enemy units, be able to show only "important" auras that Blizzard
-- itself would display on nameplates, while still using our own rendering.
--
-- We avoid spellId/sourceUnit checks (can be secret/tainted in 12.0+). Instead
-- we intersect by auraInstanceID with Blizzard's own AurasFrame lists.
local _BPF_SharedBlizzardAuraSet = {}
local _BPF_SharedNameplateOnlyAuraSet = {}

local function BuildBlizzardNameplateAuraSet(frame, kind)
    local af = frame and frame.AurasFrame
    if not af then return nil end

    local list = nil
    if kind == "BUFF" then
        list = af.buffList
    elseif kind == "DEBUFF" then
        list = af.debuffList
    end
    if not list or type(list.Iterate) ~= "function" then return nil end

    wipe(_BPF_SharedBlizzardAuraSet)
    local ok = pcall(list.Iterate, list, function(auraInstanceID)
        if auraInstanceID then _BPF_SharedBlizzardAuraSet[auraInstanceID] = true end
    end)
    if ok then
        return _BPF_SharedBlizzardAuraSet
    end
    return nil
end

local function BuildNameplateOnlyAuraSet(unit, filter)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then return nil end
    local ids = C_UnitAuras.GetUnitAuraInstanceIDs(unit, filter)
    if not ids then return nil end
    wipe(_BPF_SharedNameplateOnlyAuraSet)
    for _, auraInstanceID in ipairs(ids) do
        _BPF_SharedNameplateOnlyAuraSet[auraInstanceID] = true
    end
    return _BPF_SharedNameplateOnlyAuraSet
end

-- ============================================================================
-- 1.5. TEXT STYLING (таймер Cooldown + стаки)
-- ============================================================================
local function GetCooldownFontString(cd)
    if not cd then return nil end
    if cd._BPF_CooldownText and cd._BPF_CooldownText.GetObjectType then
        return cd._BPF_CooldownText
    end

    local n = select("#", cd:GetRegions())
    for i = 1, n do
        local r = select(i, cd:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == "FontString" then
            cd._BPF_CooldownText = r
            return r
        end
    end
    return nil
end

local PANDEMIC_TASK_NAME = "auras_pandemic_timer_color"
local PANDEMIC_TIMER_INTERVAL = 0.10
local HIGHLIGHT_GOLD_R, HIGHLIGHT_GOLD_G, HIGHLIGHT_GOLD_B, HIGHLIGHT_GOLD_A = 1.00, 0.95, 0.20, 1.00
local HIGHLIGHT_RED_R, HIGHLIGHT_RED_G, HIGHLIGHT_RED_B, HIGHLIGHT_RED_A = 1.00, 0.18, 0.18, 1.00
local PANDEMIC_RED_R, PANDEMIC_RED_G, PANDEMIC_RED_B, PANDEMIC_RED_A = 1.00, 0.18, 0.18, 1.00

local EnemyBuffDispelColorMap = {
    ["Magic"] = CreateColor(HIGHLIGHT_GOLD_R, HIGHLIGHT_GOLD_G, HIGHLIGHT_GOLD_B, HIGHLIGHT_GOLD_A),
    ["Curse"] = CreateColor(HIGHLIGHT_GOLD_R, HIGHLIGHT_GOLD_G, HIGHLIGHT_GOLD_B, HIGHLIGHT_GOLD_A),
    ["Disease"] = CreateColor(HIGHLIGHT_GOLD_R, HIGHLIGHT_GOLD_G, HIGHLIGHT_GOLD_B, HIGHLIGHT_GOLD_A),
    ["Poison"] = CreateColor(HIGHLIGHT_GOLD_R, HIGHLIGHT_GOLD_G, HIGHLIGHT_GOLD_B, HIGHLIGHT_GOLD_A),
    [""] = CreateColor(HIGHLIGHT_RED_R, HIGHLIGHT_RED_G, HIGHLIGHT_RED_B, HIGHLIGHT_RED_A),
    ["Bleed"] = CreateColor(HIGHLIGHT_GOLD_R, HIGHLIGHT_GOLD_G, HIGHLIGHT_GOLD_B, HIGHLIGHT_GOLD_A),
}

local EnemyBuffDispelCurve
if C_CurveUtil then
    EnemyBuffDispelCurve = C_CurveUtil.CreateColorCurve()
    EnemyBuffDispelCurve:SetType(Enum.LuaCurveType.Step)
    EnemyBuffDispelCurve:AddPoint(0, CreateColor(0, 0, 0, 0))
    EnemyBuffDispelCurve:AddPoint(1, EnemyBuffDispelColorMap["Magic"])
    EnemyBuffDispelCurve:AddPoint(2, EnemyBuffDispelColorMap["Curse"])
    EnemyBuffDispelCurve:AddPoint(3, EnemyBuffDispelColorMap["Disease"])
    EnemyBuffDispelCurve:AddPoint(4, EnemyBuffDispelColorMap["Poison"])
    EnemyBuffDispelCurve:AddPoint(5, CreateColor(0, 0, 0, 0))
    EnemyBuffDispelCurve:AddPoint(9, EnemyBuffDispelColorMap[""])
    EnemyBuffDispelCurve:AddPoint(10, CreateColor(0, 0, 0, 0))
    EnemyBuffDispelCurve:AddPoint(11, EnemyBuffDispelColorMap["Bleed"])
end
local PandemicIcons = setmetatable({}, { __mode = "k" })
local PandemicIconsCount = 0
local PandemicTaskRegistered = false

local function SetCooldownTextColor(icon, r, g, b, a)
    local cdText = icon and icon.cd and GetCooldownFontString(icon.cd)
    if cdText then
        cdText:SetTextColor(r or 1, g or 1, b or 1, a or 1)
    end
end

local function BuildPandemicColorCurve(r, g, b, a)
    if not (C_CurveUtil and C_CurveUtil.CreateColorCurve and CreateColor) then return nil end

    local curve = C_CurveUtil.CreateColorCurve()
    curve:SetType(Enum.LuaCurveType.Step)
    curve:AddPoint(0.00, CreateColor(PANDEMIC_RED_R, PANDEMIC_RED_G, PANDEMIC_RED_B, PANDEMIC_RED_A))
    curve:AddPoint(0.25, CreateColor(r or 1, g or 1, b or 1, a or 1))
    return curve
end

local function ApplyBaseCooldownTextColor(icon, color)
    local r, g, b, a = 1, 1, 1, 1
    if type(color) == "table" then
        r = color.r or 1
        g = color.g or 1
        b = color.b or 1
        a = color.a or 1
    end

    local changed = (icon._BPF_BaseTimeColorR ~= r)
        or (icon._BPF_BaseTimeColorG ~= g)
        or (icon._BPF_BaseTimeColorB ~= b)
        or (icon._BPF_BaseTimeColorA ~= a)

    icon._BPF_BaseTimeColorR = r
    icon._BPF_BaseTimeColorG = g
    icon._BPF_BaseTimeColorB = b
    icon._BPF_BaseTimeColorA = a

    if changed or not icon._BPF_PandemicColorCurve then
        icon._BPF_PandemicColorCurve = BuildPandemicColorCurve(r, g, b, a)
    end

    SetCooldownTextColor(icon, r, g, b, a)
end

local function RestoreCooldownTextColor(icon)
    if not icon then return end
    SetCooldownTextColor(
        icon,
        icon._BPF_BaseTimeColorR or 1,
        icon._BPF_BaseTimeColorG or 1,
        icon._BPF_BaseTimeColorB or 1,
        icon._BPF_BaseTimeColorA or 1
    )
end

local function SetPandemicTaskEnabled(enabled)
    if NS.Engine and NS.Engine.EnableFastTask then
        NS.Engine.EnableFastTask(PANDEMIC_TASK_NAME, enabled and PandemicIconsCount > 0)
    end
end

local function ApplyPandemicCurveColor(icon, pandemicColor)
    if pandemicColor and pandemicColor.GetRGBA then
        SetCooldownTextColor(icon, pandemicColor:GetRGBA())
    else
        RestoreCooldownTextColor(icon)
    end
end

local function UpdatePandemicTimerColor(icon, durationInfo)
    local colorCurve = icon and icon._BPF_PandemicColorCurve or nil
    if not (icon and durationInfo and colorCurve) then
        RestoreCooldownTextColor(icon)
        return
    end

    ApplyPandemicCurveColor(icon, durationInfo:EvaluateRemainingPercent(colorCurve))
end

local function UpdatePreviewPandemicTimerColor(icon, remaining, duration)
    local colorCurve = icon and icon._BPF_PandemicColorCurve or nil
    if not (icon and colorCurve and duration and duration > 0 and remaining) then
        RestoreCooldownTextColor(icon)
        return
    end

    local percent = remaining / duration
    if percent < 0 then
        percent = 0
    elseif percent > 1 then
        percent = 1
    end

    if colorCurve.Evaluate then
        ApplyPandemicCurveColor(icon, colorCurve:Evaluate(percent))
    else
        RestoreCooldownTextColor(icon)
    end
end

local function PandemicFastTick()
    local stale

    for icon in pairs(PandemicIcons) do
        local durationInfo = icon and icon._BPF_PandemicDurationInfo or nil
        local valid = icon
            and icon:IsShown()
            and icon.cd
            and icon.cd:IsShown()
            and durationInfo
            and icon._BPF_PandemicColorCurve

        if valid then
            UpdatePandemicTimerColor(icon, durationInfo)
        else
            stale = stale or {}
            stale[#stale + 1] = icon
        end
    end

    if stale then
        for i = 1, #stale do
            UntrackPandemicIcon(stale[i])
        end
    end
end

local function RegisterPandemicFastTask()
    if PandemicTaskRegistered then return end
    if not (NS.Engine and NS.Engine.RegisterFastTask and NS.Engine.EnableFastTask) then return end

    NS.Engine.RegisterFastTask(PANDEMIC_TASK_NAME, PANDEMIC_TIMER_INTERVAL, PandemicFastTick)
    NS.Engine.EnableFastTask(PANDEMIC_TASK_NAME, false)
    PandemicTaskRegistered = true
end

TrackPandemicIcon = function(icon, durationInfo)
    if not (icon and durationInfo and C_CurveUtil and C_CurveUtil.CreateColorCurve) then
        UntrackPandemicIcon(icon)
        return
    end

    if not PandemicTaskRegistered then
        RegisterPandemicFastTask()
    end

    icon._BPF_PandemicDurationInfo = durationInfo

    if not PandemicIcons[icon] then
        PandemicIcons[icon] = true
        PandemicIconsCount = PandemicIconsCount + 1
    end

    UpdatePandemicTimerColor(icon, durationInfo)
    SetPandemicTaskEnabled(true)
end

UntrackPandemicIcon = function(icon)
    if not icon then return end

    icon._BPF_PandemicDurationInfo = nil
    if PandemicIcons[icon] then
        PandemicIcons[icon] = nil
        PandemicIconsCount = math.max(0, PandemicIconsCount - 1)
    end

    RestoreCooldownTextColor(icon)
    SetPandemicTaskEnabled(true)
end


local function ApplyIconRect(icon, width, height)
    if not icon or not icon.tex or not width or not height then return end

    PixelSnapSetSize(icon, width, height, 1, 1)

    if icon.AuraHighlightBorder then
        ApplyAuraHighlightLayout(icon)
    end

    -- Сохраняем квадратную картинку без растяжения: режем TexCoord под прямоугольник
    local baseMin, baseMax = 0.08, 0.92
    local span = baseMax - baseMin

    if height == width then
        icon.tex:SetTexCoord(baseMin, baseMax, baseMin, baseMax)
        return
    end

    if height < width then
        local ratio = height / width
        local pad = (1 - ratio) / 2
        local y1 = baseMin + span * pad
        local y2 = baseMax - span * pad
        icon.tex:SetTexCoord(baseMin, baseMax, y1, y2)
    else
        local ratio = width / height
        local pad = (1 - ratio) / 2
        local x1 = baseMin + span * pad
        local x2 = baseMax - span * pad
        icon.tex:SetTexCoord(x1, x2, baseMin, baseMax)
    end
end

local function ApplyAuraTextStyle(icon, fontPath, timeSize, timeX, timeY, timeColor, stackSize, stackX, stackY, stackColor)
    if not icon then return end

    -- Таймер: используем встроенные цифры Cooldown (без математики с secret values)
    local cdText = GetCooldownFontString(icon.cd)
    if cdText then
        local _, _, flags = cdText:GetFont()
        cdText:SetFont(fontPath, timeSize, flags)
        cdText:ClearAllPoints()
        PixelSnapSetPoint(cdText, "CENTER", icon.cd, "CENTER", timeX, timeY, 0, 0)
        ApplyBaseCooldownTextColor(icon, timeColor)
    end

    -- Стаки
    if icon.count then
        local _, _, flags = icon.count:GetFont()
        icon.count:SetFont(fontPath, stackSize, flags)
        icon.count:ClearAllPoints()
        PixelSnapSetPoint(icon.count, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", stackX, stackY, 0, 0)
        if type(stackColor) == "table" then
            icon.count:SetTextColor(stackColor.r or 1, stackColor.g or 1, stackColor.b or 1, stackColor.a or 1)
        else
            icon.count:SetTextColor(1, 1, 1, 1)
        end
    end
end

-- =========================================================================
-- 1.6. ICON BORDER + DISPEL GLOW
-- =========================================================================
local AURA_STYLE_KEYS = {
    BUFF = {
        timeFontSize = "buffsTimeFontSize",
        timeX = "buffsTimeX",
        timeY = "buffsTimeY",
        timeColor = "buffsTimeColor",

        stackFontSize = "buffsStackFontSize",
        stackX = "buffsStackX",
        stackY = "buffsStackY",
        stackColor = "buffsStackColor",

        borderEnable = "buffsBorderEnable",
        borderThickness = "buffsBorderThickness",
        borderColor = "buffsBorderColor",
    },
    DEBUFF = {
        timeFontSize = "debuffsTimeFontSize",
        timeX = "debuffsTimeX",
        timeY = "debuffsTimeY",
        timeColor = "debuffsTimeColor",

        stackFontSize = "debuffsStackFontSize",
        stackX = "debuffsStackX",
        stackY = "debuffsStackY",
        stackColor = "debuffsStackColor",

        borderEnable = "debuffsBorderEnable",
        borderThickness = "debuffsBorderThickness",
        borderColor = "debuffsBorderColor",
    },
    CC = {
        timeFontSize = "ccTimeFontSize",
        timeX = "ccTimeX",
        timeY = "ccTimeY",
        timeColor = "ccTimeColor",

        stackFontSize = "ccStackFontSize",
        stackX = "ccStackX",
        stackY = "ccStackY",
        stackColor = "ccStackColor",

        borderEnable = "ccBorderEnable",
        borderThickness = "ccBorderThickness",
        borderColor = "ccBorderColor",
    },
}

local function GetAuraStyleKeys(auraType)
    return AURA_STYLE_KEYS[auraType] or AURA_STYLE_KEYS.CC
end

local function GetAuraNonTargetSettings(db, auraType)
    if auraType == "BUFF" then
        return db.buffsNonTargetAlphaEnable, db.buffsNonTargetAlpha, db.buffsNonTargetScaleEnable, db.buffsNonTargetScale
    elseif auraType == "DEBUFF" then
        return db.debuffsNonTargetAlphaEnable, db.debuffsNonTargetAlpha, db.debuffsNonTargetScaleEnable, db.debuffsNonTargetScale
    else
        return db.ccNonTargetAlphaEnable, db.ccNonTargetAlpha, db.ccNonTargetScaleEnable, db.ccNonTargetScale
    end
end

local function ApplyAuraBorderStyle(icon, borderEnabled, thickness, borderColor)
    if not icon or not icon.border then return end

    if borderEnabled == false then
        icon._BPF_BorderThickness = 0
        icon.border:Hide()
        return
    end

    thickness = tonumber(thickness) or 2
    if thickness < 0 then thickness = 0 end
    thickness = PixelSnapValue(icon, thickness, thickness > 0 and 1 or 0)
    icon._BPF_BorderThickness = thickness

    -- IMPORTANT: border uses a solid-color texture. If its base color is black,
    -- VertexColor multiplication will always stay black. Ensure base is white
    -- so SetVertexColor controls the final color.
    if icon.border.SetColorTexture then
        icon.border:SetColorTexture(1, 1, 1, 1)
    end

    icon.border:ClearAllPoints()
    PixelSnapSetPoint(icon.border, "TOPLEFT", icon, "TOPLEFT", -thickness, thickness, thickness > 0 and 1 or 0, thickness > 0 and 1 or 0)
    PixelSnapSetPoint(icon.border, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", thickness, -thickness, thickness > 0 and 1 or 0, thickness > 0 and 1 or 0)

    if type(borderColor) == "table" then
        icon.border:SetVertexColor(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
    else
        icon.border:SetVertexColor(0, 0, 0, 1)
    end

    if thickness == 0 then
        icon.border:Hide()
    else
        icon.border:Show()
    end
end

local AURA_HIGHLIGHT_INSET = 0
local AURA_HIGHLIGHT_THICKNESS = 2

ApplyAuraHighlightLayout = function(icon)
    if not icon or not icon.AuraHighlightBorder then return end

    local border = icon.AuraHighlightBorder
    local inset = PixelSnapValue(icon, AURA_HIGHLIGHT_INSET, 0)
    local thickness = PixelSnapValue(icon, AURA_HIGHLIGHT_THICKNESS, 1)

    if border.top then
        border.top:ClearAllPoints()
        PixelSnapSetPoint(border.top, "TOPLEFT", icon, "TOPLEFT", inset, -inset, 0, 0)
        PixelSnapSetPoint(border.top, "TOPRIGHT", icon, "TOPRIGHT", -inset, -inset, 0, 0)
        border.top:SetHeight(thickness)
    end

    if border.bottom then
        border.bottom:ClearAllPoints()
        PixelSnapSetPoint(border.bottom, "BOTTOMLEFT", icon, "BOTTOMLEFT", inset, inset, 0, 0)
        PixelSnapSetPoint(border.bottom, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset, 0, 0)
        border.bottom:SetHeight(thickness)
    end

    if border.left then
        border.left:ClearAllPoints()
        PixelSnapSetPoint(border.left, "TOPLEFT", icon, "TOPLEFT", inset, -inset, 0, 0)
        PixelSnapSetPoint(border.left, "BOTTOMLEFT", icon, "BOTTOMLEFT", inset, inset, 0, 0)
        border.left:SetWidth(thickness)
    end

    if border.right then
        border.right:ClearAllPoints()
        PixelSnapSetPoint(border.right, "TOPRIGHT", icon, "TOPRIGHT", -inset, -inset, 0, 0)
        PixelSnapSetPoint(border.right, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", -inset, inset, 0, 0)
        border.right:SetWidth(thickness)
    end
end

local function EnsureAuraHighlightBorder(icon)
    if icon.AuraHighlightBorder then
        ApplyAuraHighlightLayout(icon)
        return icon.AuraHighlightBorder
    end

    local border = {}

    local top = icon:CreateTexture(nil, "OVERLAY", nil, 1)
    top:SetColorTexture(1, 1, 1, 1)
    top:Hide()
    border.top = top

    local bottom = icon:CreateTexture(nil, "OVERLAY", nil, 1)
    bottom:SetColorTexture(1, 1, 1, 1)
    bottom:Hide()
    border.bottom = bottom

    local left = icon:CreateTexture(nil, "OVERLAY", nil, 1)
    left:SetColorTexture(1, 1, 1, 1)
    left:Hide()
    border.left = left

    local right = icon:CreateTexture(nil, "OVERLAY", nil, 1)
    right:SetColorTexture(1, 1, 1, 1)
    right:Hide()
    border.right = right

    icon.AuraHighlightBorder = border
    ApplyAuraHighlightLayout(icon)
    return border
end

local function HideAuraHighlightBorder(icon)
    local border = icon and icon.AuraHighlightBorder
    if not border then return end

    if border.top then border.top:Hide() end
    if border.bottom then border.bottom:Hide() end
    if border.left then border.left:Hide() end
    if border.right then border.right:Hide() end
end

StopAuraHighlight = function(icon)
    if not icon then return end

    UntrackPandemicIcon(icon)
    HideAuraHighlightBorder(icon)
end

local function SetAuraHighlight(icon, enabled, r, g, b, a)
    if not icon then return end

    if not enabled then
        HideAuraHighlightBorder(icon)
        return
    end

    local border = EnsureAuraHighlightBorder(icon)
    local red = r or HIGHLIGHT_GOLD_R
    local green = g or HIGHLIGHT_GOLD_G
    local blue = b or HIGHLIGHT_GOLD_B
    local alpha = a or HIGHLIGHT_GOLD_A

    if border.top then
        border.top:SetVertexColor(red, green, blue, alpha)
        border.top:Show()
    end
    if border.bottom then
        border.bottom:SetVertexColor(red, green, blue, alpha)
        border.bottom:Show()
    end
    if border.left then
        border.left:SetVertexColor(red, green, blue, alpha)
        border.left:Show()
    end
    if border.right then
        border.right:SetVertexColor(red, green, blue, alpha)
        border.right:Show()
    end
end

-- ============================================================================
-- 2. SETUP (Иконки) - Твой оригинальный код (БЕЗ ИЗМЕНЕНИЙ)
-- ============================================================================
local function GetIcon(frame, pool, index)
    if not pool[index] then
        local icon = CreateFrame("Frame", nil, frame)

        icon.border = icon:CreateTexture(nil, "BACKGROUND", nil, -7)
        icon.border:SetColorTexture(1, 1, 1, 1)
        PixelSnapSetPoint(icon.border, "TOPLEFT", icon, "TOPLEFT", -2, 2, 1, 1)
        PixelSnapSetPoint(icon.border, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2, 1, 1)

        icon.tex = icon:CreateTexture(nil, "BACKGROUND")
        icon.tex:SetAllPoints()
        icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)

        icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cd:SetAllPoints()
        icon.cd:SetReverse(true)
        icon.cd:SetDrawEdge(false)
        icon.cd:SetDrawSwipe(true)
        icon.cd:SetHideCountdownNumbers(false)
        icon.cd:SetCountdownAbbrevThreshold(20)

        icon.count = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        PixelSnapSetPoint(icon.count, "BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2, 0, 0)


        pool[index] = icon
    end
    return pool[index]
end

-- ============================================================================
-- 3. LOGIC (Единый маршрутизатор для всех 3-х пулов)
-- ============================================================================

local function AuraPassesFilter(unit, auraInstanceID, filter)
    if not filter or filter == "" then
        return true
    end
    if not (unit and auraInstanceID and C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID) then
        return true
    end
    return not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, auraInstanceID, filter)
end

local function BuildEnemyImportantSet(frame, unit, auraType)
    if auraType == "BUFF" then
        return BuildBlizzardNameplateAuraSet(frame, "BUFF")
            or BuildNameplateOnlyAuraSet(unit, "HELPFUL|INCLUDE_NAME_PLATE_ONLY")
    elseif auraType == "DEBUFF" then
        return BuildBlizzardNameplateAuraSet(frame, "DEBUFF")
            or BuildNameplateOnlyAuraSet(unit, "HARMFUL|INCLUDE_NAME_PLATE_ONLY")
    end
    return nil
end

local function IsEnemyImportant(auraInstanceID, importantSet)
    return importantSet and auraInstanceID and importantSet[auraInstanceID] or false
end

local function EvaluateFriendlyBuffMode(unit, aura, mode)
    local auraInstanceID = aura and aura.auraInstanceID
    if mode == "MINE" then
        return AuraPassesFilter(unit, auraInstanceID, "HELPFUL|PLAYER")
    elseif mode == "MINE_IMPORTANT" then
        return AuraPassesFilter(unit, auraInstanceID, "HELPFUL|PLAYER")
            and AuraPassesFilter(unit, auraInstanceID, "HELPFUL|RAID")
    elseif mode == "IMPORTANT" then
        return AuraPassesFilter(unit, auraInstanceID, "HELPFUL|RAID")
    elseif mode == "RAID_IN_COMBAT" then
        return AuraPassesFilter(unit, auraInstanceID, "HELPFUL|RAID_IN_COMBAT")
    elseif mode == "BIG_DEFENSIVE" then
        return AuraPassesFilter(unit, auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
    elseif mode == "EXTERNAL_DEFENSIVE" then
        return AuraPassesFilter(unit, auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
    elseif mode == "BIG_OR_EXTERNAL_DEFENSIVE" then
        return AuraPassesFilter(unit, auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
            or AuraPassesFilter(unit, auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
    end
    return true
end

local function EvaluateFriendlyDebuffMode(unit, aura, mode)
    local auraInstanceID = aura and aura.auraInstanceID
    if mode == "DISPEL" then
        return AuraPassesFilter(unit, auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE")
    elseif mode == "IMPORTANT" then
        return AuraPassesFilter(unit, auraInstanceID, "HARMFUL|RAID")
    elseif mode == "RAID_IN_COMBAT" then
        return AuraPassesFilter(unit, auraInstanceID, "HARMFUL|RAID_IN_COMBAT")
    elseif mode == "IMPORTANT_AND_DISPEL" then
        return AuraPassesFilter(unit, auraInstanceID, "HARMFUL|RAID")
            and AuraPassesFilter(unit, auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE")
    elseif mode == "IMPORTANT_OR_DISPEL" then
        return AuraPassesFilter(unit, auraInstanceID, "HARMFUL|RAID")
            or AuraPassesFilter(unit, auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE")
    end
    return true
end

local function IsEnemyBuffDispellableLikePlatynator(aura)
    if not aura then return false end
    return aura.dispelName ~= nil
end

local function GetEnemyBuffPurgeGlowColor(unit, aura)
    if not aura or aura.dispelName == nil then
        return nil
    end

    if C_UnitAuras and C_UnitAuras.GetAuraDispelTypeColor and EnemyBuffDispelCurve and aura.auraInstanceID then
        local color = C_UnitAuras.GetAuraDispelTypeColor(unit, aura.auraInstanceID, EnemyBuffDispelCurve)
        if color then
            return color:GetRGBA()
        end
    end

    local fallback = EnemyBuffDispelColorMap[aura.dispelName]
    if fallback then
        return fallback.r, fallback.g, fallback.b, fallback.a or 1
    end

    return HIGHLIGHT_GOLD_R, HIGHLIGHT_GOLD_G, HIGHLIGHT_GOLD_B, HIGHLIGHT_GOLD_A
end

local function GetAuraHighlightColor(unit, auraType, isFriend, db, aura, isPreview)
    if auraType == "DEBUFF" and isFriend and db.debuffsDispelGlow then
        local dispelGlow
        if isPreview then
            dispelGlow = (aura and aura.previewDispelGlow == true)
        else
            dispelGlow = AuraPassesFilter(unit, aura and aura.auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE")
        end

        if dispelGlow then
            return HIGHLIGHT_GOLD_R, HIGHLIGHT_GOLD_G, HIGHLIGHT_GOLD_B, HIGHLIGHT_GOLD_A
        end
        return nil
    end

    if auraType == "BUFF" and (not isFriend) and db.buffsPurgeGlow then
        local purgeGlow
        if isPreview then
            purgeGlow = (aura and aura.previewPurgeGlow == true)
        else
            purgeGlow = IsEnemyBuffDispellableLikePlatynator(aura)
        end

        if purgeGlow then
            return GetEnemyBuffPurgeGlowColor(unit, aura)
        end
    end

    return nil
end

local function EvaluateEnemyBuffMode(unit, aura, mode, importantSet)
    if mode == "PURGE" then
        return IsEnemyBuffDispellableLikePlatynator(aura)
    elseif mode == "IMPORTANT" then
        return IsEnemyImportant(aura and aura.auraInstanceID, importantSet)
    elseif mode == "IMPORTANT_AND_PURGE" then
        local purgeable = IsEnemyBuffDispellableLikePlatynator(aura)
        local important = IsEnemyImportant(aura and aura.auraInstanceID, importantSet)
        return important and purgeable
    elseif mode == "IMPORTANT_OR_PURGE" then
        local purgeable = IsEnemyBuffDispellableLikePlatynator(aura)
        local important = IsEnemyImportant(aura and aura.auraInstanceID, importantSet)
        return important or purgeable
    elseif mode == "BIG_DEFENSIVE" then
        return AuraPassesFilter(unit, aura and aura.auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
    elseif mode == "EXTERNAL_DEFENSIVE" then
        return AuraPassesFilter(unit, aura and aura.auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
    elseif mode == "BIG_OR_EXTERNAL_DEFENSIVE" then
        return AuraPassesFilter(unit, aura and aura.auraInstanceID, "HELPFUL|BIG_DEFENSIVE")
            or AuraPassesFilter(unit, aura and aura.auraInstanceID, "HELPFUL|EXTERNAL_DEFENSIVE")
    end
    return true
end

local function EvaluateEnemyDebuffMode(unit, aura, mode, importantSet)
    local auraInstanceID = aura and aura.auraInstanceID
    if mode == "MINE" then
        return AuraPassesFilter(unit, auraInstanceID, "HARMFUL|PLAYER")
    elseif mode == "MINE_AND_IMPORTANT" then
        return AuraPassesFilter(unit, auraInstanceID, "HARMFUL|PLAYER")
            and IsEnemyImportant(auraInstanceID, importantSet)
    elseif mode == "IMPORTANT" then
        return IsEnemyImportant(auraInstanceID, importantSet)
    end
    return true
end

local function ProcessAuraCategory(frame, unit, db, gdb, auraType, ignoreMap)
    local st = GetState(frame)
    local pool, enabled, baseFilter, size, iconH, posX, posY, align, spacing, timerEdge, timerEnable, stacksEnable

    local isFriend = UnitIsFriend("player", unit)
    local isTarget = unit and UnitExists("target") and UnitIsUnit(unit, "target")

    local friendlyBuffMode = db.buffsFriendlyFilterMode
    local friendlyDebuffMode = db.debuffsFriendlyFilterMode
    local enemyBuffMode = db.buffsEnemyFilterMode
    local enemyDebuffMode = db.debuffsEnemyFilterMode

    if auraType == "BUFF" then
        pool = st.buffs
        enabled = db.buffsEnable
        baseFilter = "HELPFUL"
        size = db.buffsSize or 20
        posX = db.buffsX or 0
        posY = db.buffsY or 18
        align = db.buffsAlign or "CENTER"
        spacing = db.buffsSpacing or 4
        iconH = db.buffsIconHeight or size
        timerEdge = db.buffsTimerEdge
        timerEnable = (db.buffsTimerEnable ~= false)
        stacksEnable = (db.buffsStacksEnable ~= false)
    elseif auraType == "CC" then
        pool = st.cc
        enabled = db.ccEnable
        baseFilter = db.ccOnlyMine and "HARMFUL|CROWD_CONTROL|PLAYER" or "HARMFUL|CROWD_CONTROL"
        size = db.ccSize or 26
        posX = db.ccX or 0
        posY = db.ccY or 65
        align = db.ccAlign or "CENTER"
        spacing = db.ccSpacing or 4
        iconH = db.ccIconHeight or size
        timerEdge = db.ccTimerEdge
        timerEnable = (db.ccTimerEnable ~= false)
        stacksEnable = (db.ccStacksEnable ~= false)
    elseif auraType == "DEBUFF" then
        pool = st.debuffs
        enabled = db.debuffsEnable
        baseFilter = "HARMFUL"
        size = db.debuffsSize or 20
        posX = db.debuffsX or 0
        posY = db.debuffsY or 40
        align = db.debuffsAlign or "CENTER"
        spacing = db.debuffsSpacing or 4
        iconH = db.debuffsIconHeight or size
        timerEdge = db.debuffsTimerEdge
        timerEnable = (db.debuffsTimerEnable ~= false)
        stacksEnable = (db.debuffsStacksEnable ~= false)
    end

    if not enabled then
        for _, icon in ipairs(pool) do HideAuraIcon(icon) end
        return
    end

    local ids = (NS.AurasData and NS.AurasData.GetIDs) and NS.AurasData.GetIDs(frame, auraType) or nil
    if not ids then
        for _, icon in ipairs(pool) do HideAuraIcon(icon) end
        return
    end

    local usePandemic
    if auraType == "BUFF" then
        usePandemic = (db.buffsPandemic ~= false)
    elseif auraType == "DEBUFF" then
        usePandemic = (db.debuffsPandemic ~= false)
    else
        usePandemic = (db.ccPandemic ~= false)
    end
    local maxAuras = 8

    local importantSet
    if not isFriend then
        if auraType == "BUFF" and (enemyBuffMode == "IMPORTANT" or enemyBuffMode == "IMPORTANT_AND_PURGE" or enemyBuffMode == "IMPORTANT_OR_PURGE") then
            importantSet = BuildEnemyImportantSet(frame, unit, "BUFF")
        elseif auraType == "DEBUFF" and (enemyDebuffMode == "IMPORTANT" or enemyDebuffMode == "MINE_AND_IMPORTANT") then
            importantSet = BuildEnemyImportantSet(frame, unit, "DEBUFF")
        end
    end

    local activeCount = 0
    local keys = GetAuraStyleKeys(auraType)
    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)

    local timeFontSize = db[keys.timeFontSize] or 12
    local timeX = db[keys.timeX] or 0
    local timeY = db[keys.timeY] or 0
    local timeColor = db[keys.timeColor]

    local stackFontSize = db[keys.stackFontSize] or 10
    local stackX = db[keys.stackX] or 2
    local stackY = db[keys.stackY] or -2
    local stackColor = db[keys.stackColor]

    local borderEnabled = db[keys.borderEnable]
    local borderThickness = db[keys.borderThickness]
    local borderColor = db[keys.borderColor]

    local nonTargetAlphaEnable, nonTargetAlpha, nonTargetScaleEnable, nonTargetScale = GetAuraNonTargetSettings(db, auraType)
    nonTargetAlpha = tonumber(nonTargetAlpha) or 0.5
    if nonTargetAlpha < 0 then nonTargetAlpha = 0 elseif nonTargetAlpha > 1 then nonTargetAlpha = 1 end
    nonTargetScale = tonumber(nonTargetScale) or 0.85
    if nonTargetScale < 0.3 then nonTargetScale = 0.3 elseif nonTargetScale > 1 then nonTargetScale = 1 end

    local renderScale = 1
    if not isTarget and nonTargetScaleEnable then
        renderScale = nonTargetScale
    end

    local renderAlpha = 1
    if not isTarget and nonTargetAlphaEnable then
        renderAlpha = nonTargetAlpha
    end

    for _, auraInstanceID in ipairs(ids) do
        local aura = (NS.AurasData and NS.AurasData.GetAura) and NS.AurasData.GetAura(frame, unit, auraInstanceID) or nil
        if aura and not (ignoreMap and ignoreMap[aura.auraInstanceID]) then
            local show = AuraPassesFilter(unit, aura.auraInstanceID, baseFilter)

            if show then
                if auraType == "BUFF" then
                    if isFriend then
                        show = EvaluateFriendlyBuffMode(unit, aura, friendlyBuffMode)
                    else
                        show = EvaluateEnemyBuffMode(unit, aura, enemyBuffMode, importantSet)
                    end
                elseif auraType == "DEBUFF" then
                    if isFriend then
                        show = EvaluateFriendlyDebuffMode(unit, aura, friendlyDebuffMode)
                    else
                        show = EvaluateEnemyDebuffMode(unit, aura, enemyDebuffMode, importantSet)
                    end
                end
            end

            if show then
                activeCount = activeCount + 1
                local icon = GetIcon(frame, pool, activeCount)

                local scaledTimeFontSize = math.max(1, math.floor((timeFontSize or 12) * renderScale + 0.5))
                local scaledTimeX = math.floor((timeX or 0) * renderScale + 0.5)
                local scaledTimeY = math.floor((timeY or 0) * renderScale + 0.5)

                local scaledStackFontSize = math.max(1, math.floor((stackFontSize or 10) * renderScale + 0.5))
                local scaledStackX = math.floor((stackX or 2) * renderScale + 0.5)
                local scaledStackY = math.floor((stackY or -2) * renderScale + 0.5)

                ApplyAuraTextStyle(
                    icon,
                    fontPath,
                    scaledTimeFontSize,
                    scaledTimeX,
                    scaledTimeY,
                    timeColor,
                    scaledStackFontSize,
                    scaledStackX,
                    scaledStackY,
                    stackColor
                )

                local renderWidth = size * renderScale
                local renderHeight = (iconH or size) * renderScale
                ApplyIconRect(icon, renderWidth, renderHeight)
                ApplyAuraBorderStyle(icon, borderEnabled, borderThickness, borderColor)
                icon.tex:SetTexture(aura.icon)

                if stacksEnable == false then
                    icon.count:Hide()
                else
                    local countStr = C_UnitAuras.GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, 2, 1000)
                    if countStr ~= nil then
                        icon.count:SetText(countStr)
                        icon.count:Show()
                    else
                        icon.count:Hide()
                    end
                end

                -- Подсветка аур:
                -- 1) Дебаффы на союзниках: реально рассеиваемые текущим игроком
                -- 2) Баффы на врагах: ауры с dispel type (визуальный признак, не player-aware проверка)
                local dispelGlowR, dispelGlowG, dispelGlowB, dispelGlowA = GetAuraHighlightColor(unit, auraType, isFriend, db, aura, false)
                local dispelGlow = dispelGlowR ~= nil

                local durationInfo = nil

                if timerEnable == false then
                    icon.cd:Hide()
                    UntrackPandemicIcon(icon)
                    icon:SetAlpha(renderAlpha)
                else
                    icon.cd:SetDrawEdge(timerEdge and true or false)
                    icon.cd:SetHideCountdownNumbers(false)

                    durationInfo = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)

                    if durationInfo then
                        -- Передаем таймер всегда, чтобы избежать Taint-ошибок
                        icon.cd:SetCooldownFromDurationObject(durationInfo)
                        icon.cd:Show()

                        -- Если IsZero (вечная аура), Alpha будет 0. Если обычная аура, Alpha будет 1.
                        local cdAlpha = C_CurveUtil.EvaluateColorValueFromBoolean(durationInfo:IsZero(), 0, 1)
                        icon.cd:SetAlpha(cdAlpha)
                        icon:SetAlpha(renderAlpha)
                    else
                        icon.cd:Hide()
                        UntrackPandemicIcon(icon)
                        icon:SetAlpha(renderAlpha)
                    end
                end

                if dispelGlow then
                    SetAuraHighlight(icon, true, dispelGlowR, dispelGlowG, dispelGlowB, dispelGlowA)
                else
                    SetAuraHighlight(icon, false)
                end

                if timerEnable ~= false and usePandemic and durationInfo then
                    TrackPandemicIcon(icon, durationInfo)
                else
                    UntrackPandemicIcon(icon)
                end

                if ignoreMap then ignoreMap[aura.auraInstanceID] = true end

                if activeCount >= maxAuras then break end
            end
        end
    end

    -- 2. Математика позиционирования для видимых иконок
    if activeCount > 0 then
        spacing = spacing or 4
        -- Считаем точную длину всей полосы иконок
        local layoutWidth = PixelSnapValue(frame, size * renderScale, 1)
        spacing = PixelSnapValue(frame, spacing, 0)
        local totalWidth = (activeCount * layoutWidth) + ((activeCount - 1) * spacing)

        for i = 1, activeCount do
            local icon = pool[i]
            icon:ClearAllPoints()
            
            if i == 1 then
                if align == "LEFT" then
                    PixelSnapSetPoint(icon, "BOTTOMLEFT", frame.healthBar, "TOPRIGHT", posX, posY, 0, 0)
                elseif align == "RIGHT" then
                    PixelSnapSetPoint(icon, "BOTTOMRIGHT", frame.healthBar, "TOPLEFT", posX, posY, 0, 0)
                else -- CENTER
                    -- Смещаем первую иконку влево на половину длины всей группы аур
                    PixelSnapSetPoint(icon, "BOTTOM", frame.healthBar, "TOP", posX - (totalWidth / 2) + (layoutWidth / 2), posY, 0, 0)
                end
            else
                if align == "RIGHT" then
                    -- Если привязка справа, ауры растут влево
                    PixelSnapSetPoint(icon, "RIGHT", pool[i-1], "LEFT", -spacing, 0, 0, 0)
                else
                    -- При привязке LEFT и CENTER ауры растут вправо
                    PixelSnapSetPoint(icon, "LEFT", pool[i-1], "RIGHT", spacing, 0, 0, 0)
                end
            end
            icon:Show()
        end
    end

    -- 3. Скрываем лишнее
    for i = activeCount + 1, #pool do
        HideAuraIcon(pool[i])
    end
end
-- ============================================================================
-- 3.5. PREVIEW MODE (фейковые ауры из Modules/AurasPreview.lua)
-- ============================================================================
local function RenderPreviewCategory(frame, unit, db, gdb, auraType, list)
    local st = GetState(frame)
    local pool, enabled, size, iconH, posX, posY, align, spacing, timerEdge, timerEnable, stacksEnable

    if auraType == "BUFF" then
        pool = st.buffs
        enabled = db.buffsEnable
        size = db.buffsSize or 20
        posX = db.buffsX or 0
        posY = db.buffsY or 18
        align = db.buffsAlign or "CENTER"
        spacing = db.buffsSpacing or 4
        iconH = db.buffsIconHeight or size
        timerEdge = db.buffsTimerEdge
        timerEnable = (db.buffsTimerEnable ~= false)
        stacksEnable = (db.buffsStacksEnable ~= false)
    elseif auraType == "CC" then
        pool = st.cc
        enabled = db.ccEnable
        size = db.ccSize or 26
        posX = db.ccX or 0
        posY = db.ccY or 65
        align = db.ccAlign or "CENTER"
        spacing = db.ccSpacing or 4
        iconH = db.ccIconHeight or size
        timerEdge = db.ccTimerEdge
        timerEnable = (db.ccTimerEnable ~= false)
        stacksEnable = (db.ccStacksEnable ~= false)
    else -- DEBUFF
        pool = st.debuffs
        enabled = db.debuffsEnable
        size = db.debuffsSize or 20
        posX = db.debuffsX or 0
        posY = db.debuffsY or 40
        align = db.debuffsAlign or "CENTER"
        spacing = db.debuffsSpacing or 4
        iconH = db.debuffsIconHeight or size
        timerEdge = db.debuffsTimerEdge
        timerEnable = (db.debuffsTimerEnable ~= false)
        stacksEnable = (db.debuffsStacksEnable ~= false)
    end

    if not enabled or not list or #list == 0 then
        for _, icon in ipairs(pool) do HideAuraIcon(icon) end
        return
    end

    local maxAuras = 8
    local activeCount = 0
    local now = GetTime()
    local isTarget = unit and UnitExists("target") and UnitIsUnit(unit, "target")
    local isFriend = unit and UnitIsFriend("player", unit)
    spacing = spacing or 4

    local usePandemic
    if auraType == "BUFF" then
        usePandemic = (db.buffsPandemic ~= false)
    elseif auraType == "DEBUFF" then
        usePandemic = (db.debuffsPandemic ~= false)
    else
        usePandemic = (db.ccPandemic ~= false)
    end

    local keys = GetAuraStyleKeys(auraType)
    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)

    local timeFontSize = db[keys.timeFontSize] or 12
    local timeX = db[keys.timeX] or 0
    local timeY = db[keys.timeY] or 0
    local timeColor = db[keys.timeColor]

    local stackFontSize = db[keys.stackFontSize] or 10
    local stackX = db[keys.stackX] or 2
    local stackY = db[keys.stackY] or -2
    local stackColor = db[keys.stackColor]

    local borderEnabled = db[keys.borderEnable]
    local borderThickness = db[keys.borderThickness]
    local borderColor = db[keys.borderColor]

    local nonTargetAlphaEnable, nonTargetAlpha, nonTargetScaleEnable, nonTargetScale = GetAuraNonTargetSettings(db, auraType)
    nonTargetAlpha = tonumber(nonTargetAlpha) or 0.5
    if nonTargetAlpha < 0 then nonTargetAlpha = 0 elseif nonTargetAlpha > 1 then nonTargetAlpha = 1 end
    nonTargetScale = tonumber(nonTargetScale) or 0.85
    if nonTargetScale < 0.3 then nonTargetScale = 0.3 elseif nonTargetScale > 1 then nonTargetScale = 1 end

    local renderScale = 1
    if not isTarget and nonTargetScaleEnable then
        renderScale = nonTargetScale
    end

    local renderAlpha = 1
    if not isTarget and nonTargetAlphaEnable then
        renderAlpha = nonTargetAlpha
    end

    for i = 1, #list do
        local a = list[i]
        activeCount = activeCount + 1
        local icon = GetIcon(frame, pool, activeCount)

        local scaledTimeFontSize = math.max(1, math.floor((timeFontSize or 12) * renderScale + 0.5))
        local scaledTimeX = math.floor((timeX or 0) * renderScale + 0.5)
        local scaledTimeY = math.floor((timeY or 0) * renderScale + 0.5)

        local scaledStackFontSize = math.max(1, math.floor((stackFontSize or 10) * renderScale + 0.5))
        local scaledStackX = math.floor((stackX or 2) * renderScale + 0.5)
        local scaledStackY = math.floor((stackY or -2) * renderScale + 0.5)

        ApplyAuraTextStyle(
            icon,
            fontPath,
            scaledTimeFontSize,
            scaledTimeX,
            scaledTimeY,
            timeColor,
            scaledStackFontSize,
            scaledStackX,
            scaledStackY,
            stackColor
        )

        local renderWidth = size * renderScale
        local renderHeight = (iconH or size) * renderScale
        ApplyIconRect(icon, renderWidth, renderHeight)
        ApplyAuraBorderStyle(icon, borderEnabled, borderThickness, borderColor)
        StopAuraHighlight(icon)
        icon.tex:SetTexture(a.icon)

        if stacksEnable == false then
    icon.count:Hide()
else
    local stacks = tonumber(a.stacks or 0) or 0
    if stacks > 1 then
        icon.count:SetText(stacks)
        icon.count:Show()
    else
        icon.count:SetText("")
        icon.count:Hide()
    end
end

        local dur = tonumber(a.duration or 0) or 0
        local rem = tonumber(a.remaining or dur) or dur
        local startFromList = tonumber(a.start)

        if timerEnable == false then
    icon.cd:Hide()
else
    icon.cd:SetDrawEdge(timerEdge and true or false)
    icon.cd:SetHideCountdownNumbers(false)

    if dur > 0 then
        local start
        if startFromList then
            start = startFromList
        else
            if rem > dur then rem = dur end
            if rem < 0 then rem = 0 end
            start = now - (dur - rem)
        end
        if start < 0 then start = 0 end
        icon.cd:SetCooldown(start, dur)
        icon.cd:Show()
    else
        icon.cd:Hide()
    end
end


        if timerEnable ~= false and usePandemic and dur > 0 then
            local remaining

            if startFromList then
                remaining = dur - (now - startFromList)
            else
                remaining = rem
            end

            if remaining < 0 then remaining = 0 end
            if remaining > dur then remaining = dur end

            UpdatePreviewPandemicTimerColor(icon, remaining, dur)
        else
            RestoreCooldownTextColor(icon)
        end

        local previewHighlightR, previewHighlightG, previewHighlightB, previewHighlightA = GetAuraHighlightColor(nil, auraType, isFriend, db, a, true)
        local previewHighlight = previewHighlightR ~= nil

        if previewHighlight then
            SetAuraHighlight(icon, true, previewHighlightR, previewHighlightG, previewHighlightB, previewHighlightA)
        else
            SetAuraHighlight(icon, false)
        end

        if a.inactive then
            icon:SetAlpha(renderAlpha * 0.25)
        else
            icon:SetAlpha(renderAlpha)
        end

        if activeCount >= maxAuras then break end
    end

    -- Positioning (как в обычном режиме)
    if activeCount > 0 then
        local layoutWidth = PixelSnapValue(frame, size * renderScale, 1)
        spacing = PixelSnapValue(frame, spacing, 0)
        local totalWidth = (activeCount * layoutWidth) + ((activeCount - 1) * spacing)

        for i = 1, activeCount do
            local icon = pool[i]
            icon:ClearAllPoints()

            if i == 1 then
                if align == "LEFT" then
                    PixelSnapSetPoint(icon, "BOTTOMLEFT", frame.healthBar, "TOPRIGHT", posX, posY, 0, 0)
                elseif align == "RIGHT" then
                    PixelSnapSetPoint(icon, "BOTTOMRIGHT", frame.healthBar, "TOPLEFT", posX, posY, 0, 0)
                else -- CENTER
                    PixelSnapSetPoint(icon, "BOTTOM", frame.healthBar, "TOP", posX - (totalWidth / 2) + (layoutWidth / 2), posY, 0, 0)
                end
            else
                if align == "RIGHT" then
                    PixelSnapSetPoint(icon, "RIGHT", pool[i-1], "LEFT", -spacing, 0, 0, 0)
                else
                    PixelSnapSetPoint(icon, "LEFT", pool[i-1], "RIGHT", spacing, 0, 0, 0)
                end
            end
            icon:Show()
        end
    end

    for i = activeCount + 1, #pool do
        HideAuraIcon(pool[i])
    end
end

-- ============================================================================
-- 4. UPDATE/RESET (обновление через общий Dispatch/Engine)
-- ============================================================================
NS.Modules.Auras = {
    Update = function(frame, unit, db, gdb)
        if not frame or frame:IsForbidden() then return end
        if not db or not unit then return end



        -- Preview mode (фейковые ауры для настройки)
        if NS.AurasPreview and NS.AurasPreview.IsEnabled and NS.AurasPreview.IsEnabled(db) then
            -- Локальные тумблеры (buffsEnable/debuffsEnable/ccEnable) должны полностью отключать логику категории,
            -- включая превью.
            local doPreview = false
            if db.buffsEnable and NS.AurasPreview.IsBuffsEnabled and NS.AurasPreview.IsBuffsEnabled(db) then doPreview = true end
            if db.debuffsEnable and NS.AurasPreview.IsDebuffsEnabled and NS.AurasPreview.IsDebuffsEnabled(db) then doPreview = true end
            if db.ccEnable and NS.AurasPreview.IsCCEnabled and NS.AurasPreview.IsCCEnabled(db) then doPreview = true end

            if not doPreview then
                HideAuraPools(frame)
                return
            end

            local buffs, debuffs, cc = nil, nil, nil
            if NS.AurasPreview.GetLists then
                buffs, debuffs, cc = NS.AurasPreview.GetLists(unit)
            end

            if db.buffsEnable and NS.AurasPreview.IsBuffsEnabled and NS.AurasPreview.IsBuffsEnabled(db) then
                RenderPreviewCategory(frame, unit, db, gdb, "BUFF", buffs)
            else
                RenderPreviewCategory(frame, unit, db, gdb, "BUFF", nil)
            end

            if db.debuffsEnable and NS.AurasPreview.IsDebuffsEnabled and NS.AurasPreview.IsDebuffsEnabled(db) then
                RenderPreviewCategory(frame, unit, db, gdb, "DEBUFF", debuffs)
            else
                RenderPreviewCategory(frame, unit, db, gdb, "DEBUFF", nil)
            end

            if db.ccEnable and NS.AurasPreview.IsCCEnabled and NS.AurasPreview.IsCCEnabled(db) then
                RenderPreviewCategory(frame, unit, db, gdb, "CC", cc)
            else
                RenderPreviewCategory(frame, unit, db, gdb, "CC", nil)
            end

            return
        end

        -- Legacy master switch: aurasEnable больше не используется в UI.
        -- Если он был выключен в старых профилях, а категории выключены — скрываем всё.
        local anyCatEnabled = (db.buffsEnable or db.debuffsEnable or db.ccEnable) and true or false
        if db.aurasEnable == false and not anyCatEnabled then
            HideAuraPools(frame)
            return
        end

        -- Data layer: incremental UNIT_AURA refreshData (captured by Dispatch)
        local pending = NS.PendingAuraUpdates and NS.PendingAuraUpdates[unit] or nil
        if NS.AurasData and NS.AurasData.ApplyRefresh then
            local _, needFull = NS.AurasData.ApplyRefresh(frame, unit, pending)
            if needFull then
                NS.AurasData.FullRefresh(frame, unit)
            else
                NS.AurasData.EnsureFull(frame, unit)
            end
            NS.AurasData.RebuildOrder(frame, unit)
        end
        if NS.PendingAuraUpdates then NS.PendingAuraUpdates[unit] = nil end

        local ccMap = {}
        ProcessAuraCategory(frame, unit, db, gdb, "BUFF", nil)
        ProcessAuraCategory(frame, unit, db, gdb, "CC", ccMap)
        ProcessAuraCategory(frame, unit, db, gdb, "DEBUFF", ccMap)
    end,
    
    Reset = function(frame)
        HideAuraPools(frame)
        if NS.AurasData and NS.AurasData.Reset then
            NS.AurasData.Reset(frame)
        end
    end
}

