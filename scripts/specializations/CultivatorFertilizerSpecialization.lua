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
    if caSettings.cultivatorBonusIsEnabled then
        -- Fertilize any cover crops in the work area, but don't mulch them (since the soil is effectively uncovered)
        CoverCropUtils.mulchAndFertilizeCoverCrops(self, workArea, false, false, caSettings:getCultivatorNitrogenValue())
    end

    -- Execute base game behavior. In case of precision farming, this fertilizes the field now, but only for shallow cultivators
    local area, totalArea = superFunc(self, workArea, dt)

    if caSettings.cultivatorBonusIsEnabled and precisionFarmingIsActive then
        -- Change the ground type to chopper straw again; otherwise, precision farming doesn't know we handled the ground already.
        --[[ 
            Note:   Currently, this always changes the ground when using a cultivator, even when not seeding into cover crops.
                    Unfortunately, this is the only way to get a stable nitrogen application.
                    The following alternatives have been tried but failed:
                    - Setting the whole work area to straw only if cover crops have been terminated somewhere
                    - Setting only those work area parts to straw which have had cover crops terminated
                    This would always lead to too much fertilizer in parts, probably because of the mismatch of the map grid and the PF nitrogen map size
        ]]
        local startX,_,startZ = getWorldTranslation(workArea.start)
        local widthX,_,widthZ = getWorldTranslation(workArea.width)
        local heightX,_,heightZ = getWorldTranslation(workArea.height)
        local strawGroundType = g_currentMission.fieldGroundSystem:getChopperTypeValue(FieldChopperType.CHOPPER_STRAW)
        FSDensityMapUtil.setGroundTypeLayerArea(startX, startZ, widthX, widthZ, heightX, heightZ, strawGroundType)
    end

    return area, totalArea
end
