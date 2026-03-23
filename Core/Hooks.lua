local _, NS = ...
-- Этот файл только устанавливает хуки. Логика реакции вынесена в Core/HooksDispatch.lua

local function HookHandler(frame, hookKey, reasonMask)
    if NS.HooksDispatch and NS.HooksDispatch.HandleCompactUpdate then
        NS.HooksDispatch.HandleCompactUpdate(frame, hookKey, reasonMask)
    end
end

if _G.CompactUnitFrame_UpdateName then
    hooksecurefunc("CompactUnitFrame_UpdateName", function(frame)
        HookHandler(frame, "name", NS.REASON_NAME or 4096)
    end)
end

if _G.CompactUnitFrame_UpdateHealth then
    hooksecurefunc("CompactUnitFrame_UpdateHealth", function(frame)
        HookHandler(frame, "health", NS.REASON_HEALTH or 8)
    end)
end

-- Перехватываем дефолтное обновление аур Blizzard
if _G.CompactUnitFrame_UpdateAuras then
    hooksecurefunc("CompactUnitFrame_UpdateAuras", function(frame)
        -- Уведомляем движок только об аурах, без полного REASON_ALL.
        HookHandler(frame, "aura", NS.REASON_AURA or 2)

        -- Принудительно глушим стандартные ауры Blizzard на неймплейтах.
        -- В 12.0+ контейнером может быть BuffFrame/DebuffFrame/AurasFrame.
        if not frame or frame:IsForbidden() then return end
        if not (frame.unit and frame.unit:find("nameplate")) then return end

        -- Если профиль для этого типа существ выключен — не вмешиваемся (иначе это ломает дефолтные неймплейты).
        if NS.GetUnitConfig then
            local udb = NS.GetUnitConfig(frame.unit)
            if udb and udb.enabled == false then
                return
            end
        end

        local function SuppressContainer(container)
            if not container or container:IsForbidden() then return end

            -- Скрываем жёстко: и альфа, и Hide(), чтобы не мигало.
            container:SetAlpha(0)
            if container:IsShown() then
                container:Hide()
            end

            -- Чтобы Blizzard не "воскрешал" контейнер на следующих апдейтах.
            if not container.__BPF_Suppressed then
                container.__BPF_Suppressed = true
                if container.HookScript then
                    container:HookScript("OnShow", function(self)
                        self:SetAlpha(0)
                        self:Hide()
                    end)
                end
            end
        end

        SuppressContainer(frame.BuffFrame)
        SuppressContainer(frame.DebuffFrame)
        SuppressContainer(frame.AurasFrame)
    end)
end

function NS.ClearHookThrottle(unit)
    if NS.HooksDispatch and NS.HooksDispatch.ClearHookThrottle then
        NS.HooksDispatch.ClearHookThrottle(unit)
    end
end
