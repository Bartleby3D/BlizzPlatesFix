local _, NS = ...

local State = setmetatable({}, { __mode = "k" })

local TEX_ALLIANCE = "Interface\\TargetingFrame\\UI-PVP-ALLIANCE"
local TEX_HORDE    = "Interface\\TargetingFrame\\UI-PVP-HORDE"

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        lastVisible = nil,
        lastFaction = nil,
        lastSize = nil,        lastX = nil,
        lastY = nil,
        lastParent = nil,
    }
    State[frame] = st
    return st
end

local function GetIcon(frame)
    local parent = frame -- Отвязываем логического родителя от healthBar
    if not frame.BPF_FactionIcon then
        frame.BPF_FactionIcon = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.BPF_FactionIcon:SetDrawLayer("OVERLAY", 7)
        frame.BPF_FactionIcon:Hide()
    else
        if frame.BPF_FactionIcon:GetParent() ~= parent then
            frame.BPF_FactionIcon:SetParent(parent)
        end
        frame.BPF_FactionIcon:SetDrawLayer("OVERLAY", 7)
    end
    return frame.BPF_FactionIcon, parent
end

local function GetFactionTexture(unit)
    local faction = UnitFactionGroup(unit)
    if faction == "Alliance" then
        return faction, TEX_ALLIANCE
    elseif faction == "Horde" then
        return faction, TEX_HORDE
    end
    return nil, nil
end

local function Update(frame, unit, dbUnit, dbGlobal)
    if not frame or frame:IsForbidden() then return end
    if not dbGlobal then return end

    local st = GetState(frame)
    local icon = GetIcon(frame)

    if not dbGlobal.factionIconEnabled then
        if st.lastVisible ~= false then
            icon:Hide()
            st.lastVisible = false
        end
        return
    end

    if dbGlobal.factionIconOnlyPlayers and not UnitIsPlayer(unit) then
        if st.lastVisible ~= false then
            icon:Hide()
            st.lastVisible = false
        end
        return
    end

    local faction, tex = GetFactionTexture(unit)
    if not tex then
        if st.lastVisible ~= false then
            icon:Hide()
            st.lastVisible = false
        end
        st.lastFaction = nil
        return
    end

    if st.lastVisible ~= true then
        icon:Show()
        st.lastVisible = true
    end

    if st.lastFaction ~= faction then
        icon:SetTexture(tex)
        st.lastFaction = faction
    end

    local size = dbGlobal.factionIconSize or 14
    if st.lastSize ~= size then
        icon:SetSize(size, size)
        st.lastSize = size
    end

    local offX = dbGlobal.factionIconX or 0
    local offY = dbGlobal.factionIconY or 0
    if st.lastX ~= offX or st.lastY ~= offY then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", frame.healthBar, "CENTER", offX, offY)
        st.lastX, st.lastY = offX, offY
    end

end

NS.Modules.FactionIcon = {
    Update = Update,
    Reset = function(frame)
        if frame and frame.BPF_FactionIcon then
            frame.BPF_FactionIcon:Hide()
        end
        
        -- Обязательно сбрасываем кэш состояний
        local st = State[frame]
        if st then
            st.lastVisible = nil
            st.lastFaction = nil
            st.lastSize = nil
            st.lastX = nil
            st.lastY = nil
            st.lastParent = nil
        end
    end,
}