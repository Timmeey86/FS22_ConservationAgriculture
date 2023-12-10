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
    -- Retrieve the world coordinates for the current Roller area (a subset of the Roller's extents)
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

    -- Execute base game behavior (If we created stubble tillage before, this will now create a seedbed).
    return superFunc(self, workArea, dt)
end
