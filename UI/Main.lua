local _, NS = ...

NS.MenuState = NS.MenuState or {}

local PixelSnapValue = NS.PixelSnapValue
local PixelSnapSetSize = NS.PixelSnapSetSize
local PixelSnapSetPoint = NS.PixelSnapSetPoint

local playerUnitSubTabKeys = {
    -- Полоса здоровья
    [1] = "hpBarEnable",
    [2] = "nameEnable", -- Текст имени
    [3] = "guildTextEnable", -- Текст гильдии
    [4] = "hpTextEnable", -- Текст здоровья
    [5] = "levelEnable", -- Уровень
    [6] = "targetIndicatorEnable", -- Индикация цели (master)
    [7] = "cbEnabled", -- Кастбар

    -- Ауры (разбито на 3 подвкладки)
    [8] = "buffsEnable",   -- Баффы
    [9] = "debuffsEnable", -- Дебаффы
    [10] = "ccEnable",      -- Контроль (CC)
}

local npcUnitSubTabKeys = {
    [1] = "hpBarEnable",
    [2] = "nameEnable",
    [3] = "###",
    [4] = "hpTextEnable",
    [5] = "levelEnable",
    [6] = "targetIndicatorEnable",
    [7] = "cbEnabled",
    [8] = "buffsEnable",
    [9] = "debuffsEnable",
    [10] = "ccEnable",
}

-- Карта "master-enable" ключей для тумблеров слева у подвкладок (на тип юнита)
-- Храним в NS.SubTabEnableKeys[mainTabIndex][subTabIndex] = key
NS.SubTabEnableKeys = NS.SubTabEnableKeys or {
    [2] = playerUnitSubTabKeys, -- Friendly Player
    [3] = npcUnitSubTabKeys, -- Friendly NPC
    [4] = playerUnitSubTabKeys, -- Enemy Player
    [5] = npcUnitSubTabKeys, -- Enemy NPC
}

local MainFrame
local CurrentMainTab = 1
local CurrentSubTab = 1

local ScrollFrame
local ContentInner
local ScrollBar

local MainTabs = { NS.L("General"), NS.L("Friendly Players"), NS.L("Friendly NPC"), NS.L("Hostile Players"), NS.L("Hostile NPC"), NS.L("Profiles") }
local GeneralSubTabs = { NS.L("Engine"), NS.L("Status"), NS.L("Effects"), NS.L("Support") }
NS.SubTabs = { NS.L("Health bar"), NS.L("Name text"), NS.L("Guild text"), NS.L("Health text"), NS.L("Show level"), NS.L("Target indicator"), NS.L("Castbar"), NS.L("Buffs"), NS.L("Debuffs"), NS.L("Crowd Control (CC)") }

local function ClearContainer()
    if not ContentInner then return end
    local kids = { ContentInner:GetChildren() }
    for _, child in ipairs(kids) do
        child:Hide()
        child:SetParent(nil)
    end
end

-- -------------------------------------------------------------
-- DrawOptions: Теперь передает opt.context в виджеты!
-- -------------------------------------------------------------
local function DrawOptions(container, mainIdx, subIdx)
    ClearContainer()

    if not NS.Options or not NS.Options.GetTable then return end
    local options = NS.Options.GetTable(mainIdx, subIdx)
    if not options then return end

    local startX_Col1 = 20
    local startX_Col2 = 370
    local startY = -15

    local yOffset1 = startY
    local yOffset2 = startY

    local lastToggle = { [1] = nil, [2] = nil }
    local radioGroups = {}
    local vLines = {}

    for _, opt in ipairs(options) do
        repeat
            -- requires: проверка зависимости
            if opt.requires and opt.requires.key then
                -- Важно: проверяем зависимость в том же контексте!
                local cur = NS.Config and NS.Config.Get and NS.Config.Get(opt.requires.key, opt.context)
                if cur ~= opt.requires.value then
                    break
                end
            end

            local widget
            local col = opt.col or 1
            local currentX = (col == 1) and startX_Col1 or startX_Col2
            local currentY = (col == 1) and yOffset1 or yOffset2
            local indent = opt.offX or 0
            local finalX = currentX + indent

            if opt.type == "header" then
                if currentY ~= startY then currentY = currentY - 10 end
                widget = NS.Widgets.CreateHeader(container, opt.text)
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", finalX - 5, currentY)
                currentY = currentY - 40

            elseif opt.type == "separator" then
                currentY = currentY - 10 + (opt.offY or 0)
                widget = NS.Widgets.CreateSeparator(container, "H", opt.width or 280)
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", finalX - 10, currentY)

            elseif opt.type == "vline" then
                widget = NS.Widgets.CreateSeparator(container, "V", opt.height or 450)
                widget._isVLine = true
                table.insert(vLines, widget)
                local vx = 325 + (opt.offX or 0)
                local vy = startY + (opt.offY or 0)
                widget._vlineTopY = vy
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", vx, vy)

            elseif opt.type == "checkbox" then
                -- ПЕРЕДАЕМ opt.context!
                widget = NS.Widgets.CreateCheckbox(container, opt.label, opt.db, opt.desc, opt.val, opt.context, opt.onChange)
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", finalX, currentY)
                local extra = opt.desc and 15 or 0
                currentY = currentY - 40 - extra

                if indent == 0 then
                    lastToggle[col] = widget
                    widget.children = {}
                end

                if opt.group then
                    radioGroups[opt.group] = radioGroups[opt.group] or {}
                    table.insert(radioGroups[opt.group], { widget = widget, db = opt.db, val = opt.val, context = opt.context })
                end

            elseif opt.type == "slider" then
                -- ПЕРЕДАЕМ opt.context!
                widget = NS.Widgets.CreateSlider(container, opt.label, opt.db, opt.min, opt.max, opt.step, opt.desc, opt.context, opt.onChange)
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", finalX, currentY)
                local extra = opt.desc and 15 or 0
                currentY = currentY - 50 - extra

            elseif opt.type == "color" then
                -- ПЕРЕДАЕМ opt.context!
                widget = NS.Widgets.CreateColorPicker(container, opt.label, opt.db, opt.context)
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", finalX, currentY)
                currentY = currentY - 35

            elseif opt.type == "dropdown" then
                -- ПЕРЕДАЕМ opt.context!
                widget = NS.Widgets.CreateDropdown(container, opt.label, opt.db, opt.options, opt.context, opt.width, opt.onChange, opt.getCurrent)
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", finalX, currentY)
                currentY = currentY - 60

            elseif opt.type == "button" then
                widget = NS.Widgets.CreateButton(container, opt.label or opt.text, opt.desc, opt.onClick)
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", finalX, currentY)
                currentY = currentY - 35

            elseif opt.type == "copyprofiles" then
                widget = NS.Widgets.CreateCopyProfilesWidget(container, opt)
                PixelSnapSetPoint(widget, "TOPLEFT", container, "TOPLEFT", finalX, currentY)
                currentY = currentY - (widget:GetHeight() or 200) - 10

            elseif opt.type == "spacer" then
                currentY = currentY - (opt.height or 10)
            end

            -- мета для глобального disable
            if widget then
                widget._dbKey = opt.db
                widget._optType = opt.type
            end

            -- ЛОГИКА ЗАВИСИМОСТИ (Enable/Disable детей)
            if widget and indent > 0 and lastToggle[col] and not opt.noToggleLink then
                table.insert(lastToggle[col].children, widget)
                NS.Widgets.SetEnabled(widget, lastToggle[col]:GetChecked())
            end

            -- Скрипт мастера-галочки
            if widget and opt.type == "checkbox" then
                widget:HookScript("OnClick", function(self)
                    local state = self:GetChecked()

                    if opt.group and state then
                        for _, other in ipairs(radioGroups[opt.group]) do
                            if other.widget ~= self then
                                other.widget:SetChecked(false)
                                -- Обновляем DB для "других" радио-кнопок
                                if other.db ~= opt.db then
                                    NS.Config.Set(other.db, false, other.context)
                                end

                                if other.widget.children then
                                    for _, child in ipairs(other.widget.children) do
                                        NS.Widgets.SetEnabled(child, false)
                                    end
                                end
                            end
                        end
                    end

                    if self.children then
                        for _, child in ipairs(self.children) do
                            NS.Widgets.SetEnabled(child, state)
                        end
                    end
                end)
            end

            if col == 1 then yOffset1 = currentY else yOffset2 = currentY end
        until true
    end


    -- BPF_MasterDisable: если модуль подвкладки выключен, делаем все элементы неактивными
    local unitContext = nil
    if mainIdx == 2 then unitContext = NS.UNIT_TYPES.FRIENDLY_PLAYER
    elseif mainIdx == 3 then unitContext = NS.UNIT_TYPES.FRIENDLY_NPC
    elseif mainIdx == 4 then unitContext = NS.UNIT_TYPES.ENEMY_PLAYER
    elseif mainIdx == 5 then unitContext = NS.UNIT_TYPES.ENEMY_NPC
    end

    local masterKey = nil
    if unitContext and NS.SubTabEnableKeys and NS.SubTabEnableKeys[mainIdx] then
        masterKey = NS.SubTabEnableKeys[mainIdx][subIdx]
        if masterKey == "###" then masterKey = nil end
    end

    if masterKey and NS.Config and NS.Config.Get then
        local enabled = NS.Config.Get(masterKey, unitContext) and true or false
        if not enabled then
            local kids = { container:GetChildren() }
            for _, child in ipairs(kids) do
                local isMaster = child and child._optType == "checkbox" and child._dbKey == masterKey
                if not isMaster then
                    NS.Widgets.SetEnabled(child, false)
                end
            end
        end
    end

    -- Scroll calc
    local bottomY = math.min(yOffset1, yOffset2)
    local contentBottom = math.abs(bottomY)
    local contentHeight = contentBottom + 15
    if contentHeight < 1 then contentHeight = 1 end

    container:SetHeight(PixelSnapValue(container, contentHeight, 1))

    local viewH = ScrollFrame and ScrollFrame:GetHeight() or 1
    local needScroll = (contentHeight > viewH + 1)

    local vlineH
    if needScroll then
        vlineH = (contentHeight - 15) - 15
    else
        vlineH = (viewH - 15) - 15
    end
    if vlineH < 1 then vlineH = 1 end

    for _, v in ipairs(vLines) do
        v:SetHeight(PixelSnapValue(v, vlineH, 1))
    end

    if needScroll then
        ScrollBar:Show()
        local maxScroll = contentHeight - viewH
        if maxScroll < 0 then maxScroll = 0 end
        ScrollBar:SetMinMaxValues(0, maxScroll)
        local cur = ScrollBar:GetValue()
        if cur > maxScroll then ScrollBar:SetValue(maxScroll) end
    else
        ScrollBar:SetValue(0)
        ScrollBar:SetMinMaxValues(0, 0)
        ScrollBar:Hide()
    end
end

function NS.InitializeGUI()
    if MainFrame then return end

    MainFrame = CreateFrame("Frame", "BPF_MainLayout", UIParent, "BackdropTemplate")
    PixelSnapSetSize(MainFrame, 900, 650, 1, 1)
    PixelSnapSetPoint(MainFrame, "CENTER", UIParent, "CENTER", 0, 0)
    MainFrame:SetMovable(true)
    MainFrame:EnableMouse(true)
    MainFrame:RegisterForDrag("LeftButton")
    MainFrame:SetScript("OnDragStart", MainFrame.StartMoving)
    MainFrame:SetScript("OnDragStop", MainFrame.StopMovingOrSizing)
    MainFrame:SetFrameStrata("HIGH")
    MainFrame:SetScript("OnMouseDown", function() NS.CloseAllDropdowns() end)
    -- Если меню закрывают (в т.ч. через "X"), выключаем превью аур,
    -- чтобы тестовые иконки не оставались в мире.
    MainFrame:SetScript("OnHide", function()
        -- Close any opened dropdown lists (they are parented to UIParent)
        NS.CloseAllDropdowns()
        if NS.AurasPreview and NS.AurasPreview.DisableAll then
            NS.AurasPreview.DisableAll()
        end
    end)
    NS.CreateBackdrop(MainFrame, NS.COLOR_BG_DARK, NS.COLOR_BORDER)
    -- Parent dropdown lists to the main menu so they are always hidden together with it.
    NS.DropdownParent = MainFrame
    MainFrame:Hide()

    if NS.PreviewNameplate and NS.PreviewNameplate.Initialize then
        NS.PreviewNameplate.Initialize(MainFrame)
    end

    local Title = MainFrame:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    PixelSnapSetPoint(Title, "BOTTOMLEFT", MainFrame, "TOPLEFT", 10, 8)
    Title:SetText("|cff00aaffBlizzPlates|r Fix")
    local font, size, flags = Title:GetFont()
    if font and size then
        Title:SetFont(font, size + 2, flags)
    end

    local TopPanel = CreateFrame("Frame", nil, MainFrame)
    PixelSnapSetPoint(TopPanel, "TOPLEFT", MainFrame, "TOPLEFT", 10, -10)
    PixelSnapSetPoint(TopPanel, "TOPRIGHT", MainFrame, "TOPRIGHT", -10, -10)
    TopPanel:SetHeight(PixelSnapValue(TopPanel, 35, 1))

    local LeftPanel = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    PixelSnapSetPoint(LeftPanel, "TOPLEFT", MainFrame, "TOPLEFT", 10, -60)
    PixelSnapSetPoint(LeftPanel, "BOTTOMLEFT", MainFrame, "BOTTOMLEFT", 10, 10)
    LeftPanel:SetWidth(PixelSnapValue(LeftPanel, 170, 1))
    NS.CreateBackdrop(LeftPanel, {0, 0, 0, 0.2}, NS.COLOR_BORDER)

    local Content = CreateFrame("Frame", nil, MainFrame, "BackdropTemplate")
    PixelSnapSetPoint(Content, "TOPLEFT", LeftPanel, "TOPRIGHT", 10, 0)
    PixelSnapSetPoint(Content, "BOTTOMRIGHT", MainFrame, "BOTTOMRIGHT", -10, 10)
    NS.CreateBackdrop(Content, NS.COLOR_BG_PANEL, NS.COLOR_BORDER)
    Content:SetScript("OnMouseDown", function() NS.CloseAllDropdowns() end)

    local Clip = CreateFrame("Frame", nil, Content)
    PixelSnapSetPoint(Clip, "TOPLEFT", Content, "TOPLEFT", 0, -2)
    PixelSnapSetPoint(Clip, "BOTTOMRIGHT", Content, "BOTTOMRIGHT", -18, 2)
    if Clip.SetClipsChildren then Clip:SetClipsChildren(true) end

    ScrollFrame = CreateFrame("ScrollFrame", nil, Clip)
    ScrollFrame:SetAllPoints()
    ScrollFrame:EnableMouseWheel(true)
    ContentInner = CreateFrame("Frame", nil, ScrollFrame)
    PixelSnapSetPoint(ContentInner, "TOPLEFT", ScrollFrame, "TOPLEFT", 0, 0)
    ContentInner:SetWidth(PixelSnapValue(ContentInner, 680, 1))
    ContentInner:SetHeight(PixelSnapValue(ContentInner, 1, 1))
    ScrollFrame:SetScrollChild(ContentInner)

    -- Warning overlay (профиль типа существ выключен)
    ContentInner.BPF_WarningText = ContentInner:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    PixelSnapSetPoint(ContentInner.BPF_WarningText, "CENTER", ContentInner, "CENTER", 0, 0)
    ContentInner.BPF_WarningText:SetTextColor(1, 0.1, 0.1, 1)
    ContentInner.BPF_WarningText:SetText("")
    ContentInner.BPF_WarningText:Hide()


    -- ScrollBar logic
    ScrollBar = CreateFrame("Slider", nil, Content, "BackdropTemplate")
    PixelSnapSetPoint(ScrollBar, "TOPRIGHT", Content, "TOPRIGHT", -5, -7)
    PixelSnapSetPoint(ScrollBar, "BOTTOMRIGHT", Content, "BOTTOMRIGHT", -5, 7)
    local TRACK_W, THUMB_W, THUMB_H = 4, 4, 44
    ScrollBar:SetWidth(PixelSnapValue(ScrollBar, TRACK_W, 1))
    ScrollBar:SetOrientation("VERTICAL")
    ScrollBar:SetMinMaxValues(0, 0)
    ScrollBar:SetValue(0)
    ScrollBar:SetValueStep(1)
    ScrollBar:SetObeyStepOnDrag(true)
    ScrollBar:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8" })
    ScrollBar:SetBackdropColor(0, 0, 0, 0.35)
    local thumb = ScrollBar:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    PixelSnapSetSize(thumb, THUMB_W, THUMB_H, 1, 1)
    thumb:SetVertexColor(unpack(NS.COLOR_ACCENT))
    ScrollBar:SetThumbTexture(thumb)
    local thumbGlow = ScrollBar:CreateTexture(nil, "OVERLAY")
    thumbGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    PixelSnapSetPoint(thumbGlow, "CENTER", thumb, "CENTER", 0, 0)
    PixelSnapSetSize(thumbGlow, THUMB_W + 2, THUMB_H + 2, 1, 1)
    thumbGlow:SetVertexColor(1, 1, 1, 0.22)
    thumbGlow:Hide()
    local thumbHit = CreateFrame("Frame", nil, ScrollBar)
    PixelSnapSetPoint(thumbHit, "CENTER", thumb, "CENTER", 0, 0)
    PixelSnapSetSize(thumbHit, THUMB_W + 10, THUMB_H + 10, 1, 1)
    ScrollBar:SetScript("OnUpdate", function(self)
        if not self:IsShown() then thumbGlow:Hide(); return end
        if MouseIsOver(thumbHit) then thumbGlow:Show() else thumbGlow:Hide() end
    end)
    ScrollBar:SetScript("OnValueChanged", function(self, value)
        ScrollFrame:SetVerticalScroll(value)
        NS.CloseAllDropdowns()
    end)
    ScrollFrame:SetScript("OnMouseWheel", function(_, delta)
        if not ScrollBar or not ScrollBar:IsShown() then return end
        local cur = ScrollBar:GetValue()
        local minV, maxV = ScrollBar:GetMinMaxValues()
        local newV = cur - (delta * 30)
        if newV < minV then newV = minV end
        if newV > maxV then newV = maxV end
        ScrollBar:SetValue(newV)
        NS.CloseAllDropdowns()
    end)
    ScrollBar:Hide()

    local mainButtons, subButtons = {}, {}

    local function RefreshLayout(preserveScroll)
        -- Preserve current scroll position when the layout is refreshed due to dropdown changes.
        local savedScroll = 0
        if preserveScroll and ScrollBar and ScrollBar:IsShown() then
            savedScroll = ScrollBar:GetValue() or 0
        end
        if NS.PreviewNameplate and NS.PreviewNameplate.ApplyMainTab then
            NS.PreviewNameplate.ApplyMainTab(CurrentMainTab)
        end
        if CurrentMainTab == 6 then
            LeftPanel:Hide()
            PixelSnapSetPoint(Content, "TOPLEFT", MainFrame, "TOPLEFT", 10, -60)

            if ContentInner and ContentInner.BPF_WarningText then
                ContentInner.BPF_WarningText:Hide()
            end

            if not preserveScroll then
                ScrollBar:SetValue(0)
                ScrollFrame:SetVerticalScroll(0)
            end

            -- Profiles tab has no left subtabs; draw it as a single page
            DrawOptions(ContentInner, 6, 1)

            -- Restore saved scroll position after the content has been rebuilt.
            if preserveScroll and ScrollBar and ScrollBar:IsShown() then
                local minV, maxV = ScrollBar:GetMinMaxValues()
                local v = savedScroll
                if v < minV then v = minV end
                if v > maxV then v = maxV end
                ScrollBar:SetValue(v)
                ScrollFrame:SetVerticalScroll(v)
            end
        else
            LeftPanel:Show()
            PixelSnapSetPoint(Content, "TOPLEFT", LeftPanel, "TOPRIGHT", 10, 0)
            local currentSubList = (CurrentMainTab == 1) and GeneralSubTabs or NS.SubTabs

            -- Определяем контекст для галочек слева (для проверки enabled)
            local context = nil
            if CurrentMainTab == 2 then context = NS.UNIT_TYPES.FRIENDLY_PLAYER
            elseif CurrentMainTab == 3 then context = NS.UNIT_TYPES.FRIENDLY_NPC
            elseif CurrentMainTab == 4 then context = NS.UNIT_TYPES.ENEMY_PLAYER
            elseif CurrentMainTab == 5 then context = NS.UNIT_TYPES.ENEMY_NPC
            end


            -- BPF_UnitDisabled: если профиль типа существ выключен - блокируем вкладку и показываем предупреждение
            local unitEnabled = true
            if context and NS.Config and NS.Config.Get then
                unitEnabled = NS.Config.Get("enabled", context) and true or false
            end

            if ContentInner and ContentInner.BPF_WarningText then
                if not unitEnabled then
                    ClearContainer()
                    ContentInner.BPF_WarningText:SetText(NS.L("Profile is disabled for this creature category"))
                    ContentInner.BPF_WarningText:Show()
                else
                    ContentInner.BPF_WarningText:Hide()
                end
            end

            for i = 1, 10 do
                local btn = subButtons[i]
                local name = currentSubList[i]
                if name then
                    btn.Text:SetText(name)
                    btn:Show()
                    local key = NS.SubTabEnableKeys and NS.SubTabEnableKeys[CurrentMainTab] and NS.SubTabEnableKeys[CurrentMainTab][i]
                    if btn.Toggle then
                        if key and key ~= "###" then
                            btn.Toggle:Show()
                            local enabled = false
                            if key ~= "###" and NS.Config and NS.Config.Get then
                                enabled = NS.Config.Get(key, context) and true or false
                            end
                            btn.Toggle:SetChecked(enabled)
                            btn.Toggle:SetAlpha(1)
                            if not unitEnabled then
                                btn:EnableMouse(false)
                                btn.Toggle:EnableMouse(false)
                                btn:SetAlpha(0.4)
                            else
                                btn:EnableMouse(true)
                                btn.Toggle:EnableMouse(true)
                                btn:SetAlpha(1)
                            end
                        else
                            btn.Toggle:Hide()
                            if not unitEnabled then
                                btn:EnableMouse(false)
                                btn:SetAlpha(0.4)
                            else
                                btn:EnableMouse(true)
                                btn:SetAlpha(1)
                            end
                        end
                    end
                    local isSelected = (i == CurrentSubTab)
                    btn:SetBackdropBorderColor(unpack(isSelected and NS.COLOR_ACCENT or {0.2, 0.2, 0.2, 1}))
                    btn.Text:SetTextColor(unpack(isSelected and {1, 1, 1, 1} or {0.6, 0.6, 0.6, 1}))
                else
                    btn:Hide()
                end
            end
            if not preserveScroll then
                ScrollBar:SetValue(0)
                ScrollFrame:SetVerticalScroll(0)
            end

            if unitEnabled then
                DrawOptions(ContentInner, CurrentMainTab, CurrentSubTab)

                -- Restore saved scroll position after the content has been rebuilt.
                if preserveScroll and ScrollBar and ScrollBar:IsShown() then
                    local minV, maxV = ScrollBar:GetMinMaxValues()
                    local v = savedScroll
                    if v < minV then v = minV end
                    if v > maxV then v = maxV end
                    ScrollBar:SetValue(v)
                    ScrollFrame:SetVerticalScroll(v)
                end
            else
                ScrollBar:Hide()
            end
        end

        for i, btn in ipairs(mainButtons) do
            local isSelected = (i == CurrentMainTab)
            btn:SetBackdropBorderColor(unpack(isSelected and NS.COLOR_ACCENT or {0.15, 0.15, 0.15, 1}))
            btn.Text:SetTextColor(unpack(isSelected and {1, 1, 1, 1} or {0.6, 0.6, 0.6, 1}))
        end
    end

    NS.RefreshGUI = RefreshLayout

    -- Top Buttons
    local totalWidth = 880
    local spacing = 4
    local mainBtnW = (totalWidth - (spacing * (#MainTabs - 1))) / #MainTabs
    for i, name in ipairs(MainTabs) do
        local btn = CreateFrame("Button", nil, TopPanel, "BackdropTemplate")
        PixelSnapSetSize(btn, mainBtnW, 30, 1, 1)
        PixelSnapSetPoint(btn, "LEFT", TopPanel, "LEFT", (i-1) * (mainBtnW + spacing), 0)
        NS.CreateBackdrop(btn, {0.02, 0.02, 0.02, 1}, {0.15, 0.15, 0.15, 1})
        btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.Text:SetFont(btn.Text:GetFont(), 11)
        btn.Text:SetPoint("CENTER")
        btn.Text:SetText(name)
        btn:SetScript("OnEnter", function(self) if i ~= CurrentMainTab then self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT)); self.Text:SetTextColor(1, 1, 1) end end)
        btn:SetScript("OnLeave", function(self) if i ~= CurrentMainTab then self:SetBackdropBorderColor(0.15, 0.15, 0.15, 1); self.Text:SetTextColor(0.6, 0.6, 0.6, 1) end end)
        btn:SetScript("OnClick", function()
            CurrentMainTab = i
            CurrentSubTab = NS.MenuState[i] or 1
            NS.CloseAllDropdowns()
            RefreshLayout()
        end)
        mainButtons[i] = btn
    end

-- Left Buttons
    for i = 1, 10 do
        local btn = CreateFrame("Button", nil, LeftPanel, "BackdropTemplate")
        PixelSnapSetSize(btn, 160, 32, 1, 1)
        PixelSnapSetPoint(btn, "TOP", LeftPanel, "TOP", 0, -10 - (i-1) * 35)
        NS.CreateBackdrop(btn, {0, 0, 0, 0.3}, {0.2, 0.2, 0.2, 1})

        btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
        btn.Text:SetPoint("LEFT", 15, 0)

        -- ГАЛОЧКА (CHECKBOX)
        btn.Toggle = CreateFrame("CheckButton", nil, btn, "BackdropTemplate")
        PixelSnapSetSize(btn.Toggle, 16, 16, 1, 1)
        PixelSnapSetPoint(btn.Toggle, "RIGHT", btn, "RIGHT", -10, 0)
        NS.CreateBackdrop(btn.Toggle, {0,0,0,0.5}, {0.3,0.3,0.3,1})
        
        local check = btn.Toggle:CreateTexture(nil, "OVERLAY")
        check:SetTexture("Interface\\Buttons\\WHITE8X8")
        check:SetVertexColor(unpack(NS.COLOR_ACCENT))
        PixelSnapSetPoint(check, "TOPLEFT", btn.Toggle, "TOPLEFT", 3, -3)
        PixelSnapSetPoint(check, "BOTTOMRIGHT", btn.Toggle, "BOTTOMRIGHT", -3, 3)
        btn.Toggle:SetCheckedTexture(check)

        -- !!! ИЗМЕНЕНИЕ 1: ВКЛЮЧАЕМ МЫШЬ !!!
        btn.Toggle:EnableMouse(true)

        -- !!! ИЗМЕНЕНИЕ 2: СКРИПТ КЛИКА ПО ГАЛОЧКЕ !!!
        btn.Toggle:SetScript("OnClick", function(self)
            local newState = self:GetChecked()

            -- 1. Определяем контекст (тип юнита)
            local context = nil
            if CurrentMainTab == 2 then context = NS.UNIT_TYPES.FRIENDLY_PLAYER
            elseif CurrentMainTab == 3 then context = NS.UNIT_TYPES.FRIENDLY_NPC
            elseif CurrentMainTab == 4 then context = NS.UNIT_TYPES.ENEMY_PLAYER
            elseif CurrentMainTab == 5 then context = NS.UNIT_TYPES.ENEMY_NPC
            end

            -- 2. Определяем ключ настройки
            local key = NS.SubTabEnableKeys and NS.SubTabEnableKeys[CurrentMainTab] and NS.SubTabEnableKeys[CurrentMainTab][i]

            -- 3. Если ключ есть и это не заглушка "###"
            if key and key ~= "###" then
                -- Сохраняем в базу
                if NS.Config and NS.Config.Set then
                    NS.Config.Set(key, newState, context)
                end

                -- Обновляем неймплейты в мире
                
if NS.RequestUpdateAll then
                    local immediate = true
                    if InCombatLockdown and InCombatLockdown() then
                        immediate = false
                    end
                    NS.RequestUpdateAll("ui_subtab_toggle:" .. key, immediate, NS.REASON_CONFIG)
                elseif NS.ForceUpdateAll then
                    NS.ForceUpdateAll()
                elseif NS.UpdateAllNameplates then
                    NS.UpdateAllNameplates()
                end

                -- Если мы сейчас находимся в этой вкладке, обновляем список справа (чтобы там галочка тоже переключилась)
                if CurrentSubTab == i then
                    RefreshLayout()
                end
            else
                -- Если это заглушка (например, полоса здоровья), запрещаем менять состояние кликом
                self:SetChecked(true)
            end
        end)

        -- Скрипты самой кнопки (смена вкладки)
        btn:SetScript("OnEnter", function(self) if i ~= CurrentSubTab then self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT)); self.Text:SetTextColor(1, 1, 1) end end)
        btn:SetScript("OnLeave", function(self) if i ~= CurrentSubTab then self:SetBackdropBorderColor(0.2, 0.2, 0.2, 1); self.Text:SetTextColor(0.6, 0.6, 0.6, 1) end end)
        
        btn:SetScript("OnClick", function()
            CurrentSubTab = i
            NS.MenuState[CurrentMainTab] = i
            NS.CloseAllDropdowns()
            RefreshLayout()
        end)

        subButtons[i] = btn
        btn:Hide()
    end

    -- Close
    local close = CreateFrame("Button", nil, MainFrame, "BackdropTemplate")
    PixelSnapSetSize(close, 26, 26, 1, 1)
    PixelSnapSetPoint(close, "TOPRIGHT", MainFrame, "TOPRIGHT", 0, 26)
    NS.CreateBackdrop(close, {0.02, 0.02, 0.02, 1}, {0.15, 0.15, 0.15, 1})
    close.t = close:CreateFontString(nil, "OVERLAY", "GameFontNormalLarge")
    -- FontString baseline in WoW fonts is slightly off-center; a small Y offset looks visually centered.
    close.t:SetPoint("CENTER", 0, -1)
    close.t:SetJustifyH("CENTER")
    close.t:SetJustifyV("MIDDLE")
    close.t:SetText("X")
    close.t:SetTextColor(0.8, 0.8, 0.8)
    -- Hover: highlight only the "X" symbol (no background flashing)
    close:SetScript("OnEnter", function(self)
        self.t:SetTextColor(1, 0.2, 0.2, 1)
        self.t:SetShadowColor(1, 0.4, 0.4, 1)
        self.t:SetShadowOffset(0, 0)
    end)
    close:SetScript("OnLeave", function(self)
        self.t:SetTextColor(0.7, 0.7, 0.7, 1)
        self.t:SetShadowColor(0, 0, 0, 0)
        self.t:SetShadowOffset(0, 0)
    end)
    close:SetScript("OnClick", function()
        if NS.AurasPreview and NS.AurasPreview.DisableAll then
            NS.AurasPreview.DisableAll()
        end
        MainFrame:Hide()
    end)


-- Fix: some UI elements (fonts) can shift by 1-2px on the first interaction due to late layout/font metric settling.
-- We run an extra refresh on show (next frame) so the user never sees the shift.
MainFrame:HookScript("OnShow", function()
    if NS.CloseAllDropdowns then NS.CloseAllDropdowns() end
    RefreshLayout()
    C_Timer.After(0, function()
        if MainFrame and MainFrame:IsShown() then
            RefreshLayout(true) -- preserve scroll if any
        end
    end)
end)

    RefreshLayout()
end

function NS.ToggleGUI()
    if not MainFrame then NS.InitializeGUI() end
    if MainFrame then MainFrame:SetShown(not MainFrame:IsShown()) end
end
