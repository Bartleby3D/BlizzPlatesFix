local _, NS = ...

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        lastVisible = nil,
        lastScale = nil,
        lastColorR = nil,
        lastColorG = nil,
        lastColorB = nil,
    }
    State[frame] = st
    return st
end


-- Добавляем аргументы unit, db, gdb
local function UpdateBorder(frame, unit, db, gdb)
    if not frame or frame:IsForbidden() then return end

    local hb = frame.healthBar
    if not hb then return end

    -- Используем ТВОЙ объект selectedBorder
    local border = hb.selectedBorder
    if not border then return end

    -- УБРАНО: local db = BlizzPlatesFixDB
    -- Теперь мы используем db, который передан в функцию (это настройки конкретного типа юнита)
    if not db then return end

    local st = GetState(frame)

    -- Логика проверки цели
    local isTarget = UnitIsUnit(unit, "target")
    local shouldShow = db.targetIndicatorEnable and db.targetBorderEnabled and isTarget

    if st.lastVisible ~= shouldShow then
        if shouldShow then
            border:Show()
            -- Твой слой отрисовки
            border:SetDrawLayer("OVERLAY", 6)
        else
            border:Hide()
            -- Сброс масштаба
            border:SetScale(1.0)
        end
        st.lastVisible = shouldShow
    end

    if not shouldShow then
        st.lastScale = nil
        st.lastColorR = nil
        st.lastColorG = nil
        st.lastColorB = nil
        return
    end

    -- Толщина рамки фиксирована (настройка удалена).
    local thick = 1.0
    if st.lastScale ~= thick then
        border:SetScale(thick)
        st.lastScale = thick
    end

    -- Твоя логика цвета
    local c = db.targetBorderColor
    local r = (c and c.r) or 1
    local g = (c and c.g) or 1
    local b = (c and c.b) or 1
    if st.lastColorR ~= r or st.lastColorG ~= g or st.lastColorB ~= b then
        border:SetVertexColor(r, g, b, 1)
        st.lastColorR, st.lastColorG, st.lastColorB = r, g, b
    end
end

-- Обновленная точка входа
NS.Modules.Border = {
    Update = function(frame, unit, db, gdb)
        UpdateBorder(frame, unit, db, gdb)
    end,
    Reset = function(frame)
        if frame and frame.healthBar and frame.healthBar.selectedBorder then
            frame.healthBar.selectedBorder:Hide()
            frame.healthBar.selectedBorder:SetScale(1.0)
        end
        local st = State[frame]
        if not st then return end
        st.lastVisible = false
        st.lastScale = nil
        st.lastColorR = nil
        st.lastColorG = nil
        st.lastColorB = nil
    end
}