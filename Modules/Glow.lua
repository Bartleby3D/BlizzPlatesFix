local _, NS = ...

local LastHighlightedFrame = nil

local function HideGlow(frame)
    if frame and frame.BPF_MouseoverGlow then
        frame.BPF_MouseoverGlow:Hide()
    end
end

-- Теперь функция принимает db (настройки юнита), а не gdb
local function ShowGlow(frame, db)
    if not frame or frame:IsForbidden() then return end
    local hb = frame.healthBar
    if not hb then return end
    
    -- Если модуль отключен для этого типа юнита (учитываем master-тумблер подвкладки "Индикация цели")
    if not db or not db.targetIndicatorEnable or not db.mouseoverGlowEnable then return end

    if not frame.BPF_MouseoverGlow then
        frame.BPF_MouseoverGlow = hb:CreateTexture(nil, "ARTWORK", nil, 1)
        frame.BPF_MouseoverGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
        frame.BPF_MouseoverGlow:SetAllPoints(hb)
        frame.BPF_MouseoverGlow:SetBlendMode("ADD")
    end

    local c = db.mouseoverGlowColor or {r=1, g=1, b=1}
    frame.BPF_MouseoverGlow:SetVertexColor(c.r, c.g, c.b, db.mouseoverGlowAlpha or 0.5)
    frame.BPF_MouseoverGlow:Show()
end

function NS.UpdateMouseoverGlow()
    local unit = "mouseover"
    local currentNP = nil

    -- 1. Определяем, есть ли фрейм под мышкой
    if UnitExists(unit) and not UnitIsUnit(unit, "target") then
        local plate = C_NamePlate.GetNamePlateForUnit(unit)
        if plate and plate.UnitFrame then
            currentNP = plate.UnitFrame
        end
    end

    -- 2. Логика переключения
    if currentNP ~= LastHighlightedFrame then
        if LastHighlightedFrame then
            HideGlow(LastHighlightedFrame)
        end

        if currentNP then
            local db = NS.GetUnitConfig(unit)
            if db and db.enabled and db.targetIndicatorEnable and db.mouseoverGlowEnable then
                ShowGlow(currentNP, db)
            else
                HideGlow(currentNP)
            end
        end

        LastHighlightedFrame = currentNP
        return
    end

    -- 3) Если фрейм не сменился, всё равно поддерживаем актуальное состояние при изменении настроек.
    if currentNP then
        local db = NS.GetUnitConfig(unit)
        if db and db.enabled and db.targetIndicatorEnable and db.mouseoverGlowEnable then
            ShowGlow(currentNP, db)
        else
            HideGlow(currentNP)
        end
    end
end

-- Переводим модуль на стандарт Clean Code (с методом Reset)
NS.Modules.Glow = {
    Update = function(frame, unit, db, gdb) 
        -- Если это наша цель, скрываем mouseover glow
        if UnitIsUnit(unit, "target") then
            HideGlow(frame)
        end
    end,
    Reset = function(frame)
        HideGlow(frame)
        
        -- Очищаем кэш, чтобы избежать утечек при пулинге фреймов
        if LastHighlightedFrame == frame then
            LastHighlightedFrame = nil
        end
    end
}