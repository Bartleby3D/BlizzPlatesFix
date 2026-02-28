local _, NS = ...

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT

local TimerManager = CreateFrame("Frame")
TimerManager:Hide()

local UPDATE_INTERVAL = 0.10
local acc = 0

local Active = setmetatable({}, { __mode = "k" })
local Hooked = setmetatable({}, { __mode = "k" })
local UnitByCB = setmetatable({}, { __mode = "k" })

local function GetState(cb)
    local st = Active[cb]
    if st then return st end

    st = {
        text = nil,
        unit = nil,
        db = nil, -- Храним настройки
        gdb = nil,

        lastFont = nil,
        lastSize = nil,
        lastOutline = nil,
        lastShadow = nil,
        lastColorR = nil,
        lastColorG = nil,
        lastColorB = nil,
        lastX = nil,
        lastY = nil,
        lastModeIcon = nil,
    }

    Active[cb] = st
    return st
end

local function ApplyStyleAndPosition(cb, st)
    local db = st.db
    local gdb = st.gdb
    if not db then return end

    if not st.text then
        st.text = cb:CreateFontString(nil, "OVERLAY", nil, 7)
    end

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local size = db.cbTimerFontSize or 12
    local style = db.cbTimerOutline or "OUTLINE"

    local outlineFlag
    if style == "SHADOW" or style == "NONE" then
        outlineFlag = nil
    else
        outlineFlag = style
    end

    if st.lastFont ~= fontPath or st.lastSize ~= size or st.lastOutline ~= outlineFlag then
        if not st.text:SetFont(fontPath, size, outlineFlag) then
            st.text:SetFont(STANDARD_TEXT_FONT, size, outlineFlag)
        end
        st.lastFont, st.lastSize, st.lastOutline = fontPath, size, outlineFlag
    end

    local wantShadow = (style == "SHADOW")
    if st.lastShadow ~= wantShadow then
        if wantShadow then
            st.text:SetShadowOffset(1, -1)
            st.text:SetShadowColor(0, 0, 0, 1)
        else
            st.text:SetShadowOffset(0, 0)
        end
        st.lastShadow = wantShadow
    end

    local c = db.cbTimerColor or { r = 1, g = 1, b = 1 }
    if st.lastColorR ~= c.r or st.lastColorG ~= c.g or st.lastColorB ~= c.b then
        st.text:SetTextColor(c.r, c.g, c.b)
        st.lastColorR, st.lastColorG, st.lastColorB = c.r, c.g, c.b
    end

    local x = db.cbTimerX or 0
    local y = db.cbTimerY or 0
    local iconMode = db.cbIconEnabled and true or false

    if st.lastX ~= x or st.lastY ~= y or st.lastModeIcon ~= iconMode then
        st.text:ClearAllPoints()

        if iconMode then
            local iconX = (db.cbIconX or -10)
            local iconY = (db.cbIconY or 0)
            local iconSize = (db.cbIconSize or 18)

            st.text:SetPoint("CENTER", cb, "LEFT",
                iconX - (iconSize * 0.5) + x,
                iconY + y
            )
        else
            st.text:SetPoint("RIGHT", cb, "RIGHT", x - 5, y)
        end

        st.lastX, st.lastY, st.lastModeIcon = x, y, iconMode
    end
end

local function RemoveCB(cb)
    local st = Active[cb]
    if st and st.text then st.text:Hide() end
    Active[cb] = nil
    if next(Active) == nil then
        TimerManager:Hide()
    end
end

local function RegisterCB(cb)
    local unit = UnitByCB[cb]
    if not unit then return end
    
    -- Получаем актуальный конфиг
    local db, gdb = NS.GetUnitConfig(unit)
    if not db or not db.cbEnabled or not db.cbTimerEnabled then return end

    if cb:IsForbidden() or not cb:IsShown() then return end

    local st = GetState(cb)
    st.unit = unit
    st.db = db
    st.gdb = gdb

    ApplyStyleAndPosition(cb, st)

    TimerManager:Show()
end

TimerManager:SetScript("OnUpdate", function(_, elapsed)
    if next(Active) == nil then
        TimerManager:Hide()
        return
    end

    acc = acc + elapsed
    if acc < UPDATE_INTERVAL then return end
    acc = 0

    for cb, st in pairs(Active) do
        if not cb or cb:IsForbidden() or not cb:IsShown() or not st.unit then
            RemoveCB(cb)
        else
            local durationObj = UnitCastingDuration(st.unit) or UnitChannelDuration(st.unit)
            if durationObj then
                local timeLeft = durationObj:GetRemainingDuration()
                local fmt = st.db and st.db.cbTimerFormat or "%.1f"
                st.text:SetText(string.format(fmt, timeLeft))
                st.text:Show()
            else
                st.text:Hide()
            end
        end
    end
end)

local function EnsureHooks(cb)
    if Hooked[cb] then return end
    Hooked[cb] = true

    cb:HookScript("OnShow", function()
        RegisterCB(cb)
    end)

    cb:HookScript("OnHide", function()
        RemoveCB(cb)
    end)
end

NS.Modules.CastTimer = {
    Update = function(frame, unit, db, gdb)
        if not frame or frame:IsForbidden() or not frame.castBar then return end
        local cb = frame.castBar
        if not db then return end

        UnitByCB[cb] = unit
        EnsureHooks(cb)

        if not db.cbEnabled or not db.cbTimerEnabled then
            RemoveCB(cb)
            return
        end

        if cb:IsShown() then
            RegisterCB(cb)
        else
            RemoveCB(cb)
        end
    end,
    Reset = function(frame)
        if frame and frame.castBar then
            RemoveCB(frame.castBar)
        end
    end
}