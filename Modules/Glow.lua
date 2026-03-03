local _, NS = ...

local LastHighlightedFrame = nil

local DEFAULT_R, DEFAULT_G, DEFAULT_B = 1, 1, 1
local DEFAULT_A = 0.5

local function HideGlow(frame)
    if frame and frame.BPF_MouseoverGlow then
        if frame.BPF_MouseoverGlowShown then
            frame.BPF_MouseoverGlow:Hide()
            frame.BPF_MouseoverGlowShown = false
        end
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

    local c = db.mouseoverGlowColor
    local r = (c and c.r) or DEFAULT_R
    local g = (c and c.g) or DEFAULT_G
    local b = (c and c.b) or DEFAULT_B
    local a = db.mouseoverGlowAlpha or DEFAULT_A

    if frame.BPF_MouseoverGlowR ~= r or frame.BPF_MouseoverGlowG ~= g or frame.BPF_MouseoverGlowB ~= b or frame.BPF_MouseoverGlowA ~= a then
        frame.BPF_MouseoverGlow:SetVertexColor(r, g, b, a)
        frame.BPF_MouseoverGlowR, frame.BPF_MouseoverGlowG, frame.BPF_MouseoverGlowB, frame.BPF_MouseoverGlowA = r, g, b, a
    end

    if not frame.BPF_MouseoverGlowShown then
        frame.BPF_MouseoverGlow:Show()
        frame.BPF_MouseoverGlowShown = true
    end
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

        frame.BPF_MouseoverGlowR = nil
        frame.BPF_MouseoverGlowG = nil
        frame.BPF_MouseoverGlowB = nil
        frame.BPF_MouseoverGlowA = nil
        frame.BPF_MouseoverGlowShown = false
        
        -- Очищаем кэш, чтобы избежать утечек при пулинге фреймов
        if LastHighlightedFrame == frame then
            LastHighlightedFrame = nil
        end
    end
}