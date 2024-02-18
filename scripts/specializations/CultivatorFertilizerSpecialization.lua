---This class is responsible for adding a specialization to cultivators which fertilizes when working oilseed radish into the field
CultivatorFertilizerSpecialization = {
}

---Checks for other required specializations.
---Since this is only added to implements with the Cultivator specilization anyway, we don't need to check anything here.
---@param   specializations     table   @A table of existing specializations (unused).
---@return  boolean     @Always true
function CultivatorFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

---Overrides the processCultivatorArea so we can add fertilizer during the rolling process
---@param   vehicleType     table     @Provides information about the current vehicle (or rather implement) type.
function CultivatorFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processCultivatorArea", CultivatorFertilizerSpecialization.processCultivatorArea)
end

---Adds fertilizer when rolling ready-to-harvest cover crops
---@param   superFunc   function        @The GIANTS implementation of the method.
---@param   workArea    table           @Provides information about the area to be mulched.
---@param   dt          table           @delta time? Not used here.
---@return  integer     @The amount of pixels which were processed
---@return  integer     @The amount of pixels in the work area
function CultivatorFertilizerSpecialization:processCultivatorArea(superFunc, workArea, dt)

    local settings = g_currentMission.conservationAgricultureSettings
    if settings.cultivatorBonusIsEnabled and not g_modIsLoaded["FS22_precisionFarming"] then
        -- Fertilize any cover crops in the work area, but don't mulch them (since the soil is effectively uncovered)
        CoverCropUtils.mulchAndFertilizeCoverCrops(self, workArea, false, false)
    end

    -- Execute base game behavior
    return superFunc(self, workArea, dt)
end
