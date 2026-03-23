local _, NS = ...
NS.RP = NS.RP or {}

local RP = NS.RP
local RequestThrottle = {}
local HooksReady = false
local AddonWatcher = CreateFrame("Frame")
AddonWatcher:RegisterEvent("ADDON_LOADED")

local function IsInstanceSuppressed()
    local inInstance, instanceType = IsInInstance()
    return inInstance and (instanceType == "party" or instanceType == "raid")
end

local function IsEnabled()
    return NS.Config and NS.Config.Get and NS.Config.Get("rpSupportEnabled", "Global") == true and not IsInstanceSuppressed()
end

local function IsPlayerUnit(unit)
    if not unit then return false end

    if type(unit) == "string" and unit:find("nameplate", 1, true) and unit:find("target", 1, true) then
        return false
    end

    return UnitExists(unit) and UnitIsPlayer(unit) and not UnitIsUnit(unit, "player")
end

local function NormalizeText(text)
    if text == nil then return nil end

    local ok, s = pcall(tostring, text)
    if not ok or not s or s == "" then return nil end

    s = s:gsub("|T.-|t", "")
    s = s:gsub("|A.-|a", "")
    s = s:gsub("|c%x%x%x%x%x%x%x%x", "")
    s = s:gsub("|r", "")
    s = s:gsub("%s+", " ")
    s = s:gsub("^%s+", "")
    s = s:gsub("%s+$", "")

    if s == "" then return nil end
    return s
end

local function GetCharacterID(unit)
    if not unit then return nil end

    if TRP3_API and TRP3_API.utils and TRP3_API.utils.str and TRP3_API.utils.str.getUnitID then
        local ok, id = pcall(TRP3_API.utils.str.getUnitID, unit)
        if ok and type(id) == "string" and id ~= "" then
            return id
        end
    end

    if UnitNameUnmodified then
        local name, realm = UnitNameUnmodified(unit)
        if type(name) == "string" and name ~= "" then
            realm = realm or ""
            if realm == "" and GetNormalizedRealmName then
                realm = GetNormalizedRealmName() or ""
            end
            if realm ~= "" then
                return name .. "-" .. realm
            end
            return name
        end
    end

    local fullName = GetUnitName and GetUnitName(unit, true)
    if type(fullName) == "string" and fullName ~= "" then
        return fullName
    end

    local name, realm = UnitFullName(unit)
    if not name or name == "" then return nil end
    realm = realm or ""
    if realm == "" and GetNormalizedRealmName then
        realm = GetNormalizedRealmName() or ""
    end
    if realm ~= "" then
        return name .. "-" .. realm
    end
    return name
end

local function RefreshUnitsByCharacterID(characterID)
    if not characterID or not NS.ActiveNamePlates then return end

    for unit in pairs(NS.ActiveNamePlates) do
        if IsPlayerUnit(unit) and GetCharacterID(unit) == characterID then
            if NS.RequestUpdate then
                NS.RequestUpdate(unit, "rp_data", false, NS.REASON_CONFIG or NS.REASON_ALL)
            elseif NS.UpdateAllModules then
                NS.UpdateAllModules(unit, NS.REASON_ALL)
            end
        end
    end
end

local function EnsureHooks()
    if HooksReady then return end

    if msp and msp.callback then
        msp.callback.received = msp.callback.received or {}
        msp.callback.updated = msp.callback.updated or {}

        table.insert(msp.callback.received, function(characterID)
            RefreshUnitsByCharacterID(characterID)
        end)

        table.insert(msp.callback.updated, function(characterID)
            RefreshUnitsByCharacterID(characterID)
        end)
    end

    if TRP3_API and TRP3_Addon and TRP3_API.RegisterCallback then
        TRP3_API.RegisterCallback(TRP3_Addon, "REGISTER_DATA_UPDATED", function(_, characterID)
            RefreshUnitsByCharacterID(characterID)
        end)
    end

    HooksReady = true
end

AddonWatcher:SetScript("OnEvent", function(_, event, addonName)
    if event == "ADDON_LOADED" and (addonName == "totalRP3" or addonName == "MyRolePlay") then
        EnsureHooks()
    end
end)

local function RequestRPData(unit, characterID)
    if not IsEnabled() then return end
    if not IsPlayerUnit(unit) then return end
    if not characterID then return end

    local now = GetTime()
    local last = RequestThrottle[characterID]
    if last and (now - last) < 15 then
        return
    end
    RequestThrottle[characterID] = now

    if TRP3_NamePlates and TRP3_NamePlates.RequestUnitProfile then
        pcall(TRP3_NamePlates.RequestUnitProfile, TRP3_NamePlates, unit)
        return
    end

    if msp and type(msp.Request) == "function" then
        pcall(msp.Request, msp, characterID, { "NA" })
    end
end

local function GetTRP3ResolvedName(unit, characterID)
    if TRP3_NamePlates and TRP3_NamePlates.GetUnitDisplayInfo then
        local ok, info = pcall(TRP3_NamePlates.GetUnitDisplayInfo, TRP3_NamePlates, unit)
        if ok and type(info) == "table" and info.name then
            local text = NormalizeText(info.name)
            if text then return text end
        end
    end

    if not (characterID and AddOn_TotalRP3 and AddOn_TotalRP3.Player and AddOn_TotalRP3.Player.CreateFromCharacterID) then
        return nil
    end

    if TRP3_API and TRP3_API.register and TRP3_API.register.isUnitIDKnown then
        local okKnown, known = pcall(TRP3_API.register.isUnitIDKnown, characterID)
        if okKnown and not known then
            return nil
        end
    end

    local okPlayer, player = pcall(AddOn_TotalRP3.Player.CreateFromCharacterID, characterID)
    if not okPlayer or not player then return nil end

    local mode = TRP3_NamePlatesSettings and TRP3_NamePlatesSettings.CustomizeNames or nil
    local name

    if mode == 2 and player.GetFirstName then
        name = player:GetFirstName()
    elseif mode == 3 and player.GetName then
        name = player:GetName()
    elseif player.GetRoleplayingName then
        name = player:GetRoleplayingName()
    end

    if (not name or name == "") and player.GetRoleplayingName then
        name = player:GetRoleplayingName()
    end

    if name and TRP3_NamePlatesSettings and TRP3_NamePlatesSettings.CustomizeTitles and player.GetTitle then
        local prefix = player:GetTitle()
        if prefix and prefix ~= "" then
            name = prefix .. " " .. name
        end
    end

    return NormalizeText(name)
end

local function GetMSPResolvedName(characterID)
    if not (characterID and msp and msp.char) then return nil end

    local char = msp.char[characterID]
    local fields = char and char.field
    local name = fields and fields.NA
    return NormalizeText(name)
end

function RP.GetDisplayName(unit, fallbackName)
    if not IsEnabled() then
        return fallbackName, "disabled"
    end

    if not IsPlayerUnit(unit) then
        return fallbackName, "non_player"
    end

    EnsureHooks()

    local characterID = GetCharacterID(unit)
    local resolved = GetTRP3ResolvedName(unit, characterID) or GetMSPResolvedName(characterID)

    if resolved then
        return resolved, "resolved"
    end

    RequestRPData(unit, characterID)
    return nil, "pending"
end

function RP.IsEnabled()
    return IsEnabled()
end

function RP.IsInstanceSuppressed()
    return IsInstanceSuppressed()
end

function RP.GetCharacterID(unit)
    return GetCharacterID(unit)
end
