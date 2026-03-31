local _, NS = ...
NS.Widgets = {}

local PixelSnapValue = NS.PixelSnapValue
local PixelSnapSetSize = NS.PixelSnapSetSize
local PixelSnapSetPoint = NS.PixelSnapSetPoint

--=============================================================================
-- 1. СТИЛЬ И КОНСТАНТЫ
--=============================================================================
NS.COLOR_ACCENT    = { 0.0, 0.6, 1.0, 1 }
NS.COLOR_BG_DARK   = { 0.02, 0.02, 0.03, 0.98 }
NS.COLOR_BG_PANEL  = { 1, 1, 1, 0.03 }
NS.COLOR_BORDER    = { 0.1, 0.12, 0.15, 1 }
NS.COLOR_TEXT_OFF  = { 0.9, 0.9, 0.9, 1 }

NS.AllDropdowns = {}

function NS.CloseAllDropdowns()
    if NS.AllDropdowns then
        for _, list in ipairs(NS.AllDropdowns) do
            if list:IsShown() then list:Hide() end
        end
    end
end

function NS.CreateBackdrop(f, bg, border)
    f:SetBackdrop({ bgFile = "Interface\\Buttons\\WHITE8X8", edgeFile = "Interface\\Buttons\\WHITE8X8", edgeSize = 1 })
    f:SetBackdropColor(unpack(bg or NS.COLOR_BG_DARK))
    f:SetBackdropBorderColor(unpack(border or NS.COLOR_BORDER))
end

function NS.CreateHeader(parent, text)
    local f = CreateFrame("Frame", nil, parent)
    PixelSnapSetSize(f, 200, 20, 1, 1)
    local h = f:CreateFontString(nil, "OVERLAY", "GameFontNormal")
    PixelSnapSetPoint(h, "LEFT", f, "LEFT", 0, 0)
    h:SetText(text)
    h:SetTextColor(0, 0.6, 1)
    return f
end

function NS.CreateDesc(parent, text, relativeRegion)
    if not text then return nil end
    local d = parent:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(d, "TOPLEFT", relativeRegion, "BOTTOMLEFT", 0, -2)
    d:SetText(text)
    d:SetTextColor(0.5, 0.5, 0.5)
    d:SetWidth(PixelSnapValue(d, 200, 1))
    d:SetJustifyH("LEFT")
    d:SetWordWrap(true)
    return d
end

--=============================================================================
-- 2. ВИЗУАЛЬНЫЕ КОМПОНЕНТЫ (Без изменений логики)
--=============================================================================
function NS.CreateModernSlider(parent, label, minV, maxV)
    local frame = CreateFrame("Frame", nil, parent)
    PixelSnapSetSize(frame, 220, 42, 1, 1)

    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(title, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    title:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    title:SetText(label)

    local s = CreateFrame("Slider", nil, frame, "BackdropTemplate")
    PixelSnapSetPoint(s, "TOPLEFT", frame, "TOPLEFT", 0, -20)
    PixelSnapSetSize(s, 160, 6, 1, 1)
    s:SetOrientation("HORIZONTAL")
    s:SetMinMaxValues(minV or 0, maxV or 100)
    s:SetValue(minV or 0)
    s:SetObeyStepOnDrag(true)
    s:HookScript("OnMouseDown", function() NS.CloseAllDropdowns() end)
    NS.CreateBackdrop(s, {0, 0, 0, 0.5}, {0, 0, 0, 1})

    local thumb = s:CreateTexture(nil, "ARTWORK")
    thumb:SetTexture("Interface\\Buttons\\WHITE8X8")
    PixelSnapSetSize(thumb, 6, 16, 1, 1)
    thumb:SetVertexColor(unpack(NS.COLOR_ACCENT))
    s:SetThumbTexture(thumb)
    s:SetHitRectInsets(0, 0, -4, -4)

    local thumbGlow = s:CreateTexture(nil, "OVERLAY")
    thumbGlow:SetTexture("Interface\\Buttons\\WHITE8X8")
    PixelSnapSetSize(thumbGlow, 8, 18, 1, 1)
    thumbGlow:SetVertexColor(1, 1, 1, 0.4)
    PixelSnapSetPoint(thumbGlow, "CENTER", thumb, "CENTER", 0, 0)
    thumbGlow:Hide()

    s:SetScript("OnEnter", function() thumbGlow:Show() end)
    s:SetScript("OnLeave", function() thumbGlow:Hide() end)

    local eb = CreateFrame("EditBox", nil, frame, "BackdropTemplate")
    PixelSnapSetSize(eb, 45, 20, 1, 1)
    PixelSnapSetPoint(eb, "LEFT", s, "RIGHT", 12, 0)
    eb:SetFontObject("GameFontHighlightSmall")
    eb:SetJustifyH("CENTER")
    NS.CreateBackdrop(eb, {0, 0, 0, 0.6}, NS.COLOR_BORDER)
    eb:SetAutoFocus(false)
    eb:HookScript("OnMouseDown", function() NS.CloseAllDropdowns() end)
    eb:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT)) end)
    eb:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(unpack(NS.COLOR_BORDER)) end)

    local function UpdateFromEB(self)
        local val = tonumber(self:GetText())
        if val then
            local min, max = s:GetMinMaxValues()
            if val < min then val = min elseif val > max then val = max end
            s:SetValue(val)
            if s.OnValueChangedCallback then s.OnValueChangedCallback(s, val) end
        else
            self:SetText(math.floor(s:GetValue() * 100) / 100)
        end
        self:ClearFocus()
    end

    eb:SetScript("OnEnterPressed", UpdateFromEB)
    eb:SetScript("OnEditFocusLost", UpdateFromEB)
    eb:SetScript("OnEscapePressed", function(self)
        self:SetText(math.floor(s:GetValue() * 100) / 100)
        self:ClearFocus()
    end)

    s:SetScript("OnValueChanged", function(self, v, userInput)
        local displayVal = (v % 1 == 0) and string.format("%.0f", v) or string.format("%.1f", v)
        eb:SetText(displayVal)
        if userInput and self.OnValueChangedCallback then self.OnValueChangedCallback(self, v) end
    end)

    frame.slider = s
    frame.editbox = eb
    return frame
end

function NS.CreateModernCheckbox(parent, label)
    local cb = CreateFrame("CheckButton", nil, parent, "BackdropTemplate")
    PixelSnapSetSize(cb, 18, 18, 1, 1)
    NS.CreateBackdrop(cb, {0, 0, 0, 0.5}, {0.3, 0.3, 0.3, 1})

    local check = cb:CreateTexture(nil, "OVERLAY")
    check:SetTexture("Interface\\Buttons\\WHITE8X8")
    check:SetVertexColor(unpack(NS.COLOR_ACCENT))
    PixelSnapSetPoint(check, "TOPLEFT", cb, "TOPLEFT", 3, -3)
    PixelSnapSetPoint(check, "BOTTOMRIGHT", cb, "BOTTOMRIGHT", -3, 3)
    cb:SetCheckedTexture(check)

    cb.Text = cb:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(cb.Text, "LEFT", cb, "RIGHT", 7, 0)
    cb.Text:SetText(label)

    cb:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT)) end)
    cb:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end)
    cb:HookScript("OnClick", function() NS.CloseAllDropdowns() end)
    return cb
end

function NS.CreateColorBox(parent, label)
    local frame = CreateFrame("Frame", nil, parent)
    PixelSnapSetSize(frame, 220, 25, 1, 1)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(title, "LEFT", frame, "LEFT", 30, 0)
    title:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    title:SetText(label)
    local box = CreateFrame("Button", nil, frame, "BackdropTemplate")
    PixelSnapSetSize(box, 18, 18, 1, 1)
    PixelSnapSetPoint(box, "LEFT", frame, "LEFT", 0, 0)
    NS.CreateBackdrop(box, {0, 0, 0, 0.6}, {0, 0, 0, 1})
    local colorTex = box:CreateTexture(nil, "OVERLAY")
    PixelSnapSetPoint(colorTex, "TOPLEFT", box, "TOPLEFT", 1, -1)
    PixelSnapSetPoint(colorTex, "BOTTOMRIGHT", box, "BOTTOMRIGHT", -1, 1)
    colorTex:SetColorTexture(1, 1, 1)
    box:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(1, 1, 1) end)
    box:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0, 0, 0) end)
    box:HookScript("OnMouseDown", function() NS.CloseAllDropdowns() end)
    frame.box = box
    frame.colorTex = colorTex
    return frame
end

-- Optional "width" allows compact dropdowns (used in Copy Profiles panel).
function NS.CreateModernDropdown(parent, label, options, func, width)
    local frame = CreateFrame("Frame", nil, parent)
    width = width or 180
    -- Keep the default sizing used across the UI (220/180). For compact dropdowns
    -- (width < 180) keep the wrapper the same width as the button so two can fit
    -- on one row in the Copy Profiles panel.
    local frameW = (width < 180) and width or (width + 40)
    PixelSnapSetSize(frame, frameW, 45, 1, 1)
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(title, "TOPLEFT", frame, "TOPLEFT", 0, 0)
    title:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    title:SetText(label)
    local btn = CreateFrame("Button", nil, frame, "BackdropTemplate")
    PixelSnapSetSize(btn, width, 22, 1, 1)
    PixelSnapSetPoint(btn, "TOPLEFT", frame, "TOPLEFT", 0, -18)
    NS.CreateBackdrop(btn, {0, 0, 0, 0.5}, {0.3, 0.3, 0.3, 1})
    btn:SetScript("OnEnter", function(self) self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT)) end)
    btn:SetScript("OnLeave", function(self) self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1) end)
    local arrow = btn:CreateTexture(nil, "OVERLAY")
    arrow:SetTexture("Interface\\ChatFrame\\ChatFrameExpandArrow")
    arrow:SetDesaturated(true)
    arrow:SetVertexColor(unpack(NS.COLOR_ACCENT))
    PixelSnapSetSize(arrow, 10, 10, 1, 1)
    PixelSnapSetPoint(arrow, "RIGHT", btn, "RIGHT", -6, 0)
    -- Default state: arrow points to the right. When the list is open, rotate it to point up.
    if arrow.SetRotation then
        arrow:SetRotation(0)
    end
    btn.Text = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(btn.Text, "LEFT", btn, "LEFT", 8, 0)
    local function ResolveOptions()
        if type(options) == "function" then
            local ok, res = pcall(options)
            if ok then return res end
            return nil
        end
        return options
    end

    local function ClearListChildren(listFrame)
        local kids = { listFrame:GetChildren() }
        for _, c in ipairs(kids) do
            c:Hide()
            c:SetParent(nil)
        end
    end

    local function BuildList(listFrame, btnFrame, opts)
        ClearListChildren(listFrame)
        local count = opts and #opts or 0
        PixelSnapSetSize(listFrame, width, count * 20 + 10, 1, 1)
        if not opts then return end
        for i, optName in ipairs(opts) do
            local display, value = optName, optName
            if type(optName) == "table" then
                display = optName.text or ""
                value = optName.value
            end
            local opt = CreateFrame("Button", nil, listFrame)
            PixelSnapSetSize(opt, math.max(10, width - 10), 18, 1, 1)
            PixelSnapSetPoint(opt, "TOPLEFT", listFrame, "TOPLEFT", 5, -5 - (i-1) * 20)
            local ot = opt:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
            PixelSnapSetPoint(ot, "LEFT", opt, "LEFT", 5, 0)
            ot:SetText(display)
            opt:SetScript("OnEnter", function() ot:SetTextColor(unpack(NS.COLOR_ACCENT)) end)
            opt:SetScript("OnLeave", function() ot:SetTextColor(1, 1, 1) end)
            opt:SetScript("OnClick", function()
                btnFrame.Text:SetText(display)
                listFrame:Hide()
                if func then func(value, display) end
            end)
        end
    end

    do
        local opts = ResolveOptions()
        local first = opts and opts[1]
        if type(first) == "table" then btn.Text:SetText(first.text or "")
        else btn.Text:SetText(first or "") end
    end
    local listParent = NS.DropdownParent or UIParent
    local list = CreateFrame("Frame", nil, listParent, "BackdropTemplate")
    list:ClearAllPoints()
    PixelSnapSetPoint(list, "TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
    local count = (type(options) == "table") and #options or 0
    PixelSnapSetSize(list, width, count * 20 + 10, 1, 1)
    list:SetFrameStrata("TOOLTIP")
    list:SetClampedToScreen(true)
    list:Hide()
    -- Keep reference to the arrow so global close can also reset it.
    list._arrow = arrow
    list:SetScript("OnShow", function()
        if arrow.SetRotation then arrow:SetRotation(math.pi / 2) end
    end)
    list:SetScript("OnHide", function()
        if arrow.SetRotation then arrow:SetRotation(0) end
    end)
    NS.CreateBackdrop(list, {0.05, 0.05, 0.08, 0.95}, NS.COLOR_ACCENT)
    table.insert(NS.AllDropdowns, list)
    btn:SetScript("OnClick", function()
        local isShown = list:IsShown()
        NS.CloseAllDropdowns()
        if not isShown then
            local opts = ResolveOptions()
            BuildList(list, btn, opts)
            list:ClearAllPoints()
            PixelSnapSetPoint(list, "TOPLEFT", btn, "BOTTOMLEFT", 0, -1)
            list:Show()
        end
    end)
    -- initial build only for static option tables
    if type(options) == "table" then
        BuildList(list, btn, options)
    end
    frame.btn = btn
    frame.list = list
    return frame
end

function NS.OpenColorPicker(r, g, b, callback)
    ColorPickerFrame:SetupColorPickerAndShow({
        swatchFunc = function()
            local newR, newG, newB = ColorPickerFrame:GetColorRGB()
            callback(newR, newG, newB)
        end,
        r = r, g = g, b = b,
        hasOpacity = false,
        cancelFunc = function() callback(r, g, b) end,
    })
end

function NS.Widgets.SetEnabled(wrapper, isEnabled)
    if not wrapper then return end
    wrapper:SetAlpha(isEnabled and 1 or 0.4)
    if wrapper.slider then
        wrapper.slider:EnableMouse(isEnabled)
        wrapper.editbox:EnableMouse(isEnabled)
    elseif wrapper.box then
        wrapper.box:EnableMouse(isEnabled)
    elseif wrapper.btn then
        wrapper.btn:EnableMouse(isEnabled)
    elseif wrapper:IsObjectType("CheckButton") or wrapper:IsObjectType("Button") then
        wrapper:EnableMouse(isEnabled)
    end
end

--=============================================================================
-- 3. BINDERS (Вот тут изменения: добавлен context)
--=============================================================================

function NS.Widgets.CreateHeader(parent, text)
    return NS.CreateHeader(parent, text)
end

function NS.Widgets.CreateSlider(parent, label, dbKey, min, max, step, desc, context, onChange)
    local wrapper = NS.CreateModernSlider(parent, label, min, max)
    local s = wrapper.slider

    if step then s:SetValueStep(step) end
    
    -- Получаем значение с учетом контекста
    local val = NS.Config.Get(dbKey, context) or min
    s:SetValue(val)

    local function UpdateValueText(value)
        local str = string.format("%.2f", value):gsub("%.?0+$", "")
        wrapper.editbox:SetText(str)
    end

    UpdateValueText(val)

    s.OnValueChangedCallback = function(self, value)
        -- Сохраняем в контекст
        NS.Config.Set(dbKey, value, context)
        UpdateValueText(value)
        if onChange then
            pcall(onChange, value)
        end
    end

    if desc then
        NS.CreateDesc(wrapper, desc, wrapper.slider)
    end

    return wrapper
end

function NS.Widgets.CreateCheckbox(parent, label, dbKey, desc, targetValue, context, onChange)
    local cb = NS.CreateModernCheckbox(parent, label)
    
    local currentVal = NS.Config.Get(dbKey, context)
    local isChecked
    if targetValue ~= nil then
        isChecked = (currentVal == targetValue)
    else
        isChecked = currentVal and true or false
    end

    cb:SetChecked(isChecked)

    local function ShowReloadPopup()
        -- Нельзя принудительно сделать релог; предлагаем /reload как безопасный вариант.
        if not StaticPopupDialogs then return end
        -- Key must be globally unique; avoid collisions with other addons/old versions.
        if not StaticPopupDialogs["BLIZZPLATESFIX_RELOAD_UI"] then
            StaticPopupDialogs["BLIZZPLATESFIX_RELOAD_UI"] = {
                text = NS.L("Change requires reloading the UI (ReloadUI)."),
                button1 = NS.L("Reload"),
                button2 = NS.L("Later"),
                OnAccept = function() ReloadUI() end,
                timeout = 0,
                whileDead = 1,
                hideOnEscape = 1,
                preferredIndex = 3,
            }
        end
        StaticPopup_Show("BLIZZPLATESFIX_RELOAD_UI")
    end

    cb:SetScript("OnClick", function(self)
        local before = NS.Config.Get(dbKey, context)
        if targetValue ~= nil then
            if self:GetChecked() then
                NS.Config.Set(dbKey, targetValue, context)
            else
                self:SetChecked(true)
            end
        else
            NS.Config.Set(dbKey, self:GetChecked(), context)
        end

        -- Для master-переключателей профилей существ (enabled) предлагаем ReloadUI.
        if dbKey == "enabled" and context and NS.UNIT_TYPES then
            local isUnitProfile = (context == NS.UNIT_TYPES.FRIENDLY_PLAYER) or (context == NS.UNIT_TYPES.FRIENDLY_NPC)
                or (context == NS.UNIT_TYPES.ENEMY_PLAYER) or (context == NS.UNIT_TYPES.ENEMY_NPC)
            if isUnitProfile then
                local after = NS.Config.Get(dbKey, context)
                if before ~= after then
                    ShowReloadPopup()
                end
            end
        end

        if onChange then
            local after = NS.Config.Get(dbKey, context)
            pcall(onChange, after)
        end

        NS.CloseAllDropdowns()
    end)

    if desc then
        NS.CreateDesc(cb, desc, cb.Text)
    end

    return cb
end

function NS.Widgets.CreateColorPicker(parent, label, dbKey, context)
    local wrapper = NS.CreateColorBox(parent, label)

    local function UpdatePreview()
        local r, g, b = NS.Config.GetColor(dbKey, context)
        wrapper.colorTex:SetColorTexture(r, g, b)
    end

    UpdatePreview()

    wrapper.box:SetScript("OnClick", function()
        local r, g, b = NS.Config.GetColor(dbKey, context)
        NS.OpenColorPicker(r, g, b, function(newR, newG, newB)
            NS.Config.SetColor(dbKey, newR, newG, newB, nil, context)
            UpdatePreview()
        end)
    end)

    return wrapper
end

function NS.Widgets.CreateDropdown(parent, label, dbKey, options, context, width, onChange, getCurrent)
    local function ApplyValue(val)
        if onChange then
            onChange(val)
            -- preserve scroll position and refresh current layout
            if NS.RefreshGUI then NS.RefreshGUI(true) end
        else
            if dbKey ~= nil then
                NS.Config.Set(dbKey, val, context)
            end
            -- Preserve scroll position when changing a dropdown value.
            if NS.RefreshGUI then NS.RefreshGUI(true) end
        end
    end

    local wrapper = NS.CreateModernDropdown(parent, label, options, ApplyValue, width)

    local current = nil
    if getCurrent then
        local ok, res = pcall(getCurrent)
        if ok then current = res end
    elseif dbKey ~= nil then
        current = NS.Config.Get(dbKey, context)
    end

    local opts = options
    if type(options) == "function" then
        local ok, res = pcall(options)
        if ok then opts = res end
    end

    if current ~= nil and opts then
        for _, opt in ipairs(opts) do
            if type(opt) == "table" then
                if opt.value == current then
                    wrapper.btn.Text:SetText(opt.text or "")
                    break
                end
            else
                if opt == current then
                    wrapper.btn.Text:SetText(opt)
                    break
                end
            end
        end
    end

    return wrapper
end

-- Generic button used by Options (kept for compatibility)
function NS.Widgets.CreateButton(parent, label, desc, onClick)
    return NS.Widgets.CreateButtonWhiteHover(parent, label, desc, onClick)
end

-- Button variant: border accent on hover, text becomes white (used in copy panel)
function NS.Widgets.CreateButtonWhiteHover(parent, label, desc, onClick)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    PixelSnapSetSize(btn, 180, 24, 1, 1)
    NS.CreateBackdrop(btn, {0, 0, 0, 0.5}, {0.3, 0.3, 0.3, 1})

    local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(t, "CENTER", btn, "CENTER", 0, 0)
    t:SetText(label or "")
    t:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    btn.Text = t

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT))
        if self.Text then self.Text:SetTextColor(1, 1, 1, 1) end
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        if self.Text then self.Text:SetTextColor(unpack(NS.COLOR_TEXT_OFF)) end
    end)
    btn:SetScript("OnClick", function(self)
        NS.CloseAllDropdowns()
        if onClick then onClick(self) end
    end)

    if desc then
        NS.CreateDesc(btn, desc, btn)
    end

    return btn
end

-- Button style used in the Copy Profiles panel (matches the rest of the UI: white text on hover).
function NS.Widgets.CreateActionButton(parent, label, onClick, width)
    local btn = CreateFrame("Button", nil, parent, "BackdropTemplate")
    PixelSnapSetSize(btn, width or 180, 24, 1, 1)
    NS.CreateBackdrop(btn, {0, 0, 0, 0.5}, {0.3, 0.3, 0.3, 1})

    local t = btn:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(t, "CENTER", btn, "CENTER", 0, 0)
    t:SetText(label or "")
    t:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    btn.Text = t

    btn:SetScript("OnEnter", function(self)
        self:SetBackdropBorderColor(unpack(NS.COLOR_ACCENT))
        if self.Text then self.Text:SetTextColor(1, 1, 1, 1) end
    end)
    btn:SetScript("OnLeave", function(self)
        self:SetBackdropBorderColor(0.3, 0.3, 0.3, 1)
        if self.Text then self.Text:SetTextColor(unpack(NS.COLOR_TEXT_OFF)) end
    end)
    btn:SetScript("OnClick", function(self)
        NS.CloseAllDropdowns()
        if onClick then onClick(self) end
    end)
    return btn
end

-- Composite widget: Copy unit-profile sections between the 4 creature profile types.
function NS.Widgets.CreateCopyProfilesWidget(parent, opt)
    local frame = CreateFrame("Frame", nil, parent)
    -- Width is computed from dropdown width + arrow + gaps.
    PixelSnapSetSize(frame, 306, 260, 1, 1)

    local unitTypeList = opt.unitTypeList or {}
    local sections = opt.sections or {}
    local srcKey = opt.srcKey or "copyProfileSource"
    local dstKey = opt.dstKey or "copyProfileDest"
    local context = opt.context

    local function FilterDestOptions()
        local src = NS.Config.Get(srcKey, "Global")
        local out = {}
        for _, o in ipairs(unitTypeList) do
            if o.value ~= src then out[#out+1] = o end
        end
        return out
    end

    -- Normalize: destination must never equal source.
    do
        local src = NS.Config.Get(srcKey, "Global")
        local dst = NS.Config.Get(dstKey, "Global")
        if src and dst and src == dst then
            local opts = FilterDestOptions()
            if opts and opts[1] then
                NS.Config.Set(dstKey, opts[1].value, "Global")
            end
        end
    end

    -- Source/Destination on one horizontal row (wider dropdowns) with a safe ASCII arrow between.
    -- Slightly wider controls for better readability.
    local ddW = 138
    local gap = 6
    local arrowW = 18
    local dstX = ddW + gap + arrowW + gap

    local srcDD = NS.Widgets.CreateDropdown(frame, NS.L("Source"), srcKey, unitTypeList, context, ddW)
    PixelSnapSetPoint(srcDD, "TOPLEFT", frame, "TOPLEFT", 0, 0)

    local arrow = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlight")
    PixelSnapSetPoint(arrow, "TOPLEFT", frame, "TOPLEFT", ddW + gap, -22)
    PixelSnapSetSize(arrow, arrowW, 18, 1, 1)
    arrow:SetJustifyH("CENTER")
    arrow:SetJustifyV("MIDDLE")
    arrow:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    arrow:SetText(">>")

    local dstDD = NS.Widgets.CreateDropdown(frame, NS.L("Destination"), dstKey, FilterDestOptions, context, ddW)
    PixelSnapSetPoint(dstDD, "TOPLEFT", frame, "TOPLEFT", dstX, 0)

    -- Sections title
    local title = frame:CreateFontString(nil, "OVERLAY", "GameFontHighlightSmall")
    PixelSnapSetPoint(title, "TOPLEFT", frame, "TOPLEFT", 0, -52)
    title:SetTextColor(unpack(NS.COLOR_TEXT_OFF))
    title:SetText(NS.L("Sections"))

    local sectionBox = CreateFrame("Frame", nil, frame)
    PixelSnapSetPoint(sectionBox, "TOPLEFT", frame, "TOPLEFT", 0, -70)
    PixelSnapSetSize(sectionBox, 306, 160, 1, 1)

    local function SetAll(val)
        for _, s in ipairs(sections) do
            NS.Config.Set(s.key, val, "Global")
        end
        if NS.RefreshGUI then NS.RefreshGUI(true) end
    end

    -- Buttons in one row: same width as the dropdowns.
    local btnAll = NS.Widgets.CreateActionButton(sectionBox, NS.L("Select all"), function() SetAll(true) end, ddW)
    PixelSnapSetPoint(btnAll, "TOPLEFT", sectionBox, "TOPLEFT", 0, 0)
    local btnNone = NS.Widgets.CreateActionButton(sectionBox, NS.L("Clear all"), function() SetAll(false) end, ddW)
    PixelSnapSetPoint(btnNone, "TOPLEFT", sectionBox, "TOPLEFT", dstX, 0)

    -- Checkboxes in 2 columns
    local cbStartY = -30
    local colX1, colX2 = 0, dstX
    local rowH = 24
    local split = math.ceil(#sections / 2)
    for i, s in ipairs(sections) do
        local col = (i <= split) and 1 or 2
        local idxInCol = (col == 1) and i or (i - split)
        local x = (col == 1) and colX1 or colX2
        local y = cbStartY - (idxInCol-1) * rowH
        local cb = NS.Widgets.CreateCheckbox(sectionBox, s.text, s.key, nil, nil, "Global")
        PixelSnapSetPoint(cb, "TOPLEFT", sectionBox, "TOPLEFT", x, y)
        cb:HookScript("OnClick", function()
            if NS.RefreshGUI then NS.RefreshGUI(true) end
        end)
        if cb.Text then cb.Text:SetFontObject("GameFontHighlightSmall") end
    end

    -- Copy button centered under the sections
    local copyBtn = NS.Widgets.CreateActionButton(frame, NS.L("Copy"), function()
        local src = NS.Config.Get(srcKey, "Global")
        local dst = NS.Config.Get(dstKey, "Global")
        if not src or not dst or src == dst then return end
        local picked = {}
        for _, s in ipairs(sections) do
            if NS.Config.Get(s.key, "Global") then picked[#picked+1] = s.sec end
        end
        if #picked == 0 then return end
        if NS.DB and NS.DB.CopySections then
            NS.DB.CopySections(src, dst, picked)
        end
    end, 180)
    PixelSnapSetPoint(copyBtn, "TOP", sectionBox, "BOTTOM", 0, -12)

    return frame
end

function NS.Widgets.CreateSeparator(parent, orientation, size)
    local f = CreateFrame("Frame", nil, parent)
    local tex = f:CreateTexture(nil, "ARTWORK")
    tex:SetAllPoints()
    -- Vertical separators should remain visible; horizontal ones should be subtler.
    local alpha = (orientation == "V") and 0.40 or 0.10
    tex:SetColorTexture(0.5, 0.5, 0.5, alpha)
    if orientation == "V" then
        PixelSnapSetSize(f, 1, size or 100, 1, 1)
    else
        PixelSnapSetSize(f, size or 250, 1, 1, 1)
    end
    return f
end