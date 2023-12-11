--- This class is responsible for adding a specialization to Rollers which fertilizes when rolling over oilseed radish
---Additionally, the ground will get a mulched and seedbed status
RollerFertilizerSpecialization = {
}

--- Checks for other required specializations.
---Since this is only added to implements with the Roller specilization anyway, we don't need to check anything here.
---@param   specializations     table   @A table of existing specializations (unused).
---@return  boolean     @Always true
function RollerFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

--- Overrides the processRollerArea so we can add fertilizer during the rolling process
---@param   vehicleType     table     @Provides information about the current vehicle (or rather implement) type.
function RollerFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processRollerArea", RollerFertilizerSpecialization.processRollerArea)
    print("RollerFertilizerSpecialization: Hooked into vehicle type " .. vehicleType.name)
end

--- Adds fertilizer when rolling ready-to-harvest cover crops
---@param   superFunc   function        @The GIANTS implementation of the method.
---@param   workArea    table           @Provides information about the area to be mulched.
---@param   dt          table           @delta time? Not used here.
---@return  integer     @The amount of pixels which were processed
---@return  integer     @The amount of pixels in the work area
function RollerFertilizerSpecialization:processRollerArea(superFunc, workArea, dt)

    -- Mulch and fertilize any cover crops in the work area
    CoverCropUtils.mulchAndFertilizeCoverCrops(workArea)

    -- Execute base game behavior
    return superFunc(self, workArea, dt)
end
