local _, NS = ...

NS.FriendlyInstanceNames = NS.FriendlyInstanceNames or {}
local M = NS.FriendlyInstanceNames

local STATE_ROOT_KEY = "Runtime"
local STATE_KEY = "FriendlyInstanceNames"

local FEATURE_CVARS = {
    "nameplateShowFriendlyPlayers",
    "nameplateShowOnlyNameForFriendlyPlayerUnits",
    "nameplateUseClassColorForFriendlyPlayerUnitNames",
    "nameplateSize",
}

local ALPHABETS = {
    "roman",
    "korean",
    "simplifiedchinese",
    "traditionalchinese",
    "russian",
}

local ORIGINAL_FONT_STATE = nil
local SYSTEM_FONT_SIZES = nil
local FONT_FAMILY_CACHE = {}
local FONT_FAMILY_COUNTER = 0
local SHORT_NAME_PATH_PATCHED = false
local MANAGED_CVAR_SUPPRESS_UNTIL = 0

local localeAlphabet = "roman"
do
    local locale = GetLocale and GetLocale() or "enUS"
    if locale == "koKR" then
        localeAlphabet = "korean"
    elseif locale == "zhCN" then
        localeAlphabet = "simplifiedchinese"
    elseif locale == "zhTW" then
        localeAlphabet = "traditionalchinese"
    elseif locale == "ruRU" then
        localeAlphabet = "russian"
    end
end

local function NormalizeForCompare(v)
    if v == nil then return nil end
    if type(v) == "boolean" then
        return v and "1" or "0"
    end
    return tostring(v)
end

local function SetCVarIfChanged(cvarName, newValue)
    if not cvarName or newValue == nil then return end
    local newStr = NormalizeForCompare(newValue)
    if not newStr then return end

    local cur = GetCVar(cvarName)
    if cur ~= newStr then
        SetCVar(cvarName, newStr)
    end
end

local function EnsureState()
    if not BlizzPlatesFixDB then return nil end
    BlizzPlatesFixDB[STATE_ROOT_KEY] = BlizzPlatesFixDB[STATE_ROOT_KEY] or {}
    local root = BlizzPlatesFixDB[STATE_ROOT_KEY]
    root[STATE_KEY] = root[STATE_KEY] or {
        active = false,
        restore = nil,
    }
    return root[STATE_KEY]
end

local function GetFeatureSettings()
    if not NS.Config or not NS.Config.Get or not NS.UNIT_TYPES then
        return false, true, 9, "SHADOW"
    end

    local ctx = NS.UNIT_TYPES.FRIENDLY_PLAYER
    local enabled = NS.Config.Get("friendlyInstanceNamesEnable", ctx) and true or false
    local classColor = NS.Config.Get("friendlyInstanceNamesClassColor", ctx)
    if classColor == nil then classColor = true end

    local fontSize = tonumber(NS.Config.Get("friendlyInstanceNamesFontSize", ctx)) or 9
    if fontSize < 4 then fontSize = 4 elseif fontSize > 20 then fontSize = 20 end

    local outline = NS.Config.Get("friendlyInstanceNamesFontOutline", ctx)
    if outline ~= "NONE" and outline ~= "OUTLINE" and outline ~= "THICKOUTLINE" and outline ~= "SHADOW" then
        outline = "SHADOW"
    end

    return enabled, classColor, fontSize, outline
end

local function IsSupportedInstance()
    local inInstance, instanceType = IsInInstance()
    if not inInstance then return false end
    return instanceType == "party" or instanceType == "raid"
end

local function ShouldFeatureBeActive()
    local enabled = GetFeatureSettings()
    return enabled and IsSupportedInstance()
end

local function BuildSystemFontSizes()
    if SYSTEM_FONT_SIZES then return SYSTEM_FONT_SIZES end
    SYSTEM_FONT_SIZES = {}

    if NamePlateConstants and NamePlateConstants.NAME_PLATE_SCALES and NamePlateConstants.HEALTH_BAR_FONT_HEIGHT then
        for i = 1, #NamePlateConstants.NAME_PLATE_SCALES do
            local details = NamePlateConstants.NAME_PLATE_SCALES[i]
            if details and details.vertical then
                SYSTEM_FONT_SIZES[i] = details.vertical * NamePlateConstants.HEALTH_BAR_FONT_HEIGHT
            end
        end
    end

    if #SYSTEM_FONT_SIZES == 0 then
        SYSTEM_FONT_SIZES = { 6, 8, 10, 12, 14 }
    end

    return SYSTEM_FONT_SIZES
end

local function PickNearestNameplateSizeIndex(targetSize)
    local sizes = BuildSystemFontSizes()
    local bestIndex, bestDelta = 1, math.huge

    for index, size in ipairs(sizes) do
        local delta = math.abs(size - targetSize)
        if delta < bestDelta then
            bestIndex, bestDelta = index, delta
        end
    end

    return bestIndex
end

local function SnapshotFontObject(fontObject)
    if not fontObject then return nil end

    local data = {
        alphabets = {},
        shadowColor = nil,
        shadowOffset = nil,
    }

    if fontObject.GetFontObjectForAlphabet then
        for _, alphabet in ipairs(ALPHABETS) do
            local sub = fontObject:GetFontObjectForAlphabet(alphabet)
            if sub and sub.GetFont then
                local font, size, flags = sub:GetFont()
                local sr, sg, sb, sa = 0, 0, 0, 0
                local sx, sy = 0, 0
                if sub.GetShadowColor then
                    sr, sg, sb, sa = sub:GetShadowColor()
                end
                if sub.GetShadowOffset then
                    sx, sy = sub:GetShadowOffset()
                end
                data.alphabets[alphabet] = {
                    font = font,
                    size = size,
                    flags = flags,
                    shadowColor = { r = sr, g = sg, b = sb, a = sa },
                    shadowOffset = { x = sx, y = sy },
                }
            end
        end
    elseif fontObject.GetFont then
        local font, size, flags = fontObject:GetFont()
        data.font = font
        data.size = size
        data.flags = flags
    end

    if fontObject.GetShadowColor then
        local r, g, b, a = fontObject:GetShadowColor()
        data.shadowColor = { r = r, g = g, b = b, a = a }
    end
    if fontObject.GetShadowOffset then
        local x, y = fontObject:GetShadowOffset()
        data.shadowOffset = { x = x, y = y }
    end

    return data
end

local function EnsureOriginalFontState()
    if ORIGINAL_FONT_STATE then return ORIGINAL_FONT_STATE end
    ORIGINAL_FONT_STATE = {
        normal = SnapshotFontObject(_G.SystemFont_NamePlate),
        outlined = SnapshotFontObject(_G.SystemFont_NamePlate_Outlined),
    }
    return ORIGINAL_FONT_STATE
end

local function EnsureShortFriendlyNamesStatic()
    local opts = _G.NamePlateFriendlyFrameOptions
    if type(opts) ~= "table" then return false end

    if rawget(opts, "updateNameUsesGetUnitName") ~= nil then
        opts.updateNameUsesGetUnitName = nil
    end

    SHORT_NAME_PATH_PATCHED = true
    return true
end

local function ApplySnapshotToFontObject(fontObject, data)
    if not fontObject or not data then return end

    if fontObject.GetFontObjectForAlphabet and data.alphabets then
        for _, alphabet in ipairs(ALPHABETS) do
            local spec = data.alphabets[alphabet]
            local sub = fontObject:GetFontObjectForAlphabet(alphabet)
            if spec and sub and sub.SetFont and spec.font and spec.size then
                sub:SetFont(spec.font, spec.size, spec.flags)
                if spec.shadowColor and sub.SetShadowColor then
                    sub:SetShadowColor(spec.shadowColor.r or 0, spec.shadowColor.g or 0, spec.shadowColor.b or 0, spec.shadowColor.a or 0)
                end
                if spec.shadowOffset and sub.SetShadowOffset then
                    sub:SetShadowOffset(spec.shadowOffset.x or 0, spec.shadowOffset.y or 0)
                end
            end
        end
    elseif fontObject.SetFont and data.font and data.size then
        fontObject:SetFont(data.font, data.size, data.flags)
    end

    if data.shadowColor and fontObject.SetShadowColor then
        fontObject:SetShadowColor(data.shadowColor.r or 0, data.shadowColor.g or 0, data.shadowColor.b or 0, data.shadowColor.a or 0)
    end
    if data.shadowOffset and fontObject.SetShadowOffset then
        fontObject:SetShadowOffset(data.shadowOffset.x or 0, data.shadowOffset.y or 0)
    end
end

local function BuildManagedFontFlags(outlineStyle)
    local outlineFlags = ""
    local useShadow = false

    if outlineStyle == "OUTLINE" or outlineStyle == "THICKOUTLINE" then
        outlineFlags = outlineStyle
    elseif outlineStyle == "SHADOW" then
        useShadow = true
    end

    local useSlug = (outlineFlags ~= "") or (not useShadow)
    if useSlug then
        if outlineFlags ~= "" then
            outlineFlags = outlineFlags .. " SLUG"
        else
            outlineFlags = "SLUG"
        end
    end

    return outlineFlags, useShadow
end

local function BuildManagedFontMembers(fontPath, outlineStyle)
    local flags = BuildManagedFontFlags(outlineStyle)
    local members = {}
    local sourceFamily = GameFontNormal

    for _, alphabet in ipairs(ALPHABETS) do
        local src = sourceFamily and sourceFamily.GetFontObjectForAlphabet and sourceFamily:GetFontObjectForAlphabet(alphabet)
        local file, size = nil, 9
        if src and src.GetFont then
            file, size = src:GetFont()
        end
        if alphabet == localeAlphabet then
            file = fontPath
        end
        members[#members + 1] = {
            alphabet = alphabet,
            file = file or fontPath,
            height = size or 9,
            flags = flags,
        }
    end

    return members
end

local function GetManagedFontFamily(fontPath, outlineStyle)
    if not CreateFontFamily then return nil end

    local flags, useShadow = BuildManagedFontFlags(outlineStyle)
    local key = table.concat({ tostring(fontPath), tostring(flags), useShadow and "1" or "0" }, "|")
    local cached = FONT_FAMILY_CACHE[key]
    if cached and _G[cached] then
        return _G[cached]
    end

    FONT_FAMILY_COUNTER = FONT_FAMILY_COUNTER + 1
    local name = "BlizzPlatesFixFriendlyInstanceFont" .. tostring(FONT_FAMILY_COUNTER)
    local family = CreateFontFamily(name, BuildManagedFontMembers(fontPath, outlineStyle))
    if not family then return nil end

    family:SetTextColor(1, 1, 1)

    if useShadow then
        for _, alphabet in ipairs(ALPHABETS) do
            local sub = family:GetFontObjectForAlphabet(alphabet)
            if sub then
                if sub.SetShadowOffset then
                    sub:SetShadowOffset(1, -1)
                end
                if sub.SetShadowColor then
                    sub:SetShadowColor(0, 0, 0, 1)
                end
            end
        end
    end

    FONT_FAMILY_CACHE[key] = name
    return family
end

local function CopyFontFamily(base, new)
    if not base or not new or not base.GetFontObjectForAlphabet or not new.GetFontObjectForAlphabet then return end

    for _, alphabet in ipairs(ALPHABETS) do
        local baseObj = base:GetFontObjectForAlphabet(alphabet)
        local newObj = new:GetFontObjectForAlphabet(alphabet)
        if baseObj and newObj and baseObj.SetFont and newObj.GetFont then
            local font, _, flags = newObj:GetFont()
            baseObj:SetFont(font, 9, flags)
            if baseObj.SetShadowColor and newObj.GetShadowColor then
                local r, g, b, a = newObj:GetShadowColor()
                baseObj:SetShadowColor(r or 0, g or 0, b or 0, a or 0)
            end
            if baseObj.SetShadowOffset and newObj.GetShadowOffset then
                local x, y = newObj:GetShadowOffset()
                baseObj:SetShadowOffset(x or 0, y or 0)
            end
        end
    end
end

local function ApplyFontStyling()
    local _, _, fontSize, outline = GetFeatureSettings()
    local fontPath = NS.GetFontPath and NS.GetFontPath(NS.Config.Get("globalFont", "Global")) or STANDARD_TEXT_FONT
    if not fontPath then return end

    EnsureOriginalFontState()

    local managed = GetManagedFontFamily(fontPath, outline)
    if managed then
        CopyFontFamily(_G.SystemFont_NamePlate, managed)
        CopyFontFamily(_G.SystemFont_NamePlate_Outlined, managed)
    end

    local index = PickNearestNameplateSizeIndex(fontSize)
    if index then
        SetCVarIfChanged("nameplateSize", tostring(index))
    end
end

local function RestoreFontStyling()
    local original = EnsureOriginalFontState()
    if not original then return end

    ApplySnapshotToFontObject(_G.SystemFont_NamePlate, original.normal)
    ApplySnapshotToFontObject(_G.SystemFont_NamePlate_Outlined, original.outlined)
end

local function SuppressManagedCVarUpdatesShortly()
    local now = (GetTimePreciseSec and GetTimePreciseSec()) or (GetTime and GetTime()) or 0
    MANAGED_CVAR_SUPPRESS_UNTIL = now + 0.5
end

local function IsManagedCVarUpdateSuppressed()
    local now = (GetTimePreciseSec and GetTimePreciseSec()) or (GetTime and GetTime()) or 0
    return now < (MANAGED_CVAR_SUPPRESS_UNTIL or 0)
end

local function RefreshVisibleNameplates()
    if NS.RequestUpdateAll then
        local mask = NS.REASON_CONFIG or NS.REASON_ALL
        NS.RequestUpdateAll("friendly_instance_names_style", true, mask)
    elseif NS.ForceUpdateAll then
        NS.ForceUpdateAll()
    end
end

local function CaptureRestoreSnapshot(state)
    if type(state.restore) == "table" and next(state.restore) ~= nil then
        return
    end

    state.restore = {}
    for _, cvarName in ipairs(FEATURE_CVARS) do
        state.restore[cvarName] = GetCVar(cvarName)
    end
end

local function ApplyFeature(state)
    if not state then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local _, classColor = GetFeatureSettings()
    CaptureRestoreSnapshot(state)

    SuppressManagedCVarUpdatesShortly()
    SetCVarIfChanged("nameplateShowFriendlyPlayers", "1")
    SetCVarIfChanged("nameplateShowOnlyNameForFriendlyPlayerUnits", "1")
    SetCVarIfChanged("nameplateUseClassColorForFriendlyPlayerUnitNames", classColor and "1" or "0")
    ApplyFontStyling()

    state.active = true
    RefreshVisibleNameplates()
    return true
end

local function RestoreFeature(state)
    if not state then return false end
    if InCombatLockdown and InCombatLockdown() then return false end

    local hadRestore = type(state.restore) == "table" and next(state.restore) ~= nil
    if not state.active and not hadRestore then
        return false
    end

    SuppressManagedCVarUpdatesShortly()
    RestoreFontStyling()

    local restore = state.restore or {}
    for _, cvarName in ipairs(FEATURE_CVARS) do
        local restoreValue = restore[cvarName]
        if restoreValue ~= nil then
            SetCVarIfChanged(cvarName, restoreValue)
        else
            local def = C_CVar and C_CVar.GetCVarDefault and C_CVar.GetCVarDefault(cvarName)
            if def ~= nil then
                SetCVarIfChanged(cvarName, def)
            end
        end
    end

    state.active = false
    state.restore = nil
    RefreshVisibleNameplates()
    return true
end

function M.UpdateState(_reason)
    EnsureShortFriendlyNamesStatic()

    local state = EnsureState()
    if not state then return false end

    if ShouldFeatureBeActive() then
        return ApplyFeature(state)
    end

    return RestoreFeature(state)
end

function M.OnSettingsChanged()
    return M.UpdateState("settings_changed")
end

function M.OnCVarUpdate(cvarName)
    if not cvarName then return end

    local isManaged = false
    for _, managedName in ipairs(FEATURE_CVARS) do
        if managedName == cvarName then
            isManaged = true
            break
        end
    end
    if not isManaged then return end

    if IsManagedCVarUpdateSuppressed() then
        return
    end

    local state = EnsureState()
    if not state then return end

    if state.active or ShouldFeatureBeActive() then
        M.UpdateState("cvar_update")
    end
end

EnsureShortFriendlyNamesStatic()
