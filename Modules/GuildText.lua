local _, NS = ...

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local FormatGuildText
local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        wrapper = nil,
        fs = nil,
        lastVisible = nil,
        lastFontPath = nil,
        lastFontSize = nil,
        lastFontFlag = nil,
        lastShadow = nil,
        lastWidth = nil,
        lastAlign = nil,
        lastPointAlign = nil,
        lastText = nil,
        lastColorR = nil,
        lastColorG = nil,
        lastColorB = nil,
        lastAnchorMode = nil,
        lastAnchorRegion = nil,
        lastX = nil,
        lastY = nil,
        lastMode = nil,
    }
    State[frame] = st
    return st
end

local MeasureWrapper = nil
local MeasureFS = nil

local function EnsureMeasureFontString()
    if MeasureFS then return MeasureFS end

    MeasureWrapper = CreateFrame("Frame", nil, UIParent)
    MeasureWrapper:SetSize(1, 1)
    MeasureWrapper:Hide()

    MeasureFS = MeasureWrapper:CreateFontString(nil, "OVERLAY", nil, 7)
    MeasureFS:Hide()
    if MeasureFS.SetIgnoreParentScale then
        MeasureFS:SetIgnoreParentScale(true)
    end
    MeasureFS:SetScale(1)
    MeasureFS:SetNonSpaceWrap(false)
    MeasureFS:SetWordWrap(false)
    if MeasureFS.SetMaxLines then
        MeasureFS:SetMaxLines(1)
    end

    return MeasureFS
end

local function GetGuildTargetScale(unit, db, gdb)
    if not unit or not db then return 1 end
    if UnitIsUnit(unit, "target") and not db.guildTextDisableTargetScale then
        return tonumber(gdb and gdb.nameplateSelectedScale) or 1.2
    end
    return 1
end

local function GetGuildDisplayColor(unit, db)
    local r, g, b
    if NS.UnitColor and NS.UnitColor.GetDisconnectedColor then
        r, g, b = NS.UnitColor.GetDisconnectedColor(unit)
    end
    if r ~= nil then
        return r, g, b
    end

    local c = db and db.guildTextColor or nil
    if not c then
        return 1, 1, 1
    end
    return c.r or 1, c.g or 1, c.b or 1
end

local function MeasureGuildTextHeight(text, db, gdb, scale)
    if not text or text == "" then return 0 end

    local fs = EnsureMeasureFontString()
    local fontScale = tonumber(scale) or 1
    if fontScale <= 0 then
        fontScale = 1
    end

    local fontSize = (tonumber(db and db.guildTextFontSize) or 7) * fontScale
    if not fs then
        return fontSize or 0
    end

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local outline = db and db.guildTextOutline or "SHADOW"
    local fontFlag = (outline ~= "NONE" and outline ~= "SHADOW") and outline or nil

    if not fs:SetFont(fontPath, fontSize, fontFlag) then
        fs:SetFont(STANDARD_TEXT_FONT, fontSize, fontFlag)
    end

    local width = (tonumber(db and db.guildTextWidth) or 135) * fontScale
    fs:SetWidth(width)
    fs:SetText(text)

    local h = (fs.GetStringHeight and fs:GetStringHeight()) or fontSize or 0
    if not h or h <= 0 then
        h = fontSize or 0
    end
    return h
end

local function CalculateNameShiftFromText(text, db, gdb, scale)
    if not db or db.guildTextEnable ~= true then return 0 end
    if (db.guildTextMode or "UNDER_NAME") ~= "UNDER_NAME" then return 0 end
    if not text or text == "" then return 0 end

    local offY = tonumber(db.guildTextY) or 0
    local gap = 1
    local guildHeight = MeasureGuildTextHeight(text, db, gdb, scale)
    return math.max(0, math.ceil(guildHeight) + gap - offY)
end

local function GetNameShift(frame, unit, db, gdb)
    if not frame or not unit or not db then return 0 end
    if db.nameEnable == false then return 0 end

    if NS.ShouldHideModuleOnSimplified and NS.ShouldHideModuleOnSimplified("GuildText", frame, unit) then
        return 0
    end

    if not UnitIsPlayer(unit) then return 0 end

    local guildName = GetGuildInfo(unit)
    local text = FormatGuildText(guildName)
    local targetScale = GetGuildTargetScale(unit, db, gdb)
    return CalculateNameShiftFromText(text, db, gdb, targetScale)
end

NS.GuildText_CalculateNameShift = CalculateNameShiftFromText
NS.GuildText_GetNameShift = GetNameShift


local function EnsureObjects(frame, st)
    if st.wrapper and st.fs then return end

    local parent = frame.healthBar or frame
    st.wrapper = st.wrapper or CreateFrame("Frame", nil, parent)
    st.wrapper:SetSize(1, 1)
    st.wrapper:Hide()

    st.fs = st.fs or st.wrapper:CreateFontString(nil, "OVERLAY", nil, 7)
    st.fs:Hide()

    if st.fs.SetIgnoreParentScale then
        st.fs:SetIgnoreParentScale(true)
    end
    st.fs:SetScale(1)
    st.fs:SetNonSpaceWrap(false)
    st.fs:SetWordWrap(false)
    if st.fs.SetMaxLines then
        st.fs:SetMaxLines(1)
    end

    frame.BPF_GuildTextWrapper = st.wrapper
    frame.BPF_GuildTextFS = st.fs
end




local function Hide(frame, db, st)
    if st.fs then st.fs:Hide() end
    if st.wrapper then st.wrapper:Hide() end
    st.lastVisible = false
    st.lastAnchorMode = nil
    st.lastAnchorRegion = nil
    st.lastPointAlign = nil
    st.lastText = nil
    st.lastMode = nil
end

local function ResolveNameAnchor(frame)
    local nameWrapper = frame and frame.BPF_NameTextWrapper
    if nameWrapper and nameWrapper.IsShown and nameWrapper:IsShown() then
        return nameWrapper, true
    end

    return nil, false
end

local function ResolveHealthBarAnchor(frame)
    return frame and (frame.healthBar or frame)
end

FormatGuildText = function(guildName)
    if not guildName or guildName == "" then return nil end
    if guildName:sub(1, 1) == "<" and guildName:sub(-1) == ">" then
        return guildName
    end
    return "<" .. guildName .. ">"
end

local function UpdateGuildText(frame, unit, db, gdb)
    if not frame or frame:IsForbidden() or not frame.healthBar or not db or not unit then return end

    local st = GetState(frame)

    if not db.guildTextEnable then
        Hide(frame, db, st)
        return
    end

    if NS.ShouldHideModuleOnSimplified and NS.ShouldHideModuleOnSimplified("GuildText", frame, unit) then
        Hide(frame, db, st)
        return
    end

    if not UnitIsPlayer(unit) then
        Hide(frame, db, st)
        return
    end

    local guildName = GetGuildInfo(unit)
    local text = FormatGuildText(guildName)
    if not text then
        Hide(frame, db, st)
        return
    end

    EnsureObjects(frame, st)
    local fs = st.fs
    local wrapper = st.wrapper
    if not fs or not wrapper then return end

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local targetScale = GetGuildTargetScale(unit, db, gdb)
    local fontSize = (db.guildTextFontSize or 7) * targetScale
    local outline = db.guildTextOutline or "SHADOW"
    local fontFlag = (outline ~= "NONE" and outline ~= "SHADOW") and outline or nil
    local wantShadow = (outline == "SHADOW")

    if st.lastFontPath ~= fontPath or st.lastFontSize ~= fontSize or st.lastFontFlag ~= fontFlag then
        if not fs:SetFont(fontPath, fontSize, fontFlag) then
            fs:SetFont(STANDARD_TEXT_FONT, fontSize, fontFlag)
        end
        st.lastFontPath = fontPath
        st.lastFontSize = fontSize
        st.lastFontFlag = fontFlag
    end

    if st.lastShadow ~= wantShadow then
        if wantShadow then
            fs:SetShadowOffset(1, -1)
            fs:SetShadowColor(0, 0, 0, 1)
        else
            fs:SetShadowOffset(0, 0)
        end
        st.lastShadow = wantShadow
    end

    if st.lastText ~= text then
        fs:SetText(text)
        st.lastText = text
    end

    local width = (db.guildTextWidth or 135) * targetScale
    if st.lastWidth ~= width then
        fs:SetWidth(width)
        st.lastWidth = width
    end

    local align = db.guildTextAlign or "CENTER"
    if st.lastAlign ~= align then
        fs:SetJustifyH(align)
        fs:SetJustifyV("TOP")
        fs:ClearAllPoints()
        if align == "LEFT" then
            fs:SetPoint("TOPLEFT", wrapper, "TOPLEFT", 0, 0)
        elseif align == "RIGHT" then
            fs:SetPoint("TOPRIGHT", wrapper, "TOPRIGHT", 0, 0)
        else
            fs:SetPoint("TOP", wrapper, "TOP", 0, 0)
        end
        st.lastAlign = align
    end

    local r, g, b = GetGuildDisplayColor(unit, db)
    if st.lastColorR ~= r or st.lastColorG ~= g or st.lastColorB ~= b then
        fs:SetTextColor(r, g, b)
        st.lastColorR, st.lastColorG, st.lastColorB = r, g, b
    end

    local offX = db.guildTextX or 0
    local offY = db.guildTextY or 0
    local mode = db.guildTextMode or "UNDER_NAME"

    local anchorRegion
    local anchorMode

    if mode == "UNDER_NAME" then
        local nameAnchor, hasNameAnchor = ResolveNameAnchor(frame)
        if hasNameAnchor and nameAnchor then
            anchorRegion = nameAnchor
            anchorMode = "NAME"
        else
            anchorRegion = ResolveHealthBarAnchor(frame)
            anchorMode = "BAR"
        end
    else
        anchorRegion = ResolveHealthBarAnchor(frame)
        anchorMode = "BAR"
    end

    if st.lastAnchorMode ~= anchorMode or st.lastAnchorRegion ~= anchorRegion or st.lastPointAlign ~= align or st.lastX ~= offX or st.lastY ~= offY or st.lastMode ~= mode then
        wrapper:ClearAllPoints()
        if anchorMode == "NAME" then
            if align == "LEFT" then
                wrapper:SetPoint("TOPLEFT", anchorRegion, "BOTTOMLEFT", offX, offY)
            elseif align == "RIGHT" then
                wrapper:SetPoint("TOPRIGHT", anchorRegion, "BOTTOMRIGHT", offX, offY)
            else
                wrapper:SetPoint("TOP", anchorRegion, "BOTTOM", offX, offY)
            end
        else
            if align == "LEFT" then
                wrapper:SetPoint("TOPLEFT", anchorRegion, "BOTTOMLEFT", offX, offY)
            elseif align == "RIGHT" then
                wrapper:SetPoint("TOPRIGHT", anchorRegion, "BOTTOMRIGHT", offX, offY)
            else
                wrapper:SetPoint("TOP", anchorRegion, "BOTTOM", offX, offY)
            end
        end
        st.lastAnchorMode = anchorMode
        st.lastAnchorRegion = anchorRegion
        st.lastPointAlign = align
        st.lastX = offX
        st.lastY = offY
        st.lastMode = mode
    end

    if not wrapper:IsShown() then wrapper:Show() end
    if not fs:IsShown() then fs:Show() end
    st.lastVisible = true
end

NS.Modules.GuildText = {
    GetNameShift = GetNameShift,
    CalculateNameShift = CalculateNameShiftFromText,
    Init = function(frame)
        if not frame or frame:IsForbidden() then return end
        local st = GetState(frame)
        EnsureObjects(frame, st)
    end,
    Update = function(frame, unit, db, gdb)
        UpdateGuildText(frame, unit, db, gdb)
    end,
    Reset = function(frame)
        local st = GetState(frame)
        if st.fs then st.fs:Hide() end
        if st.wrapper then st.wrapper:Hide() end
        st.lastVisible = false
        st.lastAnchorMode = nil
        st.lastAnchorRegion = nil
        st.lastPointAlign = nil
        st.lastText = nil
        st.lastMode = nil
    end,
}
