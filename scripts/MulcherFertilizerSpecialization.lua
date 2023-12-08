---This class is responsible for adding a specialization to mulchers which fertilizes when mulching oilseed radish
MulcherFertilizerSpecialization = {
}

---Checks for other required specializations.
-- Since this is only added to implements with the Mulcher specilization anyway, we don't need to check anything here.
-- @param   table       specializations     A table of existing specializations.
-- @return  boolean     true                (always)
function MulcherFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

---Overrides the processMulcherArea so we can add fertilizer during the mulching process
-- @param   table       vehicleType     Provides information about the current vehicle (or rather implement) type.
function MulcherFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processMulcherArea", MulcherFertilizerSpecialization.processMulcherArea)
    print(g_currentModName .. ": Hooked into vehicle type " .. vehicleType.name)
end

---Adds fertilizer when mulching ready-to-harvest oilseed radish.
-- @param   function    superFunc       The GIANTS implementation of the method.
-- @param   table       workArea        Provides information about the area to be mulched.
-- @param   table       dt              Seems not even the superFunc uses this.
-- @return  integer     realArea        Unknown
-- @return  integer     area            Unknown
function MulcherFertilizerSpecialization:processMulcherArea(superFunc, workArea, dt)
    -- Retrieve the world coordinates for the current mulcher area (a subset of the mulcher's extents)
    local sx,sy,sz = getWorldTranslation(workArea.start)
    local wx,_,wz = getWorldTranslation(workArea.width)
    local hx,_,hz = getWorldTranslation(workArea.height)

    -- Get information about what we are mulching
    local fruitType = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(sx, sz)
    local onField, _, groundType = FSDensityMapUtil.getFieldDataAtWorldPosition(sx, sy, sz)

    -- Execute base game behavior (i.e. mulch now)
    local realArea, area = superFunc(self, workArea, dt)

    -- Only if we were mulching a grown oilseed radish field...
    if onField == true and fruitType == FruitType.OILSEEDRADISH and groundType == FieldGroundType.HARVEST_READY_OTHER then
        -- ... apply two levels of fertilizer by calling what a sprayer would call
        local sprayType = FieldSprayType.FERTILIZER
        local sprayLevels = 2
        FSDensityMapUtil.updateSprayArea(sx,sz, wx,wz, hx,hz, sprayType, sprayLevels)
    end

    -- Return whatever the base game implementation returned
    return realArea, area
end
