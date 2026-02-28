local _, NS = ...

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        lastVisible = nil,
        lastScale = nil,
        lastColorKey = nil,
    }
    State[frame] = st
    return st
end

local function ColorKey(c)
    if not c then return "nil" end
    return string.format("%.3f|%.3f|%.3f", c.r or 1, c.g or 1, c.b or 1)
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
        st.lastColorKey = nil
        return
    end

    -- Толщина рамки фиксирована (настройка удалена).
    local thick = 1.0
    if st.lastScale ~= thick then
        border:SetScale(thick)
        st.lastScale = thick
    end

    -- Твоя логика цвета
    local c = db.targetBorderColor or { r=1, g=1, b=1 }
    local ck = ColorKey(c)
    if st.lastColorKey ~= ck then
        border:SetVertexColor(c.r, c.g, c.b, 1)
        st.lastColorKey = ck
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
        local st = GetState(frame)
        st.lastVisible = false
        st.lastScale = nil
        st.lastColorKey = nil
    end
}