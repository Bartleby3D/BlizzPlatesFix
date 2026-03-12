local _, NS = ...

local State = setmetatable({}, { __mode = "k" })
local QuestCache = {}

local EnumLineType = Enum and Enum.TooltipDataLineType or nil
local LINE_QUEST_OBJECTIVE = EnumLineType and EnumLineType.QuestObjective or nil
local LINE_QUEST_TITLE = EnumLineType and EnumLineType.QuestTitle or nil
local LINE_QUEST_PLAYER = EnumLineType and EnumLineType.QuestPlayer or nil
local PLAYER_NAME = UnitName and UnitName("player") or nil
local QUEST_ATLAS = "QuestNormal"

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        lastVisible = nil,
        lastSize = nil,
        lastX = nil,
        lastY = nil,
        lastParent = nil,
    }
    State[frame] = st
    return st
end

local function ClearQuestCache(unit)
    if unit then
        QuestCache[unit] = nil
        return
    end
    for k in pairs(QuestCache) do
        QuestCache[k] = nil
    end
end

local function IsQuestObjectiveLineOpen(text)
    if type(text) ~= "string" or text == "" then return false end

    local a, b = text:match("(%d+)%s*/%s*(%d+)")
    if a and b then
        return tonumber(a) ~= tonumber(b)
    end

    local pct = text:match("(%d+)%%")
    if pct then
        return tonumber(pct) ~= 100
    end

    return false
end

local function HasQuestObjective(unit)
    if not unit then return false end

    local cached = QuestCache[unit]
    if cached ~= nil then
        return cached
    end

    if UnitIsPlayer(unit) then
        QuestCache[unit] = false
        return false
    end

    if C_Secrets and C_Secrets.ShouldUnitIdentityBeSecret and C_Secrets.ShouldUnitIdentityBeSecret(unit) then
        QuestCache[unit] = false
        return false
    end

    if not (C_TooltipInfo and C_TooltipInfo.GetUnit and LINE_QUEST_OBJECTIVE and LINE_QUEST_TITLE and LINE_QUEST_PLAYER) then
        QuestCache[unit] = false
        return false
    end

    local info = C_TooltipInfo.GetUnit(unit)
    if not info or type(info.lines) ~= "table" then
        QuestCache[unit] = false
        return false
    end

    local hasOpenObjective = false
    local ignoreUntilTitle = false

    for _, line in ipairs(info.lines) do
        local ltype = line and line.type
        if not ignoreUntilTitle and ltype == LINE_QUEST_OBJECTIVE then
            if IsQuestObjectiveLineOpen(line.leftText) then
                hasOpenObjective = true
                break
            end
        elseif ltype == LINE_QUEST_TITLE then
            ignoreUntilTitle = false
        elseif ltype == LINE_QUEST_PLAYER then
            local owner = line.leftText
            if PLAYER_NAME and owner == PLAYER_NAME then
                ignoreUntilTitle = false
            else
                ignoreUntilTitle = true
            end
        end
    end

    QuestCache[unit] = hasOpenObjective and true or false
    return QuestCache[unit]
end

local function GetIcon(frame)
    local parent = frame
    if not frame.BPF_QuestIcon then
        frame.BPF_QuestIcon = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.BPF_QuestIcon:SetDrawLayer("OVERLAY", 7)
        frame.BPF_QuestIcon:SetAtlas(QUEST_ATLAS)
        frame.BPF_QuestIcon:Hide()
    else
        if frame.BPF_QuestIcon:GetParent() ~= parent then
            frame.BPF_QuestIcon:SetParent(parent)
        end
        frame.BPF_QuestIcon:SetDrawLayer("OVERLAY", 7)
        frame.BPF_QuestIcon:SetAtlas(QUEST_ATLAS)
    end
    return frame.BPF_QuestIcon
end

local function Hide(frame, st)
    local icon = frame and frame.BPF_QuestIcon
    if icon and st.lastVisible ~= false then
        icon:Hide()
        st.lastVisible = false
    end
end

local function Update(frame, unit, dbUnit, dbGlobal)
    if not frame or frame:IsForbidden() then return end
    if not dbGlobal then return end

    local st = GetState(frame)

    if not dbGlobal.questIconEnabled then
        Hide(frame, st)
        return
    end

    if not unit or UnitIsPlayer(unit) then
        Hide(frame, st)
        return
    end

    if not HasQuestObjective(unit) then
        Hide(frame, st)
        return
    end

    local icon = GetIcon(frame)

    if st.lastVisible ~= true then
        icon:Show()
        st.lastVisible = true
    end

    local size = dbGlobal.questIconSize or 18
    if st.lastSize ~= size then
        icon:SetSize(size, size)
        st.lastSize = size
    end

    local offX = dbGlobal.questIconX or 0
    local offY = dbGlobal.questIconY or 16
    if st.lastX ~= offX or st.lastY ~= offY then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", frame.healthBar, "CENTER", offX, offY)
        st.lastX, st.lastY = offX, offY
    end
end

local EventFrame = CreateFrame("Frame")
EventFrame:RegisterEvent("NAME_PLATE_UNIT_REMOVED")
EventFrame:RegisterEvent("QUEST_LOG_UPDATE")
EventFrame:RegisterEvent("PLAYER_ENTERING_WORLD")
EventFrame:RegisterEvent("ZONE_CHANGED_NEW_AREA")
EventFrame:SetScript("OnEvent", function(_, event, arg1)
    if event == "NAME_PLATE_UNIT_REMOVED" then
        ClearQuestCache(arg1)
        return
    end

    ClearQuestCache()
    if NS.RequestUpdateAll then
        NS.RequestUpdateAll("quest_icon:" .. event, false, NS.REASON_QUEST or 1024)
    elseif NS.ForceUpdateAll then
        NS.ForceUpdateAll()
    end
end)

NS.Modules.QuestIcon = {
    Update = Update,
    Reset = function(frame)
        if frame and frame.BPF_QuestIcon then
            frame.BPF_QuestIcon:Hide()
        end
        local st = State[frame]
        if st then
            st.lastVisible = nil
            st.lastSize = nil
            st.lastX = nil
            st.lastY = nil
            st.lastParent = nil
        end
    end,
}
