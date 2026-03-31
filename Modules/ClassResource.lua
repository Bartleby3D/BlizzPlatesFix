local _, NS = ...

local CR = NS.ClassResourceInternal
if not CR then return end

local max = CR.max

local function EnsureFastTaskRegistered()
    if CR.RuneTaskRegistered then return end
    if not (NS.Engine and NS.Engine.RegisterFastTask and NS.Engine.EnableFastTask) then return end

    NS.Engine.RegisterFastTask("classresource_runes", 0.1, function()
        if not CR.ActiveRuneFrame or CR.ActiveRuneFrame:IsForbidden() then
            CR.ClearActiveRuneTarget()
            return
        end

        local frame = CR.ActiveRuneFrame
        local st = CR.ActiveRuneState or CR.GetState(frame)
        local holder = frame.BPF_ClassResourceHolder

        if not holder or not holder:IsShown() or not frame.unit or not UnitIsUnit(frame.unit, "target") then
            CR.ClearActiveRuneTarget(frame)
            return
        end

        local powerType, _, maxPower = CR.GetPlayerResource(st)
        if powerType ~= CR.POWER_RUNES or not maxPower or maxPower <= 0 then
            CR.ClearActiveRuneTarget(frame)
            return
        end

        if not st.lastWidth or st.lastCount ~= maxPower then
            local gdb = NS.Config and NS.Config.GetTable and NS.Config.GetTable("Global")
            local dbUnit = NS.GetUnitConfig and NS.GetUnitConfig(frame.unit)
            CR.Update(frame, "target", dbUnit, gdb)
            return
        end

        local snapshot = CR.CollectRuneSnapshot(maxPower)
        CR.RenderRuneSnapshot(st, maxPower, snapshot, st.lastReverseFill == true, st.lastInactiveAlpha ~= nil and st.lastInactiveAlpha or 0.25, st.lastRenderStyle or CR.STYLE_CUSTOM, powerType)
    end)

    NS.Engine.EnableFastTask("classresource_runes", false)
    CR.RuneTaskRegistered = true
end

local function EnsureDynamicTaskRegistered()
    if CR.TimedTaskRegistered then return end
    if not (NS.Engine and NS.Engine.RegisterFastTask and NS.Engine.EnableFastTask) then return end

    NS.Engine.RegisterFastTask("classresource_dynamic", 0.1, function()
        if not CR.ActiveTimedFrame or CR.ActiveTimedFrame:IsForbidden() then
            CR.ClearActiveTimedTarget()
            return
        end

        local frame = CR.ActiveTimedFrame
        local st = CR.ActiveTimedState or CR.GetState(frame)
        local holder = frame.BPF_ClassResourceHolder

        if not holder or not holder:IsShown() or not frame.unit or not UnitIsUnit(frame.unit, "target") then
            CR.ClearActiveTimedTarget(frame)
            return
        end

        local gdb = NS.Config and NS.Config.GetTable and NS.Config.GetTable("Global")
        if not gdb or gdb.classResourceEnabled ~= true then
            CR.ClearActiveTimedTarget(frame)
            return
        end

        local powerType, current, maxPower, partialProgress = CR.GetPlayerResource(st)
        if not powerType or powerType == CR.POWER_RUNES or not maxPower or maxPower <= 0 then
            CR.ClearActiveTimedTarget(frame)
            return
        end

        local needsPolling = CR.NeedsDynamicPolling(powerType, current, maxPower, partialProgress)
        if not needsPolling then
            local dbUnit = NS.GetUnitConfig and NS.GetUnitConfig(frame.unit)
            CR.Update(frame, "target", dbUnit, gdb)
            CR.ClearActiveTimedTarget(frame)
            return
        end

        if st.lastResource ~= powerType or st.lastCount ~= maxPower or not st.lastWidth then
            local dbUnit = NS.GetUnitConfig and NS.GetUnitConfig(frame.unit)
            CR.Update(frame, "target", dbUnit, gdb)
            return
        end

        CR.UpdateGeneric(
            st,
            maxPower,
            current,
            st.lastInactiveAlpha ~= nil and st.lastInactiveAlpha or 0.25,
            st.lastShowEmpty ~= false,
            st.lastReverseFill == true,
            partialProgress,
            st.lastInnerWidth or max(1, ((st.lastLayoutWidth or st.lastWidth or 16) - 2)),
            powerType,
            st.lastRenderStyle or CR.STYLE_CUSTOM
        )

        holder:Show()
        st.lastShown = true
        st.lastResource = powerType
        st.lastCount = maxPower
        st.lastMax = maxPower
    end)

    NS.Engine.EnableFastTask("classresource_dynamic", false)
    CR.TimedTaskRegistered = true
end

local function UpdateRunes(frame, st, count, reverseFill, restoringAlpha, renderStyle, powerType)
    local snapshot = CR.CollectRuneSnapshot(count)
    CR.RenderRuneSnapshot(st, count, snapshot, reverseFill, restoringAlpha, renderStyle or st.lastRenderStyle or CR.STYLE_CUSTOM, powerType or CR.POWER_RUNES)

    -- Keep the rune task active while the rune bar is shown.
    CR.ActiveRuneFrame = frame
    CR.ActiveRuneState = st
    EnsureFastTaskRegistered()
    if NS.Engine and NS.Engine.EnableFastTask then
        NS.Engine.EnableFastTask("classresource_runes", true)
    end
end

function CR.Update(frame, unit, db, gdb)
    if not frame or frame:IsForbidden() or not frame.healthBar then return end

    if not gdb or gdb.classResourceEnabled ~= true or not unit or not UnitIsUnit(unit, "target") then
        if frame.BPF_ClassResourceHolder then
            CR.HideAll(frame, CR.GetState(frame))
        end
        return
    end

    if gdb.classResourceOnlyInCombat and not UnitAffectingCombat("player") then
        if frame.BPF_ClassResourceHolder then
            CR.HideAll(frame, CR.GetState(frame))
        end
        return
    end

    if gdb.classResourceHideOnTransport == true and ((IsMounted and IsMounted()) or (UnitInVehicle and UnitInVehicle("player"))) then
        if frame.BPF_ClassResourceHolder then
            CR.HideAll(frame, CR.GetState(frame))
        end
        return
    end

    local st = CR.GetState(frame)
    local powerType, current, maxPower, partialProgress = CR.GetPlayerResource(st)
    if not powerType or not maxPower or maxPower <= 0 then
        if frame.BPF_ClassResourceHolder then
            CR.HideAll(frame, CR.GetState(frame))
        end
        return
    end

    st = CR.EnsureHolder(frame)
    local holder = frame.BPF_ClassResourceHolder
    EnsureFastTaskRegistered()
    EnsureDynamicTaskRegistered()

    local style = CR.GetConfiguredStyle(gdb)
    local renderStyle = CR.GetEffectiveRenderStyle(style, powerType)

    local width, height, spacing, offX, offY, restoringAlpha, showEmpty, reverseFill
    local anchorMode = tonumber(gdb.classResourceAnchorMode) or 1
    if style == CR.STYLE_MODERN then
        local modernScale = tonumber(gdb.classResourceModernScale) or 1
        if modernScale < 0.5 then modernScale = 0.5 elseif modernScale > 3 then modernScale = 3 end

        local skin = CR.GetModernSkin(powerType)
        local baseWidth = (skin and tonumber(skin.baseWidth)) or 18
        local baseHeight = (skin and tonumber(skin.baseHeight)) or 18
        local baseSpacing = tonumber(gdb.classResourceModernSpacing) or 4

        width = math.max(6, math.floor((baseWidth * modernScale) + 0.5))
        height = math.max(6, math.floor((baseHeight * modernScale) + 0.5))
        spacing = math.max(0, math.floor((baseSpacing * modernScale) + 0.5))
        offX = tonumber(gdb.classResourceModernOffsetX) or 0
        offY = tonumber(gdb.classResourceModernOffsetY) or -16
        restoringAlpha = tonumber(gdb.classResourceModernInactiveAlpha)
        if not restoringAlpha then restoringAlpha = 0.35 end
        showEmpty = (gdb.classResourceShowEmpty ~= false)
        reverseFill = (gdb.classResourceReverseFill == true)
    else
        width = math.max(6, tonumber(gdb.classResourceWidth) or 16)
        height = math.max(4, tonumber(gdb.classResourceHeight) or 8)
        spacing = math.max(0, tonumber(gdb.classResourceSpacing) or 3)
        offX = tonumber(gdb.classResourceOffsetX) or 0
        offY = tonumber(gdb.classResourceOffsetY) or -14
        restoringAlpha = tonumber(gdb.classResourceInactiveAlpha)
        if not restoringAlpha then restoringAlpha = 0.25 end
        showEmpty = (gdb.classResourceShowEmpty ~= false)
        reverseFill = (gdb.classResourceReverseFill == true)
    end
    if restoringAlpha < 0 then restoringAlpha = 0 elseif restoringAlpha > 1 then restoringAlpha = 1 end

    if st.lastStyle ~= style or st.lastRenderStyle ~= renderStyle then
        CR.ResetSlotStyles(st)
        st.lastColorKey = nil
    end
    st.lastStyle = style
    st.lastRenderStyle = renderStyle
    st.lastReverseFill = reverseFill

    local layoutChanged = (st.lastWidth ~= width or st.lastHeight ~= height or st.lastSpacing ~= spacing or st.lastCount ~= maxPower)
    if layoutChanged then
        CR.UpdateSlotLayout(holder, st, maxPower, width, height, spacing, renderStyle)
        st.lastWidth = width
        st.lastHeight = height
        st.lastSpacing = spacing
    end

    local castShown = (anchorMode == 2) and frame.castBar and frame.castBar:IsShown() or false
    if st.lastOffX ~= offX or st.lastOffY ~= offY or st.lastAnchorMode ~= anchorMode or st.lastAnchorCastShown ~= castShown then
        CR.ApplyAnchor(frame, holder, offX, offY, anchorMode, renderStyle)
        st.lastOffX = offX
        st.lastOffY = offY
        st.lastAnchorMode = anchorMode
        st.lastAnchorCastShown = castShown
    end

    if renderStyle == CR.STYLE_CUSTOM and powerType ~= CR.POWER_RUNES and (st.lastColorKey ~= powerType or layoutChanged) then
        local r, g, b = CR.GetColor(powerType)
        for i = 1, maxPower do
            local slot = CR.EnsureSlot(holder, st, i)
            slot.fill:SetColorTexture(r, g, b, 1)
        end
        st.lastColorKey = powerType
    elseif renderStyle ~= CR.STYLE_CUSTOM then
        st.lastColorKey = nil
    elseif powerType == CR.POWER_RUNES then
        st.lastColorKey = powerType
    end

    if powerType == CR.POWER_RUNES then
        CR.ClearActiveTimedTarget(frame)
        st.dynamicActive = false
        UpdateRunes(frame, st, maxPower, reverseFill, restoringAlpha, renderStyle, powerType)
    else
        CR.ClearActiveRuneTarget(frame)
        CR.UpdateGeneric(st, maxPower, current, restoringAlpha, showEmpty, reverseFill, partialProgress, st.lastInnerWidth or max(1, ((st.lastLayoutWidth or width) - 2)), powerType, renderStyle)

        local needsDynamic = CR.NeedsDynamicPolling(powerType, current, maxPower, partialProgress)

        st.dynamicActive = needsDynamic
        if needsDynamic then
            CR.ActiveTimedFrame = frame
            CR.ActiveTimedState = st
            if NS.Engine and NS.Engine.EnableFastTask then
                NS.Engine.EnableFastTask("classresource_dynamic", true)
            end
        else
            CR.ClearActiveTimedTarget(frame)
        end
    end

    holder:Show()
    st.lastShown = true
    st.lastResource = powerType
    st.lastCount = maxPower
    st.lastMax = maxPower
    st.lastShowEmpty = showEmpty
    st.lastInactiveAlpha = restoringAlpha
    st.lastStyle = style
    st.lastRenderStyle = renderStyle
end

local function Reset(frame)
    CR.HideAll(frame, CR.GetState(frame))
end

NS.Modules.ClassResource = {
    Update = CR.Update,
    Reset = Reset,
}
