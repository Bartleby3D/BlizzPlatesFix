local _, NS = ...

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end

    st = {
        inited = false,
        lastVisible = nil,
        lastSize = nil,
        lastX = nil,
        lastY = nil,
        lastAlpha = nil,
        lastAnchor = nil,
        lastHealthBar = nil,
        lastFrameLevel = nil,
        lastFrameStrata = nil,
    }

    State[frame] = st
    return st
end


local function EnsureObjects(frame)
    local st = GetState(frame)
    if st.inited and frame.BPF_RaidTargetFrame and frame.BPF_RaidTargetFrame.Icon then
        return st
    end

    local holder = CreateFrame("Frame", nil, frame)
    holder:Hide()
    holder:SetClampedToScreen(false)
    holder:SetIgnoreParentScale(false)

    local icon = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetAllPoints()
    icon:SetTexture("Interface\\TargetingFrame\\UI-RaidTargetingIcons")
    icon:Hide()

    frame.BPF_RaidTargetFrame = holder
    holder.Icon = icon

    st.inited = true
    return st
end


local function HideCustom(frame, st)
    if frame and frame.BPF_RaidTargetFrame then
        frame.BPF_RaidTargetFrame:Hide()
    end
    if frame and frame.BPF_RaidTargetFrame and frame.BPF_RaidTargetFrame.Icon then
        frame.BPF_RaidTargetFrame.Icon:Hide()
    end

    if st then
        st.lastVisible = false
    end
end

local function HideNativeIcon(frame)
    local native = frame and frame.RaidTargetFrame and frame.RaidTargetFrame.RaidTargetIcon
    if not native then
        native = frame and frame.RaidTargetIcon
    end
    if native and native.Hide then
        native:Hide()
    end
end

local function SetIconTexture(icon, index)
    if not icon or not index then return end
    if SetRaidTargetIconTexture then
        SetRaidTargetIconTexture(icon, index)
    end
end

local function Update(frame, unit, dbUnit, dbGlobal)
    if not frame or frame:IsForbidden() then return end
    if not frame.healthBar then return end
    if not dbGlobal then return end

    local st = EnsureObjects(frame)
    local holder = frame.BPF_RaidTargetFrame
    local icon = holder and holder.Icon
    if not holder or not icon then return end

    if not dbGlobal.raidTargetIconEnabled then
        HideNativeIcon(frame)
        HideCustom(frame, st)
        st.lastSize = nil
        st.lastX = nil
        st.lastY = nil
        st.lastAlpha = nil
        st.lastAnchor = nil
        st.lastHealthBar = nil
        st.lastFrameLevel = nil
        st.lastFrameStrata = nil
        return
    end

    unit = unit or frame.unit or frame.displayedUnit or frame.unitToken or frame.namePlateUnitToken
    if not unit then
        HideNativeIcon(frame)
        HideCustom(frame, st)
        return
    end

    local index = GetRaidTargetIndex and GetRaidTargetIndex(unit) or nil
    if not index then
        HideNativeIcon(frame)
        HideCustom(frame, st)
        return
    end

    HideNativeIcon(frame)

    local size = dbGlobal.raidTargetIconSize or 20
    if st.lastSize ~= size then
        holder:SetSize(size, size)
        st.lastSize = size
    end

    local offX = dbGlobal.raidTargetIconX or 0
    local offY = dbGlobal.raidTargetIconY or 0
    local anchor = dbGlobal.raidTargetIconAnchor or "HpBar"
    if st.lastHealthBar ~= frame.healthBar or st.lastX ~= offX or st.lastY ~= offY or st.lastAnchor ~= anchor then
        st.lastAnchor = NS.ApplyStatusIconAnchor(holder, frame, anchor, offX, offY)
        st.lastHealthBar = frame.healthBar
        st.lastX, st.lastY = offX, offY
    end

    local healthBar = frame.healthBar
    local strata = healthBar:GetFrameStrata()
    local level = (healthBar:GetFrameLevel() or 0) + 25
    if st.lastFrameStrata ~= strata then
        holder:SetFrameStrata(strata)
        st.lastFrameStrata = strata
    end
    if st.lastFrameLevel ~= level then
        holder:SetFrameLevel(level)
        st.lastFrameLevel = level
    end

    local alpha = dbGlobal.raidTargetIconAlpha
    if alpha == nil then alpha = 1 end
    if st.lastAlpha ~= alpha then
        holder:SetAlpha(alpha)
        st.lastAlpha = alpha
    end

    SetIconTexture(icon, index)

    if st.lastVisible ~= true then
        holder:Show()
        icon:Show()
        st.lastVisible = true
    end
end

local function Reset(frame)
    if not frame then return end
    local st = State[frame]
    if not st then
        if frame.BPF_RaidTargetFrame then
            HideNativeIcon(frame)
            frame.BPF_RaidTargetFrame:Hide()
        end
        return
    end

    HideNativeIcon(frame)
    HideCustom(frame, st)
    st.lastVisible = nil
    st.lastSize = nil
    st.lastX = nil
    st.lastY = nil
    st.lastAlpha = nil
    st.lastAnchor = nil
    st.lastHealthBar = nil
    st.lastFrameLevel = nil
    st.lastFrameStrata = nil
end

NS.Modules.RaidTargetIcon = {
    Init = function(frame)
        if frame and not frame:IsForbidden() then
            EnsureObjects(frame)
        end
    end,
    Update = Update,
    Reset = Reset,
}

