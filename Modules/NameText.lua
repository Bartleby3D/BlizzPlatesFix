local _, NS = ...

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local FrameState = setmetatable({}, { __mode = "k" })

-- Cache references to NPC unit-type DB tables to avoid repeated NS.Config.GetTable calls
-- in hot paths (GetUnitColor is called very frequently).
local _cachedProfileName = nil
local _cachedEnemyNpcDB = nil
local _cachedFriendlyNpcDB = nil

local function RefreshNpcProfileRefs()
    local cfg = NS.Config
    if not cfg or type(cfg.GetTable) ~= "function" then
        _cachedProfileName = nil
        _cachedEnemyNpcDB = nil
        _cachedFriendlyNpcDB = nil
        return
    end

    local prof = (type(cfg.GetActiveProfileName) == "function") and cfg.GetActiveProfileName() or nil
    if prof ~= _cachedProfileName or _cachedEnemyNpcDB == nil or _cachedFriendlyNpcDB == nil then
        _cachedProfileName = prof
        _cachedEnemyNpcDB = cfg.GetTable(NS.UNIT_TYPES.ENEMY_NPC)
        _cachedFriendlyNpcDB = cfg.GetTable(NS.UNIT_TYPES.FRIENDLY_NPC)
    end
end

local function GetState(frame)
    local st = FrameState[frame]
    if st then return st end
    st = {
        fs = nil,
        wrapper = nil,
        lastShown = nil,
        lastFontPath = nil,
        lastFontSize = nil,
        lastFontStyle = nil,
        lastShadow = nil,
        lastAlignH = nil,
        lastAlignV = nil,
        lastWrap = nil,
        lastTruncate = nil,
        lastWidth = nil,
        lastPointAlignH = nil,
        lastPointX = nil,
        lastPointY = nil,
        lastFsAnchorKey = nil,
        lastColorR = nil,
        lastColorG = nil,
        lastColorB = nil,
        lastScale = nil,
        hookedBlizzName = false,
    }
    FrameState[frame] = st
    return st
end

local function EnsureFontString(frame, st)
    if st.fs then return end

    local parent = frame.healthBar or frame
    st.wrapper = CreateFrame("Frame", nil, parent)
    st.wrapper:Hide()
    st.wrapper:SetSize(1, 1)

    st.fs = st.wrapper:CreateFontString(nil, "OVERLAY", nil, 7)
    st.fs:Hide()

    if st.fs.SetIgnoreParentScale then
        st.fs:SetIgnoreParentScale(true)
    end
    st.fs:SetScale(1)

    st.fs:SetNonSpaceWrap(false)
    st.fs:SetSpacing(0)
end

local function SafeUnitNameString(unit)
    local v = UnitName(unit)
    if v == nil then return "" end
    local ok, s = pcall(tostring, v)
    if ok and s then return s end
    return ""
end

local function GetUnitColor(unit, db)
    if db.nameColorMode == 2 then
        if _cachedEnemyNpcDB == nil or _cachedFriendlyNpcDB == nil then
            RefreshNpcProfileRefs()
        end

        local c
        if _cachedEnemyNpcDB and db == _cachedEnemyNpcDB then
            local reaction = UnitReaction(unit, "player")
            if reaction == 4 then
                c = db.nameColorNeutral or db.nameColor
            else
                c = db.nameColorHostile or db.nameColor
            end
        elseif _cachedFriendlyNpcDB and db == _cachedFriendlyNpcDB then
            local reaction = UnitReaction(unit, "player")
            if reaction == 4 then
                c = db.nameColorNeutral or db.nameColor
            else
                c = db.nameColorFriendly or db.nameColor
            end
        else
            c = db.nameColor
        end

        if not c then return 1, 1, 1 end
        return c.r, c.g, c.b
    end

    -- Mode 3: Реакция (включая игроков)
    if db.nameColorMode == 3 then
        local reaction = UnitReaction(unit, "player")
        if reaction == 4 and UnitCanAttack("player", unit) then
            local threat = UnitThreatSituation("player", unit)
            if threat ~= nil then
                return 1, 0.2, 0.2
            end
        end
        return UnitSelectionColor(unit)
    end

    -- Mode 1: Авто (игроки: класс, NPC: реакция)
    if UnitIsPlayer(unit) or (UnitTreatAsPlayerForDisplay and UnitTreatAsPlayerForDisplay(unit)) then
        local _, classFilename = UnitClass(unit)
        if classFilename then
            local color = C_ClassColor.GetClassColor(classFilename)
            if color then return color.r, color.g, color.b end
        end
        return 1, 1, 1
    else
        local reaction = UnitReaction(unit, "player")
        if reaction == 4 and UnitCanAttack("player", unit) then
            local threat = UnitThreatSituation("player", unit)
            if threat ~= nil then
                return 1, 0.2, 0.2
            end
        end
        return UnitSelectionColor(unit)
    end
end

local function EnsureBlizzNameHooks(frame, st)
    if st.hookedBlizzName then return end
    
    local blizz = frame.name or (frame.UnitFrame and frame.UnitFrame.name)
    if not blizz then return end

    blizz.BPF_Block = blizz.BPF_Block or false
    blizz.BPF_InHook = blizz.BPF_InHook or false

    hooksecurefunc(blizz, "Show", function(self)
        if not self.BPF_Block then return end
        if self.BPF_InHook then return end
        self.BPF_InHook = true
        self:SetAlpha(0)
        self.BPF_InHook = false
    end)

    hooksecurefunc(blizz, "SetAlpha", function(self, a)
        if not self.BPF_Block then return end
        if self.BPF_InHook then return end
        if a and a > 0 then
            self.BPF_InHook = true
            self:SetAlpha(0)
            self.BPF_InHook = false
        end
    end)

    st.hookedBlizzName = true
end

local function SetBlizzBlocked(frame, blocked)
    local blizz = frame.name or (frame.UnitFrame and frame.UnitFrame.name)
    if not blizz then return end
    
    blizz.BPF_Block = blocked and true or false

    if blocked then
        blizz:SetAlpha(0)
    else
        blizz:SetAlpha(1)
        if blizz.Show then blizz:Show() end
    end
end


local function ApplyStyle(frame, st, unit, db, gdb)
    EnsureBlizzNameHooks(frame, st)
    
    if not db.nameEnable then
        if st.fs then st.fs:Hide() end
        if st.wrapper then st.wrapper:Hide() end
        SetBlizzBlocked(frame, false)
        st.lastShown = nil
        st.lastPointAlignH = nil
        st.lastPointX = nil
        st.lastPointY = nil
        return
    end

    if NS.IsSimplifiedNotTarget(frame, unit) then
        if st.fs then st.fs:Hide() end
        if st.wrapper then st.wrapper:Hide() end
        SetBlizzBlocked(frame, true)
        return
    end

    EnsureFontString(frame, st)
    SetBlizzBlocked(frame, true)

    local fs = st.fs
    if not fs then return false end

    -- Вычисление базовых переменных
    local targetScale = 1
    if UnitIsUnit(unit, "target") and not db.nameDisableTargetScale then
        targetScale = 1.2
    end

    local baseFontSize = db.fontScale or 12
    local fontSize = baseFontSize * targetScale

    local wrap = (db.nameWordWrap ~= false)
    local truncate = not wrap
    local baseWrapWidth = db.nameWrapWidth or 135
    local width = baseWrapWidth * targetScale

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local style = db.fontOutline or "OUTLINE"
    local fontStyle = (style == "SHADOW" or style == "NONE") and nil or style

    -- ШАГ 1: Установка шрифта (Формирование базовых метрик)
    local fontChanged = (st.lastFontPath ~= fontPath or st.lastFontSize ~= fontSize or st.lastFontStyle ~= fontStyle)

    if fontChanged then
        fs:Hide() -- Принудительно отключаем рендер для сброса геометрии движка
        if not fs:SetFont(fontPath, fontSize, fontStyle) then
            fs:SetFont(STANDARD_TEXT_FONT, fontSize, fontStyle)
        end
        st.lastFontPath = fontPath
        st.lastFontSize = fontSize
        st.lastFontStyle = fontStyle
    end

    -- ШАГ 2: Установка текста (Предоставление данных движку для расчета)
    fs:SetText(SafeUnitNameString(unit))

    -- ШАГ 3: Установка ограничений (Ширина, усечение)
    if st.lastTruncate ~= truncate then
        fs:SetWordWrap(not truncate)
        if fs.SetMaxLines then
            fs:SetMaxLines(truncate and 1 or 0)
        end
        st.lastTruncate = truncate
    end

    if st.lastWidth ~= width then
        fs:SetWidth(width)
        st.lastWidth = width
    end

    -- ШАГ 4: Выравнивание, позиционирование и стилизация
    local alignH = db.textAlign or "CENTER"
    local alignV = "BOTTOM"
    local offX = db.textX or 0
    local offY = db.textY or 0

    if st.lastAlignH ~= alignH then
        fs:SetJustifyH(alignH)
        st.lastAlignH = alignH
    end
    if st.lastAlignV ~= alignV then
        fs:SetJustifyV(alignV)
        st.lastAlignV = alignV
    end

    local anchor = frame.healthBar
    if st.wrapper and (st.lastPointAlignH ~= alignH or st.lastPointX ~= offX or st.lastPointY ~= offY) then
        st.wrapper:ClearAllPoints()
        if alignH == "LEFT" then
            st.wrapper:SetPoint("BOTTOMLEFT", anchor, "TOPLEFT", offX, offY)
        elseif alignH == "RIGHT" then
            st.wrapper:SetPoint("BOTTOMRIGHT", anchor, "TOPRIGHT", offX, offY)
        else
            st.wrapper:SetPoint("BOTTOM", anchor, "TOP", offX, offY)
        end
        st.lastPointAlignH = alignH
        st.lastPointX = offX
        st.lastPointY = offY
    end


    if st.wrapper and st.lastFsAnchorKey ~= alignH then
        fs:ClearAllPoints()
        if alignH == "LEFT" then
            fs:SetPoint("BOTTOMLEFT", st.wrapper, "BOTTOMLEFT", 0, 0)
        elseif alignH == "RIGHT" then
            fs:SetPoint("BOTTOMRIGHT", st.wrapper, "BOTTOMRIGHT", 0, 0)
        else
            fs:SetPoint("BOTTOM", st.wrapper, "BOTTOM", 0, 0)
        end
        st.lastFsAnchorKey = alignH
    end

    local wantShadow = (style == "SHADOW")
    if st.lastShadow ~= wantShadow then
        if wantShadow then
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, 1)
        else
            fs:SetShadowOffset(0, 0)
        end
        st.lastShadow = wantShadow
    end

    local r, g, b = GetUnitColor(unit, db)
    if st.lastColorR ~= r or st.lastColorG ~= g or st.lastColorB ~= b then
        fs:SetTextColor(r, g, b)
        st.lastColorR, st.lastColorG, st.lastColorB = r, g, b
    end

    -- ШАГ 5: Финальный рендер (Вывод настроенного объекта на экран)
    if st.wrapper and not st.wrapper:IsShown() then 
        st.wrapper:Show() 
    end
    
    if st.fs and not st.fs:IsShown() then 
        st.fs:Show() 
    end

    return true
end

NS.Modules.NameText = {
    Update = function(frame, unit, db, gdb)
        if not frame or frame:IsForbidden() then return end
        if not frame.healthBar then return end
        if not db then return end

        -- Keep cached NPC DB table references in sync with profile changes.
        RefreshNpcProfileRefs()

        local st = GetState(frame)
        ApplyStyle(frame, st, unit, db, gdb)
    end,
    Reset = function(frame)
        local st = GetState(frame)
        if st.fs then st.fs:Hide() end
        if st.wrapper then st.wrapper:Hide() end
        SetBlizzBlocked(frame, false)
        st.lastShown = nil
        st.lastPointAlignH = nil
        st.lastPointX = nil
        st.lastPointY = nil
    end
}