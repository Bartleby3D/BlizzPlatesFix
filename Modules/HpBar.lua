local _, NS = ...

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        geomKey = nil,
        castKey = nil,
        lastAbsorbHide = nil,
        lastHealHide   = nil,
        lastColorKey   = nil,
        lastUnit       = nil,
        combatRedUntil = 0,
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

    -- НЕ читаем точки/размеры (GetPoint/GetSize) у nameplate StatusBar: это может дать taint/secret-number.
    -- Сохраняем только то, что обычно безопасно: scale и текстуры.
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
    -- Откат при выключении модуля должен быть БЕЗОПАСНЫМ:
    -- без измерений (GetPoint/GetSize) и без вызовов CompactUnitFrame_* на tainted фреймах.
    --
    -- Мы возвращаем только предсказуемую привязку healthBar к контейнеру и визуальные альфы.
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

    st.geomKey = nil
    st.castKey = nil
    st.lastColorKey = nil
    st.applied = false
end

local function ColorDiff(cr, cg, cb, r, g, b)
    if cr == nil or cg == nil or cb == nil then return true end
    local eps = 0.01
    return (math.abs(cr - r) > eps) or (math.abs(cg - g) > eps) or (math.abs(cb - b) > eps)
end

-- Приводим значения из DB к "обычным" числам (избавляемся от возможных secret-number/taint через tostring->tonumber).
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

-- Надежно прячет визуальные слои хпбара (текстуры/фон/оверлеи),
-- но НЕ трогает альфу самого healthBar фрейма и его детей (иначе можно скрыть чужие FontString'и, например имя).
-- Идея: оставляем hb как контейнер (alpha=1), а "картинку" прячем через альфу текстур.
local function SetHealthBarVisualAlpha(frame, hb, a)
    if not hb then return end

    -- Не меняем hb:SetAlpha(a) специально.

    -- 1) Основная текстура статусбара
    local sbt = hb.GetStatusBarTexture and hb:GetStatusBarTexture()
    if sbt and sbt.SetAlpha then sbt:SetAlpha(a) end

    -- 2) Регионы самого hb (только текстуры/маски)
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

    -- 3) Дети hb: не трогаем их alpha, прячем только их текстурные регионы/StatusBarTexture
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

    -- 4) Часто используемые алиасы у Blizzard/аддонов
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

-- Основная логика цвета
local function ComputeDesiredColor(frame, unit, db)
    -- 1. Если выбран "Свой цвет" (Mode 2), возвращаем его сразу
    -- (Игнорируем угрозу и прочее, если игрок захотел жестко задать цвет)
    if db.healthColorMode == 2 then
        -- Для NPC-вкладок: отдельные цвета для разных реакций
        local enemyNpcDB = NS.Config and NS.Config.GetUnitTypeTable and NS.Config.GetUnitTypeTable(NS.UNIT_TYPES.ENEMY_NPC)
        local friendlyNpcDB = NS.Config and NS.Config.GetUnitTypeTable and NS.Config.GetUnitTypeTable(NS.UNIT_TYPES.FRIENDLY_NPC)

        local c
        if enemyNpcDB and db == enemyNpcDB then
            local reaction = UnitReaction(unit, "player")
            if reaction == 4 then
                c = db.healthColorNeutral or db.healthColor
            else
                c = db.healthColorHostile or db.healthColor
            end
        elseif friendlyNpcDB and db == friendlyNpcDB then
            local reaction = UnitReaction(unit, "player")
            if reaction == 4 then
                c = db.healthColorNeutral or db.healthColor
            else
                c = db.healthColorFriendly or db.healthColor
            end
        else
            c = db.healthColor
        end

        c = c or {r=1, g=1, b=1}
        return c.r, c.g, c.b
    end

    -- 2. Если режим не "Свой цвет" (Mode 1/3)
    
    local st = GetState(frame)
    if st.lastUnit ~= unit then
        st.lastUnit = unit
        st.lastColorKey = nil
        st.combatRedUntil = 0
    end

    local isFriend = UnitIsFriend("player", unit)
    local isPlayer = UnitIsPlayer(unit)

    -- -- Логика УГРОЗЫ (только для врагов и если это не игрок-игрок PVP, хотя в PVP угрозы нет)
    -- Если ты хочешь отключить покраснение при агро, закомментируй блок ниже
    if not isFriend and not isPlayer then
        local canAttack = UnitCanAttack("player", unit)
        if canAttack then
            local reaction = UnitReaction(unit, "player")
            local threat = UnitThreatSituation("player", unit)
            local withMe = (threat ~= nil)
            local inCombat = UnitAffectingCombat(unit)

            local now = GetTime()
            if reaction == 4 then
                -- Нейтралы: красим ТОЛЬКО если юнит реально в бою с игроком (есть threat в таблице).
                if withMe then
                    st.combatRedUntil = now + 0.25
                end
            else
                -- Остальные враги: оставляем старое поведение (в бою вообще или с игроком).
                if inCombat or withMe then
                    st.combatRedUntil = now + 0.25
                end
            end

            -- Если есть агро/бой с игроком, красим в красный
            if now < (st.combatRedUntil or 0) then
                return 1, 0.1, 0.1 -- Красный цвет угрозы
            end
        end
    end
    -- -- Конец логики угрозы

    -- Mode 3: Реакция (включая игроков)
    if db.healthColorMode == 3 then
        return UnitSelectionColor(unit)
    end

    -- Mode 1: Авто (игроки: класс, NPC: реакция)
    if isPlayer then
        local _, class = UnitClass(unit)
        if class then
            local c = C_ClassColor.GetClassColor(class)
            if c then return c.r, c.g, c.b end
        end
        return 0.5, 0.5, 0.5 -- серый если ошибка
    end

    -- NPC -> реакция
    return UnitSelectionColor(unit)
end

local function ApplyHealthColor(frame, unit, db)
    local hb = frame and frame.healthBar
    if not hb then return end
    
    -- Если db не передан (например, вызов из хука), пытаемся найти его
    if not db then
        db = NS.GetUnitConfig(unit)
    end
    if not db then return end

    local st = GetState(frame)

    local r, g, b = ComputeDesiredColor(frame, unit, db)
    if not r then return end

    local key = string.format("%.3f|%.3f|%.3f", r, g, b)
    local cr, cg, cb = hb:GetStatusBarColor()

    if st.lastColorKey ~= key or ColorDiff(cr, cg, cb, r, g, b) then
        hb:SetStatusBarColor(r, g, b)
        st.lastColorKey = key
    end
end

local function ApplyGeometry(frame, db, st)
    local hb = frame.healthBar
    if not hb then return end

    local w = SafeNumber(db.plateWidth, 140)
    local h = SafeNumber(db.plateHeight, 8)

    -- разумные пределы, чтобы не ломать лейаут
    if w < 40 then w = 40 elseif w > 400 then w = 400 end
    if h < 2 then h = 2 elseif h > 60 then h = 60 end

    local geomKey = w .. "|" .. h
    if st.geomKey ~= geomKey then
        local container = frame.HealthBarsContainer or frame

        hb:ClearAllPoints()
        hb:SetPoint("CENTER", frame, "CENTER", 0, 2)
        hb:SetSize(w, h)

        if frame.selectionHighlight then
            frame.selectionHighlight:ClearAllPoints()
            frame.selectionHighlight:SetAllPoints(hb)
        end

        st.geomKey = geomKey
        st.applied = true
    end

    -- Подстраиваем контейнер кастбара по ширине и привязываем к healthBar
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

    -- Эти настройки теперь в Глобальных (gdb)
    local hideAbsorb = gdb and gdb.hideAbsorbGlow and true or false
    local aAbsorb = hideAbsorb and 0 or 1
    -- Blizzard может вернуть альфу в 1 при пересборке/апдейте фрейма, поэтому проверяем фактическую альфу
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
-- Хук для защиты от того, что Blizzard пытается перекрасить хпбар обратно
local function PostBlizzRecolor(frame)
    if not frame or frame:IsForbidden() then return end
    local unit = frame.unit
    if not unit or not unit:find("nameplate") then return end
    
    local db, gdb = NS.GetUnitConfig(unit)
    -- Проверяем и общий профиль, и master-toggle полосы здоровья
    if db and db.enabled and db.hpBarEnable then 
        ApplyHealthColor(frame, unit, db)
        ApplyAbsorbHealToggles(frame, gdb, GetState(frame))
    end
end

if _G.CompactUnitFrame_UpdateHealthColor then
    hooksecurefunc("CompactUnitFrame_UpdateHealthColor", PostBlizzRecolor)
end
if _G.CompactUnitFrame_UpdateThreatColor then
    hooksecurefunc("CompactUnitFrame_UpdateThreatColor", PostBlizzRecolor)
end

-- ГЛАВНАЯ ФУНКЦИЯ МОДУЛЯ
-- frame: фрейм неймплейта
-- unit: unitID
-- db: настройки этого типа существ (BlizzPlatesFixDB.Units.EnemyPlayer и т.д.)
-- gdb: глобальные настройки (BlizzPlatesFixDB.Global)
NS.Modules.HpBar = {
    Update = function(frame, unit, db, gdb)
        if not frame or frame:IsForbidden() then return end
        if not frame.healthBar then return end

        if not db then return end

        -- Master-toggle: отключаем настройки вкладки и делаем хпбар полностью невидимым
        -- (включая фон/слои/детей), но не Hide() всего фрейма (меньше рисков для якорей).
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
            
            -- Обязательно применяем геометрию, так как HpBar - это якорь для NameText и CastBar!
            ApplyGeometry(frame, db, st)
            return
        end

        -- если ранее прятали мастер-тогглом — восстановим исходные альфы
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

        -- Дальше применяем геометрию/цвет/прогнозы как обычно

        ApplyGeometry(frame, db, st)

        ApplyHealthColor(frame, unit, db)
        ApplyAbsorbHealToggles(frame, gdb, st)
    end,
    Reset = function(frame)
        local st = GetState(frame)
        
        -- Вызываем вашу родную функцию очистки геометрии
        DisableCleanup(frame, st)
        
        -- Передаем управление цветом обратно движку Blizzard
        if _G.CompactUnitFrame_UpdateHealthColor and frame.unit then
            _G.CompactUnitFrame_UpdateHealthColor(frame)
        end
    end
}
