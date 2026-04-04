local _, NS = ...

NS.PreviewNameplate = NS.PreviewNameplate or {}

local PreviewFrame
local CurrentContext
local PreviewIsTarget = false

local TARGET_SYMBOLS = {
    [1] = {">", "<"},
    [2] = {"<", ">"},
    [3] = {"[", "]"},
    [4] = {"(", ")"},
    [5] = {"»", "«"},
    [6] = {"«", "»"},
    [7] = {"*", "*"},
}

local CONTEXT_ORDER = {
    "FRIENDLY_PLAYER",
    "FRIENDLY_NPC",
    "ENEMY_PLAYER",
    "ENEMY_NPC",
}

local SAMPLE_HEALTH_CUR = 76000
local SAMPLE_HEALTH_MAX = 100000
local SAMPLE_HEALTH_PCT = SAMPLE_HEALTH_CUR / SAMPLE_HEALTH_MAX
local SAMPLE_CAST_PROGRESS = 0.62

-- Manual atlas tuning for preview art.
-- Each value is an offset from the BarAnchor edges:
-- left/right move the horizontal edges, top/bottom move the vertical edges.
-- Positive values move to the right/up, negative values move to the left/down.
local ATLAS_TUNING = {
    Background = {
        left = -2,
        right = 6,
        top = 2,
        bottom = -7,
    },
    Fill = {
        left = 0,
        right = 0,
        top = 0,
        bottom = -0.6,
    },
    Overlay = {
        left = -1,
        right = 1,
        top = 1,
        bottom = -1,
    },
}

local function GetDefaultContext()
    return (NS.UNIT_TYPES and NS.UNIT_TYPES.FRIENDLY_PLAYER) or "FRIENDLY_PLAYER"
end

local function GetTargetSymbolPair(index)
    if TARGET_SYMBOLS[index] then return TARGET_SYMBOLS[index] end
    return TARGET_SYMBOLS[1]
end

local function SetPreviewTargeted(value)
    PreviewIsTarget = value and true or false
    NS.MenuState.previewIsTarget = PreviewIsTarget
    if PreviewFrame and PreviewFrame.TargetCheck and PreviewFrame.TargetCheck:GetChecked() ~= PreviewIsTarget then
        PreviewFrame.TargetCheck:SetChecked(PreviewIsTarget)
    end
end

local function ApplyEdgeOffsets(region, anchor, tuning)
    if not region or not anchor then return end
    tuning = tuning or {}
    region:ClearAllPoints()
    region:SetPoint("TOPLEFT", anchor, "TOPLEFT", tuning.left or 0, tuning.top or 0)
    region:SetPoint("BOTTOMRIGHT", anchor, "BOTTOMRIGHT", tuning.right or 0, tuning.bottom or 0)
end

local function SnapRectToAnchor(frame, anchor, tuning)
    if not frame or not anchor then return end
    tuning = tuning or {}
    local left = tuning.left or 0
    local right = tuning.right or 0
    local top = tuning.top or 0
    local bottom = tuning.bottom or 0

    local width = (anchor:GetWidth() or 0) + right - left
    local height = (anchor:GetHeight() or 0) + top - bottom
    if width < 1 then width = 1 end
    if height < 1 then height = 1 end

    frame:ClearAllPoints()
    frame:SetPoint("CENTER", anchor, "CENTER", (left + right) * 0.5, (top + bottom) * 0.5)
    frame:SetSize(width, height)
end

local function SetPixelPerfect(region)
    if not region then return end
    if region.SetSnapToPixelGrid then
        region:SetSnapToPixelGrid(false)
    end
    if region.SetTexelSnappingBias then
        region:SetTexelSnappingBias(0)
    end
end


local FACTION_ICON_ATLAS_BY_STYLE = {
    [1] = {
        Alliance = "poi-alliance",
        Horde = "poi-horde",
    },
    [2] = {
        Alliance = "AllianceSymbol",
        Horde = "HordeSymbol",
    },
    [3] = {
        Alliance = "questlog-questtypeicon-alliance",
        Horde = "questlog-questtypeicon-horde",
    },
}

local function InitScaledPreviewFontString(fs)
    if not fs then return end
    if fs.SetSpacing then
        fs:SetSpacing(0)
    end
    if fs.SetNonSpaceWrap then
        fs:SetNonSpaceWrap(false)
    end
end

local function InitUnscaledPreviewFontString(fs)
    if not fs then return end
    if fs.SetIgnoreParentScale then
        fs:SetIgnoreParentScale(true)
    end
    fs:SetScale(1)
    if fs.SetSpacing then
        fs:SetSpacing(0)
    end
    if fs.SetNonSpaceWrap then
        fs:SetNonSpaceWrap(false)
    end
end

local function FormatGuildText(guildName)
    if not guildName or guildName == "" then return nil end
    if guildName:sub(1, 1) == "<" and guildName:sub(-1) == ">" then
        return guildName
    end
    return "<" .. guildName .. ">"
end

local function FormatPreviewHealthValue(value)
    value = tonumber(value) or 0
    if AbbreviateNumbers then
        local s = tostring(AbbreviateNumbers(value) or value)
        if s ~= tostring(value) then
            return s
        end
    end

    local absValue = math.abs(value)
    if absValue >= 1000000000 then
        return string.format("%.1fB", value / 1000000000):gsub("%.0([KMB])", "%1")
    elseif absValue >= 1000000 then
        return string.format("%.1fM", value / 1000000):gsub("%.0([KMB])", "%1")
    elseif absValue >= 1000 then
        return string.format("%.0fK", value / 1000)
    end
    return tostring(value)
end

local function TruncatePreviewText(text, maxLength)
    text = tostring(text or "")
    maxLength = tonumber(maxLength) or 0
    if maxLength > 0 and #text > maxLength then
        if maxLength <= 3 then
            return text:sub(1, maxLength)
        end
        return text:sub(1, maxLength - 3) .. "..."
    end
    return text
end

local function GetSpellNameByID(spellID, fallback)
    if C_Spell and C_Spell.GetSpellName then
        local name = C_Spell.GetSpellName(spellID)
        if name and name ~= "" then return name end
    end
    if GetSpellInfo then
        local name = GetSpellInfo(spellID)
        if name and name ~= "" then return name end
    end
    return fallback or "Spell"
end

local function GetSpellTextureByID(spellID, fallback)
    if C_Spell and C_Spell.GetSpellTexture then
        local tex = C_Spell.GetSpellTexture(spellID)
        if tex then return tex end
    end
    if GetSpellTexture then
        local tex = GetSpellTexture(spellID)
        if tex then return tex end
    end
    if GetSpellInfo then
        local _, _, tex = GetSpellInfo(spellID)
        if tex then return tex end
    end
    return fallback or 136243
end

local function GetPlayerFactionPair()
    local playerFaction = UnitFactionGroup and UnitFactionGroup("player") or nil
    if playerFaction ~= "Alliance" and playerFaction ~= "Horde" then
        playerFaction = "Alliance"
    end
    local enemyFaction = (playerFaction == "Alliance") and "Horde" or "Alliance"
    return playerFaction, enemyFaction
end

local function GetPreviewStatusAnchorRegion(anchorMode)
    if anchorMode == "Name" then
        return "BOTTOM", (PreviewFrame and (PreviewFrame.NameFS or PreviewFrame.NameAnchor)), "TOP"
    end
    return "CENTER", PreviewFrame and PreviewFrame.BarAnchor, "CENTER"
end

local function ApplyPreviewStatusAnchor(region, anchorMode, offX, offY)
    if not region or not PreviewFrame then return end
    local point, relTo, relPoint = GetPreviewStatusAnchorRegion(anchorMode)
    if not relTo then return end
    region:ClearAllPoints()
    region:SetPoint(point, relTo, relPoint, offX or 0, offY or 0)
end

local function SetRaidTargetTexture(texture, index)
    if not texture or not index then return end
    texture:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(texture, index)
        return
    end

    local i = math.max(1, math.min(8, tonumber(index) or 1)) - 1
    local col = i % 4
    local row = math.floor(i / 4)
    local left = col * 0.25
    local right = left + 0.25
    local top = row * 0.25
    local bottom = top + 0.25
    texture:SetTexCoord(left, right, top, bottom)
end

local function GetClassificationPreviewAtlas(classification)
    if classification == "worldboss" or classification == "boss" then
        return "worldquest-icon-boss", 1.1
    elseif classification == "rareelite" then
        return "nameplates-icon-elite-silver", 1.0
    elseif classification == "rare" then
        return "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star", 1.0
    elseif classification == "elite" then
        return "nameplates-icon-elite-gold", 1.0
    end
    return nil, 1.0
end

local function SetIconHolderShown(holder, shown)
    if not holder then return end
    if shown then
        holder:Show()
        if holder.Icon then holder.Icon:Show() end
    else
        if holder.Icon then holder.Icon:Hide() end
        holder:Hide()
    end
end

local function GetContextLabel(unitType)
    if not NS or not NS.UNIT_TYPES then
        return unitType or ""
    end
    if unitType == NS.UNIT_TYPES.FRIENDLY_PLAYER then
        return NS.L("Friendly players")
    elseif unitType == NS.UNIT_TYPES.FRIENDLY_NPC then
        return NS.L("Friendly NPC")
    elseif unitType == NS.UNIT_TYPES.ENEMY_PLAYER then
        return NS.L("Hostile players")
    elseif unitType == NS.UNIT_TYPES.ENEMY_NPC then
        return NS.L("Hostile NPC")
    end
    return unitType or ""
end

local function GetPreviewClassResourceSample()
    local CR = NS and NS.ClassResourceInternal
    if not CR then return nil end

    local powerType, _, maxPower
    if CR.GetPlayerResource then
        powerType, _, maxPower = CR.GetPlayerResource()
    end

    if not powerType or not maxPower or maxPower <= 0 then
        powerType = CR.POWER_COMBO_POINTS
        maxPower = 5
    end

    if powerType == CR.POWER_RUNES then
        local count = math.max(1, tonumber(maxPower) or 6)
        local snapshot = {}
        for i = 1, count do
            if i <= math.min(3, count) then
                snapshot[i] = {
                    index = i,
                    ready = true,
                    remaining = 0,
                    progress = 1,
                }
            else
                local progress = 0.2 + ((i - 4) * 0.25)
                if progress > 0.95 then progress = 0.95 end
                snapshot[i] = {
                    index = i,
                    ready = false,
                    remaining = math.max(0.1, 1 - progress),
                    progress = progress,
                }
            end
        end

        return {
            powerType = powerType,
            maxPower = count,
            snapshot = snapshot,
        }
    end

    local count = math.max(1, tonumber(maxPower) or 5)
    local current
    if count >= 5 then
        current = count - 2
    elseif count >= 3 then
        current = count - 1
    else
        current = 1
    end
    if current < 0 then current = 0 end
    if current > count then current = count end

    local partial = (current < count) and 0.55 or 0

    return {
        powerType = powerType,
        maxPower = count,
        current = current,
        partial = partial,
    }
end

local function GetSampleData(unitType)
    local playerLevel = (UnitLevel and UnitLevel("player")) or 80
    if type(playerLevel) ~= "number" or playerLevel <= 0 then
        playerLevel = 80
    end

    local playerFaction, enemyFaction = GetPlayerFactionPair()

    if unitType == NS.UNIT_TYPES.FRIENDLY_PLAYER then
        return {
            name = NS.L("Friendly Player"),
            guildName = NS.L("Arcane Order"),
            isPlayer = true,
            class = "MAGE",
            level = playerLevel,
            faction = playerFaction,
            raidTargetIndex = 1,
            castSpellID = 133,
            castInterruptible = true,
            castTargetName = NS.L("Grunt"),
            castTargetClass = "WARRIOR",
            reactionColor = { r = 0.15, g = 0.85, b = 0.35 },
        }
    elseif unitType == NS.UNIT_TYPES.FRIENDLY_NPC then
        return {
            name = NS.L("Friendly NPC"),
            isPlayer = false,
            level = math.max(1, playerLevel - 2),
            classification = "rare",
            questObjective = true,
            raidTargetIndex = 4,
            castSpellID = 686,
            castInterruptible = true,
            castTargetName = NS.L("Training Dummy"),
            reactionColor = { r = 0.15, g = 0.85, b = 0.35 },
        }
    elseif unitType == NS.UNIT_TYPES.ENEMY_PLAYER then
        return {
            name = NS.L("Enemy Player"),
            guildName = NS.L("Warband"),
            isPlayer = true,
            class = "WARRIOR",
            level = playerLevel,
            faction = enemyFaction,
            raidTargetIndex = 7,
            castSpellID = 116,
            castInterruptible = true,
            castTargetName = NS.L("Archmage"),
            castTargetClass = "MAGE",
            reactionColor = { r = 0.95, g = 0.2, b = 0.2 },
        }
    end

    return {
        name = NS.L("Enemy NPC"),
        isPlayer = false,
        level = playerLevel + 1,
        classification = "rareelite",
        questObjective = true,
        raidTargetIndex = 8,
        castSpellID = 348,
        castInterruptible = false,
        castTargetName = NS.L("Defender"),
        castTargetClass = "PALADIN",
        reactionColor = { r = 0.95, g = 0.2, b = 0.2 },
    }
end

local function GetClassColor(classFile)
    if not classFile or not C_ClassColor or not C_ClassColor.GetClassColor then
        return 1, 1, 1
    end
    local c = C_ClassColor.GetClassColor(classFile)
    if not c then return 1, 1, 1 end
    return c.r or 1, c.g or 1, c.b or 1
end

local ApplyPreviewFont

local function ApplyPreviewCastTargetStyle(db, gdb, sample, castW)
    if not PreviewFrame or not PreviewFrame.CastTargetFS then return end

    local targetText = PreviewFrame.CastTargetFS
    if db.cbEnabled == false or not db.cbTargetEnabled then
        targetText:Hide()
        return
    end

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local fontSize = db.cbTargetFontSize or 10
    local outline = db.cbTargetOutline or "OUTLINE"
    ApplyPreviewFont(targetText, fontPath, fontSize, outline)

    local justify = db.cbTargetJustify or "LEFT"
    targetText:SetJustifyH(justify)
    targetText:SetWordWrap(false)
    targetText:SetWidth((db.cbTargetMaxLength and db.cbTargetMaxLength > 0) and (db.cbTargetMaxLength * (fontSize * 0.75)) or ((castW or 142) - 8))
    targetText:ClearAllPoints()

    local tx, ty = db.cbTargetX or 0, db.cbTargetY or 0
    if justify == "LEFT" then
        targetText:SetPoint("LEFT", PreviewFrame.CastBarAnchor, "LEFT", tx + 4, ty)
    elseif justify == "RIGHT" then
        targetText:SetPoint("RIGHT", PreviewFrame.CastBarAnchor, "RIGHT", tx - 4, ty)
    else
        targetText:SetPoint("CENTER", PreviewFrame.CastBarAnchor, "CENTER", tx, ty)
    end

    targetText:SetFormattedText(" |cffFF0000=>|r %s", tostring((sample and sample.castTargetName) or NS.L("Target")))

    if db.cbTargetMode == "CLASS" and sample and sample.castTargetClass then
        local r, g, b = GetClassColor(sample.castTargetClass)
        targetText:SetTextColor(r, g, b, 1)
    else
        local tc = db.cbTargetColor
        targetText:SetTextColor((tc and tc.r) or 0.8, (tc and tc.g) or 0.8, (tc and tc.b) or 0.8, 1)
    end

    targetText:Show()
end

local function GetSyntheticReactionColor(unitType)
    if unitType == NS.UNIT_TYPES.FRIENDLY_PLAYER or unitType == NS.UNIT_TYPES.FRIENDLY_NPC then
        return 0.15, 0.85, 0.35
    end
    return 0.95, 0.2, 0.2
end

local function ResolveColorByMode(db, unitType, modeKey, customKey, hostileKey, friendlyKey, neutralKey, sample)
    local mode = db and db[modeKey] or 1

    if mode == 2 then
        local c
        if unitType == NS.UNIT_TYPES.ENEMY_NPC then
            c = db[hostileKey] or db[neutralKey] or db[customKey]
        elseif unitType == NS.UNIT_TYPES.FRIENDLY_NPC then
            c = db[friendlyKey] or db[neutralKey] or db[customKey]
        else
            c = db[customKey]
        end
        if c then
            return c.r or 1, c.g or 1, c.b or 1
        end
        return 1, 1, 1
    end

    if mode == 3 then
        return GetSyntheticReactionColor(unitType)
    end

    if sample and sample.isPlayer then
        return GetClassColor(sample.class)
    end

    return GetSyntheticReactionColor(unitType)
end

local function GetMainPreviewContext(mainTab)
    if not NS or not NS.UNIT_TYPES then return nil end
    if mainTab == 2 then return NS.UNIT_TYPES.FRIENDLY_PLAYER end
    if mainTab == 3 then return NS.UNIT_TYPES.FRIENDLY_NPC end
    if mainTab == 4 then return NS.UNIT_TYPES.ENEMY_PLAYER end
    if mainTab == 5 then return NS.UNIT_TYPES.ENEMY_NPC end
    return nil
end

local function UpdateContextButtons()
    if not PreviewFrame or not PreviewFrame.ContextButtons then return end
    for unitType, btn in pairs(PreviewFrame.ContextButtons) do
        local selected = (unitType == CurrentContext)
        btn:SetBackdropBorderColor(unpack(selected and NS.COLOR_ACCENT or { 0.2, 0.2, 0.2, 1 }))
        btn.Text:SetTextColor(unpack(selected and { 1, 1, 1, 1 } or { 0.7, 0.7, 0.7, 1 }))
    end
end

ApplyPreviewFont = function(fs, fontPath, fontSize, style)
    if not fs then return end

    local fontStyle = (style == "SHADOW" or style == "NONE") and nil or style
    if not fs:SetFont(fontPath, fontSize, fontStyle) then
        fs:SetFont(STANDARD_TEXT_FONT, fontSize, fontStyle)
    end

    if style == "SHADOW" then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
    end
end

local function GetPreviewGradientColor()
    local pct = SAMPLE_HEALTH_PCT
    if pct < 0 then pct = 0 end
    if pct > 1 then pct = 1 end
    return 1 - pct, pct, 0
end

local function ApplyHpTextStyle(db, gdb)
    if not PreviewFrame or not PreviewFrame.HpValueText or not PreviewFrame.BarAnchor then return end

    local valueText = PreviewFrame.HpValueText
    local bracketLeft = PreviewFrame.HpBracketLeft
    local percentText = PreviewFrame.HpPercentText
    local bracketRight = PreviewFrame.HpBracketRight
    local anchor = PreviewFrame.BarAnchor

    local function HideAll()
        valueText:Hide()
        bracketLeft:Hide()
        percentText:Hide()
        bracketRight:Hide()
    end

    if not db.hpTextEnable then
        HideAll()
        return
    end

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local fontSize = db.hpFontSize or 10
    local style = db.hpFontOutline or "OUTLINE"
    ApplyPreviewFont(valueText, fontPath, fontSize, style)
    ApplyPreviewFont(bracketLeft, fontPath, fontSize, style)
    ApplyPreviewFont(percentText, fontPath, fontSize, style)
    ApplyPreviewFont(bracketRight, fontPath, fontSize, style)

    local mode = db.hpDisplayMode or "PERCENT"
    local align = db.hpTextAlign or "RIGHT"
    local offX = db.hpOffsetX or 0
    local offY = db.hpOffsetY or 0

    valueText:ClearAllPoints()
    bracketLeft:ClearAllPoints()
    percentText:ClearAllPoints()
    bracketRight:ClearAllPoints()

    valueText:SetText(FormatPreviewHealthValue(SAMPLE_HEALTH_CUR))
    percentText:SetFormattedText("%.0f%%", SAMPLE_HEALTH_PCT * 100)
    bracketLeft:SetText(" (")
    bracketRight:SetText(")")

    if db.hpColorMode == 1 then
        local r, g, b = GetPreviewGradientColor()
        valueText:SetTextColor(r, g, b, 1)
        percentText:SetTextColor(r, g, b, 1)
        bracketLeft:SetTextColor(r * 0.7, g * 0.7, b * 0.7, 1)
        bracketRight:SetTextColor(r * 0.7, g * 0.7, b * 0.7, 1)
    else
        local c = db.hpColor or { r = 1, g = 1, b = 1 }
        local r, g, b = c.r or 1, c.g or 1, c.b or 1
        valueText:SetTextColor(r, g, b, 1)
        percentText:SetTextColor(r, g, b, 1)
        bracketLeft:SetTextColor(r * 0.7, g * 0.7, b * 0.7, 1)
        bracketRight:SetTextColor(r * 0.7, g * 0.7, b * 0.7, 1)
    end

    HideAll()
    if mode == "VALUE" then
        valueText:Show()
        valueText:SetPoint(align, anchor, align, offX, offY)
    elseif mode == "PERCENT" then
        percentText:Show()
        percentText:SetPoint(align, anchor, align, offX, offY)
    else
        valueText:Show()
        bracketLeft:Show()
        percentText:Show()
        bracketRight:Show()

        if align == "RIGHT" then
            bracketRight:SetPoint("RIGHT", anchor, "RIGHT", offX, offY)
            percentText:SetPoint("RIGHT", bracketRight, "LEFT", 0, 0)
            bracketLeft:SetPoint("RIGHT", percentText, "LEFT", 0, 0)
            valueText:SetPoint("RIGHT", bracketLeft, "LEFT", 0, 0)
        elseif align == "LEFT" then
            valueText:SetPoint("LEFT", anchor, "LEFT", offX, offY)
            bracketLeft:SetPoint("LEFT", valueText, "RIGHT", 0, 0)
            percentText:SetPoint("LEFT", bracketLeft, "RIGHT", 0, 0)
            bracketRight:SetPoint("LEFT", percentText, "RIGHT", 0, 0)
        else
            valueText:SetPoint("CENTER", anchor, "CENTER", offX, offY)
            bracketLeft:SetPoint("LEFT", valueText, "RIGHT", 0, 0)
            percentText:SetPoint("LEFT", bracketLeft, "RIGHT", 0, 0)
            bracketRight:SetPoint("LEFT", percentText, "RIGHT", 0, 0)
        end
    end
end

local function ApplyLevelStyle(db, gdb, sample)
    if not PreviewFrame or not PreviewFrame.LevelFS or not PreviewFrame.BarAnchor then return end

    local levelFS = PreviewFrame.LevelFS
    if not db.levelEnable then
        levelFS:Hide()
        return
    end

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local fontSize = db.levelFontSize or 10
    local style = db.levelFontOutline or "OUTLINE"
    ApplyPreviewFont(levelFS, fontPath, fontSize, style)

    local level = tonumber(sample and sample.level) or 80
    levelFS:SetText(tostring(level))

    if db.levelColorMode == 2 then
        local c = db.levelColor or { r = 1, g = 1, b = 1 }
        levelFS:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)
    else
        local qc = GetQuestDifficultyColor and GetQuestDifficultyColor(level)
        if qc then
            levelFS:SetTextColor(qc.r or 1, qc.g or 1, qc.b or 1, 1)
        else
            levelFS:SetTextColor(1, 1, 1, 1)
        end
    end

    local side = db.levelAnchor or "LEFT"
    local offX = db.levelX or 0
    local offY = db.levelY or 0

    levelFS:ClearAllPoints()
    if side == "LEFT" then
        levelFS:SetPoint("RIGHT", PreviewFrame.BarAnchor, "LEFT", offX - 5, offY)
        levelFS:SetJustifyH("RIGHT")
    else
        levelFS:SetPoint("LEFT", PreviewFrame.BarAnchor, "RIGHT", offX + 5, offY)
        levelFS:SetJustifyH("LEFT")
    end
    levelFS:SetShown(true)
end


local function GetGuildTargetScalePreview(db, gdb)
    if PreviewIsTarget and db and not db.guildTextDisableTargetScale then
        return tonumber(gdb and gdb.nameplateSelectedScale) or 1.2
    end
    return 1
end

local function GetGuildNameShift(db, gdb, sample)
    if not db or not db.guildTextEnable then return 0 end
    if not sample or not sample.isPlayer or not sample.guildName then return 0 end

    local text = FormatGuildText(sample.guildName)
    local targetScale = GetGuildTargetScalePreview(db, gdb)
    local guildTextModule = NS.Modules and NS.Modules.GuildText
    if guildTextModule and guildTextModule.CalculateNameShift then
        local ok, shift = pcall(guildTextModule.CalculateNameShift, text, db, gdb, targetScale)
        if ok and shift then
            shift = tonumber(shift) or 0
            if shift > 0 then
                return shift
            end
            return 0
        end
    end

    if (db.guildTextMode or "UNDER_NAME") ~= "UNDER_NAME" then return 0 end

    local fontSize = (db.guildTextFontSize or 7) * targetScale
    local offY = db.guildTextY or 0
    local gap = 1
    return math.max(0, math.ceil(fontSize) + gap - offY)
end

local function ApplyGuildStyle(db, gdb, sample)
    if not PreviewFrame or not PreviewFrame.GuildFS then return end

    local fs = PreviewFrame.GuildFS
    local text = FormatGuildText(sample and sample.guildName)
    if not db.guildTextEnable or not sample or not sample.isPlayer or not text then
        fs:Hide()
        return
    end

    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local targetScale = GetGuildTargetScalePreview(db, gdb)
    local fontSize = (db.guildTextFontSize or 7) * targetScale
    local style = db.guildTextOutline or "SHADOW"
    ApplyPreviewFont(fs, fontPath, fontSize, style)

    fs:SetText(text)
    fs:SetWidth((db.guildTextWidth or 135) * targetScale)
    fs:SetJustifyV("TOP")

    local align = db.guildTextAlign or "CENTER"
    fs:SetJustifyH(align)

    local c = db.guildTextColor or { r = 1, g = 1, b = 1 }
    fs:SetTextColor(c.r or 1, c.g or 1, c.b or 1, 1)

    local offX = db.guildTextX or 0
    local offY = db.guildTextY or 0
    local mode = db.guildTextMode or "UNDER_NAME"
    local anchorRegion = PreviewFrame.BarAnchor

    if mode == "UNDER_NAME" and PreviewFrame.NameFS and PreviewFrame.NameFS:IsShown() then
        anchorRegion = PreviewFrame.NameAnchor or PreviewFrame.NameFS
    end

    fs:ClearAllPoints()
    if align == "LEFT" then
        fs:SetPoint("TOPLEFT", anchorRegion, (mode == "UNDER_NAME") and "BOTTOMLEFT" or "BOTTOMLEFT", offX, offY)
    elseif align == "RIGHT" then
        fs:SetPoint("TOPRIGHT", anchorRegion, (mode == "UNDER_NAME") and "BOTTOMRIGHT" or "BOTTOMRIGHT", offX, offY)
    else
        fs:SetPoint("TOP", anchorRegion, (mode == "UNDER_NAME") and "BOTTOM" or "BOTTOM", offX, offY)
    end

    fs:Show()
end

local function ApplyClassificationIconStyle(gdb, sample)
    local holder = PreviewFrame and PreviewFrame.ClassifIconHolder
    local icon = holder and holder.Icon
    if not holder or not icon then return end

    if not gdb or not gdb.classifEnabled or not sample or sample.isPlayer or not sample.classification then
        SetIconHolderShown(holder, false)
        return
    end

    if gdb.classifHideAllies and (CurrentContext == NS.UNIT_TYPES.FRIENDLY_NPC) then
        SetIconHolderShown(holder, false)
        return
    end

    if gdb.classifShowBossRareOnly and sample.classification == "elite" then
        SetIconHolderShown(holder, false)
        return
    end

    local atlas, sizeMult = GetClassificationPreviewAtlas(sample.classification)
    if not atlas then
        SetIconHolderShown(holder, false)
        return
    end

    icon:SetAtlas(atlas)
    local size = 16 * (gdb.classifScale or 1) * (sizeMult or 1)
    holder:SetSize(size, size)
    ApplyPreviewStatusAnchor(holder, gdb.classifAnchor or "HpBar", gdb.classifX or 0, gdb.classifY or 0)
    holder:SetAlpha(gdb.classifAlpha == nil and 1 or gdb.classifAlpha)

    if gdb.classifMirror then
        icon:SetTexCoord(1, 0, 0, 1)
    else
        icon:SetTexCoord(0, 1, 0, 1)
    end

    SetIconHolderShown(holder, true)
end

local function ApplyFactionIconStyle(gdb, sample)
    local holder = PreviewFrame and PreviewFrame.FactionIconHolder
    local icon = holder and holder.Icon
    if not holder or not icon then return end

    if not gdb or not gdb.factionIconEnabled or not sample or not sample.faction then
        SetIconHolderShown(holder, false)
        return
    end

    if gdb.factionIconOnlyPlayers and not sample.isPlayer then
        SetIconHolderShown(holder, false)
        return
    end

    local style = tonumber(gdb.factionIconStyle) or 3
    local atlasSet = FACTION_ICON_ATLAS_BY_STYLE[style] or FACTION_ICON_ATLAS_BY_STYLE[3]
    local atlas = atlasSet and atlasSet[sample.faction] or nil
    if not atlas then
        SetIconHolderShown(holder, false)
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetAtlas(atlas, true)
    local size = gdb.factionIconSize or 20
    holder:SetSize(size, size)
    ApplyPreviewStatusAnchor(holder, gdb.factionIconAnchor or "HpBar", gdb.factionIconX or 0, gdb.factionIconY or 0)
    holder:SetAlpha(gdb.factionIconAlpha == nil and 1 or gdb.factionIconAlpha)
    SetIconHolderShown(holder, true)
end

local function ApplyQuestIconStyle(gdb, sample)
    local holder = PreviewFrame and PreviewFrame.QuestIconHolder
    local icon = holder and holder.Icon
    if not holder or not icon then return end

    if not gdb or not gdb.questIconEnabled or not sample or sample.isPlayer or not sample.questObjective then
        SetIconHolderShown(holder, false)
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    icon:SetAtlas("QuestNormal")
    local size = gdb.questIconSize or 20
    holder:SetSize(size, size)
    ApplyPreviewStatusAnchor(holder, gdb.questIconAnchor or "HpBar", gdb.questIconX or 0, gdb.questIconY or 0)
    holder:SetAlpha(gdb.questIconAlpha == nil and 1 or gdb.questIconAlpha)
    SetIconHolderShown(holder, true)
end

local function ApplyRaidTargetIconStyle(gdb, sample)
    local holder = PreviewFrame and PreviewFrame.RaidTargetIconHolder
    local icon = holder and holder.Icon
    if not holder or not icon then return end

    if not gdb or not gdb.raidTargetIconEnabled or not sample or not sample.raidTargetIndex then
        SetIconHolderShown(holder, false)
        return
    end

    icon:SetTexCoord(0, 1, 0, 1)
    SetRaidTargetTexture(icon, sample.raidTargetIndex)
    local size = gdb.raidTargetIconSize or 20
    holder:SetSize(size, size)
    ApplyPreviewStatusAnchor(holder, gdb.raidTargetIconAnchor or "HpBar", gdb.raidTargetIconX or 0, gdb.raidTargetIconY or 0)
    holder:SetAlpha(gdb.raidTargetIconAlpha == nil and 1 or gdb.raidTargetIconAlpha)
    SetIconHolderShown(holder, true)
end

local function ApplyStatusIcons(gdb, sample)
    if not PreviewFrame then return end
    ApplyClassificationIconStyle(gdb, sample)
    ApplyFactionIconStyle(gdb, sample)
    ApplyQuestIconStyle(gdb, sample)
    ApplyRaidTargetIconStyle(gdb, sample)
end

local function ApplyNameStyle(db, gdb, sample, extraShiftY)
    if not PreviewFrame or not PreviewFrame.NameFS then return end

    local fs = PreviewFrame.NameFS
    local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
    local targetScale = 1
    if PreviewIsTarget and not db.nameDisableTargetScale then
        targetScale = tonumber(gdb and gdb.nameplateSelectedScale) or 1.2
    end

    local fontSize = (db.fontScale or 8) * targetScale
    local wrapWidth = (db.nameWrapWidth or 135) * targetScale
    local style = db.fontOutline or "SHADOW"
    local fontStyle = (style == "SHADOW" or style == "NONE") and nil or style

    if not fs:SetFont(fontPath, fontSize, fontStyle) then
        fs:SetFont(STANDARD_TEXT_FONT, fontSize, fontStyle)
    end

    if style == "SHADOW" then
        fs:SetShadowOffset(1, -1)
        fs:SetShadowColor(0, 0, 0, 1)
    else
        fs:SetShadowOffset(0, 0)
        fs:SetShadowColor(0, 0, 0, 0)
    end

    local alignH = db.textAlign or "CENTER"
    fs:SetJustifyH(alignH)
    fs:SetJustifyV("BOTTOM")
    fs:SetWordWrap(db.nameWordWrap ~= false)
    if fs.SetMaxLines then
        fs:SetMaxLines((db.nameWordWrap ~= false) and 0 or 1)
    end
    fs:SetWidth(wrapWidth)

    local r, g, b = ResolveColorByMode(
        db,
        CurrentContext,
        "nameColorMode",
        "nameColor",
        "nameColorHostile",
        "nameColorFriendly",
        "nameColorNeutral",
        sample
    )
    fs:SetTextColor(r, g, b, 1)
    fs:SetText(sample.name or "")

    PreviewFrame.NameAnchor:ClearAllPoints()
    if alignH == "LEFT" then
        PreviewFrame.NameAnchor:SetPoint("BOTTOMLEFT", PreviewFrame.BarAnchor, "TOPLEFT", db.textX or 0, (db.textY or 0) + (extraShiftY or 0))
    elseif alignH == "RIGHT" then
        PreviewFrame.NameAnchor:SetPoint("BOTTOMRIGHT", PreviewFrame.BarAnchor, "TOPRIGHT", db.textX or 0, (db.textY or 0) + (extraShiftY or 0))
    else
        PreviewFrame.NameAnchor:SetPoint("BOTTOM", PreviewFrame.BarAnchor, "TOP", db.textX or 0, (db.textY or 0) + (extraShiftY or 0))
    end

    fs:ClearAllPoints()
    if alignH == "LEFT" then
        fs:SetPoint("BOTTOMLEFT", PreviewFrame.NameAnchor, "BOTTOMLEFT", 0, 0)
    elseif alignH == "RIGHT" then
        fs:SetPoint("BOTTOMRIGHT", PreviewFrame.NameAnchor, "BOTTOMRIGHT", 0, 0)
    else
        fs:SetPoint("BOTTOM", PreviewFrame.NameAnchor, "BOTTOM", 0, 0)
    end

    fs:SetShown(db.nameEnable ~= false)
end

local function ApplyHealthStyle(db, sample)
    if not PreviewFrame or not PreviewFrame.BarAnchor then return end

    local width = db.plateWidth or 140
    local height = db.plateHeight or 8
    if width < 1 then width = 1 end
    if height < 1 then height = 1 end

    PreviewFrame.BarAnchor:SetSize(width, height)
    if PreviewFrame.ArtAnchor then
        PreviewFrame.ArtAnchor:SetSize(width, height)
    end

    local artAnchor = PreviewFrame.ArtAnchor or PreviewFrame.BarAnchor

    -- All atlas parts are first snapped to the same visual rect.
    -- This keeps symmetric top/bottom growth around the center when height changes.
    SnapRectToAnchor(PreviewFrame.BackgroundFrame, artAnchor, ATLAS_TUNING.Background)
    SnapRectToAnchor(PreviewFrame.FillClipFrame, artAnchor, ATLAS_TUNING.Fill)
    SnapRectToAnchor(PreviewFrame.OverlayFrame, artAnchor, ATLAS_TUNING.Overlay)

    PreviewFrame.HealthBarBG:ClearAllPoints()
    PreviewFrame.HealthBarBG:SetAllPoints(PreviewFrame.BackgroundFrame)

    PreviewFrame.HealthBarOverlay:ClearAllPoints()
    PreviewFrame.HealthBarOverlay:SetAllPoints(PreviewFrame.OverlayFrame)

    local fillW = PreviewFrame.FillClipFrame:GetWidth() or 1
    local fillH = PreviewFrame.FillClipFrame:GetHeight() or 1
    if fillW < 1 then fillW = 1 end
    if fillH < 1 then fillH = 1 end

    PreviewFrame.FillTexture:ClearAllPoints()
    PreviewFrame.FillTexture:SetPoint("LEFT", PreviewFrame.FillClipFrame, "LEFT", 0, 0)
    PreviewFrame.FillTexture:SetPoint("TOP", PreviewFrame.FillClipFrame, "TOP", 0, 0)
    PreviewFrame.FillTexture:SetPoint("BOTTOM", PreviewFrame.FillClipFrame, "BOTTOM", 0, 0)
    PreviewFrame.FillTexture:SetWidth(math.max(1, math.floor(fillW * SAMPLE_HEALTH_PCT + 0.5)))

    local r, g, b = ResolveColorByMode(
        db,
        CurrentContext,
        "healthColorMode",
        "healthColor",
        "healthColorHostile",
        "healthColorFriendly",
        "healthColorNeutral",
        sample
    )

    local hpBarEnabled = (db.hpBarEnable ~= false)

    PreviewFrame.FillTexture:SetVertexColor(r, g, b, 1)

    if PreviewFrame.BackgroundFrame then
        PreviewFrame.BackgroundFrame:SetShown(hpBarEnabled)
    end
    if PreviewFrame.FillClipFrame then
        PreviewFrame.FillClipFrame:SetShown(hpBarEnabled)
    end
    if PreviewFrame.OverlayFrame then
        PreviewFrame.OverlayFrame:SetShown(hpBarEnabled)
    end

    PreviewFrame.FillTexture:SetShown(hpBarEnabled)
    PreviewFrame.HealthBarBG:SetShown(hpBarEnabled)
    PreviewFrame.HealthBarOverlay:SetShown(hpBarEnabled)
    PreviewFrame.HealthBarBG:SetAlpha(hpBarEnabled and 1 or 0)
    PreviewFrame.HealthBarOverlay:SetAlpha(hpBarEnabled and 1 or 0)
end

local function HidePreviewClassResource()
    local CR = NS and NS.ClassResourceInternal
    if not CR or not PreviewFrame or not PreviewFrame.ClassResourceProxy then return end

    local proxy = PreviewFrame.ClassResourceProxy
    if proxy.BPF_ClassResourceHolder then
        CR.HideAll(proxy, CR.GetState(proxy))
    end
end

local function ApplyClassResourceStyle(gdb)
    local CR = NS and NS.ClassResourceInternal
    if not CR or not PreviewFrame or not PreviewFrame.ClassResourceProxy then return end

    if not gdb or gdb.classResourceEnabled ~= true then
        HidePreviewClassResource()
        return
    end

    local sample = GetPreviewClassResourceSample()
    if not sample or not sample.powerType or not sample.maxPower or sample.maxPower <= 0 then
        HidePreviewClassResource()
        return
    end

    local proxy = PreviewFrame.ClassResourceProxy
    local st = CR.EnsureHolder(proxy)
    local holder = proxy.BPF_ClassResourceHolder
    if not holder then return end

    local style = CR.GetConfiguredStyle(gdb)
    local renderStyle = CR.GetEffectiveRenderStyle(style, sample.powerType)

    local width, height, spacing, offX, offY, restoringAlpha, showEmpty, reverseFill
    local anchorMode = tonumber(gdb.classResourceAnchorMode) or 1
    if style == CR.STYLE_MODERN then
        local modernScale = tonumber(gdb.classResourceModernScale) or 1
        if modernScale < 0.5 then modernScale = 0.5 elseif modernScale > 3 then modernScale = 3 end

        local skin = CR.GetModernSkin(sample.powerType)
        local baseWidth = (skin and tonumber(skin.baseWidth)) or 18
        local baseHeight = (skin and tonumber(skin.baseHeight)) or 18
        local baseSpacing = tonumber(gdb.classResourceModernSpacing) or 4

        width = math.max(6, math.floor((baseWidth * modernScale) + 0.5))
        height = math.max(6, math.floor((baseHeight * modernScale) + 0.5))
        spacing = math.max(0, math.floor((baseSpacing * modernScale) + 0.5))
        offX = tonumber(gdb.classResourceModernOffsetX) or 0
        offY = tonumber(gdb.classResourceModernOffsetY) or -16
        restoringAlpha = tonumber(gdb.classResourceModernInactiveAlpha)
        if restoringAlpha == nil then restoringAlpha = 0.35 end
        showEmpty = (gdb.classResourceShowEmpty ~= false)
        reverseFill = (gdb.classResourceReverseFill == true)
    else
        width = math.max(6, tonumber(gdb.classResourceWidth) or 16)
        height = math.max(4, tonumber(gdb.classResourceHeight) or 8)
        spacing = math.max(0, tonumber(gdb.classResourceSpacing) or 3)
        offX = tonumber(gdb.classResourceOffsetX) or 0
        offY = tonumber(gdb.classResourceOffsetY) or -14
        restoringAlpha = tonumber(gdb.classResourceInactiveAlpha)
        if restoringAlpha == nil then restoringAlpha = 0.25 end
        showEmpty = (gdb.classResourceShowEmpty ~= false)
        reverseFill = (gdb.classResourceReverseFill == true)
    end

    if restoringAlpha < 0 then restoringAlpha = 0 elseif restoringAlpha > 1 then restoringAlpha = 1 end

    if st.lastStyle ~= style or st.lastRenderStyle ~= renderStyle then
        CR.ResetSlotStyles(st)
    end
    st.lastStyle = style
    st.lastRenderStyle = renderStyle
    st.lastReverseFill = reverseFill

    local count = sample.maxPower
    local layoutChanged = (st.lastWidth ~= width or st.lastHeight ~= height or st.lastSpacing ~= spacing or st.lastCount ~= count)
    if layoutChanged then
        CR.UpdateSlotLayout(holder, st, count, width, height, spacing)
        st.lastWidth = width
        st.lastHeight = height
        st.lastSpacing = spacing
    end

    local castShown = (anchorMode == 2) and proxy.castBar and proxy.castBar:IsShown() or false
    if st.lastOffX ~= offX or st.lastOffY ~= offY or st.lastAnchorMode ~= anchorMode or st.lastAnchorCastShown ~= castShown then
        CR.ApplyAnchor(proxy, holder, offX, offY, anchorMode)
        st.lastOffX = offX
        st.lastOffY = offY
        st.lastAnchorMode = anchorMode
        st.lastAnchorCastShown = castShown
    end

    if sample.powerType == CR.POWER_RUNES and sample.snapshot then
        CR.RenderRuneSnapshot(st, count, sample.snapshot, reverseFill, restoringAlpha, renderStyle, sample.powerType)
    else
        CR.UpdateGeneric(
            st,
            count,
            sample.current or 0,
            restoringAlpha,
            showEmpty,
            reverseFill,
            sample.partial or 0,
            math.max(1, (st.lastWidth or width) - 2),
            sample.powerType,
            renderStyle
        )
    end

    holder:Show()
    st.lastShown = true
    st.lastResource = sample.powerType
    st.lastCount = count
    st.lastMax = count
    st.lastShowEmpty = showEmpty
    st.lastInactiveAlpha = restoringAlpha
end

local function ApplyCastBarStyle(db, gdb, sample)
    if not PreviewFrame or not PreviewFrame.CastBarAnchor then return end

    local showCast = db.cbEnabled ~= false
    PreviewFrame.CastRoot:SetShown(showCast)
    if not showCast then
        PreviewFrame.CastShield:Hide()
        PreviewFrame.CastBackground:Hide()
        PreviewFrame.CastFillClip:Hide()
        PreviewFrame.CastFill:Hide()
        PreviewFrame.CastTextFS:Hide()
        PreviewFrame.CastTargetFS:Hide()
        PreviewFrame.CastIcon:Hide()
        PreviewFrame.CastIconBorder:Hide()
        return
    end

    PreviewFrame.CastBackground:Show()
    PreviewFrame.CastFillClip:Show()
    PreviewFrame.CastFill:Show()

    local castW = db.cbWidth or 142
    local castH = db.cbHeight or 8
    if castW < 1 then castW = 1 end
    if castH < 1 then castH = 1 end

    local castOffY = (db.cbY or -1) - 2
    PreviewFrame.CastBarAnchor:ClearAllPoints()
    PreviewFrame.CastBarAnchor:SetPoint("TOP", PreviewFrame.BarAnchor, "BOTTOM", db.cbX or 0, castOffY)
    PreviewFrame.CastBarAnchor:SetSize(castW, castH)

    PreviewFrame.CastBackground:ClearAllPoints()
    PreviewFrame.CastBackground:SetPoint("TOPLEFT", PreviewFrame.CastBarAnchor, "TOPLEFT", 0, 0)
    PreviewFrame.CastBackground:SetPoint("BOTTOMRIGHT", PreviewFrame.CastBarAnchor, "BOTTOMRIGHT", -1, 0)

    PreviewFrame.CastFillClip:ClearAllPoints()
    PreviewFrame.CastFillClip:SetAllPoints(PreviewFrame.CastBarAnchor)

    local fillW = PreviewFrame.CastFillClip:GetWidth() or 1
    if fillW < 1 then fillW = 1 end
    PreviewFrame.CastFill:ClearAllPoints()
    PreviewFrame.CastFill:SetPoint("LEFT", PreviewFrame.CastFillClip, "LEFT", 0, 0)
    PreviewFrame.CastFill:SetPoint("TOP", PreviewFrame.CastFillClip, "TOP", 0, 0)
    PreviewFrame.CastFill:SetPoint("BOTTOM", PreviewFrame.CastFillClip, "BOTTOM", 0, 0)
    PreviewFrame.CastFill:SetWidth(math.max(1, math.floor(fillW * SAMPLE_CAST_PROGRESS + 0.5)))

    local barShown = db.cbBarEnabled ~= false
    PreviewFrame.CastBackground:SetAlpha(barShown and 1 or 0)
    PreviewFrame.CastFill:SetAlpha(barShown and 1 or 0)

    local shieldShown = barShown and sample and sample.castInterruptible == false and not (gdb and gdb.hideCastShield)
    PreviewFrame.CastShield:SetShown(shieldShown)
    if shieldShown then
        PreviewFrame.CastShield:ClearAllPoints()
        PreviewFrame.CastShield:SetPoint("TOPLEFT", PreviewFrame.CastBarAnchor, "TOPLEFT", -2, 2)
        PreviewFrame.CastShield:SetPoint("BOTTOMRIGHT", PreviewFrame.CastBarAnchor, "BOTTOMRIGHT", 2, -2)
    end

    local text = PreviewFrame.CastTextFS
    if db.cbTextEnabled then
        local fontPath = NS.GetFontPath(gdb and gdb.globalFont)
        local fontSize = db.cbFontSize or 9
        local outline = db.cbTextOutline or "SHADOW"
        ApplyPreviewFont(text, fontPath, fontSize, outline)
        text:SetTextColor((db.cbTextColor and db.cbTextColor.r) or 1, (db.cbTextColor and db.cbTextColor.g) or 1, (db.cbTextColor and db.cbTextColor.b) or 1, 1)
        text:SetJustifyH(db.cbTextJustify or "LEFT")
        text:SetWordWrap(false)
        text:SetWidth((db.cbTextMaxLength and db.cbTextMaxLength > 0) and (db.cbTextMaxLength * (fontSize * 0.75)) or (castW - 8))
        text:ClearAllPoints()
        local tx, ty = db.cbTextX or 0, db.cbTextY or 0
        local j = db.cbTextJustify or "CENTER"
        if j == "LEFT" then
            text:SetPoint("LEFT", PreviewFrame.CastBarAnchor, "LEFT", tx + 4, ty)
        elseif j == "RIGHT" then
            text:SetPoint("RIGHT", PreviewFrame.CastBarAnchor, "RIGHT", tx - 4, ty)
        else
            text:SetPoint("CENTER", PreviewFrame.CastBarAnchor, "CENTER", tx, ty)
        end
        local spellName = GetSpellNameByID(sample and sample.castSpellID, NS.L("Fireball"))
        text:SetText(TruncatePreviewText(spellName, db.cbTextMaxLength))
        text:Show()
    else
        text:Hide()
    end

    local icon = PreviewFrame.CastIcon
    local border = PreviewFrame.CastIconBorder
    if db.cbIconEnabled then
        local size = db.cbIconSize or 20
        icon:ClearAllPoints()
        icon:SetPoint("RIGHT", PreviewFrame.CastBarAnchor, "LEFT", db.cbIconX or -3, db.cbIconY or 7)
        icon:SetSize(size, size)
        icon:SetTexture(GetSpellTextureByID(sample and sample.castSpellID, 136243))
        icon:SetTexCoord(0.08, 0.92, 0.08, 0.92)
        icon:Show()

        local showBorder = (db.cbIconBorderEnable ~= false) and ((tonumber(db.cbIconBorderThickness) or 0) > 0)
        if showBorder then
            local t = tonumber(db.cbIconBorderThickness) or 0
            local c = db.cbIconBorderColor or { r = 0, g = 0, b = 0, a = 1 }
            border:ClearAllPoints()
            border:SetPoint("TOPLEFT", icon, "TOPLEFT", -t, t)
            border:SetPoint("BOTTOMRIGHT", icon, "BOTTOMRIGHT", t, -t)
            border:SetColorTexture(1, 1, 1, 1)
            border:SetVertexColor(c.r or 0, c.g or 0, c.b or 0, c.a or 1)
            border:Show()
        else
            border:Hide()
        end
    else
        icon:Hide()
        border:Hide()
    end

    ApplyPreviewCastTargetStyle(db, gdb, sample, castW)
end

local function ApplyPreviewTargetStyle(db)
    if not PreviewFrame then return end

    local isTarget = PreviewIsTarget and true or false
    if PreviewFrame.TargetCheck and PreviewFrame.TargetCheck:GetChecked() ~= isTarget then
        PreviewFrame.TargetCheck:SetChecked(isTarget)
    end

    local border = PreviewFrame.TargetSelectedBorder
    local arrow = PreviewFrame.TargetArrow
    local left = PreviewFrame.TargetMarkerLeft
    local right = PreviewFrame.TargetMarkerRight

    local function HideArrow()
        if not arrow then return end
        arrow:Hide()
        if arrow.ag and arrow.ag:IsPlaying() then
            arrow.ag:Stop()
        end
    end

    local function HideSymbols()
        if left then left:Hide() end
        if right then right:Hide() end
    end

    if not isTarget or not db or db.targetIndicatorEnable == false then
        if border then border:Hide() end
        HideArrow()
        HideSymbols()
        return
    end

    if border then
        if db.targetBorderEnabled then
            ApplyEdgeOffsets(border, PreviewFrame.BarAnchor, { left = -3, right = 3, top = 4, bottom = -3 })
            local c = db.targetBorderColor
            border:SetVertexColor((c and c.r) or 1, (c and c.g) or 1, (c and c.b) or 1, (c and c.a) or 1)
            border:Show()
        else
            border:Hide()
        end
    end

    if arrow then
        if db.targetIndicatorArrowEnable then
            local size = tonumber(db.targetIndicatorArrowSize) or 30
            if size < 1 then size = 1 end
            arrow:SetSize(size, size)
            arrow:ClearAllPoints()
            arrow:SetPoint("BOTTOM", PreviewFrame.BarAnchor, "TOP", db.targetIndicatorArrowX or 0, db.targetIndicatorArrowY or 20)
            local ac = db.targetIndicatorArrowColor
            arrow:SetVertexColor((ac and ac.r) or 1, (ac and ac.g) or 1, (ac and ac.b) or 1, (ac and ac.a) or 1)
            arrow:Show()
            if db.targetIndicatorArrowAnim then
                if not arrow.ag:IsPlaying() then
                    arrow.ag:Play()
                end
            elseif arrow.ag:IsPlaying() then
                arrow.ag:Stop()
            end
        else
            HideArrow()
        end
    end

    if left and right then
        if db.targetIndicatorSymbolEnable then
            local fontSize = tonumber(db.targetIndicatorSymbolSize) or 18
            local outline = db.targetIndicatorSymbolOutline or "NONE"
            if outline == "SHADOW" then
                left:SetFont(STANDARD_TEXT_FONT, fontSize, nil)
                left:SetShadowColor(0, 0, 0, 1)
                left:SetShadowOffset(1, -1)
                right:SetFont(STANDARD_TEXT_FONT, fontSize, nil)
                right:SetShadowColor(0, 0, 0, 1)
                right:SetShadowOffset(1, -1)
            else
                local flag = (outline ~= "NONE") and outline or nil
                left:SetFont(STANDARD_TEXT_FONT, fontSize, flag)
                left:SetShadowOffset(0, 0)
                right:SetFont(STANDARD_TEXT_FONT, fontSize, flag)
                right:SetShadowOffset(0, 0)
            end

            local pair = GetTargetSymbolPair(db.targetIndicatorSymbolIndex or 1)
            left:SetText(pair[1])
            right:SetText(pair[2])

            local sc = db.targetIndicatorSymbolColor
            local r = (sc and sc.r) or 1
            local g = (sc and sc.g) or 1
            local b = (sc and sc.b) or 1
            local a = (sc and sc.a) or 1
            left:SetTextColor(r, g, b, a)
            right:SetTextColor(r, g, b, a)

            local sx = db.targetIndicatorSymbolX or 10
            local sy = db.targetIndicatorSymbolY or 0
            left:ClearAllPoints()
            right:ClearAllPoints()
            left:SetPoint("RIGHT", PreviewFrame.BarAnchor, "LEFT", -sx, sy)
            right:SetPoint("LEFT", PreviewFrame.BarAnchor, "RIGHT", sx, sy)
            left:Show()
            right:Show()
        else
            HideSymbols()
        end
    end
end

function NS.PreviewNameplate.Refresh()
    if not PreviewFrame or not PreviewFrame:IsShown() then return end
    CurrentContext = CurrentContext or NS.MenuState.previewContext or GetDefaultContext()
    NS.MenuState.previewContext = CurrentContext

    local db = NS.Config and NS.Config.GetTable and NS.Config.GetTable(CurrentContext)
    local gdb = NS.Config and NS.Config.GetTable and NS.Config.GetTable("Global")
    if not db or not gdb then return end

    local sample = GetSampleData(CurrentContext)
    local guildShift = GetGuildNameShift(db, gdb, sample)

    ApplyHealthStyle(db, sample)
    ApplyCastBarStyle(db, gdb, sample)
    ApplyPreviewTargetStyle(db)
    ApplyClassResourceStyle(gdb)
    ApplyNameStyle(db, gdb, sample, guildShift)
    ApplyGuildStyle(db, gdb, sample)
    ApplyHpTextStyle(db, gdb)
    ApplyLevelStyle(db, gdb, sample)
    ApplyStatusIcons(gdb, sample)

    local scale = tonumber(gdb.globalScale) or 1
    if scale < 0.5 then scale = 0.5 end
    if scale > 1.5 then scale = 1.5 end
    if PreviewIsTarget then
        local selectedScale = tonumber(gdb.nameplateSelectedScale) or 1.2
        if selectedScale < 0.5 then selectedScale = 0.5 end
        if selectedScale > 3 then selectedScale = 3 end
        scale = scale * selectedScale
    end
    PreviewFrame.SampleRoot:SetScale(scale)

    local profileEnabled = NS.Config.Get and NS.Config.Get("enabled", CurrentContext)
    PreviewFrame.SampleRoot:SetAlpha(profileEnabled and 1 or 0.45)
    PreviewFrame.ContextLabel:SetText(GetContextLabel(CurrentContext))
    UpdateContextButtons()
end

function NS.PreviewNameplate.SetContext(unitType)
    if not unitType then return end
    CurrentContext = unitType
    NS.MenuState.previewContext = unitType
    if PreviewFrame and PreviewFrame:IsShown() then
        NS.PreviewNameplate.Refresh()
    else
        UpdateContextButtons()
    end
end

function NS.PreviewNameplate.ApplyMainTab(mainTab)
    if not PreviewFrame then return end

    if mainTab == 6 then
        PreviewFrame:Hide()
        return
    end

    PreviewFrame:Show()

    local autoContext = GetMainPreviewContext(mainTab)
    if autoContext then
        CurrentContext = autoContext
        NS.MenuState.previewContext = autoContext
    elseif not CurrentContext then
        CurrentContext = NS.MenuState.previewContext or GetDefaultContext()
    end

    NS.PreviewNameplate.Refresh()
end

function NS.PreviewNameplate.NotifyConfigChanged()
    if PreviewFrame and PreviewFrame:IsShown() then
        NS.PreviewNameplate.Refresh()
    end
end

function NS.PreviewNameplate.Initialize(parent)
    if PreviewFrame then return PreviewFrame end

    CurrentContext = NS.MenuState.previewContext or GetDefaultContext()
    PreviewIsTarget = NS.MenuState.previewIsTarget and true or false

    local frame = CreateFrame("Frame", nil, parent, "BackdropTemplate")
    frame:SetSize(290, 250)
    frame:SetPoint("TOPLEFT", parent, "TOPRIGHT", 10, 0)
    frame:SetFrameStrata(parent:GetFrameStrata())
    frame:SetFrameLevel(parent:GetFrameLevel() + 5)
    frame:EnableMouse(true)
    frame:SetScript("OnMouseDown", function()
        if NS.CloseAllDropdowns then NS.CloseAllDropdowns() end
    end)
    NS.CreateBackdrop(frame, NS.COLOR_BG_DARK, NS.COLOR_BORDER)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    title:SetPoint("TOPLEFT", 12, -12)
    title:SetText(NS.L("Preview"))
    title:SetTextColor(1, 1, 1, 1)
    frame.Title = title

    local contextLabel = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    contextLabel:SetPoint("TOPRIGHT", -12, -14)
    contextLabel:SetTextColor(0.7, 0.7, 0.7, 1)
    frame.ContextLabel = contextLabel

    local sep = frame:CreateTexture(nil, "ARTWORK")
    sep:SetTexture("Interface\\Buttons\\WHITE8X8")
    sep:SetVertexColor(1, 1, 1, 0.06)
    sep:SetPoint("TOPLEFT", 10, -34)
    sep:SetPoint("TOPRIGHT", -10, -34)
    sep:SetHeight(1)

    frame.ContextButtons = {}
    local btnW, btnH = 126, 24
    local cols = 2
    for i, key in ipairs(CONTEXT_ORDER) do
        local unitType = NS.UNIT_TYPES and NS.UNIT_TYPES[key] or key
        local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
        btn:SetSize(btnW, btnH)
        local row = math.floor((i - 1) / cols)
        local col = (i - 1) % cols
        btn:SetPoint("TOPLEFT", 12 + (col * (btnW + 10)), -46 - (row * (btnH + 8)))
        NS.CreateBackdrop(btn, { 0, 0, 0, 0.35 }, { 0.2, 0.2, 0.2, 1 })
        btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.Text:SetPoint("CENTER")
        btn.Text:SetText(GetContextLabel(unitType))
        btn:SetScript("OnClick", function()
            if NS.CloseAllDropdowns then NS.CloseAllDropdowns() end
            NS.PreviewNameplate.SetContext(unitType)
        end)
        btn:SetScript("OnEnter", function(self)
            if unitType ~= CurrentContext then
                self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT))
                self.Text:SetTextColor(1, 1, 1, 1)
            end
        end)
        btn:SetScript("OnLeave", function(self)
            if unitType ~= CurrentContext then
                self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1)
                self.Text:SetTextColor(0.7, 0.7, 0.7, 1)
            end
        end)
        frame.ContextButtons[unitType] = btn
    end

    local previewArea = CreateFrame("Frame", nil, frame, "BackdropTemplate")
    previewArea:SetPoint("TOPLEFT", 12, -112)
    previewArea:SetPoint("BOTTOMRIGHT", -12, 12)
    NS.CreateBackdrop(previewArea, { 0, 0, 0, 0.22 }, { 0.15, 0.15, 0.18, 1 })
    frame.PreviewArea = previewArea

    local targetCheck = NS.CreateModernCheckbox and NS.CreateModernCheckbox(previewArea, NS.L("Take target")) or CreateFrame("CheckButton", nil, previewArea, "UICheckButtonTemplate")
    targetCheck:SetPoint("TOPLEFT", previewArea, "TOPLEFT", 8, -8)
    targetCheck:SetChecked(PreviewIsTarget)
    targetCheck:HookScript("OnClick", function(self)
        SetPreviewTargeted(self:GetChecked())
        NS.PreviewNameplate.Refresh()
    end)
    frame.TargetCheck = targetCheck

    local sampleRoot = CreateFrame("Frame", nil, previewArea)
    sampleRoot:SetSize(220, 80)
    sampleRoot:SetPoint("CENTER", previewArea, "CENTER", 0, -6)
    frame.SampleRoot = sampleRoot

    local barAnchor = CreateFrame("Frame", nil, sampleRoot)
    barAnchor:SetPoint("CENTER", sampleRoot, "CENTER", 0, -8)
    barAnchor:SetSize(140, 8)
    frame.BarAnchor = barAnchor

    local artAnchor = CreateFrame("Frame", nil, sampleRoot)
    artAnchor:SetPoint("CENTER", barAnchor, "CENTER", 0, 1)
    artAnchor:SetSize(140, 8)
    frame.ArtAnchor = artAnchor

    local bgFrame = CreateFrame("Frame", nil, artAnchor)
    bgFrame:SetFrameLevel(barAnchor:GetFrameLevel())
    frame.BackgroundFrame = bgFrame

    local bg = bgFrame:CreateTexture(nil, "ARTWORK")
    bg:SetAtlas("UI-HUD-CoolDownManager-Bar-BG")
    SetPixelPerfect(bg)
    frame.HealthBarBG = bg

    local fillClip = CreateFrame("Frame", nil, artAnchor)
    fillClip:SetFrameLevel(barAnchor:GetFrameLevel() + 1)
    if fillClip.SetClipsChildren then
        fillClip:SetClipsChildren(true)
    end
    frame.FillClipFrame = fillClip

    local fillTexture = fillClip:CreateTexture(nil, "ARTWORK")
    fillTexture:SetAtlas("UI-HUD-CoolDownManager-Bar")
    fillTexture:SetHorizTile(false)
    fillTexture:SetVertTile(false)
    SetPixelPerfect(fillTexture)
    frame.FillTexture = fillTexture

    local overlayFrame = CreateFrame("Frame", nil, artAnchor)
    overlayFrame:SetFrameLevel(barAnchor:GetFrameLevel() + 2)
    frame.OverlayFrame = overlayFrame

    local overlay = overlayFrame:CreateTexture(nil, "ARTWORK")
    overlay:SetAtlas("ui-hud-nameplates-deselected-overlay")
    SetPixelPerfect(overlay)
    frame.HealthBarOverlay = overlay

    local selectedBorder = overlayFrame:CreateTexture(nil, "OVERLAY", nil, 1)
    selectedBorder:SetAtlas("UI-HUD-Nameplates-Selected")
    SetPixelPerfect(selectedBorder)
    selectedBorder:Hide()
    frame.TargetSelectedBorder = selectedBorder

    local textOverlay = CreateFrame("Frame", nil, sampleRoot)
    textOverlay:SetAllPoints(sampleRoot)
    textOverlay:SetFrameLevel(overlayFrame:GetFrameLevel() + 10)
    frame.TextOverlay = textOverlay

    local nameAnchor = CreateFrame("Frame", nil, textOverlay)
    nameAnchor:SetSize(1, 1)
    nameAnchor:SetPoint("BOTTOM", barAnchor, "TOP", 0, 5)
    frame.NameAnchor = nameAnchor

    local nameFS = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    InitUnscaledPreviewFontString(nameFS)
    nameFS:SetPoint("BOTTOM", nameAnchor, "BOTTOM", 0, 0)
    frame.NameFS = nameFS

    local hpValueText = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    local hpBracketLeft = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    local hpPercentText = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    local hpBracketRight = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    InitScaledPreviewFontString(hpValueText)
    InitScaledPreviewFontString(hpBracketLeft)
    InitScaledPreviewFontString(hpPercentText)
    InitScaledPreviewFontString(hpBracketRight)
    frame.HpValueText = hpValueText
    frame.HpBracketLeft = hpBracketLeft
    frame.HpPercentText = hpPercentText
    frame.HpBracketRight = hpBracketRight

    local levelFS = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    InitScaledPreviewFontString(levelFS)
    frame.LevelFS = levelFS

    local guildFS = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    InitUnscaledPreviewFontString(guildFS)
    frame.GuildFS = guildFS

    local castRoot = CreateFrame("Frame", nil, sampleRoot)
    castRoot:SetAllPoints(sampleRoot)
    castRoot:SetFrameLevel(barAnchor:GetFrameLevel())
    frame.CastRoot = castRoot

    local castBarAnchor = CreateFrame("Frame", nil, castRoot)
    castBarAnchor:SetPoint("TOP", barAnchor, "BOTTOM", 0, -3)
    castBarAnchor:SetSize(142, 8)
    frame.CastBarAnchor = castBarAnchor

    sampleRoot.healthBar = barAnchor
    sampleRoot.castBar = castBarAnchor
    frame.ClassResourceProxy = sampleRoot

    local castBG = castRoot:CreateTexture(nil, "BACKGROUND")
    castBG:SetAtlas("ui-castingbar-background")
    SetPixelPerfect(castBG)
    frame.CastBackground = castBG

    local castFillClip = CreateFrame("Frame", nil, castRoot)
    castFillClip:SetFrameLevel(castBarAnchor:GetFrameLevel() + 1)
    if castFillClip.SetClipsChildren then
        castFillClip:SetClipsChildren(true)
    end
    frame.CastFillClip = castFillClip

    local castFill = castFillClip:CreateTexture(nil, "ARTWORK")
    if castFill.SetAtlas then
        castFill:SetAtlas("ui-castingbar-filling-standard", true)
    else
        castFill:SetTexture("Interface\\TargetingFrame\\UI-TargetingFrame-BarFill")
    end
    castFill:SetVertexColor(1, 1, 1, 1)
    castFill:SetHorizTile(false)
    castFill:SetVertTile(false)
    SetPixelPerfect(castFill)
    frame.CastFill = castFill

    local castShield = castRoot:CreateTexture(nil, "OVERLAY", nil, 2)
    castShield:SetAtlas("nameplates-InterruptShield")
    SetPixelPerfect(castShield)
    castShield:Hide()
    frame.CastShield = castShield

    local castTextFS = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    InitScaledPreviewFontString(castTextFS)
    frame.CastTextFS = castTextFS

    local castTargetFS = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    InitScaledPreviewFontString(castTargetFS)
    castTargetFS:Hide()
    frame.CastTargetFS = castTargetFS

    local castIconBorder = textOverlay:CreateTexture(nil, "OVERLAY", nil, 0)
    castIconBorder:Hide()
    frame.CastIconBorder = castIconBorder

    local castIcon = textOverlay:CreateTexture(nil, "OVERLAY", nil, 1)
    SetPixelPerfect(castIcon)
    castIcon:Hide()
    frame.CastIcon = castIcon

    local targetMarkerLeft = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    local targetMarkerRight = textOverlay:CreateFontString(nil, "OVERLAY", nil, 7)
    targetMarkerLeft:Hide()
    targetMarkerRight:Hide()
    frame.TargetMarkerLeft = targetMarkerLeft
    frame.TargetMarkerRight = targetMarkerRight

    local statusOverlay = CreateFrame("Frame", nil, sampleRoot)
    statusOverlay:SetAllPoints(sampleRoot)
    statusOverlay:SetFrameLevel(overlayFrame:GetFrameLevel() + 5)
    frame.StatusOverlay = statusOverlay

    local function CreateStatusHolder()
        local holder = CreateFrame("Frame", nil, statusOverlay)
        holder:SetSize(1, 1)
        local icon = holder:CreateTexture(nil, "ARTWORK")
        icon:SetAllPoints()
        SetPixelPerfect(icon)
        holder.Icon = icon
        holder:Hide()
        icon:Hide()
        return holder
    end

    frame.ClassifIconHolder = CreateStatusHolder()
    frame.FactionIconHolder = CreateStatusHolder()
    frame.QuestIconHolder = CreateStatusHolder()
    frame.RaidTargetIconHolder = CreateStatusHolder()

    local targetArrow = statusOverlay:CreateTexture(nil, "OVERLAY", nil, 7)
    targetArrow:SetTexture("Interface\\Minimap\\MiniMap-QuestArrow")
    targetArrow:SetTexCoord(0, 1, 1, 0)
    targetArrow:Hide()
    local ag = targetArrow:CreateAnimationGroup()
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
    targetArrow.ag = ag
    frame.TargetArrow = targetArrow

    PreviewFrame = frame
    NS.PreviewNameplate.Refresh()
    return frame
end
