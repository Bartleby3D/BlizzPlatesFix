local _, NS = ...

-- =============================================================
-- PROFILES: character-bound profile selection + management
-- SavedVariables layout:
--   BlizzPlatesFixDB.profileKeys[charKey] = "ProfileName"
--   BlizzPlatesFixDB.profiles["ProfileName"] = { Global = {...}, Units = {...} }
-- BlizzPlatesFixDB.Global / BlizzPlatesFixDB.Units are maintained as aliases to the active profile for backward compatibility.
-- =============================================================

NS.Profiles = NS.Profiles or {}

-- Combat-safe profile switch:
-- Switch request in combat is deferred until PLAYER_REGEN_ENABLED.
local _PendingProfileSwitch = nil

function NS.Profiles.CommitPending()
    if not _PendingProfileSwitch then return false end
    if InCombatLockdown and InCombatLockdown() then return false end
    local name = _PendingProfileSwitch
    _PendingProfileSwitch = nil
    NS.Profiles.SetCurrent(name)
    return true
end

local function Trim(s)
    if type(s) ~= "string" then return "" end
    s = s:gsub("^%s+", ""):gsub("%s+$", "")
    return s
end

local function DeepCopy(v, seen)
    if type(v) ~= "table" then return v end
    seen = seen or {}
    if seen[v] then return seen[v] end
    local t = {}
    seen[v] = t
    for k, v2 in pairs(v) do
        t[DeepCopy(k, seen)] = DeepCopy(v2, seen)
    end
    return t
end

local function EnsureDB()
    if NS.Config and NS.Config.EnsureDB then
        NS.Config.EnsureDB()
    else
        BlizzPlatesFixDB = BlizzPlatesFixDB or {}
        BlizzPlatesFixDB.profileKeys = BlizzPlatesFixDB.profileKeys or {}
        BlizzPlatesFixDB.profiles = BlizzPlatesFixDB.profiles or {}
        BlizzPlatesFixDB.profiles["Default"] = BlizzPlatesFixDB.profiles["Default"] or { Global = {}, Units = {} }
    end
end

local function FillDefaults(prof)
    if not (NS.DB and NS.DB.globalDefaults and NS.DB.unitDefaults and NS.UNIT_TYPES) then return end

    prof.Global = prof.Global or {}
    for k, v in pairs(NS.DB.globalDefaults) do
        if prof.Global[k] == nil then
            prof.Global[k] = DeepCopy(v)
        end
    end

    prof.Units = prof.Units or {}
    for _, unitType in pairs(NS.UNIT_TYPES) do
        prof.Units[unitType] = prof.Units[unitType] or {}
        for k, v in pairs(NS.DB.unitDefaults) do
            if prof.Units[unitType][k] == nil then
                prof.Units[unitType][k] = DeepCopy(v)
            end
        end
    end
end

local function RefreshAll(reason)
    if NS.ApplySystemCVars then
        NS.SafeCall(NS.ApplySystemCVars)
    end
    if NS.ClearUnitConfigCache then
        NS.ClearUnitConfigCache()
    end
    if NS.RequestUpdateAll then
        NS.RequestUpdateAll(reason or "profiles", true, NS.REASON_ALL)
    elseif NS.ForceUpdateAll then
        NS.ForceUpdateAll()
    end
end

function NS.Profiles.GetCurrent()
    return (NS.Config and NS.Config.GetActiveProfileName and NS.Config.GetActiveProfileName()) or "Default"
end

function NS.Profiles.List()
    EnsureDB()
    local out = {}
    for name in pairs(BlizzPlatesFixDB.profiles or {}) do
        out[#out + 1] = name
    end
    table.sort(out)
    return out
end

function NS.Profiles.GetDropdownOptions()
    local opts = {}
    for _, name in ipairs(NS.Profiles.List()) do
        opts[#opts + 1] = { text = name, value = name }
    end
    return opts
end

function NS.Profiles.SetCurrent(profileName)
    EnsureDB()
    if InCombatLockdown and InCombatLockdown() then
        _PendingProfileSwitch = profileName
        if NS.RefreshGUI then NS.RefreshGUI(true) end
        return
    end

    profileName = Trim(profileName)
    if profileName == "" then return end
    if not (BlizzPlatesFixDB.profiles and BlizzPlatesFixDB.profiles[profileName]) then
        profileName = "Default"
        if not BlizzPlatesFixDB.profiles[profileName] then
            BlizzPlatesFixDB.profiles[profileName] = { Global = {}, Units = {} }
            FillDefaults(BlizzPlatesFixDB.profiles[profileName])
        end
    end

    if NS.Config and NS.Config.SetActiveProfileName then
        NS.Config.SetActiveProfileName(profileName)
    end

    -- Update legacy aliases
    local active = BlizzPlatesFixDB.profiles[profileName]
    BlizzPlatesFixDB.Global = active.Global
    BlizzPlatesFixDB.Units  = active.Units

    RefreshAll("profile_switch")
    if NS.RefreshGUI then NS.RefreshGUI(true) end
end

function NS.Profiles.Create(profileName, copyFrom)
    EnsureDB()
    profileName = Trim(profileName)
    if profileName == "" then return false, "empty" end
    if BlizzPlatesFixDB.profiles[profileName] then return false, "exists" end

    local prof = { Global = {}, Units = {} }
    if copyFrom and BlizzPlatesFixDB.profiles[copyFrom] then
        prof.Global = DeepCopy(BlizzPlatesFixDB.profiles[copyFrom].Global or {})
        prof.Units  = DeepCopy(BlizzPlatesFixDB.profiles[copyFrom].Units or {})
    end
    FillDefaults(prof)
    BlizzPlatesFixDB.profiles[profileName] = prof
    return true
end

function NS.Profiles.Reset(profileName)
    EnsureDB()
    profileName = Trim(profileName)
    local prof = BlizzPlatesFixDB.profiles[profileName]
    if not prof then return false, "missing" end
    prof.Global = {}
    prof.Units = {}
    FillDefaults(prof)

    -- If this profile is active, keep aliases consistent
    if NS.Profiles.GetCurrent() == profileName then
        BlizzPlatesFixDB.Global = prof.Global
        BlizzPlatesFixDB.Units  = prof.Units
        RefreshAll("profile_reset")
    end
    return true
end

function NS.Profiles.Copy(srcName, dstName)
    EnsureDB()
    srcName = Trim(srcName)
    dstName = Trim(dstName)
    if srcName == "" or dstName == "" then return false, "empty" end
    if not BlizzPlatesFixDB.profiles[srcName] or not BlizzPlatesFixDB.profiles[dstName] then return false, "missing" end
    if srcName == dstName then return false, "same" end

    local src = BlizzPlatesFixDB.profiles[srcName]
    local dst = BlizzPlatesFixDB.profiles[dstName]

    dst.Global = DeepCopy(src.Global or {})
    dst.Units  = DeepCopy(src.Units  or {})
    FillDefaults(dst)

    if NS.Profiles.GetCurrent() == dstName then
        BlizzPlatesFixDB.Global = dst.Global
        BlizzPlatesFixDB.Units  = dst.Units
        RefreshAll("profile_copy")
    end
    return true
end

function NS.Profiles.Delete(profileName)
    EnsureDB()
    profileName = Trim(profileName)
    if profileName == "" then return false, "empty" end
    if profileName == "Default" then return false, "default" end
    if not BlizzPlatesFixDB.profiles[profileName] then return false, "missing" end
    if NS.Profiles.GetCurrent() == profileName then return false, "active" end

    -- Rebind characters using this profile back to Default
    if type(BlizzPlatesFixDB.profileKeys) == "table" then
        for ck, pn in pairs(BlizzPlatesFixDB.profileKeys) do
            if pn == profileName then
                BlizzPlatesFixDB.profileKeys[ck] = "Default"
            end
        end
    end

    BlizzPlatesFixDB.profiles[profileName] = nil
    return true
end

-- =============================================================
-- UI helpers (StaticPopup)
-- =============================================================

-- NOTE: keys must be globally unique in StaticPopupDialogs.
-- Using addon-prefixed keys avoids collisions with other addons/old versions.
local POPUP_CREATE = "BLIZZPLATESFIX_CREATE_PROFILE"
local POPUP_CONFIRM = "BLIZZPLATESFIX_CONFIRM_PROFILE_ACTION"

local function PrintMsg(msg)
    if DEFAULT_CHAT_FRAME and DEFAULT_CHAT_FRAME.AddMessage then
        DEFAULT_CHAT_FRAME:AddMessage("|cff00aaffBlizzPlatesFix:|r " .. tostring(msg))
    else
        print("BlizzPlatesFix:", msg)
    end
end

local function EnsurePopups()
    if StaticPopupDialogs and StaticPopupDialogs[POPUP_CREATE] then return end
    if not StaticPopupDialogs then return end

    StaticPopupDialogs[POPUP_CREATE] = {
        text = NS.L("Enter profile name"),
        button1 = NS.L("Create"),
        button2 = NS.L("Cancel"),
        hasEditBox = true,
        maxLetters = 30,
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnShow = function(self, data)
			local eb = self.editBox or self.EditBox
			if eb then
				eb:SetText("")
				eb:SetFocus()
				-- Some client builds don't wire dialogInfo.EditBoxOnEnterPressed.
				-- Force Enter/Escape handling directly on the edit box.
				eb:SetScript("OnEnterPressed", function(box)
					local dlg = box and box:GetParent() or nil
					if dlg and StaticPopup_OnClick then
						StaticPopup_OnClick(dlg, 1)
						return
					end
					if dlg and dlg.dialogInfo and dlg.dialogInfo.OnAccept then
						dlg.dialogInfo.OnAccept(dlg, dlg.data)
						if dlg.Hide then dlg:Hide() end
					end
				end)
				eb:SetScript("OnEscapePressed", function(box)
					local dlg = box and box:GetParent() or nil
					if dlg and StaticPopup_OnClick then
						StaticPopup_OnClick(dlg, 2)
						return
					end
					if dlg and dlg.Hide then dlg:Hide() end
				end)
			end
            self.data = data
        end,
        OnAccept = function(self, data)
			local eb = self.editBox or self.EditBox
			local name = eb and Trim(eb:GetText()) or ""
            if name == "" then
                PrintMsg(NS.L("Profile name is empty."))
                return
            end
            local copy = data and data.copyFrom or nil
            local ok, why = NS.Profiles.Create(name, copy)
            if not ok then
                if why == "exists" then
                    PrintMsg(NS.L("Profile already exists: ") .. name)
                else
                    PrintMsg(NS.L("Failed to create profile."))
                end
                return
            end
            NS.Profiles.SetCurrent(name)
            PrintMsg(NS.L("Profile created: ") .. name)
            if NS.RefreshGUI then NS.RefreshGUI(true) end
        end,
        EditBoxOnEnterPressed = function(self)
            local p = self:GetParent()
			local btn = (p and (p.button1 or p.Button1)) or nil
			if not btn and p and p.Buttons and p.Buttons[1] then btn = p.Buttons[1] end
			if btn and btn.Click then btn:Click() end
        end,
    }

    StaticPopupDialogs[POPUP_CONFIRM] = {
        text = "",
        button1 = NS.L("Yes"),
        button2 = NS.L("No"),
        timeout = 0,
        whileDead = true,
        hideOnEscape = true,
        OnAccept = function(self, data)
            if data and data.fn then
                data.fn()
            end
        end,
    }
end

function NS.Profiles.PromptCreate(copyCurrent)
    EnsureDB()
    EnsurePopups()
    local copyFrom = nil
    if copyCurrent then
        copyFrom = NS.Profiles.GetCurrent()
    end
    if StaticPopup_Show then
        StaticPopup_Show(POPUP_CREATE, nil, nil, { copyFrom = copyFrom })
    end
end

function NS.Profiles.ConfirmResetCurrent()
    EnsureDB()
    EnsurePopups()
    local cur = NS.Profiles.GetCurrent()
    if StaticPopup_Show then
        local f = function()
            NS.Profiles.Reset(cur)
            PrintMsg(NS.L("Profile reset: ") .. cur)
            if NS.RefreshGUI then NS.RefreshGUI(true) end
        end
        StaticPopupDialogs[POPUP_CONFIRM].text = NS.L("Reset current profile \"") .. cur .. NS.L("\" to defaults?")
        StaticPopup_Show(POPUP_CONFIRM, nil, nil, { fn = f })
    end
end

function NS.Profiles.ConfirmCopyIntoCurrent()
    EnsureDB()
    EnsurePopups()
    local cur = NS.Profiles.GetCurrent()
    local src = (NS.Config and NS.Config.Get and NS.Config.Get("profileCopySource", "Global")) or nil
    src = Trim(src)
    if src == "" then
        PrintMsg(NS.L("No copy source selected."))
        return
    end
    if src == cur then
        PrintMsg(NS.L("Source matches the current profile."))
        return
    end
    if not (BlizzPlatesFixDB.profiles and BlizzPlatesFixDB.profiles[src]) then
        PrintMsg(NS.L("Source not found: ") .. src)
        return
    end

    if StaticPopup_Show then
        local f = function()
            local ok = NS.Profiles.Copy(src, cur)
            if ok then
                PrintMsg(NS.L("Copied from \"") .. src .. NS.L("\" to \"") .. cur .. "\"")
            else
                PrintMsg(NS.L("Failed to copy profile."))
            end
        end
        StaticPopupDialogs[POPUP_CONFIRM].text = NS.L("Overwrite current profile \"") .. cur .. NS.L("\" with profile \"") .. src .. "\"?"
        StaticPopup_Show(POPUP_CONFIRM, nil, nil, { fn = f })
    end
end

function NS.Profiles.ConfirmDeleteSelected()
    EnsureDB()
    EnsurePopups()
    local name = (NS.Config and NS.Config.Get and NS.Config.Get("profileDeleteTarget", "Global")) or nil
    name = Trim(name)
    if name == "" then
        PrintMsg(NS.L("No profile selected for deletion."))
        return
    end
    if name == "Default" then
        PrintMsg(NS.L("You cannot delete the Default profile."))
        return
    end
    if name == NS.Profiles.GetCurrent() then
        PrintMsg(NS.L("You cannot delete the active profile. Switch to another one first."))
        return
    end
    if not (BlizzPlatesFixDB.profiles and BlizzPlatesFixDB.profiles[name]) then
        PrintMsg(NS.L("Profile not found: ") .. name)
        return
    end

    if StaticPopup_Show then
        local f = function()
            local ok, why = NS.Profiles.Delete(name)
            if ok then
                -- if UI dropdowns were pointing to the deleted profile, move them to a safe value
                if NS.Config and NS.Config.Get and NS.Config.Set then
                    local ctx = "Global"
                    if NS.Config.Get("profileDeleteTarget", ctx) == name then
                        NS.Config.Set("profileDeleteTarget", "Default", ctx)
                    end
                    if NS.Config.Get("profileCopySource", ctx) == name then
                        NS.Config.Set("profileCopySource", "Default", ctx)
                    end
                end
                PrintMsg(NS.L("Profile deleted: ") .. name)
                if NS.RefreshGUI then NS.RefreshGUI(true) end
            else
                PrintMsg(NS.L("Failed to delete profile (") .. tostring(why) .. ")")
            end
        end
        StaticPopupDialogs[POPUP_CONFIRM].text = NS.L("Delete profile \"") .. name .. "\"?"
        StaticPopup_Show(POPUP_CONFIRM, nil, nil, { fn = f })
    end
end
