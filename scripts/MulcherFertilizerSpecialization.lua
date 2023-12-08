MulcherFertilizerSpecialization = {
    modName = g_currentModName
}

function MulcherFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

function MulcherFertilizerSpecialization.registerEventListeners(vehicleType)
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", MulcherFertilizerSpecialization)
    print("-- Registered MulcherFertilizerSpecialization for " .. tostring(vehicleType.name))
end

function MulcherFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processMulcherArea", MulcherFertilizerSpecialization.processMulcherArea)
    print("-- Registered functions for MulcherFertilizerSpecialization " .. tostring(vehicleType.name))
end

function MulcherFertilizerSpecialization:onLoad(savegame)
    print("-- MulcherFertilizerSpecialization:onLoad start")
    self.spec_MulcherFertilizerSpecialization = self["spec_" .. MulcherFertilizerSpecialization.modName .. ".MulcherFertilizerSpecialization"]

    DebugUtil.printTableRecursively(self.spec_MulcherFertilizerSpecialization, "DBG::", 0, 0)
end

function MulcherFertilizerSpecialization:processMulcherArea(superFunc, workArea, dt)
    realArea, area = superFunc(self, workArea, dt)
    -- Retrieve the world coordinates for the current mulcher area (a subset of the mulcher's extents)
    local sx,sy,sz = getWorldTranslation(workArea.start)
    local wx,_,wz = getWorldTranslation(workArea.width)
    local hx,_,hz = getWorldTranslation(workArea.height)
    -- Get information about what we are mulching
    local fruitType = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(sx, sz)
    local onField, groundTypeBits, groundType = FSDensityMapUtil.getFieldDataAtWorldPosition(sx, sy, sz)
    -- Only if we are mulching a grown oilseed radish field
    if onField == true and fruitType == FruitType.OILSEEDRADISH and groundType == FieldGroundType.HARVEST_READY_OTHER then
        -- Apply two levels of fertilizer
        FSDensityMapUtil.updateSprayArea(sx,sz, wx,wz, hx,hz, 1, 2 )
    end
    return realArea, area
end
