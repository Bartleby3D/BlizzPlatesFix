local _, NS = ...

local HiddenPool = CreateFrame("Frame")
HiddenPool:Hide()

local State = setmetatable({}, { __mode = "k" })

local function GetState(frame)
    local st = State[frame]
    if st then return st end
    st = {
        hiddenBlizz = false,
        lastVisible = nil,
        lastAtlas = nil,
        lastSize = nil,
        lastX = nil,
        lastY = nil,
        lastMirror = nil,
        lastBlizzShown = nil,
    }
    State[frame] = st
    return st
end

local function GetMyIcon(frame)
    local parent = frame -- Отвязываем логического родителя от healthBar
    if not frame.BPF_ClassIcon then
        frame.BPF_ClassIcon = parent:CreateTexture(nil, "OVERLAY", nil, 7)
        frame.BPF_ClassIcon:SetDrawLayer("OVERLAY", 7)
    else
        if frame.BPF_ClassIcon:GetParent() ~= parent then
            frame.BPF_ClassIcon:SetParent(parent)
        end
        frame.BPF_ClassIcon:SetDrawLayer("OVERLAY", 7)
    end
    return frame.BPF_ClassIcon
end

local function UpdateIcon(frame, unit, db, gdb)
    if not frame or frame:IsForbidden() then return end
    
    -- ВАЖНО: Настройки иконок у нас в GLOBAL (gdb), согласно твоей Database.lua
    if not gdb then return end

    local st = GetState(frame)

    -- Скрытие стандарта
    if not st.hiddenBlizz and frame.ClassificationFrame then
        frame.ClassificationFrame:SetParent(HiddenPool)
        frame.ClassificationFrame:Hide()
        st.hiddenBlizz = true
    end

    local icon = GetMyIcon(frame)

    if not gdb.classifEnabled then
        if st.lastVisible ~= false then
            icon:Hide()
            st.lastVisible = false
        end
        return
    end

    local blizzName = frame.name or (frame.UnitFrame and frame.UnitFrame.name)
    local blizzShown = (not blizzName) or blizzName:IsShown()

    if st.lastBlizzShown ~= blizzShown then
        st.lastBlizzShown = blizzShown
    end
    if not blizzShown then
        if st.lastVisible ~= false then
            icon:Hide()
            st.lastVisible = false
        end
        return
    end

    if gdb.classifHideAllies and UnitIsFriend("player", unit) then
        if st.lastVisible ~= false then
            icon:Hide()
            st.lastVisible = false
        end
        return
    end

    local classif = UnitClassification(unit)
    local level = UnitEffectiveLevel(unit)
    local playerLevel = UnitEffectiveLevel("player")

    local inInstance, instanceType = IsInInstance()
    local plus2Boss = false
    if inInstance and instanceType == "party" and level and playerLevel then
        plus2Boss = (level >= playerLevel + 2)
    end

    local isBoss = (UnitIsBossMob and UnitIsBossMob(unit)) or (classif == "worldboss") or (level == -1) or plus2Boss
    local isRareElite = (classif == "rareelite")
    local isRare = (classif == "rare")
    local isElite = (classif == "elite")

    if gdb.classifShowBossRareOnly then
        if isElite and not (isBoss or isRareElite or isRare) then
            if st.lastVisible ~= false then
                icon:Hide()
                st.lastVisible = false
            end
            return
        end
    end

    if not (isBoss or isRareElite or isRare or isElite) then
        if st.lastVisible ~= false then
            icon:Hide()
            st.lastVisible = false
        end
        return
    end

    local atlas
    local bossSizeMult = 1.0

    if isBoss then
        atlas = "worldquest-icon-boss"
        bossSizeMult = 1.1
    elseif isRareElite then
        atlas = "nameplates-icon-elite-silver"
    elseif isRare then
        atlas = "UI-HUD-UnitFrame-Target-PortraitOn-Boss-Rare-Star"
    elseif isElite then
        atlas = "nameplates-icon-elite-gold"
    end

    if not atlas then
        if st.lastVisible ~= false then
            icon:Hide()
            st.lastVisible = false
        end
        return
    end

    if st.lastVisible ~= true then
        icon:Show()
        st.lastVisible = true
    end

    if st.lastAtlas ~= atlas then
        icon:SetAtlas(atlas)
        st.lastAtlas = atlas
    end

    local size = 16 * (gdb.classifScale or 1) * bossSizeMult
    if st.lastSize ~= size then
        icon:SetSize(size, size)
        st.lastSize = size
    end

    local offX = gdb.classifX or 0
    local offY = gdb.classifY or 0
    if st.lastX ~= offX or st.lastY ~= offY then
        icon:ClearAllPoints()
        icon:SetPoint("CENTER", frame.healthBar, "CENTER", offX, offY)
        st.lastX, st.lastY = offX, offY
    end

    local mirror = gdb.classifMirror and true or false
    if st.lastMirror ~= mirror then
        if mirror then
            icon:SetTexCoord(1, 0, 0, 1)
        else
            icon:SetTexCoord(0, 1, 0, 1)
        end
        st.lastMirror = mirror
    end
end

NS.Modules.Icon = {
    Update = function(frame, unit, db, gdb)
        UpdateIcon(frame, unit, db, gdb)
    end,
    Reset = function(frame)
        local st = GetState(frame)
        if frame.BPF_ClassIcon then
            frame.BPF_ClassIcon:Hide()
        end
        st.lastVisible = false
        st.lastBlizzShown = nil
        if st.hiddenBlizz and frame.ClassificationFrame then
            frame.ClassificationFrame:SetParent(frame)
            st.hiddenBlizz = false
        end
    end
}