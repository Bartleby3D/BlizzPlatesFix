local _, NS = ...

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        lastW = nil,
        lastH = nil,
        castKey = nil,
        lastAbsorbHide = nil,
        lastHealHide = nil,
        lastColorR = nil,
        lastColorG = nil,
        lastColorB = nil,
        lastUnit = nil,
        applied = false,
    }
    State[frame] = st
    return st
end

local function CaptureOriginal(frame, st)
    if st._origCaptured then return end
    local hb = frame.healthBar
    if not hb then return end

    st._origCaptured = true

    local okS, s = pcall(hb.GetScale, hb)
    if okS and s then
        st._origScale = s
    end

    if hb.barTexture and hb.barTexture.GetTexture then
        local okT, tex = pcall(hb.barTexture.GetTexture, hb.barTexture)
        if okT and tex then st._origBarTex = tex end
    end
    if hb.bgTexture and hb.bgTexture.GetTexture then
        local okB, tex = pcall(hb.bgTexture.GetTexture, hb.bgTexture)
        if okB and tex then st._origBgTex = tex end
    end
end

local function DisableCleanup(frame, st)
    local hb = frame.healthBar
    if hb then
        local container = frame.HealthBarsContainer
        if container then
            hb:ClearAllPoints()
            hb:SetAllPoints(container)
        else
            hb:ClearAllPoints()
            hb:SetAllPoints(frame)
        end

        if hb.overAbsorbGlow then hb.overAbsorbGlow:SetAlpha(1) end
        if hb.overHealAbsorbGlow then hb.overHealAbsorbGlow:SetAlpha(1) end
        if hb.myHealPrediction then hb.myHealPrediction:SetAlpha(1) end
        if hb.otherHealPrediction then hb.otherHealPrediction:SetAlpha(1) end
    end

    if frame.myHealPrediction then frame.myHealPrediction:SetAlpha(1) end
    if frame.otherHealPrediction then frame.otherHealPrediction:SetAlpha(1) end

    if frame.selectionHighlight and hb then
        frame.selectionHighlight:ClearAllPoints()
        frame.selectionHighlight:SetAllPoints(hb)
    end

    st.lastW = nil
    st.lastH = nil
    st.castKey = nil
    st.lastColorR = nil
    st.lastColorG = nil
    st.lastColorB = nil
    st.lastUnit = nil
    st.applied = false
end

local function ColorDiff(cr, cg, cb, r, g, b)
    if cr == nil or cg == nil or cb == nil then return true end
    local eps = 0.01
    return (math.abs(cr - r) > eps) or (math.abs(cg - g) > eps) or (math.abs(cb - b) > eps)
end

local function SafeNumber(v, fallback)
    local n = tonumber(tostring(v))
    if not n then return fallback end
    return n
end

local function GetAlphaSafe(obj, fallback)
    if not obj or not obj.GetAlpha then return fallback end
    local ok, a = pcall(obj.GetAlpha, obj)
    if ok and a ~= nil then return a end
    return fallback
end

local function SetHealthBarVisualAlpha(frame, hb, a)
    if not hb then return end

    local sbt = hb.GetStatusBarTexture and hb:GetStatusBarTexture()
    if sbt and sbt.SetAlpha then sbt:SetAlpha(a) end

    if hb.GetRegions then
        local regs = { hb:GetRegions() }
        for i = 1, #regs do
            local r = regs[i]
            if r and r.GetObjectType then
                local t = r:GetObjectType()
                if (t == "Texture" or t == "MaskTexture") and r.SetAlpha then
                    r:SetAlpha(a)
                end
            end
        end
    end

    if hb.GetChildren then
        local children = { hb:GetChildren() }
        for i = 1, #children do
            local ch = children[i]
            if ch then
                local cst = ch.GetStatusBarTexture and ch:GetStatusBarTexture()
                if cst and cst.SetAlpha then cst:SetAlpha(a) end

                if ch.GetRegions then
                    local cregs = { ch:GetRegions() }
                    for j = 1, #cregs do
                        local r = cregs[j]
                        if r and r.GetObjectType then
                            local t = r:GetObjectType()
                            if (t == "Texture" or t == "MaskTexture") and r.SetAlpha then
                                r:SetAlpha(a)
                            end
                        end
                    end
                end
            end
        end
    end

    local extra = {
        frame and frame.healthBarBackground,
        frame and frame.healthBarBorder,
        frame and frame.healthBarBackdrop,
        hb.background, hb.bg, hb.Bg, hb.Background,
        hb.border, hb.Border,
        hb.barTexture, hb.bgTexture,
        hb.overAbsorbGlow, hb.overHealAbsorbGlow,
        hb.myHealPrediction, hb.otherHealPrediction,
    }
    for i = 1, #extra do
        local o = extra[i]
        if o and o.SetAlpha then
            o:SetAlpha(a)
        end
    end
end

local function ComputeDesiredColor(unit, db, gdb)
    if not (NS.UnitColor and NS.UnitColor.GetColor) then
        return 1, 1, 1
    end

    return NS.UnitColor.GetColor(
        unit,
        db,
        gdb,
        "healthColorMode",
        "healthColor",
        "healthColorHostile",
        "healthColorFriendly",
        "healthColorNeutral",
        0.5, 0.5, 0.5,
        true
    )
end

local function ApplyHealthColor(frame, unit, db, gdb)
    local hb = frame and frame.healthBar
    if not hb then return end

    if not db or not gdb then
        db, gdb = NS.GetUnitConfig(unit)
    end
    if not db then return end

    local st = GetState(frame)
    if st.lastUnit ~= unit then
        st.lastUnit = unit
        st.lastColorR = nil
        st.lastColorG = nil
        st.lastColorB = nil
    end

    local r, g, b = ComputeDesiredColor(unit, db, gdb)
    if not r then return end

    local cr, cg, cb = hb:GetStatusBarColor()
    if st.lastColorR ~= r or st.lastColorG ~= g or st.lastColorB ~= b or ColorDiff(cr, cg, cb, r, g, b) then
        hb:SetStatusBarColor(r, g, b)
        st.lastColorR, st.lastColorG, st.lastColorB = r, g, b
    end
end

local function ApplyGeometry(frame, db, st)
    local hb = frame.healthBar
    if not hb then return end

    local w = SafeNumber(db.plateWidth, 140)
    local h = SafeNumber(db.plateHeight, 8)

    if w < 40 then w = 40 elseif w > 400 then w = 400 end
    if h < 2 then h = 2 elseif h > 60 then h = 60 end

    if st.lastW ~= w or st.lastH ~= h then
        hb:ClearAllPoints()
        hb:SetPoint("CENTER", frame, "CENTER", 0, 2)
        hb:SetSize(w, h)

        if frame.selectionHighlight then
            frame.selectionHighlight:ClearAllPoints()
            frame.selectionHighlight:SetAllPoints(hb)
        end

        st.lastW, st.lastH = w, h
        st.applied = true
    end

    if frame.CastBarContainer then
        local cbKey = w
        if st.castKey ~= cbKey then
            frame.CastBarContainer:SetWidth(w)
            frame.CastBarContainer:ClearAllPoints()
            frame.CastBarContainer:SetPoint("TOP", hb, "BOTTOM", 0, -5)
            st.castKey = cbKey
        end
    end
end

local function ApplyAbsorbHealToggles(frame, gdb, st)
    local hb = frame.healthBar
    if not hb then return end

    local function SetAlphaIfNeeded(obj, a)
        if not obj then return end
        local ok, cur = pcall(obj.GetAlpha, obj)
        if ok and cur ~= a then
            obj:SetAlpha(a)
        elseif not ok then
            obj:SetAlpha(a)
        end
    end

    local hideAbsorb = gdb and gdb.hideAbsorbGlow and true or false
    local aAbsorb = hideAbsorb and 0 or 1
    if st.lastAbsorbHide ~= hideAbsorb
        or (hb.overAbsorbGlow and hb.overAbsorbGlow:GetAlpha() ~= aAbsorb)
        or (hb.overHealAbsorbGlow and hb.overHealAbsorbGlow:GetAlpha() ~= aAbsorb) then
        SetAlphaIfNeeded(hb.overAbsorbGlow, aAbsorb)
        SetAlphaIfNeeded(hb.overHealAbsorbGlow, aAbsorb)
        st.lastAbsorbHide = hideAbsorb
    end

    local hideHeal = gdb and gdb.hideHealPrediction and true or false
    local aHeal = hideHeal and 0 or 1
    if st.lastHealHide ~= hideHeal
        or (hb.myHealPrediction and hb.myHealPrediction:GetAlpha() ~= aHeal)
        or (hb.otherHealPrediction and hb.otherHealPrediction:GetAlpha() ~= aHeal)
        or (frame.myHealPrediction and frame.myHealPrediction:GetAlpha() ~= aHeal)
        or (frame.otherHealPrediction and frame.otherHealPrediction:GetAlpha() ~= aHeal) then
        SetAlphaIfNeeded(hb.myHealPrediction, aHeal)
        SetAlphaIfNeeded(hb.otherHealPrediction, aHeal)
        SetAlphaIfNeeded(frame.myHealPrediction, aHeal)
        SetAlphaIfNeeded(frame.otherHealPrediction, aHeal)
        st.lastHealHide = hideHeal
    end
end

local function PostBlizzRecolor(frame)
    if not frame or frame:IsForbidden() then return end
    local unit = frame.unit
    if not unit or not unit:find("nameplate") then return end

    local db, gdb = NS.GetUnitConfig(unit)
    if not (db and db.enabled and db.hpBarEnable) then return end

    local st = GetState(frame)
    if st.lastUnit ~= unit then return end
    if st.lastColorR == nil or st.lastColorG == nil or st.lastColorB == nil then return end

    local hb = frame.healthBar
    if not hb then return end

    local cr, cg, cb = hb:GetStatusBarColor()
    if ColorDiff(cr, cg, cb, st.lastColorR, st.lastColorG, st.lastColorB) then
        hb:SetStatusBarColor(st.lastColorR, st.lastColorG, st.lastColorB)
    end

    ApplyAbsorbHealToggles(frame, gdb, st)
end

if _G.CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", PostBlizzRecolor)
end
if _G.CompactUnitFrame_UpdateThreatColor then
    hooksecurefunc("CompactUnitFrame_UpdateThreatColor", PostBlizzRecolor)
end

NS.Modules.HpBar = {
    Update = function(frame, unit, db, gdb)
        if not frame or frame:IsForbidden() then return end
        if not frame.healthBar then return end
        if not db then return end

        local st = GetState(frame)
        if db.hpBarEnable == false then
            local hb = frame.healthBar

            if not st._hpForcedHidden then
                st._hpForcedHidden = true
                st._hbAlpha = 1
                st._selAlpha = GetAlphaSafe(frame.selectionHighlight, 1)
                st._myHealAlpha = GetAlphaSafe(frame.myHealPrediction, 1)
                st._otherHealAlpha = GetAlphaSafe(frame.otherHealPrediction, 1)
            end

            SetHealthBarVisualAlpha(frame, hb, 0)
            if frame.myHealPrediction then frame.myHealPrediction:SetAlpha(0) end
            if frame.otherHealPrediction then frame.otherHealPrediction:SetAlpha(0) end
            if frame.selectionHighlight then frame.selectionHighlight:SetAlpha(0) end

            ApplyGeometry(frame, db, st)
            return
        end

        if st._hpForcedHidden then
            st._hpForcedHidden = false
            local hb = frame.healthBar
            if hb then
                SetHealthBarVisualAlpha(frame, hb, 1)
            end
            if frame.myHealPrediction then frame.myHealPrediction:SetAlpha(st._myHealAlpha or 1) end
            if frame.otherHealPrediction then frame.otherHealPrediction:SetAlpha(st._otherHealAlpha or 1) end
            if frame.selectionHighlight then frame.selectionHighlight:SetAlpha(st._selAlpha or 1) end
        end

        CaptureOriginal(frame, st)
        ApplyGeometry(frame, db, st)
        ApplyHealthColor(frame, unit, db, gdb)
        ApplyAbsorbHealToggles(frame, gdb, st)
    end,

    Reset = function(frame)
        local st = GetState(frame)
        DisableCleanup(frame, st)

        if _G.CompactUnitFrame_UpdateHealthColor and frame.unit then
            _G.CompactUnitFrame_UpdateHealthColor(frame)
        end
    end
}
