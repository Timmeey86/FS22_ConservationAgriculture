---This class is responsible for adding a specialization to Rollers which fertilizes when rolling over oilseed radish
-- Additionally, the ground will get mulched
RollerFertilizerSpecialization = {
}

---Checks for other required specializations.
-- Since this is only added to implements with the Roller specilization anyway, we don't need to check anything here.
-- @param   table       specializations     A table of existing specializations.
-- @return  boolean     true                (always)
function RollerFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

---Overrides the processRollerArea so we can add fertilizer during the rolling process
-- @param   table       vehicleType     Provides information about the current vehicle (or rather implement) type.
function RollerFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processRollerArea", RollerFertilizerSpecialization.processRollerArea)
    print("RollerFertilizerSpecialization: Hooked into vehicle type " .. vehicleType.name)
end

---Adds fertilizer when rolling ready-to-harvest oilseed radish.
-- @param   function    superFunc       The GIANTS implementation of the method.
-- @param   table       workArea        Provides information about the area to be mulched.
-- @param   table       dt              Seems not even the superFunc uses this.
-- @return  integer     realArea        Unknown
-- @return  integer     area            Unknown
function RollerFertilizerSpecialization:processRollerArea(superFunc, workArea, dt)
    -- Retrieve the world coordinates for the current Roller area (a subset of the Roller's extents)
    local sx,sy,sz = getWorldTranslation(workArea.start)
    local wx,_,wz = getWorldTranslation(workArea.width)
    local hx,_,hz = getWorldTranslation(workArea.height)

    -- Get information about what we are rolling over
    local fruitType = FSDensityMapUtil.getFruitTypeIndexAtWorldPos(sx, sz)
    local onField, _, groundType = FSDensityMapUtil.getFieldDataAtWorldPosition(sx, sy, sz)

    -- Execute base game behavior (Probably won't do anything in this case)
    local realArea, area = superFunc(self, workArea, dt)

    -- Only if we were rolling a grown oilseed radish field...
    if self.spec_roller.isSoilRoller and 
       onField == true and
       fruitType == FruitType.OILSEEDRADISH and
       groundType == FieldGroundType.HARVEST_READY_OTHER then
        -- ... mulch the field by calling what a mulcher would call ...
        FSDensityMapUtil.updateMulcherArea(sx,sz, wx,wz, hx,hz)
        -- ... and apply two levels of fertilizer by calling what a sprayer would call
        local sprayType = FieldSprayType.FERTILIZER
        local sprayLevels = 2
        FSDensityMapUtil.updateSprayArea(sx,sz, wx,wz, hx,hz, sprayType, sprayLevels)
    end

    -- Return whatever the base game implementation returned
    return realArea, area
end
