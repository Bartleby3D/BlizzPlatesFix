local _, NS = ...

local State = setmetatable({}, { __mode = "k" })
local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        lastVisible = nil,
        lastBlizzShown = nil,
        lastFontPath = nil,
        lastFontSize = nil,
        lastFontFlag = nil,
        lastShadow = nil,
        lastText = nil,
        lastColorR = nil,
        lastColorG = nil,
        lastColorB = nil,
        lastSide = nil,
        lastX = nil,
        lastY = nil,
        lastJustify = nil,
    }
    State[frame] = st
    return st
end

local function GetMyLevelText(frame)
    if not frame.BPF_LevelText then
        frame.BPF_LevelText = frame:CreateFontString(nil, "OVERLAY", nil, 7)
    end
    return frame.BPF_LevelText
end


local function UpdateLevel(frame, unit, db, gdb)
    if not frame or frame:IsForbidden() then return end
    if not unit then return end
    if not db then return end

    local st = GetState(frame)
    local levelText = GetMyLevelText(frame)
    
    -- Если модуль выключен
    if not db.levelEnable then
        if st.lastVisible ~= false then
            levelText:Hide()
            st.lastVisible = false
        end
        return
    end

    local blizzName = frame.name or (frame.UnitFrame and frame.UnitFrame.name)
    local blizzShown = (not blizzName) or blizzName:IsShown()
    if st.lastBlizzShown ~= blizzShown then
        st.lastBlizzShown = blizzShown
    end
    if not blizzShown then
        if st.lastVisible ~= false then
            levelText:Hide()
            st.lastVisible = false
        end
        return
    end

    local classif = UnitClassification(unit)
    if classif == "minus" or classif == "trivial" then
        if st.lastVisible ~= false then
            levelText:Hide()
            st.lastVisible = false
        end
        return
    end

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local size = db.levelFontSize or 10
    local outline = db.levelFontOutline or "OUTLINE"
    local flag = (outline ~= "NONE" and outline ~= "SHADOW") and outline or nil
    local shadow = (outline == "SHADOW")

    if st.lastFontPath ~= fontPath or st.lastFontSize ~= size or st.lastFontFlag ~= flag then
        if not levelText:SetFont(fontPath, size, flag) then
            levelText:SetFont(STANDARD_TEXT_FONT, size, flag)
        end
        st.lastFontPath, st.lastFontSize, st.lastFontFlag = fontPath, size, flag
    end

    if st.lastShadow ~= shadow then
        if shadow then
            levelText:SetShadowOffset(1, -1)
            levelText:SetShadowColor(0, 0, 0, 1)
        else
            levelText:SetShadowOffset(0, 0)
        end
        st.lastShadow = shadow
    end

    local level = UnitLevel(unit)
    if level == -1 then
        if st.lastText ~= "??" then
            levelText:SetText("??")
            st.lastText = "??"
        end
        local r, g, b = 1, 0, 0
        if st.lastColorR ~= r or st.lastColorG ~= g or st.lastColorB ~= b then
            levelText:SetTextColor(r, g, b)
            st.lastColorR, st.lastColorG, st.lastColorB = r, g, b
        end
    else
        local txt = tostring(level)
        if st.lastText ~= txt then
            levelText:SetText(txt)
            st.lastText = txt
        end
        
        -- Логика цвета
        local r, g, b
        if db.levelColorMode == 2 then
            local c = db.levelColor
            r = (c and c.r) or 1
            g = (c and c.g) or 1
            b = (c and c.b) or 1
        else
            local c = GetQuestDifficultyColor(level)
            r, g, b = c.r, c.g, c.b
        end
        if st.lastColorR ~= r or st.lastColorG ~= g or st.lastColorB ~= b then
            levelText:SetTextColor(r, g, b)
            st.lastColorR, st.lastColorG, st.lastColorB = r, g, b
        end
    end

    local side = db.levelAnchor or "LEFT"
    local offX = db.levelX or 0
    local offY = db.levelY or 0
    if st.lastSide ~= side or st.lastX ~= offX or st.lastY ~= offY then
        levelText:ClearAllPoints()
        if side == "LEFT" then
            levelText:SetPoint("RIGHT", frame.healthBar, "LEFT", offX - 5, offY)
            levelText:SetJustifyH("RIGHT")
            st.lastJustify = "RIGHT"
        else
            levelText:SetPoint("LEFT", frame.healthBar, "RIGHT", offX + 5, offY)
            levelText:SetJustifyH("LEFT")
            st.lastJustify = "LEFT"
        end
        st.lastSide, st.lastX, st.lastY = side, offX, offY
    end

    if st.lastVisible ~= true then
        levelText:Show()
        st.lastVisible = true
    end
end

NS.Modules.Level = {
    Update = function(frame, unit, db, gdb)
        UpdateLevel(frame, unit, db, gdb)
    end,
    Reset = function(frame)
        local st = GetState(frame)
        if frame.BPF_LevelText then
            frame.BPF_LevelText:Hide()
        end
        st.lastVisible = false
        st.lastText = nil
    end
}