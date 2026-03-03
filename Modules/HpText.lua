local _, NS = ...

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT

-- Percent curve (0..1 -> 0..100) for numeric percent text
local PctCurve = C_CurveUtil and C_CurveUtil.CreateCurve()
if PctCurve then
    PctCurve:AddPoint(0, 0)
    PctCurve:AddPoint(1, 100)
end

-- Color curves for gradient (no math on secret values)
-- HP%: 0 => red, 1 => green
local HpColorCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve()
if HpColorCurve then
    -- type is optional; default linear is fine, but set if available
    if Enum and Enum.LuaCurveType and HpColorCurve.SetType then
        HpColorCurve:SetType(Enum.LuaCurveType.Linear)
    end
    HpColorCurve:AddPoint(0, CreateColor(1, 0, 0, 1))
    HpColorCurve:AddPoint(1, CreateColor(0, 1, 0, 1))
end

-- Darker curve for brackets (pre-scaled, no multiplication at runtime)
local HpBracketCurve = C_CurveUtil and C_CurveUtil.CreateColorCurve()
if HpBracketCurve then
    if Enum and Enum.LuaCurveType and HpBracketCurve.SetType then
        HpBracketCurve:SetType(Enum.LuaCurveType.Linear)
    end
    HpBracketCurve:AddPoint(0, CreateColor(0.7, 0,   0,   1))
    HpBracketCurve:AddPoint(1, CreateColor(0,   0.7, 0,   1))
end

local HiddenPool = CreateFrame("Frame")
HiddenPool:Hide()

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        lastFontPath  = nil,
        lastFontSize  = nil,
        lastFontFlag  = nil,
        lastFontStyle = nil,
        lastColorR    = nil,
        lastColorG    = nil,
        lastColorB    = nil,
        lastColorMode = nil,
        lastLayoutMode = nil,
        lastLayoutAlign = nil,
        lastLayoutX = nil,
        lastLayoutY = nil,
        lastMode      = nil,
    }
    State[frame] = st
    return st
end

local function GetLabels(frame, gdb)
    if not frame.BPF_ValueText then
        frame.BPF_ValueText = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.BPF_BrakL     = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.BPF_PctText   = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
        frame.BPF_BrakR     = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")

        -- Шрифт берем из глобальных настроек
        local path = NS.GetFontPath(gdb and gdb.globalFont)
        for _, l in ipairs({frame.BPF_ValueText, frame.BPF_BrakL, frame.BPF_PctText, frame.BPF_BrakR}) do
            l:SetFont(path or STANDARD_TEXT_FONT, 10, "OUTLINE")
            l:SetDrawLayer("OVERLAY", 7)
        end
    end
    return frame.BPF_ValueText, frame.BPF_BrakL, frame.BPF_PctText, frame.BPF_BrakR
end

local function ApplyStaticColor(vL, bL, pL, bR, mode, color)
    local r = (color and color.r) or 1
    local g = (color and color.g) or 1
    local b = (color and color.b) or 1

    if mode == "VALUE" then
        vL:SetTextColor(r, g, b)
    elseif mode == "PERCENT" then
        pL:SetTextColor(r, g, b)
        bR:SetTextColor(r, g, b) -- %
    else -- BOTH
        vL:SetTextColor(r, g, b)
        pL:SetTextColor(r, g, b)
        -- bracket tint (static only)
        local d = 0.7
        bL:SetTextColor(r*d, g*d, b*d)
        bR:SetTextColor(r*d, g*d, b*d)
    end
end

local function ApplyGradientColor(unit, vL, bL, pL, bR, mode)
    if not HpColorCurve then return false end

    local colMain = UnitHealthPercent(unit, true, HpColorCurve) -- returns Color (may contain secret values)
    if not colMain then return false end
    local r, g, b, a = colMain:GetRGBA()

    if mode == "VALUE" then
        vL:SetTextColor(r, g, b, a)

    elseif mode == "PERCENT" then
        pL:SetTextColor(r, g, b, a)
        bR:SetTextColor(r, g, b, a)

    else -- BOTH
        vL:SetTextColor(r, g, b, a)
        pL:SetTextColor(r, g, b, a)

        if HpBracketCurve then
            local colBr = UnitHealthPercent(unit, true, HpBracketCurve)
            if colBr then
                local br, bg, bb, ba = colBr:GetRGBA()
                bL:SetTextColor(br, bg, bb, ba)
                bR:SetTextColor(br, bg, bb, ba)
            else
                bL:SetTextColor(r, g, b, a)
                bR:SetTextColor(r, g, b, a)
            end
        else
            bL:SetTextColor(r, g, b, a)
            bR:SetTextColor(r, g, b, a)
        end
    end

    return true
end

local function UpdateHpText(frame, unit, db, gdb)
    local hb = frame.healthBar
    if not hb then return end

    if not db then return end

    local st = GetState(frame)

    local simplifiedHidden = NS.IsSimplifiedNotTarget(frame, unit)
    if simplifiedHidden then
        if frame.BPF_ValueText then
            frame.BPF_ValueText:Hide()
            frame.BPF_BrakL:Hide()
            frame.BPF_PctText:Hide()
            frame.BPF_BrakR:Hide()
        end
        st._wasSimplifiedHidden = true
        return
    elseif st._wasSimplifiedHidden then
        -- Leaving simplified mode (or became target): force layout to re-show labels
        st._wasSimplifiedHidden = false
        st.lastLayoutMode = nil
        st.lastLayoutAlign = nil
        st.lastLayoutX = nil
        st.lastLayoutY = nil
        st.lastMode = nil
    end


    if db.hpTextEnable == false then
        if frame.BPF_ValueText then
            frame.BPF_ValueText:Hide()
            frame.BPF_BrakL:Hide()
            frame.BPF_PctText:Hide()
            frame.BPF_BrakR:Hide()
        end
        st._disabled = true
        return
    end

    -- Если модуль был выключен, а затем включён обратно, нужно форсировать пересборку layout,
    -- иначе лейаут-блок не выполнится (ключи те же) и лейблы останутся скрытыми до релога.
    if st._disabled then
        st._disabled = false
        st.lastLayoutMode = nil
        st.lastLayoutAlign = nil
        st.lastLayoutX = nil
        st.lastLayoutY = nil
        st.lastMode = nil
    end

    local vL, bL, pL, bR = GetLabels(frame, gdb)

    -- 2) ШРИФТ
    local activePath = NS.GetFontPath(gdb.globalFont)
    local size = db.hpFontSize or 10
    local style = db.hpFontOutline or "OUTLINE"
    local fontStyle = (style == "NONE" or style == "SHADOW") and "" or style
    if st.lastFontPath ~= activePath or st.lastFontSize ~= size or st.lastFontFlag ~= fontStyle or st.lastFontStyle ~= style then
        if not vL:SetFont(activePath, size, fontStyle) then
            vL:SetFont(STANDARD_TEXT_FONT, size, fontStyle)
        end
        if style == "SHADOW" then
            vL:SetShadowOffset(1, -1)
            vL:SetShadowColor(0, 0, 0, 1)
        else
            vL:SetShadowOffset(0, 0)
        end

        if not bL:SetFont(activePath, size, fontStyle) then
            bL:SetFont(STANDARD_TEXT_FONT, size, fontStyle)
        end
        if style == "SHADOW" then
            bL:SetShadowOffset(1, -1)
            bL:SetShadowColor(0, 0, 0, 1)
        else
            bL:SetShadowOffset(0, 0)
        end

        if not pL:SetFont(activePath, size, fontStyle) then
            pL:SetFont(STANDARD_TEXT_FONT, size, fontStyle)
        end
        if style == "SHADOW" then
            pL:SetShadowOffset(1, -1)
            pL:SetShadowColor(0, 0, 0, 1)
        else
            pL:SetShadowOffset(0, 0)
        end

        if not bR:SetFont(activePath, size, fontStyle) then
            bR:SetFont(STANDARD_TEXT_FONT, size, fontStyle)
        end
        if style == "SHADOW" then
            bR:SetShadowOffset(1, -1)
            bR:SetShadowColor(0, 0, 0, 1)
        else
            bR:SetShadowOffset(0, 0)
        end

        st.lastFontPath = activePath
        st.lastFontSize = size
        st.lastFontFlag = fontStyle
        st.lastFontStyle = style
    end

    -- 3) LAYOUT
    local mode  = db.hpDisplayMode or "BOTH"
    local align = db.hpTextAlign or "CENTER"
    local offX  = db.hpOffsetX or 0
    local offY  = db.hpOffsetY or 0
    if st.lastLayoutMode ~= mode or st.lastLayoutAlign ~= align or st.lastLayoutX ~= offX or st.lastLayoutY ~= offY then
        st.lastLayoutMode = mode
        st.lastLayoutAlign = align
        st.lastLayoutX = offX
        st.lastLayoutY = offY

        vL:ClearAllPoints()
        bL:ClearAllPoints()
        pL:ClearAllPoints()
        bR:ClearAllPoints()

        local function HideAll()
            vL:Hide(); bL:Hide(); pL:Hide(); bR:Hide()
        end

        if mode == "VALUE" then
            HideAll()
            vL:Show()
            vL:SetPoint(align, hb, align, offX, offY)

        elseif mode == "PERCENT" then
            HideAll()
            pL:Show()
            bR:Hide()
            bR:SetText("")
            pL:SetPoint(align, hb, align, offX, offY)

        else -- BOTH
            bL:SetText(" (")
            bR:SetText(")")
            vL:Show(); bL:Show(); pL:Show(); bR:Show()

            if align == "RIGHT" then
                bR:SetPoint("RIGHT", hb, "RIGHT", offX, offY)
                pL:SetPoint("RIGHT", bR, "LEFT", 0, 0)
                bL:SetPoint("RIGHT", pL, "LEFT", 0, 0)
                vL:SetPoint("RIGHT", bL, "LEFT", 0, 0)
            elseif align == "LEFT" then
                vL:SetPoint("LEFT", hb, "LEFT", offX, offY)
                bL:SetPoint("LEFT", vL, "RIGHT", 0, 0)
                pL:SetPoint("LEFT", bL, "RIGHT", 0, 0)
                bR:SetPoint("LEFT", pL, "RIGHT", 0, 0)
            else
                vL:SetPoint("CENTER", hb, "CENTER", offX, offY)
                bL:SetPoint("LEFT", vL, "RIGHT", 0, 0)
                pL:SetPoint("LEFT", bL, "RIGHT", 0, 0)
                bR:SetPoint("LEFT", pL, "RIGHT", 0, 0)
            end
        end
    end

    -- 4) DATA
    vL:SetText(AbbreviateNumbers(UnitHealth(unit)))
    if mode == "PERCENT" or mode == "BOTH" then
        pL:SetFormattedText("%.0f%%", UnitHealthPercent(unit, true, PctCurve))
    else
        pL:SetFormattedText("%.0f", UnitHealthPercent(unit, true, PctCurve))
    end

    -- 5) COLOR
    local colorMode = db.hpColorMode or 2 -- (ВНИМАНИЕ: hpTextColorMode -> hpColorMode, унификация)
    local useGradient = (colorMode == 1)

    local modeKey = useGradient and "__gradient__" or "__static__"
    if st.lastMode ~= modeKey then
        st.lastMode = modeKey
        st.lastColorR = nil
        st.lastColorG = nil
        st.lastColorB = nil
        st.lastColorMode = nil
    end

    if useGradient and HpColorCurve then
        ApplyGradientColor(unit, vL, bL, pL, bR, mode)
        st.lastColorMode = "__gradient__"
    else
        local color = db.hpColor
        local r = (color and color.r) or 1
        local g = (color and color.g) or 1
        local b = (color and color.b) or 1
        if st.lastColorR ~= r or st.lastColorG ~= g or st.lastColorB ~= b or st.lastColorMode ~= mode then
            ApplyStaticColor(vL, bL, pL, bR, mode, color)
            st.lastColorR, st.lastColorG, st.lastColorB = r, g, b
            st.lastColorMode = mode
        end
    end

    -- 6) Очистка Blizzard
    local targets = {hb.TextString, hb.Text, hb.LeftText, hb.RightText}
    for _, o in ipairs(targets) do
        if o and o:GetParent() ~= HiddenPool then
            o:SetParent(HiddenPool)
        end
    end
end

NS.Modules.HpText = {
    Update = function(frame, unit, db, gdb)
        if not frame or frame:IsForbidden() then return end
        UpdateHpText(frame, unit, db, gdb)
    end,
    Reset = function(frame)
        if frame.BPF_ValueText then
            frame.BPF_ValueText:Hide()
            frame.BPF_BrakL:Hide()
            frame.BPF_PctText:Hide()
            frame.BPF_BrakR:Hide()
        end
        local st = State[frame]
        if st then st._disabled = true end
    end
}
