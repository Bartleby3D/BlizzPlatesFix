local _, NS = ...

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local FrameState = setmetatable({}, { __mode = "k" })

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
        lastNameIdentity = nil,
    }
    FrameState[frame] = st
    return st
end

local function EnsureFontString(frame, st)
    if st.fs then return end

    local parent = frame.healthBar or frame
    st.wrapper = CreateFrame("Frame", nil, parent)
    frame.BPF_NameTextWrapper = st.wrapper
    st.wrapper:Hide()
    st.wrapper:SetSize(1, 1)

    st.fs = st.wrapper:CreateFontString(nil, "OVERLAY", nil, 7)
    frame.BPF_NameTextFS = st.fs
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

local function GetNameWithOptionalTitle(unit, fallbackName, db, rpState)
    if not db or db.nameShowPlayerTitle ~= true then
        return fallbackName
    end

    if not unit or not UnitExists(unit) or not UnitIsPlayer(unit) or UnitIsUnit(unit, "player") then
        return fallbackName
    end

    if rpState == "resolved" or rpState == "pending" then
        return fallbackName
    end

    local titledName = UnitPVPName and UnitPVPName(unit)
    if titledName == nil or titledName == "" then
        return fallbackName
    end

    local ok, s = pcall(tostring, titledName)
    if ok and s and s ~= "" then
        return s
    end

    return fallbackName
end

local function GetUnitColor(unit, db, gdb)
    if not (NS.UnitColor and NS.UnitColor.GetColor) then
        return 1, 1, 1
    end

    return NS.UnitColor.GetColor(
        unit,
        db,
        gdb,
        "nameColorMode",
        "nameColor",
        "nameColorHostile",
        "nameColorFriendly",
        "nameColorNeutral",
        0.5, 0.5, 0.5
    )
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
        if self.Hide then self:Hide() end
        self:SetAlpha(0)
        self.BPF_InHook = false
    end)

    hooksecurefunc(blizz, "SetShown", function(self, shown)
        if not self.BPF_Block then return end
        if self.BPF_InHook then return end
        if shown then
            self.BPF_InHook = true
            if self.Hide then self:Hide() end
            self:SetAlpha(0)
            self.BPF_InHook = false
        end
    end)

    hooksecurefunc(blizz, "SetAlpha", function(self, a)
        if not self.BPF_Block then return end
        if self.BPF_InHook then return end
        if a and a > 0 then
            self.BPF_InHook = true
            if self.Hide then self:Hide() end
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


local function GetExtraNameShift(frame, unit, db, gdb)
    local guildTextModule = NS.Modules and NS.Modules.GuildText
    if not (guildTextModule and guildTextModule.GetNameShift) then
        return 0
    end

    local ok, shift = pcall(guildTextModule.GetNameShift, frame, unit, db, gdb)
    if not ok then
        return 0
    end

    shift = tonumber(shift) or 0
    if shift < 0 then
        shift = 0
    end
    return shift
end


local function ApplyStyle(frame, st, unit, db, gdb)
    EnsureBlizzNameHooks(frame, st)
    
    if not db.nameEnable then
        if st.fs then st.fs:Hide() end
        if st.wrapper then st.wrapper:Hide() end
        frame.BPF_NameTextWrapper = st.wrapper
        frame.BPF_NameTextFS = st.fs
        SetBlizzBlocked(frame, false)
        st.lastShown = nil
        st.lastPointAlignH = nil
        st.lastPointX = nil
        st.lastPointY = nil
        st.lastNameIdentity = nil
        return
    end

    if NS.ShouldHideModuleOnSimplified("NameText", frame, unit) then
        if st.fs then st.fs:Hide() end
        if st.wrapper then st.wrapper:Hide() end
        SetBlizzBlocked(frame, true)
        st.lastNameIdentity = nil
        return
    end

    EnsureFontString(frame, st)
    SetBlizzBlocked(frame, true)

    local fs = st.fs
    if not fs then return false end

    -- Вычисление базовых переменных
    local targetScale = 1
    if UnitIsUnit(unit, "target") and not db.nameDisableTargetScale then
        targetScale = tonumber(gdb and gdb.nameplateSelectedScale) or 1.2
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
    local fallbackName = SafeUnitNameString(unit)
    local displayName = fallbackName
    local rpState = nil

    if NS.RP and NS.RP.GetDisplayName then
        local resolvedName, state = NS.RP.GetDisplayName(unit, fallbackName)
        rpState = state
        if resolvedName ~= nil then
            displayName = resolvedName
        end
    end

    displayName = GetNameWithOptionalTitle(unit, displayName, db, rpState)

    local nameIdentity = UnitGUID(unit) or unit
    -- RP data can be pending for a while; keep showing the regular name as a fallback
    -- instead of blanking the text until the RP addon resolves a profile name.
    fs:SetText(displayName)
    st.lastNameIdentity = nameIdentity

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
    local offY = (db.textY or 0) + GetExtraNameShift(frame, unit, db, gdb)

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

    frame.BPF_NameTextWrapper = st.wrapper
    frame.BPF_NameTextFS = fs

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

    local r, g, b = GetUnitColor(unit, db, gdb)
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
    Init = function(frame)
        if not frame or frame:IsForbidden() then return end
        local st = GetState(frame)
        EnsureFontString(frame, st)
    end,
    Update = function(frame, unit, db, gdb)
        if not frame or frame:IsForbidden() then return end
        if not frame.healthBar then return end
        if not db then return end

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
        st.lastNameIdentity = nil
    end
}