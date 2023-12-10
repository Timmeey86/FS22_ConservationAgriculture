--- This class is responsible for adding a specialization to Mulchers which fertilizes when mulching over oilseed radish
---Additionally, the ground will get a mulched and seedbed status
MulcherFertilizerSpecialization = {
}

--- Checks for other required specializations.
---Since this is only added to implements with the Mulcher specilization anyway, we don't need to check anything here.
---@param   specializations     table   @A table of existing specializations (unused).
---@return  boolean     @Always true
function MulcherFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

--- Overrides the processMulcherArea so we can add fertilizer during the mulching process
---@param   vehicleType     table     @Provides information about the current vehicle (or rather implement) type.
function MulcherFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processMulcherArea", MulcherFertilizerSpecialization.processMulcherArea)
    print("MulcherFertilizerSpecialization: Hooked into vehicle type " .. vehicleType.name)
end

--- Adds fertilizer when mulching ready-to-harvest cover crops
---@param   superFunc   function        @The GIANTS implementation of the method.
---@param   workArea    table           @Provides information about the area to be mulched.
---@param   dt          table           @delta time? Not used here.
---@return  integer     @The amount of pixels which were processed
---@return  integer     @The amount of pixels in the work area
function MulcherFertilizerSpecialization:processMulcherArea(superFunc, workArea, dt)
    -- Retrieve the world coordinates for the current Mulcher area (a subset of the Mulcher's extents)
    local sx,_,sz = getWorldTranslation(workArea.start)
    local wx,_,wz = getWorldTranslation(workArea.width)
    local hx,_,hz = getWorldTranslation(workArea.height)

    -- Retrieve a modifier and filter for testing for cover crop pixels and for eventually modifying them
    local groundTypeModifier, groundTypeFilter = CoverCropUtils.getCoverCropModifierAndFilter(sx,sz, wx,wz, hx,hz)

    -- Check if there are any cover crop pixels in the work area
    local numOfPixelsMatchingFilter = CoverCropUtils.getCoverCropPixels(groundTypeModifier, groundTypeFilter)

    if numOfPixelsMatchingFilter > 0 then

        -- Apply a mulching effect, a fertilizing stage and set the ground type to stubble tillage so we don't re-apply this stuff endlessly
        -- We reuse the functions used by mulchers and fertilizers to hopefully profit from future changes without adapting the mod

        -- Mulching effect
        FSDensityMapUtil.updateMulcherArea(sx,sz, wx,wz, hx,hz)
        CoverCropUtils.applyFertilizer(sx,sz, wx,wz, hx,hz)
        CoverCropUtils.setGroundToStubbleTillage(groundTypeModifier, groundTypeFilter)
    end

    -- Execute base game behavior now. Won't do anything if we changed the ground already.
    return superFunc(self, workArea, dt)
end
