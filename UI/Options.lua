local _, NS = ...
NS.Options = {}

function NS.Options.GetTable(mainIdx, subIdx)
    local t = {}

    -- ОПРЕДЕЛЯЕМ КОНТЕКСТ БАЗЫ ДАННЫХ
    local dbContext = nil
    if mainIdx == 1 then dbContext = "Global"
    elseif mainIdx == 2 then dbContext = NS.UNIT_TYPES.FRIENDLY_PLAYER
    elseif mainIdx == 3 then dbContext = NS.UNIT_TYPES.FRIENDLY_NPC
    elseif mainIdx == 4 then dbContext = NS.UNIT_TYPES.ENEMY_PLAYER
    elseif mainIdx == 5 then dbContext = NS.UNIT_TYPES.ENEMY_NPC
    end

    local function Add(widgetType, label, desc, dbKey, min, max, step, optionsList, column, extra)
        local e = extra or {}
        table.insert(t, {
            type = widgetType, 
            label = label, 
            desc = desc,
            text = label,
            db = dbKey, 
            min = min, max = max, step = step,
            options = optionsList,
            col = column or 1,
            onClick = e.onClick,
            onChange = e.onChange,
            getCurrent = e.getCurrent,
            val = e.val,
            group = e.group,
            offX = e.offX,
            offY = e.offY,
            width = (e.width or e.size),
            height = (e.height or e.size),
            requires = e.requires,
            noToggleLink = e.noToggleLink,
            -- extra payload for composite widgets
            unitTypeList = e.unitTypeList,
            sections = e.sections,
            srcKey = e.srcKey,
            dstKey = e.dstKey,
            context = (e.context ~= nil and e.context or dbContext) -- Передаем контекст автоматически
        })
    end

    -- ========================================================================
    -- ФУНКЦИЯ ГЕНЕРАЦИИ НАСТРОЕК ЮНИТА (ЧТОБЫ НЕ КОПИПАСТИТЬ 4 РАЗА)
    -- ========================================================================
    local function GenerateUnitOptions()
        -- 1. Полоса здоровья
        if subIdx == 1 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})

            Add("header", NS.L("Health bar size"), nil, nil, nil, nil, nil, nil, 1)
            Add("slider", NS.L("Width"), nil, "plateWidth", 30, 200, 1, nil, 1)
            Add("slider", NS.L("Height"), nil, "plateHeight", 2, 30, 1, nil, 1)

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Health bar color"), nil, nil, nil, nil, nil, nil, 1)
            local hpModeList
            if dbContext == NS.UNIT_TYPES.FRIENDLY_PLAYER then
                hpModeList = { { text = NS.L("By class"), value = 1 }, { text = NS.L("Custom color"), value = 2 } }
            elseif dbContext == NS.UNIT_TYPES.ENEMY_PLAYER then
                hpModeList = { { text = NS.L("By class"), value = 1 }, { text = NS.L("By reaction"), value = 3 }, { text = NS.L("Custom color"), value = 2 } }
            else
                -- NPC (friendly/enemy): реакция или свой цвет
                hpModeList = { { text = NS.L("By reaction"), value = 1 }, { text = NS.L("Custom color"), value = 2 } }
            end
            Add("dropdown", NS.L("Color mode"), nil, "healthColorMode", nil, nil, nil, hpModeList, 1)
            if dbContext == NS.UNIT_TYPES.ENEMY_NPC then
                Add("color", NS.L("Color: Neutral (attackable)"), nil, "healthColorNeutral", nil, nil, nil, nil, 1, {
                    offX = 20, noToggleLink = true, requires = { key = "healthColorMode", value = 2 }
                })
                Add("color", NS.L("Color: Hostile"), nil, "healthColorHostile", nil, nil, nil, nil, 1, {
                    offX = 20, noToggleLink = true, requires = { key = "healthColorMode", value = 2 }
                })
            elseif dbContext == NS.UNIT_TYPES.FRIENDLY_NPC then
                Add("color", NS.L("Color: Neutral (non-attackable)"), nil, "healthColorNeutral", nil, nil, nil, nil, 1, {
                    offX = 20, noToggleLink = true, requires = { key = "healthColorMode", value = 2 }
                })
                Add("color", NS.L("Color: Friendly"), nil, "healthColorFriendly", nil, nil, nil, nil, 1, {
                    offX = 20, noToggleLink = true, requires = { key = "healthColorMode", value = 2 }
                })
            else
                Add("color", NS.L("Fixed color"), nil, "healthColor", nil, nil, nil, nil, 1, {
                    offX = 20, noToggleLink = true, requires = { key = "healthColorMode", value = 2 }
                })
            end
        end

        -- 2. Текст имени
        if subIdx == 2 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            -- Col 1
            Add("header", NS.L("Font settings"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Disable target scaling"), nil, "nameDisableTargetScale", nil, nil, nil, nil, 1)
            if dbContext == NS.UNIT_TYPES.FRIENDLY_PLAYER or dbContext == NS.UNIT_TYPES.ENEMY_PLAYER then
                Add("checkbox", NS.L("Show title"), nil, "nameShowPlayerTitle", nil, nil, nil, nil, 1)
            end
            Add("slider", NS.L("Size"), nil, "fontScale", 4, 20, 0.5, nil, 1)
            Add("slider", NS.L("Offset X"), nil, "textX", -100, 100, 0.5, nil, 1)
            Add("slider", NS.L("Offset Y"), nil, "textY", -100, 100, 0.5, nil, 1)
            local alignList = { { text = NS.L("Left"), value = "LEFT" }, { text = NS.L("Center"), value = "CENTER" }, { text = NS.L("Right"), value = "RIGHT" } }
            Add("dropdown", NS.L("Alignment"), nil, "textAlign", nil, nil, nil, alignList, 1)
            local outlineList = { { text = NS.L("Disable"), value = "NONE" }, { text = NS.L("Outline"), value = "OUTLINE" }, { text = NS.L("Thick outline"), value = "THICKOUTLINE" }, { text = NS.L("Shadow"), value = "SHADOW" } }
            Add("dropdown", NS.L("Outline"), nil, "fontOutline", nil, nil, nil, outlineList, 1)
            -- Col 2
            Add("header", NS.L("Wrap/Shorten text"), nil, nil, nil, nil, nil, nil, 2)
            Add("slider", NS.L("Width limit"), nil, "nameWrapWidth", 10, 200, 1, nil, 2)
            Add("checkbox", NS.L("Text wrapping"), nil, "nameWordWrap", nil, nil, nil, nil, 2)


            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Name color"), nil, nil, nil, nil, nil, nil, 2)
            local nameModeList
            if dbContext == NS.UNIT_TYPES.FRIENDLY_PLAYER then
                nameModeList = { { text = NS.L("By class"), value = 1 }, { text = NS.L("Custom color"), value = 2 } }
            elseif dbContext == NS.UNIT_TYPES.ENEMY_PLAYER then
                nameModeList = { { text = NS.L("By class"), value = 1 }, { text = NS.L("By reaction"), value = 3 }, { text = NS.L("Custom color"), value = 2 } }
            else
                -- NPC (friendly/enemy): реакция или свой цвет
                nameModeList = { { text = NS.L("By reaction"), value = 1 }, { text = NS.L("Custom color"), value = 2 } }
            end
            Add("dropdown", NS.L("Color mode"), nil, "nameColorMode", nil, nil, nil, nameModeList, 2)
            if dbContext == NS.UNIT_TYPES.ENEMY_NPC then
                Add("color", NS.L("Color: Neutral (attackable)"), nil, "nameColorNeutral", nil, nil, nil, nil, 2, { offX = 20, noToggleLink = true, requires = { key = "nameColorMode", value = 2 } })
                Add("color", NS.L("Color: Hostile"), nil, "nameColorHostile", nil, nil, nil, nil, 2, { offX = 20, noToggleLink = true, requires = { key = "nameColorMode", value = 2 } })
            elseif dbContext == NS.UNIT_TYPES.FRIENDLY_NPC then
                Add("color", NS.L("Color: Neutral (non-attackable)"), nil, "nameColorNeutral", nil, nil, nil, nil, 2, { offX = 20, noToggleLink = true, requires = { key = "nameColorMode", value = 2 } })
                Add("color", NS.L("Color: Friendly"), nil, "nameColorFriendly", nil, nil, nil, nil, 2, { offX = 20, noToggleLink = true, requires = { key = "nameColorMode", value = 2 } })
            else
                Add("color", NS.L("Fixed color"), nil, "nameColor", nil, nil, nil, nil, 2, { offX = 20, noToggleLink = true, requires = { key = "nameColorMode", value = 2 } })
            end

            if dbContext == NS.UNIT_TYPES.FRIENDLY_PLAYER then
                Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
                Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
                Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

                Add("header", NS.L("Name display in dungeons/raids"), nil, nil, nil, nil, nil, nil, 2)
                Add("checkbox", NS.L("Enable"), nil, "friendlyInstanceNamesEnable", nil, nil, nil, nil, 2, {
                    onChange = function()
                        if NS.FriendlyInstanceNames and NS.FriendlyInstanceNames.OnSettingsChanged then
                            NS.FriendlyInstanceNames.OnSettingsChanged()
                        end
                    end,
                })
                Add("checkbox", NS.L("Class color"), nil, "friendlyInstanceNamesClassColor", nil, nil, nil, nil, 2, {
                    offX = 20,
                    onChange = function()
                        if NS.FriendlyInstanceNames and NS.FriendlyInstanceNames.OnSettingsChanged then
                            NS.FriendlyInstanceNames.OnSettingsChanged()
                        end
                    end,
                })
                local friendlyOutlineList = {
                    { text = NS.L("Disable"), value = "NONE" },
                    { text = NS.L("Outline"), value = "OUTLINE" },
                    { text = NS.L("Thick outline"), value = "THICKOUTLINE" },
                    { text = NS.L("Shadow"), value = "SHADOW" },
                }
                Add("slider", NS.L("Size"), nil, "friendlyInstanceNamesFontSize", 10, 16, 2, nil, 2, {
                    offX = 20,
                    onChange = function()
                        if NS.FriendlyInstanceNames and NS.FriendlyInstanceNames.OnSettingsChanged then
                            NS.FriendlyInstanceNames.OnSettingsChanged()
                        end
                    end,
                })
                Add("dropdown", NS.L("Outline"), nil, "friendlyInstanceNamesFontOutline", nil, nil, nil, friendlyOutlineList, 2, {
                    offX = 20,
                    onChange = function(value)
                        NS.Config.Set("friendlyInstanceNamesFontOutline", value, dbContext)
                        if NS.FriendlyInstanceNames and NS.FriendlyInstanceNames.OnSettingsChanged then
                            NS.FriendlyInstanceNames.OnSettingsChanged()
                        end
                    end,
                })
            end
        end

        -- 3. Guild text
        if subIdx == 3 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})

            if dbContext == NS.UNIT_TYPES.FRIENDLY_PLAYER or dbContext == NS.UNIT_TYPES.ENEMY_PLAYER then
                local alignList = { { text = NS.L("Left"), value = "LEFT" }, { text = NS.L("Center"), value = "CENTER" }, { text = NS.L("Right"), value = "RIGHT" } }
                local outlineList = { { text = NS.L("Disable"), value = "NONE" }, { text = NS.L("Outline"), value = "OUTLINE" }, { text = NS.L("Thick outline"), value = "THICKOUTLINE" }, { text = NS.L("Shadow"), value = "SHADOW" } }
                local guildModeList = { { text = NS.L("Under Name"), value = "UNDER_NAME" }, { text = NS.L("Below Health Bar"), value = "BELOW_HEALTHBAR" } }

                Add("header", NS.L("Font settings"), nil, nil, nil, nil, nil, nil, 1)
                Add("checkbox", NS.L("Disable target scaling"), nil, "guildTextDisableTargetScale", nil, nil, nil, nil, 1)
                Add("slider", NS.L("Size"), nil, "guildTextFontSize", 4, 20, 0.5, nil, 1)
                Add("slider", NS.L("Offset X"), nil, "guildTextX", -100, 100, 0.5, nil, 1)
                Add("slider", NS.L("Offset Y"), nil, "guildTextY", -100, 100, 0.5, nil, 1)
                Add("dropdown", NS.L("Anchor"), nil, "guildTextMode", nil, nil, nil, guildModeList, 1)
                Add("dropdown", NS.L("Alignment"), nil, "guildTextAlign", nil, nil, nil, alignList, 1)
                Add("dropdown", NS.L("Outline"), nil, "guildTextOutline", nil, nil, nil, outlineList, 1)
                Add("header", NS.L("Shorten text"), nil, nil, nil, nil, nil, nil, 2)
                Add("slider", NS.L("Width limit"), nil, "guildTextWidth", 10, 200, 1, nil, 2)

                Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
                Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
                Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

                Add("header", NS.L("Guild color"), nil, nil, nil, nil, nil, nil, 2)
                Add("color", NS.L("Color"), nil, "guildTextColor", nil, nil, nil, nil, 2, { offX = 20, noToggleLink = true })
            else
                Add("header", NS.L("Guild text"), nil, nil, nil, nil, nil, nil, 1)
                Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -10})
                Add("header", NS.L("|cffff0000Available only for players|r"), nil, nil, nil, nil, nil, nil, 1)
            end
        end

        -- 4. Текст здоровья
        if subIdx == 4 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            -- Col 1
            Add("header", NS.L("Font settings"), nil, nil, nil, nil, nil, nil, 1)
            Add("slider", NS.L("Size"), nil, "hpFontSize", 5, 20, 0.5, nil, 1)
            Add("slider", NS.L("Offset X"), nil, "hpOffsetX", -100, 100, 1, nil, 1)
            Add("slider", NS.L("Offset Y"), nil, "hpOffsetY", -50, 50, 1, nil, 1)
            local hpAlignList = { { text = NS.L("Left"), value = "LEFT" }, { text = NS.L("Center"), value = "CENTER" }, { text = NS.L("Right"), value = "RIGHT" } }
            Add("dropdown", NS.L("Alignment"), nil, "hpTextAlign", nil, nil, nil, hpAlignList, 1)
            local hpOutlineList = { { text = NS.L("Disable"), value = "NONE" }, { text = NS.L("Outline"), value = "OUTLINE" }, { text = NS.L("Thick outline"), value = "THICKOUTLINE" }, { text = NS.L("Shadow"), value = "SHADOW" } }
            Add("dropdown", NS.L("Outline"), nil, "hpFontOutline", nil, nil, nil, hpOutlineList, 1)
            -- Col 2
            Add("header", NS.L("Display mode"), nil, nil, nil, nil, nil, nil, 2)
            local hpDispModeList = { { text = NS.L("Number"), value = "VALUE" }, { text = "%", value = "PERCENT" }, { text = NS.L("Number & %"), value = "BOTH" } }
            Add("dropdown", NS.L("Style"), nil, "hpDisplayMode", nil, nil, nil, hpDispModeList, 2)

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Text color"), nil, nil, nil, nil, nil, nil, 2)
            local hpColorModeList = { { text = NS.L("Gradient"), value = 1 }, { text = NS.L("Custom color"), value = 2 } }
            Add("dropdown", NS.L("Color mode"), nil, "hpColorMode", nil, nil, nil, hpColorModeList, 2)
            Add("color", NS.L("Fixed color"), nil, "hpColor", nil, nil, nil, nil, 2, { offX = 20, noToggleLink = true, requires = { key = "hpColorMode", value = 2 } })
        end

        -- 4. Отображение уровня
        if subIdx == 5 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            -- Col 1
            Add("header", NS.L("Font settings"), nil, nil, nil, nil, nil, nil, 1)
            Add("slider", NS.L("Size"), nil, "levelFontSize", 5, 20, 0.5, nil, 1)
            Add("slider", NS.L("Offset X"), nil, "levelX", -100, 100, 1, nil, 1)
            Add("slider", NS.L("Offset Y"), nil, "levelY", -50, 50, 1, nil, 1)
            local lvlAnchorList = { { text = NS.L("Left side"), value = "LEFT" }, { text = NS.L("Right side"), value = "RIGHT" } }
            Add("dropdown", NS.L("Side"), nil, "levelAnchor", nil, nil, nil, lvlAnchorList, 1)
            local lvlOutlineList = { { text = NS.L("Disable"), value = "NONE" }, { text = NS.L("Outline"), value = "OUTLINE" }, { text = NS.L("Thick outline"), value = "THICKOUTLINE" }, { text = NS.L("Shadow"), value = "SHADOW" } }
            Add("dropdown", NS.L("Outline"), nil, "levelFontOutline", nil, nil, nil, lvlOutlineList, 1)
            -- Col 2
            Add("header", NS.L("Level color"), nil, nil, nil, nil, nil, nil, 2)
            local lvlColorModeList = { { text = NS.L("By difficulty"), value = 1 }, { text = NS.L("Custom color"), value = 2 } }
            Add("dropdown", NS.L("Color mode"), nil, "levelColorMode", nil, nil, nil, lvlColorModeList, 2)
            Add("color", NS.L("Fixed color"), nil, "levelColor", nil, nil, nil, nil, 2, { offX = 20, noToggleLink = true, requires = { key = "levelColorMode", value = 2 } })
        end

        -- 5. Индикация цели
        if subIdx == 6 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            -- Col 1
            Add("header", NS.L("Side symbols"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Enable"), nil, "targetIndicatorSymbolEnable", nil, nil, nil, nil, 1)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -10})
            
            local symList = { 
                { text="> <", value=1 }, { text="< >", value=2 }, { text="[ ]", value=3 }, 
                { text="( )", value=4 }, { text="» «", value=5 }, { text="« »", value=6 } 
            }
            Add("dropdown", NS.L("Symbol selection"), nil, "targetIndicatorSymbolIndex", nil, nil, nil, symList, 1, {offX=20})
            local outlines = { { text = NS.L("Disable"), value = "NONE" }, { text = NS.L("Outline"), value = "OUTLINE" }, { text = NS.L("Thick outline"), value = "THICKOUTLINE" }, { text = NS.L("Shadow"), value = "SHADOW" } }
            Add("dropdown", NS.L("Outline"), nil, "targetIndicatorSymbolOutline", nil, nil, nil, outlines, 1, {offX=20})
            Add("slider", NS.L("Size"), nil, "targetIndicatorSymbolSize", 8, 30, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "targetIndicatorSymbolX", -150, 150, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "targetIndicatorSymbolY", -100, 100, 1, nil, 1, {offX=20})
            Add("color", NS.L("Symbol color"), nil, "targetIndicatorSymbolColor", nil, nil, nil, nil, 1, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Target border"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Enable"), nil, "targetBorderEnabled", nil, nil, nil, nil, 1)
            Add("color", NS.L("Border color"), nil, "targetBorderColor", nil, nil, nil, nil, 1, {offX=20})

            -- Col 2
            Add("header", NS.L("Highlight on mouseover"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Enable"), nil, "mouseoverGlowEnable", nil, nil, nil, nil, 2)
            Add("slider", NS.L("Brightness"), nil, "mouseoverGlowAlpha", 0, 1, 0.1, nil, 2, {offX=20})
            Add("color", NS.L("Highlight color"), nil, "mouseoverGlowColor", nil, nil, nil, nil, 2, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Target color"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Enable"), nil, "targetColorEnable", nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Apply to name text"), nil, "targetNameColorEnable", nil, nil, nil, nil, 2, {offX=20})
            Add("color", NS.L("Target color"), nil, "targetColor", nil, nil, nil, nil, 2, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Arrow above target"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Enable"), nil, "targetIndicatorArrowEnable", nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Animation"), nil, "targetIndicatorArrowAnim", nil, nil, nil, nil, 2, {offX=20})
            Add("slider", NS.L("Size"), nil, "targetIndicatorArrowSize", 10, 60, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Position X"), nil, "targetIndicatorArrowX", -100, 100, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Position Y"), nil, "targetIndicatorArrowY", -100, 100, 1, nil, 2, {offX=20})
            Add("color", NS.L("Arrow color"), nil, "targetIndicatorArrowColor", nil, nil, nil, nil, 2, {offX=20})
        end

        -- 6. Кастбар
        if subIdx == 7 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            local outlines = { { text = NS.L("Disable"), value = "NONE" }, { text = NS.L("Outline"), value = "OUTLINE" }, { text = NS.L("Thick outline"), value = "THICKOUTLINE" }, { text = NS.L("Shadow"), value = "SHADOW" } }
            local aligns   = { { text = NS.L("Left"), value = "LEFT" }, { text = NS.L("Center"), value = "CENTER" }, { text = NS.L("Right"), value = "RIGHT" } }
            local timerFmtList = { { text = "1.0", value = "%.1f" }, { text = "0.1", value = "%.2f" } } -- Исправлены значения
            local cbColorModeList = { { text = NS.L("By class"), value = "CLASS" }, { text = NS.L("Custom color"), value = "CUSTOM" } }

            -- Col 1
            Add("header", NS.L("Cast bar"), nil, nil, nil, nil, nil, nil, 1)
            -- Включение кастбара управляется master-toggle слева (cbEnabled).
            Add("checkbox", NS.L("Show bar"), nil, "cbBarEnabled", nil, nil, nil, nil, 1)
            Add("slider", NS.L("Width"), nil, "cbWidth", 50, 300, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Height"), nil, "cbHeight", 2, 30, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "cbX", -100, 100, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "cbY", -100, 100, 1, nil, 1, {offX=20})
            
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Spell icon"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Show icon"), nil, "cbIconEnabled", nil, nil, nil, nil, 1)
            Add("slider", NS.L("Size"), nil, "cbIconSize", 8, 40, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "cbIconX", -50, 50, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "cbIconY", -20, 20, 1, nil, 1, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Icon border"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Border"), nil, "cbIconBorderEnable", nil, nil, nil, nil, 1)
            Add("slider", NS.L("Thickness"), nil, "cbIconBorderThickness", 0, 8, 1, nil, 1, {offX=20})
            Add("color", NS.L("Border color"), nil, "cbIconBorderColor", nil, nil, nil, nil, 1, {offX=20})


            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Cast timer"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Show timer"), nil, "cbTimerEnabled", nil, nil, nil, nil, 1)
            Add("slider", NS.L("Size"), nil, "cbTimerFontSize", 6, 24, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "cbTimerX", -50, 50, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "cbTimerY", -20, 20, 1, nil, 1, {offX=20})
            Add("dropdown", NS.L("Time format"), nil, "cbTimerFormat", nil, nil, nil, timerFmtList, 1, {offX=20})
            Add("dropdown", NS.L("Outline"), nil, "cbTimerOutline", nil, nil, nil, outlines, 1, {offX=20})
            Add("color", NS.L("Timer color"), nil, "cbTimerColor", nil, nil, nil, nil, 1, {offX=20})

            -- Col 2
            Add("header", NS.L("Spell name"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Show name"), nil, "cbTextEnabled", nil, nil, nil, nil, 2)
            Add("slider", NS.L("Size"), nil, "cbFontSize", 6, 20, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "cbTextX", -100, 100, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "cbTextY", -20, 20, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Max length (0=off)"), nil, "cbTextMaxLength", 0, 30, 1, nil, 2, {offX=20})
            Add("dropdown", NS.L("Alignment"), nil, "cbTextJustify", nil, nil, nil, aligns, 2, {offX=20})
            Add("dropdown", NS.L("Outline"), nil, "cbTextOutline", nil, nil, nil, outlines, 2, {offX=20})
            Add("color", NS.L("Title color"), nil, "cbTextColor", nil, nil, nil, nil, 2, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Spell target"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Show cast target"), nil, "cbTargetEnabled", nil, nil, nil, nil, 2)
            Add("slider", NS.L("Size"), nil, "cbTargetFontSize", 6, 20, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "cbTargetX", -100, 100, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "cbTargetY", -20, 20, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Max length (0=off)"), nil, "cbTargetMaxLength", 0, 30, 1, nil, 2, {offX=20})
            Add("dropdown", NS.L("Alignment"), nil, "cbTargetJustify", nil, nil, nil, aligns, 2, {offX=20})
            Add("dropdown", NS.L("Outline"), nil, "cbTargetOutline", nil, nil, nil, outlines, 2, {offX=20})
            Add("dropdown", NS.L("Color mode"), nil, "cbTargetMode", nil, nil, nil, cbColorModeList, 2, {offX=20})
            Add("color", NS.L("Fixed color"), nil, "cbTargetColor", nil, nil, nil, nil, 2, {
                offX = 40, noToggleLink = true, requires = { key = "cbTargetMode", value = "CUSTOM" }
            })
        end

        -- 7. Баффы
        if subIdx == 8 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            local aligns = { { text = NS.L("Left"), value = "LEFT" }, { text = NS.L("Center"), value = "CENTER" }, { text = NS.L("Right"), value = "RIGHT" } }

            -- Col 1: Иконки
            Add("header", NS.L("|cffffd700Preview|r"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Show buff preview"), nil, "buffsPreview", nil, nil, nil, nil, 1)

            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Buffs"), nil, nil, nil, nil, nil, nil, 1)
            Add("slider", NS.L("Icon width"), nil, "buffsSize", 10, 50, 1, nil, 1)
            Add("slider", NS.L("Icon height"), nil, "buffsIconHeight", 6, 60, 1, nil, 1)
            Add("slider", NS.L("Offset X"), nil, "buffsX", -50, 50, 1, nil, 1)
            Add("slider", NS.L("Offset Y"), nil, "buffsY", -50, 50, 1, nil, 1)
            Add("slider", NS.L("Spacing"), nil, "buffsSpacing", 0, 20, 1, nil, 1)
            Add("dropdown", NS.L("Alignment"), nil, "buffsAlign", nil, nil, nil, aligns, 1)

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Icon border"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Border"), nil, "buffsBorderEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Border thickness"), nil, "buffsBorderThickness", 0, 8, 1, nil, 1, {offX=20})
            Add("color", NS.L("Border color"), nil, "buffsBorderColor", nil, nil, nil, nil, 1, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Additional effects"), nil, nil, nil, nil, nil, nil, 1)
            if dbContext == NS.UNIT_TYPES.ENEMY_PLAYER or dbContext == NS.UNIT_TYPES.ENEMY_NPC then
                Add("checkbox", NS.L("Highlight if dispellable"), nil, "buffsPurgeGlow", nil, nil, nil, nil, 1)
            end
            Add("checkbox", NS.L("Non-target alpha"), nil, "buffsNonTargetAlphaEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Alpha"), nil, "buffsNonTargetAlpha", 0, 1, 0.05, nil, 1, {offX=20, requires = { key = "buffsNonTargetAlphaEnable", value = true }})
            Add("checkbox", NS.L("Non-target scale"), nil, "buffsNonTargetScaleEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Scale"), nil, "buffsNonTargetScale", 0.3, 1, 0.05, nil, 1, {offX=20, requires = { key = "buffsNonTargetScaleEnable", value = true }})
            local buffFilterFriendly = {
                { text = NS.L("All"), value = "ALL" },
                { text = NS.L("Mine"), value = "MINE" },
                { text = NS.L("My important"), value = "MINE_IMPORTANT" },
                { text = NS.L("My raid"), value = "MINE_RAID" },
                { text = NS.L("Raid"), value = "RAID" },
                { text = NS.L("Raid in combat"), value = "RAID_IN_COMBAT" },
                { text = NS.L("Defensive"), value = "BIG_DEFENSIVE" },
                { text = NS.L("External defensive"), value = "EXTERNAL_DEFENSIVE" },
                { text = NS.L("Defensive or external defensive"), value = "BIG_OR_EXTERNAL_DEFENSIVE" },
            }
            local buffFilterEnemy = {
                { text = NS.L("All"), value = "ALL" },
                { text = NS.L("Important"), value = "IMPORTANT" },
                { text = NS.L("Purgeable"), value = "PURGE" },
                { text = NS.L("Important and purgeable"), value = "IMPORTANT_AND_PURGE" },
                { text = NS.L("Important or purgeable"), value = "IMPORTANT_OR_PURGE" },
                { text = NS.L("Defensive"), value = "BIG_DEFENSIVE" },
                { text = NS.L("External defensive"), value = "EXTERNAL_DEFENSIVE" },
                { text = NS.L("Defensive or external defensive"), value = "BIG_OR_EXTERNAL_DEFENSIVE" },
            }
            if dbContext == NS.UNIT_TYPES.ENEMY_PLAYER or dbContext == NS.UNIT_TYPES.ENEMY_NPC then
                Add("dropdown", NS.L("Buff filter"), nil, "buffsEnemyFilterMode", nil, nil, nil, buffFilterEnemy, 1)
            end

            if dbContext == NS.UNIT_TYPES.FRIENDLY_PLAYER or dbContext == NS.UNIT_TYPES.FRIENDLY_NPC then
                Add("dropdown", NS.L("Buff filter"), nil, "buffsFriendlyFilterMode", nil, nil, nil, buffFilterFriendly, 1)
            end
            -- Col 2: Превью + Тексты
            Add("header", NS.L("Timer"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Show timer"), nil, "buffsTimerEnable", nil, nil, nil, nil, 2)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Timer edge"), nil, "buffsTimerEdge", nil, nil, nil, nil, 2, {offX=20})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Red timer at < 25% remaining"), nil, "buffsPandemic", nil, nil, nil, nil, 2, {offX=20})
            Add("slider", NS.L("Size"), nil, "buffsTimeFontSize", 6, 24, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "buffsTimeX", -30, 30, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "buffsTimeY", -30, 30, 1, nil, 2, {offX=20})
            Add("color", NS.L("Timer color"), nil, "buffsTimeColor", nil, nil, nil, nil, 2, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Stacks"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Show stacks"), nil, "buffsStacksEnable", nil, nil, nil, nil, 2)
            Add("slider", NS.L("Size"), nil, "buffsStackFontSize", 6, 24, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "buffsStackX", -30, 30, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "buffsStackY", -30, 30, 1, nil, 2, {offX=20})
            Add("color", NS.L("Stack color"), nil, "buffsStackColor", nil, nil, nil, nil, 2, {offX=20})
        end

        -- 8. Дебаффы
        if subIdx == 9 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            local aligns = { { text = NS.L("Left"), value = "LEFT" }, { text = NS.L("Center"), value = "CENTER" }, { text = NS.L("Right"), value = "RIGHT" } }

            -- Col 1: Иконки
            Add("header", NS.L("|cffffd700Preview|r"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Show debuff preview"), nil, "debuffsPreview", nil, nil, nil, nil, 1)

            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Debuffs"), nil, nil, nil, nil, nil, nil, 1)
            Add("slider", NS.L("Icon width"), nil, "debuffsSize", 10, 50, 1, nil, 1)
            Add("slider", NS.L("Icon height"), nil, "debuffsIconHeight", 6, 80, 1, nil, 1)
            Add("slider", NS.L("Offset X"), nil, "debuffsX", -50, 50, 1, nil, 1)
            Add("slider", NS.L("Offset Y"), nil, "debuffsY", -50, 50, 1, nil, 1)
            Add("slider", NS.L("Spacing"), nil, "debuffsSpacing", 0, 20, 1, nil, 1)
            Add("dropdown", NS.L("Alignment"), nil, "debuffsAlign", nil, nil, nil, aligns, 1)

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Icon border"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Border"), nil, "debuffsBorderEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Border thickness"), nil, "debuffsBorderThickness", 0, 8, 1, nil, 1, {offX=20})
            Add("color", NS.L("Border color"), nil, "debuffsBorderColor", nil, nil, nil, nil, 1, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Additional effects"), nil, nil, nil, nil, nil, nil, 1)
            if dbContext == NS.UNIT_TYPES.FRIENDLY_PLAYER or dbContext == NS.UNIT_TYPES.FRIENDLY_NPC then
                Add("checkbox", NS.L("Highlight if dispellable by me"), nil, "debuffsDispelGlow", nil, nil, nil, nil, 1)
            end
            Add("checkbox", NS.L("Non-target alpha"), nil, "debuffsNonTargetAlphaEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Alpha"), nil, "debuffsNonTargetAlpha", 0, 1, 0.05, nil, 1, {offX=20, requires = { key = "debuffsNonTargetAlphaEnable", value = true }})
            Add("checkbox", NS.L("Non-target scale"), nil, "debuffsNonTargetScaleEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Scale"), nil, "debuffsNonTargetScale", 0.3, 1, 0.05, nil, 1, {offX=20, requires = { key = "debuffsNonTargetScaleEnable", value = true }})
            local debuffFilterFriendly = {
                { text = NS.L("All"), value = "ALL" },
                { text = NS.L("Dispellable"), value = "DISPEL" },
                { text = NS.L("Important"), value = "IMPORTANT" },
                { text = NS.L("Raid"), value = "RAID" },
                { text = NS.L("Raid in combat"), value = "RAID_IN_COMBAT" },
                { text = NS.L("Important and dispellable"), value = "IMPORTANT_AND_DISPEL" },
                { text = NS.L("Important or dispellable"), value = "IMPORTANT_OR_DISPEL" },
                { text = NS.L("Raid and dispellable"), value = "RAID_AND_DISPEL" },
                { text = NS.L("Raid or dispellable"), value = "RAID_OR_DISPEL" },
            }
            local debuffFilterEnemy = {
                { text = NS.L("All"), value = "ALL" },
                { text = NS.L("Important"), value = "IMPORTANT" },
                { text = NS.L("Mine"), value = "MINE" },
                { text = NS.L("My important"), value = "MINE_AND_IMPORTANT" },
            }
            if dbContext == NS.UNIT_TYPES.ENEMY_PLAYER or dbContext == NS.UNIT_TYPES.ENEMY_NPC then
                Add("dropdown", NS.L("Debuff filter"), nil, "debuffsEnemyFilterMode", nil, nil, nil, debuffFilterEnemy, 1)
            end
            if dbContext == NS.UNIT_TYPES.FRIENDLY_PLAYER or dbContext == NS.UNIT_TYPES.FRIENDLY_NPC then
                Add("dropdown", NS.L("Debuff filter"), nil, "debuffsFriendlyFilterMode", nil, nil, nil, debuffFilterFriendly, 1)
            end

            -- Col 2: Превью + Тексты
            Add("header", NS.L("Timer"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Show timer"), nil, "debuffsTimerEnable", nil, nil, nil, nil, 2)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Timer edge"), nil, "debuffsTimerEdge", nil, nil, nil, nil, 2, {offX=20})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Red timer at < 25% remaining"), nil, "debuffsPandemic", nil, nil, nil, nil, 2, {offX=20})
            Add("slider", NS.L("Size"), nil, "debuffsTimeFontSize", 6, 24, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "debuffsTimeX", -30, 30, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "debuffsTimeY", -30, 30, 1, nil, 2, {offX=20})
            Add("color", NS.L("Timer color"), nil, "debuffsTimeColor", nil, nil, nil, nil, 2, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Stacks"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Show stacks"), nil, "debuffsStacksEnable", nil, nil, nil, nil, 2)
            Add("slider", NS.L("Size"), nil, "debuffsStackFontSize", 6, 24, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "debuffsStackX", -30, 30, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "debuffsStackY", -30, 30, 1, nil, 2, {offX=20})
            Add("color", NS.L("Stack color"), nil, "debuffsStackColor", nil, nil, nil, nil, 2, {offX=20})
        end

        -- 9. Контроль
        if subIdx == 10 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            local aligns = { { text = NS.L("Left"), value = "LEFT" }, { text = NS.L("Center"), value = "CENTER" }, { text = NS.L("Right"), value = "RIGHT" } }

            -- Col 1: Иконки
            Add("header", NS.L("|cffffd700Preview|r"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Show CC preview"), nil, "ccPreview", nil, nil, nil, nil, 1)

            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Crowd Control"), nil, nil, nil, nil, nil, nil, 1)
            Add("slider", NS.L("Icon width"), nil, "ccSize", 10, 50, 1, nil, 1)
            Add("slider", NS.L("Icon height"), nil, "ccIconHeight", 6, 100, 1, nil, 1)
            Add("slider", NS.L("Offset X"), nil, "ccX", -50, 50, 1, nil, 1)
            Add("slider", NS.L("Offset Y"), nil, "ccY", -50, 50, 1, nil, 1)
            Add("slider", NS.L("Spacing"), nil, "ccSpacing", 0, 20, 1, nil, 1)
            Add("dropdown", NS.L("Alignment"), nil, "ccAlign", nil, nil, nil, aligns, 1)

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Icon border"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Border"), nil, "ccBorderEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Border thickness"), nil, "ccBorderThickness", 0, 8, 1, nil, 1, {offX=20})
            Add("color", NS.L("Border color"), nil, "ccBorderColor", nil, nil, nil, nil, 1, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Additional effects"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Non-target alpha"), nil, "ccNonTargetAlphaEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Alpha"), nil, "ccNonTargetAlpha", 0, 1, 0.05, nil, 1, {offX=20, requires = { key = "ccNonTargetAlphaEnable", value = true }})
            Add("checkbox", NS.L("Non-target scale"), nil, "ccNonTargetScaleEnable", nil, nil, nil, nil, 1, {onChange=function() if NS.RefreshGUI then NS.RefreshGUI(true) end end})
            Add("slider", NS.L("Scale"), nil, "ccNonTargetScale", 0.3, 1, 0.05, nil, 1, {offX=20, requires = { key = "ccNonTargetScaleEnable", value = true }})
            if dbContext == NS.UNIT_TYPES.ENEMY_PLAYER or dbContext == NS.UNIT_TYPES.ENEMY_NPC then
                Add("checkbox", NS.L("Mine only"), nil, "ccOnlyMine", nil, nil, nil, nil, 1)
            end

            -- Col 2: Превью + Тексты
            Add("header", NS.L("Timer"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Show timer"), nil, "ccTimerEnable", nil, nil, nil, nil, 2)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Timer edge"), nil, "ccTimerEdge", nil, nil, nil, nil, 2, {offX=20})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Red timer at < 25% remaining"), nil, "ccPandemic", nil, nil, nil, nil, 2, {offX=20})
            Add("slider", NS.L("Size"), nil, "ccTimeFontSize", 6, 24, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "ccTimeX", -30, 30, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "ccTimeY", -30, 30, 1, nil, 2, {offX=20})
            Add("color", NS.L("Timer color"), nil, "ccTimeColor", nil, nil, nil, nil, 2, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Stacks"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Show stacks"), nil, "ccStacksEnable", nil, nil, nil, nil, 2)
            Add("slider", NS.L("Size"), nil, "ccStackFontSize", 6, 24, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "ccStackX", -30, 30, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "ccStackY", -30, 30, 1, nil, 2, {offX=20})
            Add("color", NS.L("Stack color"), nil, "ccStackColor", nil, nil, nil, nil, 2, {offX=20})
        end

    end

    -- ========================================================================
    -- ВКЛАДКА 1: ОБЩЕЕ
    -- ========================================================================
    if mainIdx == 1 then
        if subIdx == 1 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            Add("header", NS.L("Global settings"), nil, nil, nil, nil, nil, nil, 1)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -5})
            Add("dropdown", NS.L("Global font"), nil, "globalFont", nil, nil, nil, NS.GetFontList(), 1)
            Add("slider", NS.L("Global scale"), nil, "globalScale", 0.5, 2.0, 0.05, nil, 1)
            Add("slider", NS.L("X offset"), nil, "globalX", -100, 100, 0.5, nil, 1)
            Add("slider", NS.L("Y offset"), nil, "globalY", -100, 100, 0.5, nil, 1)

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("System |cffff0000(CVars)|r"), nil, nil, nil, nil, nil, nil, 1)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -10})
            Add("slider", NS.L("Visibility range"), nil, "nameplateMaxDistance", 10, 60, 1, nil, 1)
            Add("slider", NS.L("Target scale"), nil, "nameplateSelectedScale", 1, 2, 0.1, nil, 1)
            Add("slider", NS.L("Fade behind walls"), nil, "nameplateOccludedAlphaMult", 0, 1, 0.1, nil, 1)

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Minimap"), nil, nil, nil, nil, nil, nil, 1)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -5})
            Add("checkbox", NS.L("Show minimap icon"), nil, "showMinimapIcon", nil, nil, nil, nil, 1, {
                context = "Global",
                onChange = function(val)
                    if NS.SetMinimapIconShown then NS.SetMinimapIconShown(val) end
                end
            })

            Add("header", NS.L("|cffffd700ACTIVE MODULES|r"), nil, nil, nil, nil, nil, nil, 2)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -25})
            Add("header", NS.L("|cffff0000*Do not disable unless absolutely necessary!|r"), nil, nil, nil, nil, nil, nil, 2)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Friendly: Players"), nil, "enabled", nil, nil, nil, nil, 2, { context = NS.UNIT_TYPES.FRIENDLY_PLAYER })
            Add("checkbox", NS.L("Friendly: NPC"), nil, "enabled", nil, nil, nil, nil, 2, { context = NS.UNIT_TYPES.FRIENDLY_NPC })
            Add("checkbox", NS.L("Hostile: Players"), nil, "enabled", nil, nil, nil, nil, 2, { context = NS.UNIT_TYPES.ENEMY_PLAYER })
            Add("checkbox", NS.L("Hostile: NPC"), nil, "enabled", nil, nil, nil, nil, 2, { context = NS.UNIT_TYPES.ENEMY_NPC })

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=250, offY=15})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Copying"), nil, nil, nil, nil, nil, nil, 2)

            local unitTypeList = {
                { text = NS.L("Friendly players"), value = NS.UNIT_TYPES.FRIENDLY_PLAYER },
                { text = NS.L("Friendly NPC"),    value = NS.UNIT_TYPES.FRIENDLY_NPC },
                { text = NS.L("Hostile players"), value = NS.UNIT_TYPES.ENEMY_PLAYER },
                { text = NS.L("Hostile NPC"),    value = NS.UNIT_TYPES.ENEMY_NPC },
            }

            local sections = {
                { text = NS.L("Health bar"), key = "copySec_HPBAR", sec = "HPBAR" },
                { text = NS.L("Name"), key = "copySec_NAME", sec = "NAME" },
                { text = NS.L("Guild text"), key = "copySec_GUILD", sec = "GUILD" },
                { text = NS.L("Health text"), key = "copySec_HPTEXT", sec = "HPTEXT" },
                { text = NS.L("Level"), key = "copySec_LEVEL", sec = "LEVEL" },
                { text = NS.L("Target indicator"), key = "copySec_TARGET", sec = "TARGET" },
                { text = NS.L("Castbar"), key = "copySec_CASTBAR", sec = "CASTBAR" },
                { text = NS.L("Buffs"), key = "copySec_BUFFS", sec = "BUFFS" },
                { text = NS.L("Debuffs"), key = "copySec_DEBUFFS", sec = "DEBUFFS" },
                { text = NS.L("Crowd Control (CC)"), key = "copySec_CC", sec = "CC" },
            }

            Add("copyprofiles", nil, nil, nil, nil, nil, nil, nil, 2, {
                unitTypeList = unitTypeList,
                sections = sections,
                srcKey = "copyProfileSource",
                dstKey = "copyProfileDest",
                noToggleLink = true,
            })


        end

        if subIdx == 2 then
            local iconAnchorList = { { text = NS.L("HpBar (Center, Center)"), value = "HpBar" }, { text = NS.L("Name (Center, Top)"), value = "Name" } }
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            Add("header", NS.L("|cff00aaffIcon(|r|cff9d9d9dRare|r/|cffffd700Elite|r/|cffff0000Boss|r|cff00aaff)|r"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Enable"), nil, "classifEnabled", nil, nil, nil, nil, 1)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -5})
            Add("checkbox", NS.L("Hide on friendly"), nil, "classifHideAllies", nil, nil, nil, nil, 1, {offX=20})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -10})
            Add("checkbox", NS.L("Bosses and rares only"), nil, "classifShowBossRareOnly", nil, nil, nil, nil, 1, {offX=20})
            Add("slider", NS.L("Size"), nil, "classifScale", 0.5, 3, 0.1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "classifX", -150, 150, 0.5, nil, 1, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "classifY", -150, 150, 0.5, nil, 1, {offX=20})
            Add("slider", NS.L("Opacity"), nil, "classifAlpha", 0, 1, 0.1, nil, 1, {offX=20})
            Add("dropdown", NS.L("Anchor"), nil, "classifAnchor", nil, nil, nil, iconAnchorList, 1, {offX=20})
            Add("checkbox", NS.L("Mirror icon"), nil, "classifMirror", nil, nil, nil, nil, 1, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Faction icon"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Enable"), nil, "factionIconEnabled", nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Players only"), nil, "factionIconOnlyPlayers", nil, nil, nil, nil, 1, {offX=20})
            Add("slider", NS.L("Size"), nil, "factionIconSize", 8, 40, 1, nil, 1, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "factionIconX", -150, 150, 0.5, nil, 1, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "factionIconY", -150, 150, 0.5, nil, 1, {offX=20})
            Add("slider", NS.L("Opacity"), nil, "factionIconAlpha", 0, 1, 0.1, nil, 1, {offX=20})
            local factionIconStyleList = {
                { text = NS.L("Classic icons"), value = 1 },
                { text = NS.L("Symbols"), value = 2 },
                { text = NS.L("Modern icons"), value = 3 },
            }
            Add("dropdown", NS.L("Style"), nil, "factionIconStyle", nil, nil, nil, factionIconStyleList, 1, {offX=20})
            Add("dropdown", NS.L("Anchor"), nil, "factionIconAnchor", nil, nil, nil, iconAnchorList, 1, {offX=20})

            Add("header", NS.L("Quest objective icon"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Enable"), nil, "questIconEnabled", nil, nil, nil, nil, 2)
            Add("slider", NS.L("Size"), nil, "questIconSize", 8, 40, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "questIconX", -150, 150, 0.5, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "questIconY", -150, 150, 0.5, nil, 2, {offX=20})
            Add("slider", NS.L("Opacity"), nil, "questIconAlpha", 0, 1, 0.1, nil, 2, {offX=20})
            Add("dropdown", NS.L("Anchor"), nil, "questIconAnchor", nil, nil, nil, iconAnchorList, 2, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 2, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 5})

            Add("header", NS.L("Raid target icon"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Enable"), nil, "raidTargetIconEnabled", nil, nil, nil, nil, 2)
            Add("slider", NS.L("Size"), nil, "raidTargetIconSize", 8, 60, 1, nil, 2, {offX=20})
            Add("slider", NS.L("Offset X"), nil, "raidTargetIconX", -150, 150, 0.5, nil, 2, {offX=20})
            Add("slider", NS.L("Offset Y"), nil, "raidTargetIconY", -150, 150, 0.5, nil, 2, {offX=20})
            Add("slider", NS.L("Opacity"), nil, "raidTargetIconAlpha", 0, 1, 0.1, nil, 2, {offX=20})
            Add("dropdown", NS.L("Anchor"), nil, "raidTargetIconAnchor", nil, nil, nil, iconAnchorList, 2, {offX=20})
        end

        if subIdx == 3 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            Add("header", NS.L("Opacity settings"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Enable"), nil, "transparencyEnabled", nil, nil, nil, nil, 1)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -5})
            Add("checkbox", NS.L("Style: No distance"), nil, "transparencyMode", nil, nil, nil, nil, 1, {offX=20, group="TransparencyStyle", val=1, onChange=function() if NS.RefreshGUI then NS.RefreshGUI() end end})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = -10})
            Add("checkbox", NS.L("Style: By distance"), nil, "transparencyMode", nil, nil, nil, nil, 1, {offX=20, group="TransparencyStyle", val=2, onChange=function() if NS.RefreshGUI then NS.RefreshGUI() end end})
            Add("slider", NS.L("Opacity"), nil, "transparencyAlpha", 0, 1, 0.1, nil, 1, {offX=20})
            Add("slider", NS.L("Range (yards)"), nil, "transparencyRange", 5, 60, 1, nil, 1, {offX=20, requires={key="transparencyMode", value=2}})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Tank mode"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Enable"), nil, "tankModeEnable", nil, nil, nil, nil, 1)
            Add("color", NS.L("Color: Aggro on you"), nil, "tankModePlayerAggroColor", nil, nil, nil, nil, 1, {offX=20})
            Add("color", NS.L("Color: Aggro not on you"), nil, "tankModeOffTankColor", nil, nil, nil, nil, 1, {offX=20})

            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 10})
            Add("separator", nil, nil, nil, nil, nil, nil, nil, 1, {size=260, offY=8})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 5})

            Add("header", NS.L("Additional effects"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Hide highlight (Absorb)"), nil, "hideAbsorbGlow", nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Hide heal prediction"), nil, "hideHealPrediction", nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Hide shield (uninterruptible cast)"), nil, "hideCastShield", nil, nil, nil, nil, 1)

            Add("header", NS.L("Class resource indicators"), nil, nil, nil, nil, nil, nil, 2)
            Add("checkbox", NS.L("Enable"), nil, "classResourceEnabled", nil, nil, nil, nil, 2)
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Show only in combat"), nil, "classResourceOnlyInCombat", nil, nil, nil, nil, 2, {offX=20})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Hide on transport"), nil, "classResourceHideOnTransport", nil, nil, nil, nil, 2, {offX=20})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Show empty slots"), nil, "classResourceShowEmpty", nil, nil, nil, nil, 2, {offX=20})
            Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = -5})
            Add("checkbox", NS.L("Fill from right to left"), nil, "classResourceReverseFill", nil, nil, nil, nil, 2, {offX=20})
            local classResourceAnchorModeList = {
                { text = NS.L("Anchor free"), value = 1 },
                { text = NS.L("Anchor dynamic under cast bar"), value = 2 },
            }
            Add("dropdown", NS.L("Anchor mode"), nil, "classResourceAnchorMode", nil, nil, nil, classResourceAnchorModeList, 2, {
                offX=20,
                onChange=function(val)
                    if NS.Config and NS.Config.Set then
                        NS.Config.Set("classResourceAnchorMode", val, "Global")
                    end
                    if NS.RequestUpdateAll then
                        NS.RequestUpdateAll("classresource_anchor_mode", true, NS.REASON_POWER or NS.REASON_ALL)
                    elseif NS.ForceUpdateAll then
                        NS.ForceUpdateAll()
                    end
                end,
            })
            local classResourceStyleList = {
                { text = NS.L("Custom"), value = 1 },
                { text = NS.L("Modern"), value = 2 },
            }
            Add("dropdown", NS.L("Style"), nil, "classResourceStyle", nil, nil, nil, classResourceStyleList, 2, {
                offX=20,
                onChange=function(val)
                    if NS.Config and NS.Config.Set then
                        NS.Config.Set("classResourceStyle", val, "Global")
                    end
                    if NS.RequestUpdateAll then
                        NS.RequestUpdateAll("classresource_style", true, NS.REASON_POWER or NS.REASON_ALL)
                    elseif NS.ForceUpdateAll then
                        NS.ForceUpdateAll()
                    end
                end,
            })
            Add("header", NS.L("Custom style settings"), nil, nil, nil, nil, nil, nil, 2, {offX=20, requires={key="classResourceStyle", value=1}})
            Add("slider", NS.L("Width"), nil, "classResourceWidth", 6, 30, 1, nil, 2, {offX=20, requires={key="classResourceStyle", value=1}})
            Add("slider", NS.L("Height"), nil, "classResourceHeight", 4, 20, 1, nil, 2, {offX=20, requires={key="classResourceStyle", value=1}})
            Add("slider", NS.L("Spacing"), nil, "classResourceSpacing", 0, 10, 1, nil, 2, {offX=20, requires={key="classResourceStyle", value=1}})
            Add("slider", NS.L("Offset X"), nil, "classResourceOffsetX", -150, 150, 1, nil, 2, {offX=20, requires={key="classResourceStyle", value=1}})
            Add("slider", NS.L("Offset Y"), nil, "classResourceOffsetY", -150, 150, 1, nil, 2, {offX=20, requires={key="classResourceStyle", value=1}})
            Add("slider", NS.L("Recovering opacity"), nil, "classResourceInactiveAlpha", 0, 1, 0.05, nil, 2, {offX=20, requires={key="classResourceStyle", value=1}})

            Add("header", NS.L("Modern style settings"), nil, nil, nil, nil, nil, nil, 2, {offX=20, requires={key="classResourceStyle", value=2}})
            Add("slider", NS.L("Scale"), nil, "classResourceModernScale", 0.5, 2, 0.05, nil, 2, {offX=20, requires={key="classResourceStyle", value=2}})
            Add("slider", NS.L("Spacing"), nil, "classResourceModernSpacing", 0, 15, 1, nil, 2, {offX=20, requires={key="classResourceStyle", value=2}})
            Add("slider", NS.L("Offset X"), nil, "classResourceModernOffsetX", -150, 150, 1, nil, 2, {offX=20, requires={key="classResourceStyle", value=2}})
            Add("slider", NS.L("Offset Y"), nil, "classResourceModernOffsetY", -150, 150, 1, nil, 2, {offX=20, requires={key="classResourceStyle", value=2}})
            Add("slider", NS.L("Recovering opacity"), nil, "classResourceModernInactiveAlpha", 0, 1, 0.05, nil, 2, {offX=20, requires={key="classResourceStyle", value=2}})
        end

        if subIdx == 4 then
            Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, {size=550, offX=25, offY=0})
            Add("header", NS.L("Roleplay support"), nil, nil, nil, nil, nil, nil, 1)
            Add("checkbox", NS.L("Enable RP/TRP3 support"), NS.L("Use roleplay names from Total RP 3 and compatible MSP-based addons on nameplates."), "rpSupportEnabled", nil, nil, nil, nil, 1)
        end
    end

    -- ========================================================================
    -- ГЕНЕРАЦИЯ ДЛЯ ВСЕХ 4-Х ТИПОВ ЮНИТОВ
    -- ========================================================================
    if mainIdx >= 2 and mainIdx <= 5 then
        GenerateUnitOptions()
    end


    -- ========================================================================
    -- ПРОФИЛИ (привязка к персонажу)
    -- ========================================================================
    if mainIdx == 6 then
        Add("vline", nil, nil, nil, nil, nil, nil, nil, 1, { height = 420, offX = 25, offY = 0 })

        Add("header", NS.L("This character's profile"), nil, nil, nil, nil, nil, nil, 1)
        Add("dropdown", NS.L("Active profile"), nil, nil, nil, nil, nil,
            function()
                return (NS.Profiles and NS.Profiles.GetDropdownOptions and NS.Profiles.GetDropdownOptions()) or {}
            end,
            1,
            {
                width = 220,
                onChange = function(val)
                    if NS.Profiles and NS.Profiles.SetCurrent then
                        NS.Profiles.SetCurrent(val)
                    end
                end,
                getCurrent = function()
                    return (NS.Profiles and NS.Profiles.GetCurrent and NS.Profiles.GetCurrent()) or "Default"
                end,
                context = "Global",
            }
        )

        Add("button", NS.L("Create new profile"), NS.L("Create an empty default profile and switch to it."), nil, nil, nil, nil, nil, 1, {
            onClick = function()
                if NS.Profiles and NS.Profiles.PromptCreate then
                    NS.Profiles.PromptCreate(false)
                end
            end
        })

        Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 30})
        Add("button", NS.L("Create copy of current"), NS.L("Create a new profile as a copy of the current one and switch to it."), nil, nil, nil, nil, nil, 1, {
            onClick = function()
                if NS.Profiles and NS.Profiles.PromptCreate then
                    NS.Profiles.PromptCreate(true)
                end
            end
        })

        Add("spacer", nil, nil, nil, nil, nil, nil, nil, 1, {size = 30})
        Add("button", NS.L("Reset current profile"), NS.L("Reset current profile settings to defaults."), nil, nil, nil, nil, nil, 1, {
            onClick = function()
                if NS.Profiles and NS.Profiles.ConfirmResetCurrent then
                    NS.Profiles.ConfirmResetCurrent()
                end
            end
        })


        Add("header", NS.L("Copying"), nil, nil, nil, nil, nil, nil, 2)

        Add("dropdown", NS.L("Copy source"), nil, "profileCopySource", nil, nil, nil,
            function()
                return (NS.Profiles and NS.Profiles.GetDropdownOptions and NS.Profiles.GetDropdownOptions()) or {}
            end,
            2,
            { width = 220, context = "Global" }
        )

        Add("button", NS.L("Copy"), NS.L("Completely replaces the current profile with the selected source's settings."), nil, nil, nil, nil, nil, 2, {
            onClick = function()
                if not (NS.Profiles and NS.Profiles.ConfirmCopyIntoCurrent) then return end
                NS.Profiles.ConfirmCopyIntoCurrent()
            end
        })

        Add("spacer", nil, nil, nil, nil, nil, nil, nil, 2, {size = 30})
        Add("header", NS.L("Deletion"), nil, nil, nil, nil, nil, nil, 2)
        Add("dropdown", NS.L("Profile to delete"), nil, "profileDeleteTarget", nil, nil, nil,
            function()
                return (NS.Profiles and NS.Profiles.GetDropdownOptions and NS.Profiles.GetDropdownOptions()) or {}
            end,
            2,
            { width = 220, context = "Global" }
        )

        Add("button", NS.L("Delete"), NS.L("Deletes the profile. You cannot delete the active profile."), nil, nil, nil, nil, nil, 2, {
            onClick = function()
                if not (NS.Profiles and NS.Profiles.ConfirmDeleteSelected) then return end
                NS.Profiles.ConfirmDeleteSelected()
            end
        })
    end


    return t
end
