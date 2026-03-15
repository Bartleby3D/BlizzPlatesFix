local _, NS = ...

local State = setmetatable({}, { __mode = "k" })

local STYLE_CLASSIC = 1
local STYLE_SYMBOLS = 2
local STYLE_MODERN = 3

local ATLAS_BY_STYLE = {
    [STYLE_CLASSIC] = {
        Alliance = "poi-alliance",
        Horde = "poi-horde",
    },
    [STYLE_SYMBOLS] = {
        Alliance = "AllianceSymbol",
        Horde = "HordeSymbol",
    },
    [STYLE_MODERN] = {
        Alliance = "questlog-questtypeicon-alliance",
        Horde = "questlog-questtypeicon-horde",
    },
}

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        inited = false,
        lastVisible = nil,
        lastFaction = nil,
        lastStyle = nil,
        lastSize = nil,
        lastX = nil,
        lastY = nil,
        lastAlpha = nil,
        lastAnchor = nil,
        lastFrameLevel = nil,
        lastFrameStrata = nil,
    }
    State[frame] = st
    return st
end

local function EnsureObjects(frame)
    local st = GetState(frame)
    if st.inited and frame.BPF_FactionIconFrame and frame.BPF_FactionIconFrame.Icon then
        return st, frame.BPF_FactionIconFrame, frame.BPF_FactionIconFrame.Icon
    end

    local holder = CreateFrame("Frame", nil, frame)
    holder:Hide()
    holder:SetClampedToScreen(false)
    holder:SetIgnoreParentScale(false)

    local icon = holder:CreateTexture(nil, "OVERLAY", nil, 7)
    icon:SetAllPoints()
    icon:Hide()

    frame.BPF_FactionIconFrame = holder
    holder.Icon = icon

    st.inited = true
    return st, holder, icon
end

local function HideCustom(frame, st)
    local holder = frame and frame.BPF_FactionIconFrame
    if holder then holder:Hide() end
    if holder and holder.Icon then holder.Icon:Hide() end
    if st then st.lastVisible = false end
end

local function GetFactionAndAtlas(unit, style)
    local faction = UnitFactionGroup(unit)
    if faction ~= "Alliance" and faction ~= "Horde" then
        return nil, nil
    end

    local atlasSet = ATLAS_BY_STYLE[style] or ATLAS_BY_STYLE[STYLE_MODERN]
    return faction, atlasSet and atlasSet[faction] or nil
end

local function Update(frame, unit, dbUnit, dbGlobal)
    if not frame or frame:IsForbidden() then return end
    if not dbGlobal then return end
    if not frame.healthBar then return end

    local st, holder, icon = EnsureObjects(frame)
    if not holder or not icon then return end

    if not dbGlobal.factionIconEnabled then
        HideCustom(frame, st)
        st.lastFaction = nil
        st.lastStyle = nil
        return
    end

    if dbGlobal.factionIconOnlyPlayers and not UnitIsPlayer(unit) then
        HideCustom(frame, st)
        st.lastFaction = nil
        st.lastStyle = nil
        return
    end

    local style = tonumber(dbGlobal.factionIconStyle) or STYLE_MODERN
    local faction, atlas = GetFactionAndAtlas(unit, style)
    if not atlas then
        HideCustom(frame, st)
        st.lastFaction = nil
        st.lastStyle = nil
        return
    end

    if st.lastFaction ~= faction or st.lastStyle ~= style then
        icon:SetAtlas(atlas, true)
        st.lastFaction = faction
        st.lastStyle = style
    end

    local size = dbGlobal.factionIconSize or 14
    if st.lastSize ~= size then
        holder:SetSize(size, size)
        st.lastSize = size
    end

    local offX = dbGlobal.factionIconX or 0
    local offY = dbGlobal.factionIconY or 0
    local anchor = dbGlobal.factionIconAnchor or "HpBar"
    if st.lastX ~= offX or st.lastY ~= offY or st.lastAnchor ~= anchor then
        st.lastAnchor = NS.ApplyStatusIconAnchor(holder, frame, anchor, offX, offY)
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

    local alpha = dbGlobal.factionIconAlpha
    if alpha == nil then alpha = 1 end
    if st.lastAlpha ~= alpha then
        holder:SetAlpha(alpha)
        st.lastAlpha = alpha
    end

    if st.lastVisible ~= true then
        holder:Show()
        icon:Show()
        st.lastVisible = true
    end
end

NS.Modules.FactionIcon = {
    Init = function(frame)
        if frame and not frame:IsForbidden() then
            EnsureObjects(frame)
        end
    end,
    Update = Update,
    Reset = function(frame)
        if frame and frame.BPF_FactionIconFrame then
            frame.BPF_FactionIconFrame:Hide()
            if frame.BPF_FactionIconFrame.Icon then
                frame.BPF_FactionIconFrame.Icon:Hide()
            end
        end

        local st = State[frame]
        if st then
            st.inited = nil
            st.lastVisible = nil
            st.lastFaction = nil
            st.lastStyle = nil
            st.lastSize = nil
            st.lastX = nil
            st.lastY = nil
            st.lastAlpha = nil
            st.lastAnchor = nil
            st.lastFrameLevel = nil
            st.lastFrameStrata = nil
        end
    end,
}
