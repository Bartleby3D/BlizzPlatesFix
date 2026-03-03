local _, NS = ...

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT
local CastBarState = setmetatable({}, { __mode = "k" }) -- key = castBar

local function ApplyBarVisibility(cb, db)
    if not cb or not db then return end
    local show = (db.cbBarEnabled ~= false)

    local tex = cb.GetStatusBarTexture and cb:GetStatusBarTexture()
    if tex then tex:SetAlpha(show and 1 or 0) end

    -- разные версии/шаблоны неймплейтов могут использовать разные имена
    if cb.Background then cb.Background:SetAlpha(show and 1 or 0) end
    if cb.BG then cb.BG:SetAlpha(show and 1 or 0) end
    if cb.bg then cb.bg:SetAlpha(show and 1 or 0) end
    if cb.Spark then cb.Spark:SetAlpha(show and 1 or 0) end
end

local function GetState(cb)
    local st = CastBarState[cb]
    if st then return st end
    st = {
        icon = nil,
        iconBorder = nil, -- Добавлено состояние обводки
        castText = nil,
        targetText = nil,
        unit = nil,
    }
    CastBarState[cb] = st
    return st
end

local function GetClassColorRGB(unit)
    if not unit or not UnitExists(unit) then return 0.8, 0.8, 0.8 end
    
    -- 1. Игроки и компаньоны (например, Бранн): красим по классу
    if UnitIsPlayer(unit) or (UnitTreatAsPlayerForDisplay and UnitTreatAsPlayerForDisplay(unit)) then
        local _, classFile = UnitClass(unit)
        if classFile then
            local c = C_ClassColor.GetClassColor(classFile)
            if c then return c.r, c.g, c.b end
        end
    end
    
    -- 2. Остальные NPC: красим по стандартной реакции (Враг = красный, Нейтрал = желтый, Друг = зеленый)
    local r, g, b = UnitSelectionColor(unit)
    if r and g and b then
        return r, g, b
    end
    
    -- 3. Фоллбэк на случай непредвиденных ошибок API
    return 0.8, 0.8, 0.8
end

local function UpdateIconTexture(cb, st, db)
    if not cb or not st or not st.icon then return end
    
    if not db or not db.cbIconEnabled or not st.unit then
        st.icon:Hide()
        if st.iconBorder then st.iconBorder:Hide() end
        return
    end

    local _, _, texture = UnitCastingInfo(st.unit)
    if not texture then
        _, _, texture = UnitChannelInfo(st.unit)
    end

    if texture then
                st.icon:SetTexture(texture)
        st.icon:Show()
        if st.iconBorder then
            local showBorder = (db.cbIconBorderEnable ~= false) and ((tonumber(db.cbIconBorderThickness) or 0) > 0)
            if showBorder then
                st.iconBorder:Show()
            else
                st.iconBorder:Hide()
            end
        end
    else
        st.icon:Hide()
        if st.iconBorder then st.iconBorder:Hide() end
    end
end

local TargetManager = CreateFrame("Frame")
TargetManager:Hide()

local TARGET_INTERVAL = 0.20
local targetAcc = 0

local TargetActive = setmetatable({}, { __mode = "k" })

local function UpdateTargetText(cb, st, db)
    if not db or not st or not st.unit or not st.targetText then return end

    if not db.cbTargetEnabled then
        st.targetText:Hide()
        return
    end

    local unit = st.unit

    if st.lastUnit ~= unit then
        st.unitTarget = unit .. "target"
        st.lastUnit = unit
    end
    local unitTarget = st.unitTarget
    local name = UnitName(unitTarget)
    if name then
        st.targetText:SetText(" |cffFF0000=>|r " .. name)

        if db.cbTargetMode == "CLASS" then
            local cr, cg, cbCol = GetClassColorRGB(unitTarget)
            st.targetText:SetTextColor(cr, cg, cbCol)
        else
            local tc = db.cbTargetColor
            local r = (tc and tc.r) or 0.8
            local g = (tc and tc.g) or 0.8
            local b = (tc and tc.b) or 0.8
            st.targetText:SetTextColor(r, g, b)
        end

        st.targetText:Show()
    else
        st.targetText:Hide()
    end
end

local function RegisterTarget(cb)
    TargetActive[cb] = true
    TargetManager:Show()
end

local function UnregisterTarget(cb)
    TargetActive[cb] = nil
    if next(TargetActive) == nil then
        TargetManager:Hide()
    end
end

TargetManager:SetScript("OnUpdate", function(_, elapsed)
    targetAcc = targetAcc + elapsed
    if targetAcc < TARGET_INTERVAL then return end
    targetAcc = 0

    if next(TargetActive) == nil then
        TargetManager:Hide()
        return
    end

    for cb in pairs(TargetActive) do
        local st = CastBarState[cb]
        if not cb or cb:IsForbidden() or not cb:IsShown() or not st or not st.unit then
            if st and st.targetText then st.targetText:Hide() end
            TargetActive[cb] = nil
        else
            local db = NS.GetUnitConfig(st.unit)
            if db and db.cbEnabled and db.cbTargetEnabled then
                UpdateTargetText(cb, st, db)
            else
                if st.targetText then st.targetText:Hide() end
                TargetActive[cb] = nil
            end
        end
    end
end)

local function EnsureWidgets(cb, st)
    if not st.castText then
        st.castText = cb:CreateFontString(nil, "OVERLAY", nil, 7)
    end
    if not st.targetText then
        st.targetText = cb:CreateFontString(nil, "OVERLAY", nil, 7)
    end
    if not st.icon then
        -- Иконка на подуровне 1
        st.icon = cb:CreateTexture(nil, "OVERLAY", nil, 1)
        st.icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
    end
    if not st.iconBorder then
        -- Чёрная обводка на подуровне 0 (под иконкой)
        st.iconBorder = cb:CreateTexture(nil, "OVERLAY", nil, 0)
        st.iconBorder:SetColorTexture(1, 1, 1, 1)
        st.iconBorder:SetPoint("TOPLEFT", st.icon, "TOPLEFT", -2, 2)
        st.iconBorder:SetPoint("BOTTOMRIGHT", st.icon, "BOTTOMRIGHT", 2, -2)
    end
end

local function ApplyIconBorderStyle(st, db)
    if not st or not st.iconBorder or not st.icon or not db then return end

    local show = (db.cbIconEnabled ~= false) and (db.cbIconBorderEnable ~= false)
    local t = tonumber(db.cbIconBorderThickness) or 0
    if t < 0 then t = 0 end

    if not show or t == 0 then
        st.iconBorder:Hide()
        return
    end

    -- Ensure base is white so vertex color works
    st.iconBorder:SetColorTexture(1, 1, 1, 1)

    local c = db.cbIconBorderColor
    local r, g, b, a = 0, 0, 0, 1
    if type(c) == "table" then
        r = tonumber(c.r) or r
        g = tonumber(c.g) or g
        b = tonumber(c.b) or b
        a = tonumber(c.a) or a
    end
    st.iconBorder:SetVertexColor(r, g, b, a)

    st.iconBorder:ClearAllPoints()
    st.iconBorder:SetPoint("TOPLEFT", st.icon, "TOPLEFT", -t, t)
    st.iconBorder:SetPoint("BOTTOMRIGHT", st.icon, "BOTTOMRIGHT", t, -t)
    st.iconBorder:Show()
end

local function LayoutIcon(cb, st, db)
    if not st.icon then return end

    if db.cbIconEnabled then
        st.icon:ClearAllPoints()
        st.icon:SetPoint("RIGHT", cb, "LEFT", (db.cbIconX or -10), (db.cbIconY or 0))
        st.icon:SetSize(db.cbIconSize or 18, db.cbIconSize or 18)
        st.icon:Show()
        ApplyIconBorderStyle(st, db)
    else
        st.icon:Hide()
        if st.iconBorder then st.iconBorder:Hide() end
    end

    if cb.Icon then
        cb.Icon:SetAlpha(0)
        cb.Icon:ClearAllPoints()
        cb.Icon:SetPoint("RIGHT", cb, "LEFT", (db.cbIconX or -10), (db.cbIconY or 0))
        cb.Icon:SetSize(db.cbIconSize or 18, db.cbIconSize or 18)
    end
end

local function UpdateCastText(cb, st, db)
    if not db then return end

    if not db.cbEnabled then
        cb:Hide()
        cb:SetAlpha(0)
        if st.castText then st.castText:Hide() end
        if st.targetText then st.targetText:Hide() end
        if st.icon then st.icon:Hide() end
        if st.iconBorder then st.iconBorder:Hide() end
        UnregisterTarget(cb)
        return
    end
    if db.cbTextEnabled and st.castText and cb.Text then
        st.castText:SetText(cb.Text:GetText() or "")
    end
end

local function UpdateCastBarLayout(frame, unit, db, gdb)
    local cb = frame.castBar
    if not cb or frame:IsForbidden() then return end

    local st = GetState(cb)
    st.unit = unit
    
    if not db then return end

    if not db.cbEnabled then
        cb:Hide()
        cb:SetAlpha(0)
        if st.castText then st.castText:Hide() end
        if st.targetText then st.targetText:Hide() end
        if st.icon then st.icon:Hide() end
        if st.iconBorder then st.iconBorder:Hide() end
        UnregisterTarget(cb)
        return
    end

    if cb:GetParent() ~= frame then cb:SetParent(frame) end

    EnsureWidgets(cb, st)

    local activeFontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local barW, barH = db.cbWidth or 110, db.cbHeight or 15

    cb:ClearAllPoints()
    local barOffY = (db.cbY or -10) - ((db.plateHeight or 8) / 2)
    cb:SetPoint("TOP", frame, "CENTER", db.cbX or 0, barOffY)
    cb:SetSize(barW, barH)

    ApplyBarVisibility(cb, db)

    if cb.Text then cb.Text:SetAlpha(0) end
    if cb.CastTargetNameText then cb.CastTargetNameText:SetAlpha(0) end

    if db.cbTextEnabled then
        local fSize = db.cbFontSize or 10
        local outline = db.cbTextOutline or "OUTLINE"
        local flag = (outline ~= "NONE" and outline ~= "SHADOW") and outline or nil

        if not st.castText:SetFont(activeFontPath, fSize, flag) then
            st.castText:SetFont(STANDARD_TEXT_FONT, fSize, flag)
        end
        st.castText:SetShadowOffset(outline == "SHADOW" and 1 or 0, outline == "SHADOW" and -1 or 0)
        st.castText:SetJustifyH(db.cbTextJustify or "CENTER")
        st.castText:ClearAllPoints()

        local tx, ty = db.cbTextX or 0, db.cbTextY or 0
        local j = db.cbTextJustify or "CENTER"
        if j == "LEFT" then st.castText:SetPoint("LEFT", cb, "LEFT", tx + 4, ty)
        elseif j == "RIGHT" then st.castText:SetPoint("RIGHT", cb, "RIGHT", tx - 4, ty)
        else st.castText:SetPoint("CENTER", cb, "CENTER", tx, ty) end

        st.castText:SetWidth(db.cbTextMaxLength > 0 and (db.cbTextMaxLength * (fSize * 0.75)) or (barW - 8))
        st.castText:SetWordWrap(false)

        local tc = db.cbTextColor
        local r = (tc and tc.r) or 1
        local g = (tc and tc.g) or 1
        local b = (tc and tc.b) or 1
        st.castText:SetTextColor(r, g, b)
        st.castText:Show()
    else
        st.castText:Hide()
    end

    if db.cbTargetEnabled then
        local tSize = db.cbTargetFontSize or 10
        local tOutline = db.cbTargetOutline or "OUTLINE"
        local tFlag = (tOutline ~= "NONE" and tOutline ~= "SHADOW") and tOutline or nil

        if not st.targetText:SetFont(activeFontPath, tSize, tFlag) then
            st.targetText:SetFont(STANDARD_TEXT_FONT, tSize, tFlag)
        end
        st.targetText:SetShadowOffset(tOutline == "SHADOW" and 1 or 0, tOutline == "SHADOW" and -1 or 0)

        local tJustify = db.cbTargetJustify or "LEFT"
        st.targetText:SetJustifyH(tJustify)
        st.targetText:ClearAllPoints()

        local tX, tY = db.cbTargetX or 0, db.cbTargetY or 0
        if tJustify == "LEFT" then st.targetText:SetPoint("LEFT", cb, "LEFT", tX + 4, tY)
        elseif tJustify == "RIGHT" then st.targetText:SetPoint("RIGHT", cb, "RIGHT", tX - 4, tY)
        else st.targetText:SetPoint("CENTER", cb, "CENTER", tX, tY) end

        st.targetText:SetWidth(db.cbTargetMaxLength > 0 and (db.cbTargetMaxLength * (tSize * 0.75)) or (barW - 8))
        st.targetText:SetWordWrap(false)
    else
        st.targetText:Hide()
    end

    LayoutIcon(cb, st, db)

    if cb.Border then cb.Border:SetAlpha(0) end
    if cb.Flash then cb.Flash:SetAlpha(0) end
    if cb.BorderShield then
        cb.BorderShield:SetAlpha((gdb and gdb.hideCastShield) and 0 or 1)
    end

    if (cb.casting or cb.channeling) and not cb:IsShown() then
        cb:Show()
    end

    UpdateCastText(cb, st, db)
    UpdateIconTexture(cb, st, db)

    if cb:IsShown() and db.cbTargetEnabled then
        RegisterTarget(cb)
        UpdateTargetText(cb, st, db)
    else
        UnregisterTarget(cb)
        if st.targetText then st.targetText:Hide() end
    end
end

local function UpdateCastBar(frame, unit, db, gdb)
    local cb = frame.castBar
    if not cb or frame:IsForbidden() then return end

    local st = GetState(cb)
    st.unit = unit
    
    if not db then return end

    if not frame.BPF_CastBarHooked then
        hooksecurefunc(cb, "Show", function(self)
            local curDB = NS.GetUnitConfig(st.unit)
            if curDB and not curDB.cbEnabled then
                self:Hide()
                self:SetAlpha(0)
            end
        end)

        cb:HookScript("OnShow", function()
            local curDB, curGDB = NS.GetUnitConfig(st.unit)
            if curDB then
                UpdateCastBarLayout(frame, st.unit, curDB, curGDB)
                UpdateIconTexture(cb, st, curDB)
                if curDB.cbTargetEnabled then
                    RegisterTarget(cb)
                    UpdateTargetText(cb, st, curDB)
                end
            end
        end)

        cb:HookScript("OnHide", function()
            if st.icon then st.icon:Hide() end
            if st.iconBorder then st.iconBorder:Hide() end
            if st.targetText then st.targetText:Hide() end
            UnregisterTarget(cb)
        end)

        cb:HookScript("OnSizeChanged", function()
            local curDB, curGDB = NS.GetUnitConfig(st.unit)
            if curDB then
                UpdateCastBarLayout(frame, st.unit, curDB, curGDB)
                UpdateIconTexture(cb, st, curDB)
            end
        end)

        if cb.Text then
            hooksecurefunc(cb.Text, "SetText", function()
                local curDB = NS.GetUnitConfig(st.unit)
                UpdateCastText(cb, st, curDB)
                UpdateIconTexture(cb, st, curDB)
            end)
        end

        if cb.BorderShield then
            hooksecurefunc(cb.BorderShield, "Show", function(self)
                local _, curGDB = NS.GetUnitConfig(st.unit)
                if curGDB and curGDB.hideCastShield then self:SetAlpha(0) end
            end)
        end

        if cb.CastTargetNameText then
            hooksecurefunc(cb.CastTargetNameText, "Show", function(self) self:SetAlpha(0) end)
        end

        frame.BPF_CastBarHooked = true
    end

    UpdateCastBarLayout(frame, unit, db, gdb)

    if db.cbEnabled and (cb.casting or cb.channeling) and not cb:IsShown() then
        cb:Show()
    end

    if cb:IsShown() then
        UpdateIconTexture(cb, st, db)
        if db.cbTargetEnabled then
            RegisterTarget(cb)
            UpdateTargetText(cb, st, db)
        else
            UnregisterTarget(cb)
            if st.targetText then st.targetText:Hide() end
        end
    else
        UnregisterTarget(cb)
        if st.targetText then st.targetText:Hide() end
    end
end

NS.Modules.CastBar = {
    Update = function(frame, unit, db, gdb)
        UpdateCastBar(frame, unit, db, gdb)
    end,
    Reset = function(frame)
        local cb = frame.castBar
        if cb then
            UnregisterTarget(cb)
            local st = CastBarState[cb]
            if st then
                if st.targetText then st.targetText:Hide() end
                if st.icon then st.icon:Hide() end
                if st.iconBorder then st.iconBorder:Hide() end
            end
        end
    end
}