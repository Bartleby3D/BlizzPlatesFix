local _, NS = ...

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
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

local function ClearNameAnchorCache(st)
    st.lastNameWrapper = nil
    st.lastNameAlign = nil
    st.lastNameX = nil
    st.lastNameY = nil
    st.lastNameShift = nil
end

local function ApplyNameWrapperShift(frame, db, st, shiftY)
    local nameWrapper = frame and frame.BPF_NameTextWrapper
    local hb = frame and frame.healthBar
    if not nameWrapper or not hb or not db then
        ClearNameAnchorCache(st)
        return false
    end

    local align = db.textAlign or "CENTER"
    local offX = db.textX or 0
    local offY = (db.textY or 0) + (shiftY or 0)

    if st.lastNameWrapper ~= nameWrapper or st.lastNameAlign ~= align or st.lastNameX ~= offX or st.lastNameY ~= offY or st.lastNameShift ~= shiftY then
        nameWrapper:ClearAllPoints()
        if align == "LEFT" then
            nameWrapper:SetPoint("BOTTOMLEFT", hb, "TOPLEFT", offX, offY)
        elseif align == "RIGHT" then
            nameWrapper:SetPoint("BOTTOMRIGHT", hb, "TOPRIGHT", offX, offY)
        else
            nameWrapper:SetPoint("BOTTOM", hb, "TOP", offX, offY)
        end
        st.lastNameWrapper = nameWrapper
        st.lastNameAlign = align
        st.lastNameX = offX
        st.lastNameY = offY
        st.lastNameShift = shiftY
    end

    return true
end

local function RestoreNameWrapperShift(frame, db, st)
    if st and st.lastNameShift ~= nil and st.lastNameShift ~= 0 then
        ApplyNameWrapperShift(frame, db, st, 0)
    else
        ClearNameAnchorCache(st)
    end
end

local function Hide(frame, db, st)
    RestoreNameWrapperShift(frame, db, st)
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
    local nameFS = frame and frame.BPF_NameTextFS
    if nameFS and nameFS.IsShown and nameFS:IsShown() then
        return nameFS, true
    end

    local nameWrapper = frame and frame.BPF_NameTextWrapper
    if nameWrapper and nameWrapper.IsShown and nameWrapper:IsShown() then
        return nameWrapper, true
    end

    return nil, false
end

local function ResolveHealthBarAnchor(frame)
    return frame and (frame.healthBar or frame)
end

local function FormatGuildText(guildName)
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
    local fontSize = db.guildTextFontSize or 7
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

    local width = db.guildTextWidth or 135
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

    local c = db.guildTextColor or {}
    local r = c.r or 1
    local g = c.g or 1
    local b = c.b or 1
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
            local guildHeight = (fs.GetStringHeight and fs:GetStringHeight()) or fontSize or 0
            local gap = 1
            local nameShift = math.max(0, math.ceil(guildHeight) + gap - offY)
            ApplyNameWrapperShift(frame, db, st, nameShift)
            anchorRegion = ResolveNameAnchor(frame)
            if anchorRegion then
                anchorMode = "NAME"
            else
                anchorRegion = ResolveHealthBarAnchor(frame)
                anchorMode = "BAR"
            end
        else
            RestoreNameWrapperShift(frame, db, st)
            anchorRegion = ResolveHealthBarAnchor(frame)
            anchorMode = "BAR"
        end
    else
        RestoreNameWrapperShift(frame, db, st)
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
        ClearNameAnchorCache(st)
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
