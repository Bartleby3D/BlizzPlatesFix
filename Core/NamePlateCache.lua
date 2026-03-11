local _, NS = ...
-- =============================================================
-- АКТИВНЫЕ НЕЙМПЛЕЙТЫ (КЕШ)
-- =============================================================
NS.ActiveNamePlates = NS.ActiveNamePlates or {}

function NS.AddActivePlate(unit)
    local plate = C_NamePlate.GetNamePlateForUnit(unit)
    if plate and plate.UnitFrame and not plate:IsForbidden() then
        local frame = plate.UnitFrame

        frame.BPF_CoreCache = nil
        frame.BPF_InstanceHidden = nil

        NS.ActiveNamePlates[unit] = frame
    end
end

function NS.RemoveActivePlate(unit)
    local frame = NS.ActiveNamePlates[unit]
    if frame and NS.ModuleManager and NS.ModuleManager.ResetFrame then
        -- очищаем модульные “следы” при реюзе неймплейтов
        NS.ModuleManager.ResetFrame(frame)
    end
    NS.ActiveNamePlates[unit] = nil
end