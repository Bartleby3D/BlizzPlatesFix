local _, NS = ...

local CR = NS.ClassResourceInternal
if not CR then return end

local floor = CR.floor
local max = CR.max
local min = CR.min

local function EnsureModernTextures(slot)
    if slot.modernBg and slot.modernFill and slot.modernFillClip then return end

    slot.modernBg = slot:CreateTexture(nil, "BACKGROUND", nil, 0)
    slot.modernBg:SetAllPoints()
    slot.modernBg:Hide()

    slot.modernFillClip = CreateFrame("Frame", nil, slot)
    slot.modernFillClip:SetClipsChildren(true)
    slot.modernFillClip:Hide()

    slot.modernFill = slot.modernFillClip:CreateTexture(nil, "ARTWORK", nil, 1)
    slot.modernFill:Hide()
end

local function SetTextureFillMode(slot, tex, mode, reverseFill, insetX, insetY)
    if not tex then return end

    insetX = insetX or 1
    insetY = insetY or 1

    local cacheKey = tex
    slot._fillCache = slot._fillCache or {}
    local cached = slot._fillCache[cacheKey]
    if cached and cached.mode == mode and cached.reverseFill == (reverseFill and true or false)
        and cached.insetX == insetX and cached.insetY == insetY then
        return
    end

    slot._fillCache[cacheKey] = {
        mode = mode,
        reverseFill = reverseFill and true or false,
        insetX = insetX,
        insetY = insetY,
    }

    tex:ClearAllPoints()
    if mode == "FULL" then
        tex:SetPoint("TOPLEFT", insetX, -insetY)
        tex:SetPoint("BOTTOMRIGHT", -insetX, insetY)
    elseif reverseFill then
        tex:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -insetX, -insetY)
        tex:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -insetX, insetY)
    else
        tex:SetPoint("TOPLEFT", slot, "TOPLEFT", insetX, -insetY)
        tex:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", insetX, insetY)
    end
end

function CR.SetSlotFillMode(slot, mode, reverseFill)
    SetTextureFillMode(slot, slot.fill, mode, reverseFill, 1, 1)
end

function CR.GetVisualSlot(st, count, logicalIndex, reverseFill)
    local visualIndex = reverseFill and (count - logicalIndex + 1) or logicalIndex
    return st.slots[visualIndex]
end

function CR.EnsureHolder(frame)
    local st = CR.GetState(frame)
    if st.inited and frame.BPF_ClassResourceHolder then return st end

    local holder = CreateFrame("Frame", nil, frame)
    holder:SetFrameStrata(frame:GetFrameStrata())
    holder:SetFrameLevel((frame:GetFrameLevel() or 1) + 8)
    holder:Hide()
    frame.BPF_ClassResourceHolder = holder

    st.inited = true
    return st
end

function CR.EnsureSlot(holder, st, index)
    local slot = st.slots[index]
    if slot then return slot end

    slot = CreateFrame("Frame", nil, holder)
    slot.bg = slot:CreateTexture(nil, "BACKGROUND", nil, 0)
    slot.bg:SetAllPoints()
    slot.bg:SetColorTexture(0, 0, 0, 0.65)

    slot.fill = slot:CreateTexture(nil, "ARTWORK", nil, 1)
    slot.fill:SetPoint("TOPLEFT", 1, -1)
    slot.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    slot.fill:SetColorTexture(1, 1, 1, 1)

    st.slots[index] = slot
    return slot
end

function CR.ResetSlotStyle(slot)
    if not slot then return end

    slot.visualState = nil
    slot.renderStyle = nil
    slot.skinKey = nil
    slot.fillMode = nil
    slot.fillReverse = nil
    slot._fillCache = nil

    if slot.bg then
        slot.bg:Show()
        slot.bg:SetAlpha(1)
    end
    if slot.fill then
        slot.fill:Show()
        slot.fill:SetAlpha(1)
        slot.fill:SetTexCoord(0, 1, 0, 1)
        slot.fill:SetColorTexture(1, 1, 1, 1)
        slot.fill:ClearAllPoints()
        slot.fill:SetPoint("TOPLEFT", 1, -1)
        slot.fill:SetPoint("BOTTOMRIGHT", -1, 1)
    end

    if slot.modernBg then
        slot.modernBg:Hide()
    end
    if slot.modernFillClip then
        slot.modernFillClip:Hide()
    end
    if slot.modernFill then
        slot.modernFill:SetAlpha(1)
        slot.modernFill:SetTexCoord(0, 1, 0, 1)
        slot.modernFill:ClearAllPoints()
        slot.modernFill:Hide()
    end
end

function CR.ResetSlotStyles(st)
    if not st or not st.slots then return end
    for i = 1, #st.slots do
        CR.ResetSlotStyle(st.slots[i])
    end
end

local function ApplyModernFillClip(slot, fillMode, reverseFill, skin, visibleWidth)
    local clip = slot.modernFillClip
    local tex = slot.modernFill
    if not clip or not tex then return end

    local insetX = (skin and skin.insetX) or 0
    local insetY = (skin and skin.insetY) or 0
    local slotWidth = tonumber(slot._bpfLayoutWidth) or 0
    local slotHeight = tonumber(slot._bpfLayoutHeight) or 0
    local fullWidth = max(1, floor((slotWidth - (insetX * 2)) + 0.5))
    local fullHeight = max(1, floor((slotHeight - (insetY * 2)) + 0.5))
    local clipWidth = fullWidth

    if fillMode == "PROGRESS" then
        clipWidth = min(fullWidth, max(0, floor((visibleWidth or 0) + 0.5)))
    end

    clip:ClearAllPoints()
    if reverseFill then
        clip:SetPoint("TOPRIGHT", slot, "TOPRIGHT", -insetX, -insetY)
        clip:SetPoint("BOTTOMRIGHT", slot, "BOTTOMRIGHT", -insetX, insetY)
    else
        clip:SetPoint("TOPLEFT", slot, "TOPLEFT", insetX, -insetY)
        clip:SetPoint("BOTTOMLEFT", slot, "BOTTOMLEFT", insetX, insetY)
    end
    clip:SetWidth(clipWidth)

    tex:ClearAllPoints()
    tex:SetSize(fullWidth, fullHeight)
    if reverseFill then
        tex:SetPoint("TOPRIGHT", clip, "TOPRIGHT", 0, 0)
    else
        tex:SetPoint("TOPLEFT", clip, "TOPLEFT", 0, 0)
    end
end

local function ApplyCustomVisual(slot, visualState, reverseFill, opts)
    if visualState == "HIDDEN" then
        if slot.visualState ~= "HIDDEN" or slot:IsShown() then
            slot.bg:Hide()
            slot.fill:Hide()
            if slot.modernBg then slot.modernBg:Hide() end
            if slot.modernFillClip then slot.modernFillClip:Hide() end
            if slot.modernFill then slot.modernFill:Hide() end
            slot:Hide()
        end
        slot.visualState = "HIDDEN"
        slot.renderStyle = CR.STYLE_CUSTOM
        slot.skinKey = nil
        return
    end

    if not slot:IsShown() then slot:Show() end
    if slot.modernBg then slot.modernBg:Hide() end
    if slot.modernFillClip then slot.modernFillClip:Hide() end
    if slot.modernFill then slot.modernFill:Hide() end

    if opts and opts.showBg == false then
        slot.bg:Hide()
    else
        slot.bg:Show()
    end

    if opts and opts.showFill == false then
        slot.fill:Hide()
    else
        if not slot.fill:IsShown() then slot.fill:Show() end
    end

    if opts and opts.fillAlpha ~= nil then
        slot.fill:SetAlpha(opts.fillAlpha)
    end

    if opts and opts.colorR ~= nil and opts.colorG ~= nil and opts.colorB ~= nil then
        slot.fill:SetColorTexture(opts.colorR, opts.colorG, opts.colorB, 1)
    end

    if opts and opts.fillMode then
        CR.SetSlotFillMode(slot, opts.fillMode, reverseFill)
    end

    if opts and opts.fillWidth ~= nil then
        slot.fill:SetWidth(opts.fillWidth)
    end

    slot.visualState = visualState
    slot.renderStyle = CR.STYLE_CUSTOM
    slot.skinKey = nil
end

local function ApplyModernVisual(slot, visualState, reverseFill, opts)
    -- Modern atlas rendering path.
    local skin = opts and opts.skin
    if not skin then
        return ApplyCustomVisual(slot, visualState, reverseFill, opts)
    end

    EnsureModernTextures(slot)

    if visualState == "HIDDEN" then
        slot.bg:Hide()
        slot.fill:Hide()
        slot.modernBg:Hide()
        if slot.modernFillClip then slot.modernFillClip:Hide() end
        slot.modernFill:Hide()
        slot:Hide()
        slot.visualState = "HIDDEN"
        slot.renderStyle = CR.STYLE_MODERN
        slot.skinKey = opts.skinKey
        return
    end

    if not slot:IsShown() then slot:Show() end
    slot.bg:Hide()
    slot.fill:Hide()

    if slot.skinKey ~= opts.skinKey then
        -- Partial recharge resources reveal the same fill atlas through a clipped child frame.
        slot.modernBg:SetAtlas(skin.bgAtlas, true)
        slot.modernFill:SetAtlas((skin.fillAtlas or skin.activeAtlas), true)
        slot.skinKey = opts.skinKey
    end

    if opts and opts.showBg == false then
        slot.modernBg:Hide()
    else
        slot.modernBg:Show()
    end

    if opts and opts.showFill == false then
        if slot.modernFillClip then slot.modernFillClip:Hide() end
        slot.modernFill:Hide()
    else
        if slot.modernFillClip then slot.modernFillClip:Show() end
        slot.modernFill:Show()
    end

    if opts and opts.fillAlpha ~= nil then
        slot.modernFill:SetAlpha(opts.fillAlpha)
    end

    ApplyModernFillClip(slot, opts and opts.fillMode or "FULL", reverseFill, skin, opts and opts.fillWidth)

    slot.visualState = visualState
    slot.renderStyle = CR.STYLE_MODERN
end

function CR.UpdateSlotLayout(holder, st, count, width, height, spacing)
    local totalWidth = (count * width) + ((count - 1) * spacing)
    holder:SetSize(totalWidth, height)

    for i = 1, count do
        local slot = CR.EnsureSlot(holder, st, i)
        slot:ClearAllPoints()
        slot:SetSize(width, height)
        slot._bpfLayoutWidth = width
        slot._bpfLayoutHeight = height
        if i == 1 then
            slot:SetPoint("LEFT", holder, "LEFT", 0, 0)
        else
            slot:SetPoint("LEFT", st.slots[i - 1], "RIGHT", spacing, 0)
        end
        slot:Show()
    end

    for i = count + 1, #st.slots do
        st.slots[i]:Hide()
    end
end

function CR.ApplyAnchor(frame, holder, offX, offY, anchorMode)
    holder:ClearAllPoints()

    local dynamic = (anchorMode == 2)
    local castBar = frame and frame.castBar
    local castShown = dynamic and castBar and castBar:IsShown()

    if castShown then
        holder:SetPoint("TOP", castBar, "BOTTOM", offX, offY)
    else
        holder:SetPoint("TOP", frame.healthBar, "BOTTOM", offX, offY)
    end
end

function CR.ApplySlotVisual(slot, visualState, reverseFill, opts)
    if not slot then return end

    local renderStyle = (opts and opts.renderStyle) or CR.STYLE_CUSTOM
    if renderStyle == CR.STYLE_MODERN then
        return ApplyModernVisual(slot, visualState, reverseFill, opts)
    end

    return ApplyCustomVisual(slot, visualState, reverseFill, opts)
end

function CR.RenderRuneSnapshot(st, count, snapshot, reverseFill, restoringAlpha, renderStyle, powerType)
    local r, g, b = CR.GetRuneColor()
    local order = CR.BuildRuneOrder(st, snapshot)
    local innerWidth = max(1, (st and st.lastWidth or 16) - 2)
    local skin = (renderStyle == CR.STYLE_MODERN) and CR.GetModernSkin(powerType) or nil

    st.runeSnapshot = snapshot
    st.runeDisplayOrder = order

    local hasCooldown = false
    for displayIndex = 1, count do
        local slot = CR.GetVisualSlot(st, count, displayIndex, reverseFill)
        local runeInfo = order[displayIndex]
        local snap = runeInfo and snapshot[runeInfo.index]
        if slot and runeInfo and snap then
            if snap.ready then
                CR.ApplySlotVisual(slot, "ACTIVE", reverseFill, {
                    showBg = true,
                    showFill = true,
                    fillAlpha = 1,
                    colorR = r,
                    colorG = g,
                    colorB = b,
                    fillMode = "FULL",
                    fillWidth = 0,
                    renderStyle = renderStyle,
                    skin = skin,
                    skinKey = CR.GetModernSkinKey and CR.GetModernSkinKey(powerType, skin) or powerType,
                })
            else
                hasCooldown = true
                local fillWidth = floor((innerWidth * snap.progress) + 0.0001)
                CR.ApplySlotVisual(slot, "PARTIAL", reverseFill, {
                    showBg = true,
                    showFill = (fillWidth >= 1),
                    fillAlpha = restoringAlpha or 0.25,
                    colorR = r,
                    colorG = g,
                    colorB = b,
                    fillMode = "PROGRESS",
                    fillWidth = (fillWidth >= 1) and fillWidth or 0,
                    renderStyle = renderStyle,
                    skin = skin,
                    skinKey = CR.GetModernSkinKey and CR.GetModernSkinKey(powerType, skin) or powerType,
                })
            end
        elseif slot then
            CR.ApplySlotVisual(slot, "HIDDEN", reverseFill, {
                renderStyle = renderStyle,
                skin = skin,
                skinKey = CR.GetModernSkinKey and CR.GetModernSkinKey(powerType, skin) or powerType,
            })
        end
    end

    st.runeHasCooldown = hasCooldown
    return hasCooldown
end

function CR.UpdateGeneric(st, count, current, restoringAlpha, showEmpty, reverseFill, partialProgress, innerWidth, powerType, renderStyle)
    st.runeDisplayOrder = nil
    st.runeHasCooldown = false

    count = count or 0
    current = max(0, min(current or 0, count))
    partialProgress = partialProgress or 0
    if partialProgress < 0 then
        partialProgress = 0
    elseif partialProgress > 0.999 then
        partialProgress = 0.999
    end

    local partialIndex = nil
    if partialProgress > 0 and current < count then
        partialIndex = current + 1
    end

    local fullR, fullG, fullB = CR.GetColor(powerType)
    local skin = (renderStyle == CR.STYLE_MODERN) and CR.GetModernSkin(powerType) or nil

    for i = 1, count do
        local slot = CR.GetVisualSlot(st, count, i, reverseFill)
        if slot then
            if i <= current then
                CR.ApplySlotVisual(slot, "ACTIVE", reverseFill, {
                    showBg = true,
                    showFill = true,
                    fillAlpha = 1,
                    colorR = fullR,
                    colorG = fullG,
                    colorB = fullB,
                    fillMode = "FULL",
                    renderStyle = renderStyle,
                    skin = skin,
                    skinKey = CR.GetModernSkinKey and CR.GetModernSkinKey(powerType, skin) or powerType,
                })
            elseif partialIndex and i == partialIndex then
                CR.ApplySlotVisual(slot, "PARTIAL", reverseFill, {
                    showBg = true,
                    showFill = true,
                    fillAlpha = restoringAlpha,
                    colorR = fullR,
                    colorG = fullG,
                    colorB = fullB,
                    fillMode = "PROGRESS",
                    fillWidth = max(1, (innerWidth or 1) * partialProgress),
                    renderStyle = renderStyle,
                    skin = skin,
                    skinKey = CR.GetModernSkinKey and CR.GetModernSkinKey(powerType, skin) or powerType,
                })
            elseif showEmpty then
                CR.ApplySlotVisual(slot, "INACTIVE", reverseFill, {
                    showBg = true,
                    showFill = false,
                    fillAlpha = 0,
                    fillMode = "FULL",
                    fillWidth = 0,
                    renderStyle = renderStyle,
                    skin = skin,
                    skinKey = CR.GetModernSkinKey and CR.GetModernSkinKey(powerType, skin) or powerType,
                })
            else
                CR.ApplySlotVisual(slot, "HIDDEN", reverseFill, {
                    renderStyle = renderStyle,
                    skin = skin,
                    skinKey = CR.GetModernSkinKey and CR.GetModernSkinKey(powerType, skin) or powerType,
                })
            end
        end
    end
end
