local _, NS = ...

-- ============================================================================
-- 1. PANDEMIC CURVE
-- ============================================================================
local pandemicCurve
if C_CurveUtil then
    pandemicCurve = C_CurveUtil.CreateCurve()
    pandemicCurve:SetType(Enum.LuaCurveType.Step)
    pandemicCurve:AddPoint(0, 1)
    pandemicCurve:AddPoint(0.3, 0)
end

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    if not State[frame] then
        -- ДОБАВЛЕН ТРЕТИЙ ПУЛ: cc
        State[frame] = {
            buffs = {},
            debuffs = {},
            cc = {},
        }
    end
    return State[frame]
end

local function HideAuraPools(frame)
    local st = GetState(frame)
    for _, icon in ipairs(st.buffs) do icon:Hide() end
    for _, icon in ipairs(st.debuffs) do icon:Hide() end
    for _, icon in ipairs(st.cc) do icon:Hide() end
end

-- ============================================================================
-- 1.25. SECRET-SAFE HELPERS (12.0+)
-- ============================================================================
-- Some aura fields can be "secret" (including booleans). Any boolean-test
-- (if/and/or/not) on a secret value can error in tainted execution.
-- Use canaccessvalue() to safely read them.
local _canaccessvalue = _G.canaccessvalue
local function SafeBool(v)
    if _canaccessvalue and v ~= nil and _canaccessvalue(v) then
        return (v and true or false)
    end
    return false
end

-- ==========================================================================
-- IMPORTANT AURAS (Blizzard nameplate filters)
-- ==========================================================================
-- Goal: for enemy units, be able to show only "important" auras that Blizzard
-- itself would display on nameplates, while still using our own rendering.
--
-- We avoid spellId/sourceUnit checks (can be secret/tainted in 12.0+). Instead
-- we intersect by auraInstanceID with Blizzard's own AurasFrame lists.
local _BPF_SharedBlizzardAuraSet = {}
local _BPF_SharedNameplateOnlyAuraSet = {}

local function BuildBlizzardNameplateAuraSet(frame, kind)
    local af = frame and frame.AurasFrame
    if not af then return nil end

    local list = nil
    if kind == "BUFF" then
        list = af.buffList
    elseif kind == "DEBUFF" then
        list = af.debuffList
    end
    if not list or type(list.Iterate) ~= "function" then return nil end

    wipe(_BPF_SharedBlizzardAuraSet)
    local ok = pcall(list.Iterate, list, function(auraInstanceID)
        if auraInstanceID then _BPF_SharedBlizzardAuraSet[auraInstanceID] = true end
    end)
    if ok then
        return _BPF_SharedBlizzardAuraSet
    end
    return nil
end

local function BuildNameplateOnlyAuraSet(unit, filter)
    if not (C_UnitAuras and C_UnitAuras.GetUnitAuraInstanceIDs) then return nil end
    local ids = C_UnitAuras.GetUnitAuraInstanceIDs(unit, filter)
    if not ids then return nil end
    wipe(_BPF_SharedNameplateOnlyAuraSet)
    for _, auraInstanceID in ipairs(ids) do
        _BPF_SharedNameplateOnlyAuraSet[auraInstanceID] = true
    end
    return _BPF_SharedNameplateOnlyAuraSet
end

-- ============================================================================
-- 1.5. TEXT STYLING (таймер Cooldown + стаки)
-- ============================================================================
local function GetCooldownFontString(cd)
    if not cd then return nil end
    if cd._BPF_CooldownText and cd._BPF_CooldownText.GetObjectType then
        return cd._BPF_CooldownText
    end

    local n = select("#", cd:GetRegions())
    for i = 1, n do
        local r = select(i, cd:GetRegions())
        if r and r.GetObjectType and r:GetObjectType() == "FontString" then
            cd._BPF_CooldownText = r
            return r
        end
    end
    return nil
end


local function ApplyIconRect(icon, width, height)
    if not icon or not icon.tex or not width or not height then return end

    icon:SetSize(width, height)

    -- Сохраняем квадратную картинку без растяжения: режем TexCoord под прямоугольник
    local baseMin, baseMax = 0.08, 0.92
    local span = baseMax - baseMin

    if height == width then
        icon.tex:SetTexCoord(baseMin, baseMax, baseMin, baseMax)
        return
    end

    if height < width then
        local ratio = height / width
        local pad = (1 - ratio) / 2
        local y1 = baseMin + span * pad
        local y2 = baseMax - span * pad
        icon.tex:SetTexCoord(baseMin, baseMax, y1, y2)
    else
        local ratio = width / height
        local pad = (1 - ratio) / 2
        local x1 = baseMin + span * pad
        local x2 = baseMax - span * pad
        icon.tex:SetTexCoord(x1, x2, baseMin, baseMax)
    end
end

local function ApplyAuraTextStyle(icon, fontPath, timeSize, timeX, timeY, timeColor, stackSize, stackX, stackY, stackColor)
    if not icon then return end

    -- Таймер: используем встроенные цифры Cooldown (без математики с secret values)
    local cdText = GetCooldownFontString(icon.cd)
    if cdText then
        local _, _, flags = cdText:GetFont()
        cdText:SetFont(fontPath, timeSize, flags)
        cdText:ClearAllPoints()
        cdText:SetPoint("CENTER", icon.cd, "CENTER", timeX, timeY)
        if type(timeColor) == "table" then
            cdText:SetTextColor(timeColor.r or 1, timeColor.g or 1, timeColor.b or 1, timeColor.a or 1)
        else
            cdText:SetTextColor(1, 1, 1, 1)
        end
    end

    -- Стаки
    if icon.count then
        local _, _, flags = icon.count:GetFont()
        icon.count:SetFont(fontPath, stackSize, flags)
        icon.count:ClearAllPoints()
        icon.count:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", stackX, stackY)
        if type(stackColor) == "table" then
            icon.count:SetTextColor(stackColor.r or 1, stackColor.g or 1, stackColor.b or 1, stackColor.a or 1)
        else
            icon.count:SetTextColor(1, 1, 1, 1)
        end
    end
end

-- =========================================================================
-- 1.6. ICON BORDER + DISPEL GLOW
-- =========================================================================
local AURA_STYLE_KEYS = {
    BUFF = {
        timeFontSize = "buffsTimeFontSize",
        timeX = "buffsTimeX",
        timeY = "buffsTimeY",
        timeColor = "buffsTimeColor",

        stackFontSize = "buffsStackFontSize",
        stackX = "buffsStackX",
        stackY = "buffsStackY",
        stackColor = "buffsStackColor",

        borderEnable = "buffsBorderEnable",
        borderThickness = "buffsBorderThickness",
        borderColor = "buffsBorderColor",
    },
    DEBUFF = {
        timeFontSize = "debuffsTimeFontSize",
        timeX = "debuffsTimeX",
        timeY = "debuffsTimeY",
        timeColor = "debuffsTimeColor",

        stackFontSize = "debuffsStackFontSize",
        stackX = "debuffsStackX",
        stackY = "debuffsStackY",
        stackColor = "debuffsStackColor",

        borderEnable = "debuffsBorderEnable",
        borderThickness = "debuffsBorderThickness",
        borderColor = "debuffsBorderColor",
    },
    CC = {
        timeFontSize = "ccTimeFontSize",
        timeX = "ccTimeX",
        timeY = "ccTimeY",
        timeColor = "ccTimeColor",

        stackFontSize = "ccStackFontSize",
        stackX = "ccStackX",
        stackY = "ccStackY",
        stackColor = "ccStackColor",

        borderEnable = "ccBorderEnable",
        borderThickness = "ccBorderThickness",
        borderColor = "ccBorderColor",
    },
}

local function GetAuraStyleKeys(auraType)
    return AURA_STYLE_KEYS[auraType] or AURA_STYLE_KEYS.CC
end

local function ApplyAuraBorderStyle(icon, borderEnabled, thickness, borderColor)
    if not icon or not icon.border then return end

    if borderEnabled == false then
        icon.border:Hide()
        return
    end

    thickness = tonumber(thickness) or 2
    if thickness < 0 then thickness = 0 end

    -- IMPORTANT: border uses a solid-color texture. If its base color is black,
    -- VertexColor multiplication will always stay black. Ensure base is white
    -- so SetVertexColor controls the final color.
    if icon.border.SetColorTexture then
        icon.border:SetColorTexture(1, 1, 1, 1)
    end

    icon.border:ClearAllPoints()
    icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -thickness, thickness)
    icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", thickness, -thickness)

    if type(borderColor) == "table" then
        icon.border:SetVertexColor(borderColor.r or 0, borderColor.g or 0, borderColor.b or 0, borderColor.a or 1)
    else
        icon.border:SetVertexColor(0, 0, 0, 1)
    end

    if thickness == 0 then
        icon.border:Hide()
    else
        icon.border:Show()
    end
end

local function SetDispelGlow(icon, enabled)
    if not icon then return end

    -- Prefer Blizzard overlay glow if available
    if _G.ActionButton_ShowOverlayGlow and _G.ActionButton_HideOverlayGlow then
        if enabled then
            pcall(_G.ActionButton_ShowOverlayGlow, icon)
        else
            pcall(_G.ActionButton_HideOverlayGlow, icon)
        end
        return
    end

    -- Fallback: simple pulsing glow texture
    if not icon.DispelGlow then return end
    icon.DispelGlow:SetShown(enabled and true or false)
end

-- ============================================================================
-- 2. SETUP (Иконки) - Твой оригинальный код (БЕЗ ИЗМЕНЕНИЙ)
-- ============================================================================
local function GetIcon(frame, pool, index)
    if not pool[index] then
        local icon = CreateFrame("Frame", nil, frame)
        
        icon.border = icon:CreateTexture(nil, "BACKGROUND", nil, -7)
	    -- Use white base so VertexColor can tint the border.
	    icon.border:SetColorTexture(1, 1, 1, 1)
        icon.border:SetPoint("TOPLEFT", icon, "TOPLEFT", -2, 2)
        icon.border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", 2, -2)
        
        icon.tex = icon:CreateTexture(nil, "BACKGROUND")
        icon.tex:SetAllPoints()
        icon.tex:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        
        icon.cd = CreateFrame("Cooldown", nil, icon, "CooldownFrameTemplate")
        icon.cd:SetAllPoints()
        icon.cd:SetReverse(true)
        icon.cd:SetDrawEdge(false)
        icon.cd:SetDrawSwipe(true)
        icon.cd:SetHideCountdownNumbers(false)
        icon.cd:SetCountdownAbbrevThreshold(20)
        
        icon.Pandemic = CreateFrame("Frame", nil, icon)
        icon.Pandemic:SetAllPoints()
        icon.Pandemic:SetAlpha(0)
        
        icon.Pandemic.Glow = icon.Pandemic:CreateTexture(nil, "OVERLAY")
        icon.Pandemic.Glow:SetAllPoints()
        icon.Pandemic.Glow:SetTexture("Interface\\Buttons\\WHITE8x8")
        icon.Pandemic.Glow:SetVertexColor(1, 0, 0)
        icon.Pandemic.Glow:SetBlendMode("ADD")
        
        local ag = icon.Pandemic.Glow:CreateAnimationGroup()
        ag:SetLooping("REPEAT")
        local a1 = ag:CreateAnimation("Alpha")
        a1:SetFromAlpha(0.2); a1:SetToAlpha(0.6); a1:SetDuration(0.6); a1:SetSmoothing("IN_OUT")
        local a2 = ag:CreateAnimation("Alpha")
        a2:SetFromAlpha(0.6); a2:SetToAlpha(0.2); a2:SetDuration(0.6); a2:SetSmoothing("IN_OUT"); a2:SetOrder(2)
        ag:Play()

        -- Dispel glow (fallback). Prefer ActionButton_* overlay glow when available.
        icon.DispelGlow = icon:CreateTexture(nil, "OVERLAY")
        icon.DispelGlow:SetAllPoints()
        icon.DispelGlow:SetTexture("Interface\\Buttons\\WHITE8x8")
        icon.DispelGlow:SetVertexColor(1, 1, 0, 0.45)
        icon.DispelGlow:SetBlendMode("ADD")
        icon.DispelGlow:Hide()

        local dg = icon.DispelGlow:CreateAnimationGroup()
        dg:SetLooping("REPEAT")
        local d1 = dg:CreateAnimation("Alpha")
        d1:SetFromAlpha(0.10); d1:SetToAlpha(0.55); d1:SetDuration(0.55); d1:SetSmoothing("IN_OUT")
        local d2 = dg:CreateAnimation("Alpha")
        d2:SetFromAlpha(0.55); d2:SetToAlpha(0.10); d2:SetDuration(0.55); d2:SetSmoothing("IN_OUT"); d2:SetOrder(2)
        dg:Play()
        
        icon.count = icon:CreateFontString(nil, "OVERLAY", "GameFontNormalSmall")
        icon.count:SetPoint("BOTTOMRIGHT", 2, -2)
        
        pool[index] = icon
    end
    return pool[index]
end

-- ============================================================================
-- 3. LOGIC (Единый маршрутизатор для всех 3-х пулов)
-- ============================================================================
local function ProcessAuraCategory(frame, unit, db, gdb, auraType, ignoreMap)
    local st = GetState(frame)
    local pool, enabled, filter, size, iconH, posX, posY, align, spacing, timerEdge, timerEnable, stacksEnable

    local isFriend = UnitIsFriend("player", unit)

    -- One dropdown mode per context (friendly/enemy) and per aura type.
    local friendlyBuffMode  = db.buffsFriendlyFilterMode
    local friendlyDebuffMode = db.debuffsFriendlyFilterMode
    local enemyBuffMode     = db.buffsEnemyFilterMode
    local enemyDebuffMode   = db.debuffsEnemyFilterMode

    -- РАСПРЕДЕЛЕНИЕ НАСТРОЕК ПО КАТЕГОРИЯМ (ДОБАВЛЕНО ЧТЕНИЕ ALIGN)
    if auraType == "BUFF" then
        pool = st.buffs
        enabled = db.buffsEnable
        if isFriend then
            if friendlyBuffMode == "MINE" then
                filter = "HELPFUL|PLAYER"
            elseif friendlyBuffMode == "IMPORTANT" then
                filter = "HELPFUL|RAID"
            elseif friendlyBuffMode == "MINE_IMPORTANT" then
                filter = "HELPFUL|RAID|PLAYER"
            else
                filter = "HELPFUL"
            end
        else
            -- Enemy buffs: fetch all helpful auras; extra filtering happens below by mode.
            filter = "HELPFUL"
        end
        size = db.buffsSize or 20
        posX = db.buffsX or 0
        posY = db.buffsY or 18
        align = db.buffsAlign or "CENTER"
        spacing = db.buffsSpacing or 4
        iconH = db.buffsIconHeight or size
        timerEdge = db.buffsTimerEdge
        timerEnable = (db.buffsTimerEnable ~= false)
        stacksEnable = (db.buffsStacksEnable ~= false)
    elseif auraType == "CC" then
        pool = st.cc
        enabled = db.ccEnable
        filter = "HARMFUL|CROWD_CONTROL"
        size = db.ccSize or 26
        posX = db.ccX or 0
        posY = db.ccY or 65
        align = db.ccAlign or "CENTER"
        spacing = db.ccSpacing or 4
        iconH = db.ccIconHeight or size
        timerEdge = db.ccTimerEdge
        timerEnable = (db.ccTimerEnable ~= false)
        stacksEnable = (db.ccStacksEnable ~= false)
    elseif auraType == "DEBUFF" then
        pool = st.debuffs
        enabled = db.debuffsEnable
        if isFriend then
            filter = "HARMFUL"
        else
            -- Enemy debuffs: mine modes use PLAYER as base, others fetch all.
            if enemyDebuffMode == "MINE" or enemyDebuffMode == "MINE_AND_IMPORTANT" then
                filter = "HARMFUL|PLAYER"
            else
                filter = "HARMFUL"
            end
        end
        size = db.debuffsSize or 20
        posX = db.debuffsX or 0
        posY = db.debuffsY or 40
        align = db.debuffsAlign or "CENTER"
        spacing = db.debuffsSpacing or 4
        iconH = db.debuffsIconHeight or size
        timerEdge = db.debuffsTimerEdge
        timerEnable = (db.debuffsTimerEnable ~= false)
        stacksEnable = (db.debuffsStacksEnable ~= false)
    end



    if not enabled then
        -- Скрываем иконки выключенного пула
        for _, icon in ipairs(pool) do icon:Hide() end
        return
    end

    -- Data layer provides ordered auraInstanceID lists
    local ids = (NS.AurasData and NS.AurasData.GetIDs) and NS.AurasData.GetIDs(frame, auraType) or nil
    if not ids then
        for _, icon in ipairs(pool) do icon:Hide() end
        return
    end
    local usePandemic
    if auraType == "BUFF" then
        usePandemic = (db.buffsPandemic ~= false)
    elseif auraType == "DEBUFF" then
        usePandemic = (db.debuffsPandemic ~= false)
    else -- CC
        usePandemic = (db.ccPandemic ~= false)
    end
	local maxAuras = 8


	-- ENEMY AURAS: Blizzard "nameplate-important" set (used by enemy IMPORTANT modes).
	-- We intersect by auraInstanceID with Blizzard's nameplate lists (preferred),
	-- and fall back to INCLUDE_NAME_PLATE_ONLY if lists are unavailable.
	local importantSet
	if not isFriend then
		if auraType == "BUFF" then
			if enemyBuffMode == "IMPORTANT" or enemyBuffMode == "IMPORTANT_AND_PURGE" or enemyBuffMode == "IMPORTANT_OR_PURGE" then
				importantSet = BuildBlizzardNameplateAuraSet(frame, "BUFF")
				if not importantSet then
					importantSet = BuildNameplateOnlyAuraSet(unit, "HELPFUL|INCLUDE_NAME_PLATE_ONLY")
				end
			end
		elseif auraType == "DEBUFF" then
			if enemyDebuffMode == "IMPORTANT" or enemyDebuffMode == "MINE_AND_IMPORTANT" then
				importantSet = BuildBlizzardNameplateAuraSet(frame, "DEBUFF")
				if not importantSet then
					importantSet = BuildNameplateOnlyAuraSet(unit, "HARMFUL|INCLUDE_NAME_PLATE_ONLY")
				end
			end
		end
	end
	local activeCount = 0-- Per-category styling (avoid per-update string concatenations)
local keys = GetAuraStyleKeys(auraType)
local fontPath = NS.GetFontPath(gdb and gdb.globalFont)

local timeFontSize = db[keys.timeFontSize] or 12
local timeX = db[keys.timeX] or 0
local timeY = db[keys.timeY] or 0
local timeColor = db[keys.timeColor]

local stackFontSize = db[keys.stackFontSize] or 10
local stackX = db[keys.stackX] or 2
local stackY = db[keys.stackY] or -2
local stackColor = db[keys.stackColor]

local borderEnabled = db[keys.borderEnable]
local borderThickness = db[keys.borderThickness]
local borderColor = db[keys.borderColor]

    -- 1. Сначала применяем данные ко всем валидным аурам
    for _, auraInstanceID in ipairs(ids) do
        local aura = (NS.AurasData and NS.AurasData.GetAura) and NS.AurasData.GetAura(frame, unit, auraInstanceID) or nil
        if aura and not (ignoreMap and ignoreMap[aura.auraInstanceID]) then
            local show = true

            -- Apply base filter (HELPFUL|PLAYER, HARMFUL|PLAYER, etc.)
            if C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID then
                if C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, filter) then
                    show = false
                end
            end

            -- FRIENDLY DEBUFFS: dropdown modes (IMPORTANT=RAID)
            if show and auraType == "DEBUFF" and isFriend and C_UnitAuras and C_UnitAuras.IsAuraFilteredOutByInstanceID then
                if friendlyDebuffMode == "IMPORTANT" then
                    if C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, "HARMFUL|RAID") then
                        show = false
                    end
                elseif friendlyDebuffMode == "DISPEL" then
                    if C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE") then
                        show = false
                    end
                elseif friendlyDebuffMode == "IMPORTANT_AND_DISPEL" then
                    if C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, "HARMFUL|RAID") then
                        show = false
                    elseif C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, "HARMFUL|RAID_PLAYER_DISPELLABLE") then
                        show = false
                    end
                elseif friendlyDebuffMode == "IMPORTANT_OR_DISPEL" then
                    local important = not C_UnitAuras.IsAuraFilteredOutByInstanceID(unit, aura.auraInstanceID, "HARMFUL|RAID")
                    local dispel = SafeBool(aura and aura.canActivePlayerDispel)
                    if not (important or dispel) then
                        show = false
                    end
                end
            end

            -- ENEMY IMPORTANT (NAMEPLATE): intersect by auraInstanceID
            if show and (not isFriend) and importantSet then
                if not importantSet[aura.auraInstanceID] then
                    show = false
                end
            end

            -- ENEMY BUFFS: purge/steal filter modes
            if show and (not isFriend) and auraType == "BUFF" then
                local purgeable = (NS and NS.IsEnemyBuffPurgeable) and NS.IsEnemyBuffPurgeable(aura) or false
                if enemyBuffMode == "PURGE" then
                    show = purgeable
                elseif enemyBuffMode == "IMPORTANT_AND_PURGE" then
                    show = purgeable and (not importantSet or importantSet[aura.auraInstanceID])
                elseif enemyBuffMode == "IMPORTANT_OR_PURGE" then
                    local imp = (not importantSet) or importantSet[aura.auraInstanceID]
                    show = imp or purgeable
                end
            end



            -- КОНТРОЛЬ: опционально показываем только мои эффекты.
            -- isFromPlayerOrPlayerPet может быть secret; фильтруем только если значение доступно.
            if show and auraType == "CC" and db.ccOnlyMine then
                local mine = aura and aura.isFromPlayerOrPlayerPet
                if _canaccessvalue and mine ~= nil and _canaccessvalue(mine) then
                    if not mine then
                        show = false
                    end
                end
            end

            if show then
                activeCount = activeCount + 1
                local icon = GetIcon(frame, pool, activeCount)

                ApplyAuraTextStyle(icon, fontPath, timeFontSize, timeX, timeY, timeColor, stackFontSize, stackX, stackY, stackColor)

                ApplyIconRect(icon, size, iconH or size)
                ApplyAuraBorderStyle(icon, borderEnabled, borderThickness, borderColor)
                icon.tex:SetTexture(aura.icon)

                                if stacksEnable == false then
                    icon.count:Hide()
                else
                    local countStr = C_UnitAuras.GetAuraApplicationDisplayCount(unit, aura.auraInstanceID, 2, 1000)
                    if countStr ~= nil then
                        icon.count:SetText(countStr)
                        icon.count:Show()
                    else
                        icon.count:Hide()
                    end
                end

                -- Подсветка аур (dispel/purge/steal)
                -- 1) Дебаффы на союзниках: если диспелится мной (Blizzard flag canActivePlayerDispel)
                -- 2) Баффы на врагах: если можно снять/украсть (Purge/Spellsteal и аналоги)
                local dispelGlow = false
                if auraType == "DEBUFF" and isFriend and db.debuffsDispelGlow then
                    dispelGlow = SafeBool(aura and aura.canActivePlayerDispel)
                elseif auraType == "BUFF" and (not isFriend) and db.buffsPurgeGlow then
                    dispelGlow = (NS and NS.IsEnemyBuffPurgeable) and NS.IsEnemyBuffPurgeable(aura) or false
                end
                SetDispelGlow(icon, dispelGlow)

                if timerEnable == false then
                    icon.cd:Hide()
                    icon.Pandemic:SetAlpha(0)
                    icon:SetAlpha(1)
                else
                    icon.cd:SetDrawEdge(timerEdge and true or false)
                    icon.cd:SetHideCountdownNumbers(false)
                
                    local durationInfo = C_UnitAuras.GetAuraDuration(unit, aura.auraInstanceID)
                
                    if durationInfo then
                        -- Передаем таймер всегда, чтобы избежать Taint-ошибок
                        icon.cd:SetCooldownFromDurationObject(durationInfo)
                        icon.cd:Show()
                
                        -- 1. Вычисляем прозрачность таймера (CooldownFrame) на стороне C-движка.
                        -- Если IsZero (вечная аура), Alpha будет 0. Если обычная аура, Alpha будет 1.
                        local cdAlpha = C_CurveUtil.EvaluateColorValueFromBoolean(durationInfo:IsZero(), 0, 1)
                        icon.cd:SetAlpha(cdAlpha)

                        -- 2. Прозрачность самой иконки
                        icon:SetAlpha(1)
                
                        -- 3. Красное свечение пандемика (отключаем для вечных)
                        if usePandemic and pandemicCurve then
                            local panAlpha = C_CurveUtil.EvaluateColorValueFromBoolean(
                                durationInfo:IsZero(), 0, durationInfo:EvaluateRemainingPercent(pandemicCurve)
                            )
                            icon.Pandemic:SetAlpha(panAlpha)
                        else
                            icon.Pandemic:SetAlpha(0)
                        end
                    else
                        icon.cd:Hide()
                        icon.Pandemic:SetAlpha(0)
                        icon:SetAlpha(1)
                    end
                end

                if ignoreMap then ignoreMap[aura.auraInstanceID] = true end

                if activeCount >= maxAuras then break end
            end
        end
    end

    -- 2. Математика позиционирования для видимых иконок
    if activeCount > 0 then
        spacing = spacing or 4
        -- Считаем точную длину всей полосы иконок
        local totalWidth = (activeCount * size) + ((activeCount - 1) * spacing)

        for i = 1, activeCount do
            local icon = pool[i]
            icon:ClearAllPoints()
            
            if i == 1 then
                if align == "LEFT" then
                    icon:SetPoint("BOTTOMLEFT", frame.healthBar, "TOPRIGHT", posX, posY)
                elseif align == "RIGHT" then
                    icon:SetPoint("BOTTOMRIGHT", frame.healthBar, "TOPLEFT", posX, posY)
                else -- CENTER
                    -- Смещаем первую иконку влево на половину длины всей группы аур
                    icon:SetPoint("BOTTOM", frame.healthBar, "TOP", posX - (totalWidth / 2) + (size / 2), posY)
                end
            else
                if align == "RIGHT" then
                    -- Если привязка справа, ауры растут влево
                    icon:SetPoint("RIGHT", pool[i-1], "LEFT", -spacing, 0)
                else
                    -- При привязке LEFT и CENTER ауры растут вправо
                    icon:SetPoint("LEFT", pool[i-1], "RIGHT", spacing, 0)
                end
            end
            icon:Show()
        end
    end

    -- 3. Скрываем лишнее
    for i = activeCount + 1, #pool do 
        pool[i]:Hide() 
    end
end
-- ============================================================================
-- 3.5. PREVIEW MODE (фейковые ауры из Modules/AurasPreview.lua)
-- ============================================================================
local function RenderPreviewCategory(frame, db, gdb, auraType, list)
    local st = GetState(frame)
    local pool, enabled, size, iconH, posX, posY, align, spacing, timerEdge, timerEnable, stacksEnable

    if auraType == "BUFF" then
        pool = st.buffs
        enabled = db.buffsEnable
        size = db.buffsSize or 20
        posX = db.buffsX or 0
        posY = db.buffsY or 18
        align = db.buffsAlign or "CENTER"
        spacing = db.buffsSpacing or 4
        iconH = db.buffsIconHeight or size
        timerEdge = db.buffsTimerEdge
        timerEnable = (db.buffsTimerEnable ~= false)
        stacksEnable = (db.buffsStacksEnable ~= false)
    elseif auraType == "CC" then
        pool = st.cc
        enabled = db.ccEnable
        size = db.ccSize or 26
        posX = db.ccX or 0
        posY = db.ccY or 65
        align = db.ccAlign or "CENTER"
        spacing = db.ccSpacing or 4
        iconH = db.ccIconHeight or size
        timerEdge = db.ccTimerEdge
        timerEnable = (db.ccTimerEnable ~= false)
        stacksEnable = (db.ccStacksEnable ~= false)
    else -- DEBUFF
        pool = st.debuffs
        enabled = db.debuffsEnable
        size = db.debuffsSize or 20
        posX = db.debuffsX or 0
        posY = db.debuffsY or 40
        align = db.debuffsAlign or "CENTER"
        spacing = db.debuffsSpacing or 4
        iconH = db.debuffsIconHeight or size
        timerEdge = db.debuffsTimerEdge
        timerEnable = (db.debuffsTimerEnable ~= false)
        stacksEnable = (db.debuffsStacksEnable ~= false)
    end

    if not enabled or not list or #list == 0 then
        for _, icon in ipairs(pool) do icon:Hide() end
        return
    end

    local maxAuras = 8
    local activeCount = 0
    local now = GetTime()
    spacing = spacing or 4

    for i = 1, #list do
        local a = list[i]
        activeCount = activeCount + 1
        local icon = GetIcon(frame, pool, activeCount)

        ApplyAuraTextStyle(icon, fontPath, timeFontSize, timeX, timeY, timeColor, stackFontSize, stackX, stackY, stackColor)

        ApplyIconRect(icon, size, iconH or size)
        ApplyAuraBorderStyle(icon, borderEnabled, borderThickness, borderColor)
        SetDispelGlow(icon, false)
        icon.tex:SetTexture(a.icon)

        if stacksEnable == false then
    icon.count:Hide()
else
    local stacks = tonumber(a.stacks or 0) or 0
    if stacks > 1 then
        icon.count:SetText(stacks)
        icon.count:Show()
    else
        icon.count:SetText("")
        icon.count:Hide()
    end
end

        local dur = tonumber(a.duration or 0) or 0
        local rem = tonumber(a.remaining or dur) or dur
        local startFromList = tonumber(a.start)

        if timerEnable == false then
    icon.cd:Hide()
else
    icon.cd:SetDrawEdge(timerEdge and true or false)
    icon.cd:SetHideCountdownNumbers(false)

    if dur > 0 then
        local start
        if startFromList then
            start = startFromList
        else
            if rem > dur then rem = dur end
            if rem < 0 then rem = 0 end
            start = now - (dur - rem)
        end
        if start < 0 then start = 0 end
        icon.cd:SetCooldown(start, dur)
        icon.cd:Show()
    else
        icon.cd:Hide()
    end
end


        icon.Pandemic:SetAlpha(0)
        if a.inactive then
            icon:SetAlpha(0.25)
        else
            icon:SetAlpha(1)
        end

        if activeCount >= maxAuras then break end
    end

    -- Positioning (как в обычном режиме)
    if activeCount > 0 then
        local totalWidth = (activeCount * size) + ((activeCount - 1) * spacing)

        for i = 1, activeCount do
            local icon = pool[i]
            icon:ClearAllPoints()

            if i == 1 then
                if align == "LEFT" then
                    icon:SetPoint("BOTTOMLEFT", frame.healthBar, "TOPRIGHT", posX, posY)
                elseif align == "RIGHT" then
                    icon:SetPoint("BOTTOMRIGHT", frame.healthBar, "TOPLEFT", posX, posY)
                else -- CENTER
                    icon:SetPoint("BOTTOM", frame.healthBar, "TOP", posX - (totalWidth / 2) + (size / 2), posY)
                end
            else
                if align == "RIGHT" then
                    icon:SetPoint("RIGHT", pool[i-1], "LEFT", -spacing, 0)
                else
                    icon:SetPoint("LEFT", pool[i-1], "RIGHT", spacing, 0)
                end
            end
            icon:Show()
        end
    end

    for i = activeCount + 1, #pool do
        pool[i]:Hide()
    end
end

-- ============================================================================
-- 4. UPDATE/RESET (обновление через общий Dispatch/Engine)
-- ============================================================================
NS.Modules.Auras = {
    Update = function(frame, unit, db, gdb)
        if not frame or frame:IsForbidden() then return end
        if not db or not unit then return end



        -- Preview mode (фейковые ауры для настройки)
        if NS.AurasPreview and NS.AurasPreview.IsEnabled and NS.AurasPreview.IsEnabled(db) then
            -- Локальные тумблеры (buffsEnable/debuffsEnable/ccEnable) должны полностью отключать логику категории,
            -- включая превью.
            local doPreview = false
            if db.buffsEnable and NS.AurasPreview.IsBuffsEnabled and NS.AurasPreview.IsBuffsEnabled(db) then doPreview = true end
            if db.debuffsEnable and NS.AurasPreview.IsDebuffsEnabled and NS.AurasPreview.IsDebuffsEnabled(db) then doPreview = true end
            if db.ccEnable and NS.AurasPreview.IsCCEnabled and NS.AurasPreview.IsCCEnabled(db) then doPreview = true end

            if not doPreview then
                HideAuraPools(frame)
                return
            end

            local buffs, debuffs, cc = nil, nil, nil
            if NS.AurasPreview.GetLists then
                buffs, debuffs, cc = NS.AurasPreview.GetLists(unit)
            end

            if db.buffsEnable and NS.AurasPreview.IsBuffsEnabled and NS.AurasPreview.IsBuffsEnabled(db) then
                RenderPreviewCategory(frame, db, gdb, "BUFF", buffs)
            else
                RenderPreviewCategory(frame, db, gdb, "BUFF", nil)
            end

            if db.debuffsEnable and NS.AurasPreview.IsDebuffsEnabled and NS.AurasPreview.IsDebuffsEnabled(db) then
                RenderPreviewCategory(frame, db, gdb, "DEBUFF", debuffs)
            else
                RenderPreviewCategory(frame, db, gdb, "DEBUFF", nil)
            end

            if db.ccEnable and NS.AurasPreview.IsCCEnabled and NS.AurasPreview.IsCCEnabled(db) then
                RenderPreviewCategory(frame, db, gdb, "CC", cc)
            else
                RenderPreviewCategory(frame, db, gdb, "CC", nil)
            end

            return
        end

        -- Legacy master switch: aurasEnable больше не используется в UI.
        -- Если он был выключен в старых профилях, а категории выключены — скрываем всё.
        local anyCatEnabled = (db.buffsEnable or db.debuffsEnable or db.ccEnable) and true or false
        if db.aurasEnable == false and not anyCatEnabled then
            HideAuraPools(frame)
            return
        end

        -- Data layer: incremental UNIT_AURA refreshData (captured by Dispatch)
        local pending = NS.PendingAuraUpdates and NS.PendingAuraUpdates[unit] or nil
        if NS.AurasData and NS.AurasData.ApplyRefresh then
            local _, needFull = NS.AurasData.ApplyRefresh(frame, unit, pending)
            if needFull then
                NS.AurasData.FullRefresh(frame, unit)
            else
                NS.AurasData.EnsureFull(frame, unit)
            end
            NS.AurasData.RebuildOrder(frame, unit)
        end
        if NS.PendingAuraUpdates then NS.PendingAuraUpdates[unit] = nil end

        local ccMap = {}
        ProcessAuraCategory(frame, unit, db, gdb, "BUFF", nil)
        ProcessAuraCategory(frame, unit, db, gdb, "CC", ccMap)
        ProcessAuraCategory(frame, unit, db, gdb, "DEBUFF", ccMap)
    end,
    
    Reset = function(frame)
        HideAuraPools(frame)
        if NS.AurasData and NS.AurasData.Reset then
            NS.AurasData.Reset(frame)
        end
    end
}