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

    local caSettings = g_currentMission.conservationAgricultureSettings
    local precisionFarmingIsActive = g_modIsLoaded["FS22_precisionFarming"]

    local cultivatorBonusBefore = nil
    local nitrogenMap = nil
    if caSettings.cultivatorBonusIsEnabled then
        if not precisionFarmingIsActive then
            -- Fertilize any cover crops in the work area, but don't mulch them (since the soil is effectively uncovered)
            CoverCropUtils.mulchAndFertilizeCoverCrops(self, workArea, false, false, 0)
        else
            -- Precision Farming alraedy has a logic for this, but we can change the amount
            nitrogenMap = FS22_precisionFarming.g_precisionFarming.nitrogenMap
            cultivatorBonusBefore = nitrogenMap.catchCropsStateChange
            nitrogenMap.catchCropsStateChange = caSettings:getCultivatorNitrogenValue()
        end
    end

    -- Execute base game behavior. In case of precision farming, this fertilizes the field now, but only for shallow cultivators
    local realArea, area = superFunc(self, workArea, dt)

    -- Set the nitrogen map catch crops state change value back to normal if required
    if nitrogenMap ~= nil then
        nitrogenMap.catchCropsStateChange = cultivatorBonusBefore
    end

    return realArea, area
end
