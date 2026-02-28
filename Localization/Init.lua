local _, NS = ...

-- Simple localization layer.
-- Base language in code: English strings.
-- Usage in code: NS.L("String") -> translated or fallback to enUS/key.

NS._locales = NS._locales or {}
NS._activeLocale = (GetLocale and GetLocale()) or "enUS"

function NS.AddLocale(locale, tbl)
    if type(locale) ~= "string" or type(tbl) ~= "table" then return end
    NS._locales[locale] = tbl
end

local function Translate(key)
    if key == nil then return "" end
    if type(key) ~= "string" then return tostring(key) end

    local loc = NS._activeLocale
    local t = NS._locales[loc]
    local v = t and t[key]
    if v ~= nil then return v end

    local en = NS._locales["enUS"]
    v = en and en[key]
    if v ~= nil then return v end

    return key
end

function NS.L(key)
    return Translate(key)
end

function NS.LF(key, ...)
    return string.format(Translate(key), ...)
end
