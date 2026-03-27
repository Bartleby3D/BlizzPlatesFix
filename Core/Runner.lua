local _, NS = ...
NS.Modules = NS.Modules or {}

-- =============================================================
-- ГЛАВНЫЙ АПДЕЙТЕР
-- =============================================================

local _bit = _G.bit or _G.bit32
local bor = _bit and _bit.bor
local band = _bit and _bit.band
if not (bor and band) then
    bor = function() return -1 end
    band = function() return -1 end
end

local CORE_MASK = bor(bor(NS.REASON_PLATE or 1, NS.REASON_CONFIG or 128), NS.REASON_CVAR or 256)
function NS.UpdateAllModules(unit, reasonMask)
    if not unit then return end

    reasonMask = reasonMask or NS.REASON_ALL

    local coreNeeded = (reasonMask == NS.REASON_ALL) or (band(reasonMask, CORE_MASK) ~= 0)

    local frame = NS.ActiveNamePlates[unit]
    local namePlate

    if not frame then
        namePlate = C_NamePlate.GetNamePlateForUnit(unit)
        frame = namePlate and namePlate.UnitFrame
        if frame and not frame:IsForbidden() then
            NS.ActiveNamePlates[unit] = frame
        end
    end

    if not frame or frame:IsForbidden() then return end

    -- Widgets-only nameplates (интерактивные объекты/прогресс бары и т.п.).
    -- Для них нельзя рисовать наши HP/Level/Name, но нужно оставить Blizzard widgets.
    if _G.UnitNameplateShowsWidgetsOnly and _G.UnitNameplateShowsWidgetsOnly(unit) then
        -- Снимаем следы наших модулей, но НЕ прячем весь UnitFrame (иначе пропадут widgets).
        if NS.ModuleManager and NS.ModuleManager.ResetFrame then
            NS.ModuleManager.ResetFrame(frame)
        end

        -- Прячем только health/name-часть, чтобы не было "хвостов" от реюза.
        pcall(function()
            if frame.HealthBarsContainer then frame.HealthBarsContainer:Hide() end
            if frame.healthBar then frame.healthBar:Hide() end
            if frame.name then frame.name:Hide() end
        end)

        -- Сбрасываем наш core-cache, чтобы при реюзе под обычный юнит применилось заново.
        frame.BPF_CoreCache = nil
        frame.BPF_DisabledState = nil
        return
    else
        -- Если фрейм был в widgets-only режиме, возвращаем health/name контейнеры.
        if frame.HealthBarsContainer and not frame.HealthBarsContainer:IsShown() then
            pcall(frame.HealthBarsContainer.Show, frame.HealthBarsContainer)
        end
        if frame.healthBar and not frame.healthBar:IsShown() then
            pcall(frame.healthBar.Show, frame.healthBar)
        end
        if frame.name and not frame.name:IsShown() then
            pcall(frame.name.Show, frame.name)
        end
    end

    -- 1. ПОЛУЧАЕМ КОНФИГИ ДЛЯ КОНКРЕТНОГО ЮНИТА
    local dbUnit, dbGlobal = NS.GetUnitConfig(unit)
    
    -- Если конфиги еще не загрузились - выходим
    if not dbUnit or not dbGlobal then return end
    
    -- === ГЛАВНЫЙ ТУМБЛЕР ===
    -- Если профиль типа существ выключен: аддон перестает влиять на эту категорию.
    -- Важно: не используем GetPoint/GetNumPoints (это может давать taint на restricted nameplates).
    if not dbUnit.enabled then
        -- Если профиль выключен: выполняем безопасный откат один раз, дальше игнорируем, пока не включат.
        if frame.BPF_DisabledState and not coreNeeded then
            return
        end
        frame.BPF_DisabledState = true
        -- Профиль типа существ выключен: НЕ меняем геометрию/альфу/якоря, чтобы не ломать штатные неймплейты Blizzard.
        -- Только убираем следы наших модулей и прекращаем обработку.
        frame.BPF_DisabledHidden = nil
        frame.BPF_CoreCache = nil
        -- Если ранее был widgets-only suppress, вернем контейнеры (на случай реюза).
        if frame.BPF_WidgetsOnlySuppressed then
            frame.BPF_WidgetsOnlySuppressed = nil
            local ok
            if frame.HealthBarsContainer then pcall(frame.HealthBarsContainer.Show, frame.HealthBarsContainer) end
            if frame.healthBar then pcall(frame.healthBar.Show, frame.healthBar) end
            if frame.name then pcall(frame.name.Show, frame.name) end
        end

        if NS.ModuleManager and NS.ModuleManager.ResetFrame then
            NS.ModuleManager.ResetFrame(frame)
        end
        frame.BPF_CoreCache = nil
        return
    end

    -- профиль включен
    if frame.BPF_DisabledState then
        frame.BPF_DisabledState = nil
    end

    if not namePlate then
        namePlate = C_NamePlate.GetNamePlateForUnit(unit)
    end

	if coreNeeded then
	    -- 2) Глобальные настройки (Масштаб, Позиция) + Размеры из профиля юнита
    if namePlate then
        local scale = dbGlobal.globalScale or 1.0
        if scale < 0.1 then scale = 0.1 end

        local x = dbGlobal.globalX or 0
        local y = dbGlobal.globalY or 0
        
        -- Ширину/Высоту берем из профиля юнита.
        -- Если выключена подвкладка "Полоса здоровья" (hpBarEnable=false) — не применяем ее геометрию.
        local w, h
        if dbUnit.hpBarEnable == false then
            w, h = 110, 8
        else
            w = dbUnit.plateWidth or 110
            h = dbUnit.plateHeight or 8
	    	end

        local cache = frame.BPF_CoreCache
        if not cache then
            cache = {}
            frame.BPF_CoreCache = cache
        end

        local anchorChanged = (cache.anchorPlate ~= namePlate)

        if cache.scale ~= scale then
            frame:SetScale(scale)
            cache.scale = scale
        end

        if anchorChanged or cache.x ~= x or cache.y ~= y then
            frame:ClearAllPoints()
            frame:SetPoint("CENTER", namePlate, "CENTER", x, y)
            cache.x, cache.y = x, y
            cache.anchorPlate = namePlate
        end

        if cache.w ~= w or cache.h ~= h then
            frame:SetSize(w, h)
            cache.w, cache.h = w, h
	    end
	end
	end

    -- 4) Запуск модулей
    -- Передаем им настройки ЮНИТА и ГЛОБАЛЬНЫЕ
    if NS.ModuleManager and NS.ModuleManager.RunAll then
        NS.ModuleManager.RunAll(frame, unit, dbUnit, dbGlobal, reasonMask)
    else
        -- fallback на старую модель (на случай частичной загрузки)
        for name, func in pairs(NS.Modules) do
            if type(func) == "function" then
                local ok, err = pcall(func, frame, unit, dbUnit, dbGlobal)
                if not ok and NS.DEBUG then
                    print("|cffff0000" .. NS.L("BlizzPlatesFix error in module:") .. "|r", name, err)
                end
            end
        end
    end
end

function NS.ForceUpdateAll()
    if NS.Engine and NS.Engine.FlushAllNow then
        NS.Engine.FlushAllNow()
        return
    end

    for unitToken in pairs(NS.ActiveNamePlates) do
        NS.UpdateAllModules(unitToken, NS.REASON_ALL)
    end
end