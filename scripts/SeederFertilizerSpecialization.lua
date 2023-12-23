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

function SeederFertilizerSpecialization:createFieldArea(workArea)
    -- Retrieve world coordinates for the work area
    local coords = CoverCropUtils.getWorldCoords(workArea)

    -- Clear any deco stuff which is in the way
    FSDensityMapUtil.clearDecoArea(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3)

    -- Set any ground which is not on the field to plowed. This is only temporary as that area will be seeded into right after
    local groundTypeModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.GROUND_TYPE)
    local notOnFieldFilter = DensityMapFilter.new(groundTypeModifier)
    notOnFieldFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
    groundTypeModifier:executeSet(g_currentMission.fieldGroundSystem:getFieldGroundValue(FieldGroundType.PLOWED), notOnFieldFilter)
end

--- Adds fertilizer when sowing ready-to-harvest cover crops
---@param   superFunc   function        @The GIANTS implementation of the method.
---@param   workArea    table           @Provides information about the area to be mulched.
---@param   dt          table           @delta time? Not used here.
---@return  integer     @The amount of pixels which were processed
---@return  integer     @The amount of pixels in the work area
function SeederFertilizerSpecialization:processSowingMachineArea(superFunc, workArea, dt)

    local basegameSpec = self.spec_sowingMachine

    -- Do nothing if the machine is turned off, stationary or the fruit can't be planted (we might have to add more exclusions in future)
    if not basegameSpec.workAreaParameters.isActive or self:getLastSpeed() <= 0.5 or not basegameSpec.workAreaParameters.canFruitBePlanted then
        return 0, 0
    end

    -- Create fields where necessary if that feature is turned on
    if true then
        SeederFertilizerSpecialization:createFieldArea(workArea)
    end

    -- Fertilize any cover crops in the work area, but do not set the "mulched" ground 
    -- Otherwise, there would be no benefit of mulching/roller crimping before sowing
    CoverCropUtils.mulchAndFertilizeCoverCrops(workArea, false)

    -- Execute base game behavior
    return superFunc(self, workArea, dt)
end
