local _, NS = ...

local STANDARD_TEXT_FONT = _G.STANDARD_TEXT_FONT

-- 1. ТАБЛИЦА СИМВОЛОВ
-- Я переделал ключи в цифры (1, 2, 3), чтобы это легко ложилось в настройки (Dropdown)
local SYMBOLS = {
    [1] = {">", "<"},
    [2] = {"<", ">"},
    [3] = {"[", "]"},
    [4] = {"(", ")"},
    [5] = {"»", "«"},
    [6] = {"«", "»"},
    [7] = {"*", "*"},
}

local function GetSymbolPair(index)
    -- Если индекс пришел как строка (старый конфиг), или число
    if SYMBOLS[index] then return SYMBOLS[index] end
    return SYMBOLS[1]
end

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        inited = false,
        lastIsTarget = nil,
        
        -- Кэш состояния стрелки
        arrowShown = nil,
        arrowAnim = nil,
        arrowSize = nil,
        arrowX = nil,
        arrowY = nil,
        arrowColorR = nil,
        arrowColorG = nil,
        arrowColorB = nil,
        
        -- Кэш состояния символов
        symShown = nil,
        symOutline = nil,
        symSize = nil,
        symX = nil,
        symY = nil,
        symColorR = nil,
        symColorG = nil,
        symColorB = nil,
        symPairIndex = nil,
    }
    State[frame] = st
    return st
end


-- Создаем объекты (Текстуру стрелки и Текст символов)
local function EnsureObjects(frame)
    local st = GetState(frame)
    if st.inited then return end

    -- СТРЕЛКА
    frame.BPF_TargetArrow = frame:CreateTexture(nil, "OVERLAY", nil, 7)
    -- Используем стандартную стрелку квеста (как в твоем коде)
    frame.BPF_TargetArrow:SetTexture("Interface\\Minimap\\MiniMap-QuestArrow")
    frame.BPF_TargetArrow:SetTexCoord(0, 1, 1, 0) -- Поворот вниз
    frame.BPF_TargetArrow:Hide()

    -- АНИМАЦИЯ (Твой код)
    local ag = frame.BPF_TargetArrow:CreateAnimationGroup()
    local down = ag:CreateAnimation("Translation")
    down:SetOffset(0, -10)
    down:SetDuration(0.8)
    down:SetOrder(1)
    down:SetSmoothing("IN_OUT")
    
    local up = ag:CreateAnimation("Translation")
    up:SetOffset(0, 10)
    up:SetDuration(0.8)
    up:SetOrder(2)
    up:SetSmoothing("IN_OUT")
    
    ag:SetLooping("REPEAT")
    frame.BPF_TargetArrow.ag = ag

    -- СИМВОЛЫ
    frame.BPF_MarkerLeft = frame.healthBar:CreateFontString(nil, "OVERLAY", nil, 7)
    frame.BPF_MarkerRight = frame.healthBar:CreateFontString(nil, "OVERLAY", nil, 7)
    frame.BPF_MarkerLeft:Hide()
    frame.BPF_MarkerRight:Hide()

    st.inited = true
end

local function HideAll(frame, st)
    local arrow = frame.BPF_TargetArrow
    if arrow then
        arrow:Hide()
        if arrow.ag and arrow.ag:IsPlaying() then arrow.ag:Stop() end
    end
    
    if frame.BPF_MarkerLeft then frame.BPF_MarkerLeft:Hide() end
    if frame.BPF_MarkerRight then frame.BPF_MarkerRight:Hide() end

    st.lastIsTarget = false
    st.arrowShown = false
    -- Важно: сбрасываем флаг анимации, иначе при повторном выборе той же цели
    -- st.arrowAnim уже == true, и блок включения анимации не срабатывает.
    st.arrowAnim = nil
    st.symShown = false
    st.arrowX = nil
    st.arrowY = nil
    st.symX = nil
    st.symY = nil
    st.arrowColorR = nil
    st.arrowColorG = nil
    st.arrowColorB = nil
    st.symColorR = nil
    st.symColorG = nil
    st.symColorB = nil
end

local function UpdateTargetIndicator(frame, unit, db, gdb)
    if not frame or frame:IsForbidden() then return end
    if not frame.healthBar then return end

    -- Если настройки не пришли, выходим
    if not db then return end

    EnsureObjects(frame)
    local st = GetState(frame)

    -- Мастер-тумблер подвкладки "Индикация цели".
    -- При OFF должна отключаться вся индикация (стрелка + символы).
    if db.targetIndicatorEnable == false then
        if st.lastIsTarget ~= false or st.arrowShown or st.symShown then
            HideAll(frame, st)
        end
        return
    end

    local isTarget = UnitIsUnit(unit, "target")
    
    -- Если это не цель, скрываем всё и выходим
    if not isTarget then
        if st.lastIsTarget ~= false then 
            HideAll(frame, st) 
        end
        st.lastIsTarget = false
        return
    end

    st.lastIsTarget = true
    
    local arrow = frame.BPF_TargetArrow
    local left = frame.BPF_MarkerLeft
    local right = frame.BPF_MarkerRight

    -- =========================================================
    -- ЛОГИКА СТРЕЛКИ (ARROW)
    -- =========================================================
    if db.targetIndicatorArrowEnable then
        if not st.arrowShown then 
            arrow:Show()
            st.arrowShown = true 
            -- Если анимация включена, нужно явно стартовать при повторном показе стрелки
            -- (после снятия таргета AnimationGroup был остановлен).
            if db.targetIndicatorArrowAnim then
                if arrow.ag:IsPlaying() then arrow.ag:Stop() end
                arrow.ag:Play()
                st.arrowAnim = true
            end
        end
        
        local size = db.targetIndicatorArrowSize or 30
        if st.arrowSize ~= size then 
            arrow:SetSize(size, size)
            st.arrowSize = size 
        end
        
        local ax = db.targetIndicatorArrowX or 0
        local ay = db.targetIndicatorArrowY or 20

        if st.arrowX ~= ax or st.arrowY ~= ay then
            arrow:ClearAllPoints()
            arrow:SetPoint("BOTTOM", frame.healthBar, "TOP", ax, ay)
            st.arrowX, st.arrowY = ax, ay
        end

        local ac = db.targetIndicatorArrowColor
        local r = (ac and ac.r) or 1
        local g = (ac and ac.g) or 1
        local b = (ac and ac.b) or 1

        if st.arrowColorR ~= r or st.arrowColorG ~= g or st.arrowColorB ~= b then
            arrow:SetVertexColor(r, g, b)
            st.arrowColorR, st.arrowColorG, st.arrowColorB = r, g, b
        end
        
        local wantAnim = db.targetIndicatorArrowAnim and true or false
        if st.arrowAnim ~= wantAnim then
            if wantAnim then
                if not arrow.ag:IsPlaying() then arrow.ag:Play() end
            else
                if arrow.ag:IsPlaying() then arrow.ag:Stop() end
            end
            st.arrowAnim = wantAnim
        elseif wantAnim and not arrow.ag:IsPlaying() then
            -- На случай если AnimationGroup был остановлен (например, HideAll),
            -- но флаг st.arrowAnim уже true.
            arrow.ag:Play()
        end
    else
        -- Если стрелка выключена в настройках
        if st.arrowShown then
            arrow:Hide()
            if arrow.ag:IsPlaying() then arrow.ag:Stop() end
            st.arrowShown = false
            st.arrowAnim = nil
        end
    end

    -- =========================================================
    -- ЛОГИКА СИМВОЛОВ (SYMBOLS) > < [ ]
    -- =========================================================
    if db.targetIndicatorSymbolEnable then
        if not st.symShown then 
            left:Show()
            right:Show()
            st.symShown = true 
        end

        local fontPath = STANDARD_TEXT_FONT
        local fontSize = db.targetIndicatorSymbolSize or 18
        local outline = db.targetIndicatorSymbolOutline or "NONE"

        -- Обновление шрифта
        if st.symOutline ~= outline or st.symSize ~= fontSize then
            if outline == "SHADOW" then
                left:SetFont(fontPath, fontSize, nil)
                left:SetShadowColor(0, 0, 0, 1)
                left:SetShadowOffset(1, -1)
                
                right:SetFont(fontPath, fontSize, nil)
                right:SetShadowColor(0, 0, 0, 1)
                right:SetShadowOffset(1, -1)
            else
                local flag = (outline ~= "NONE") and outline or nil
                left:SetFont(fontPath, fontSize, flag)
                left:SetShadowOffset(0, 0)
                
                right:SetFont(fontPath, fontSize, flag)
                right:SetShadowOffset(0, 0)
            end
            st.symOutline = outline
            st.symSize = fontSize
        end

        -- Обновление самих скобок (Index)
        local idx = db.targetIndicatorSymbolIndex or 1
        if st.symPairIndex ~= idx then
            local pair = GetSymbolPair(idx)
            left:SetText(pair[1])
            right:SetText(pair[2])
            st.symPairIndex = idx
        end

        -- Цвет
        local sc = db.targetIndicatorSymbolColor
        local r = (sc and sc.r) or 1
        local g = (sc and sc.g) or 1
        local b = (sc and sc.b) or 1
        if st.symColorR ~= r or st.symColorG ~= g or st.symColorB ~= b then
            left:SetTextColor(r, g, b)
            right:SetTextColor(r, g, b)
            st.symColorR, st.symColorG, st.symColorB = r, g, b
        end

        -- Позиция
        local sx = db.targetIndicatorSymbolX or 10
        local sy = db.targetIndicatorSymbolY or 0

        if st.symX ~= sx or st.symY ~= sy then
            left:ClearAllPoints()
            right:ClearAllPoints()
            left:SetPoint("RIGHT", frame.healthBar, "LEFT", -sx, sy)
            right:SetPoint("LEFT", frame.healthBar, "RIGHT", sx, sy)
            st.symX, st.symY = sx, sy
        end
    else
        -- Если символы выключены
        if st.symShown then 
            left:Hide()
            right:Hide()
            st.symShown = false 
        end
    end
end

NS.Modules.TargetIndicator = {
    Update = function(frame, unit, db, gdb)
        UpdateTargetIndicator(frame, unit, db, gdb)
    end,
    Reset = function(frame)
        local st = GetState(frame)
        HideAll(frame, st)
    end
}