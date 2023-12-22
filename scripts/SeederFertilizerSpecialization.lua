--- This class is responsible for adding a specialization to Seeders in order to provide a fertilization boost when direct seeding into cover crops
--- Note that basegame adds one fertilization stage and precision farming 25kg of nitrogen for oilseed radish
SeederFertilizerSpecialization = {
}

--- Checks for other required specializations.
---Since this is only added to implements with the SowingMachine specilization anyway, we don't need to check anything here.
---@param   specializations     table   @A table of existing specializations (unused).
---@return  boolean     @Always true
function SeederFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

--- Overrides the processRollerArea so we can add fertilizer during the sowing process
---@param   vehicleType     table     @Provides information about the current vehicle (or rather implement) type.
function SeederFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSowingMachineArea", SeederFertilizerSpecialization.processSowingMachineArea)
    print("SeederFertilizerSpecialization: Hooked into vehicle type " .. vehicleType.name)
end

--- Adds fertilizer when sowing ready-to-harvest cover crops
---@param   superFunc   function        @The GIANTS implementation of the method.
---@param   workArea    table           @Provides information about the area to be mulched.
---@param   dt          table           @delta time? Not used here.
---@return  integer     @The amount of pixels which were processed
---@return  integer     @The amount of pixels in the work area
function SeederFertilizerSpecialization:processSowingMachineArea(superFunc, workArea, dt)

    -- Fertilize any cover crops in the work area, but do not set the "mulched" ground 
    -- Otherwise, there would be no benefit of mulching/roller crimping before sowing
    CoverCropUtils.mulchAndFertilizeCoverCrops(workArea, false)

    -- Execute base game behavior
    return superFunc(self, workArea, dt)
end
