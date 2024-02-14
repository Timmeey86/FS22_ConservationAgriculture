---@Class ChopperFertilizerSpecialization
---This class extends the Combine specialization so it fertilizes the field when straw is being chopped instead of being swathed
---This makes deciding between chopping and swathing a more interesting decision
ChopperFertilizerSpecialization = {}

---Checks for other required specializations.
---Since this is only added to implements with the Combine specilization anyway, we don't need to check anything here.
---@param   specializations     table   @A table of existing specializations (unused).
---@return  boolean     @Always true
function ChopperFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

---Overrides the processCombineChopperArea so we can add fertilizer during the straw chopping process
---@param   vehicleType     table     @Provides information about the current vehicle (or rather implement) type.
function ChopperFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processCombineChopperArea", ChopperFertilizerSpecialization.processCombineChopperArea)
end

local function toCoords(workArea)
    -- Translate the work area into world coordinates. The coordinates are three corner points of a rectangle, each defined by (X|Y|Z)
    local coords = {}
    coords.x1, coords.y1, coords.z1 = getWorldTranslation(workArea.start)
    coords.x2, coords.y2, coords.z2 = getWorldTranslation(workArea.width)
    coords.x3, coords.y3, coords.z3 = getWorldTranslation(workArea.height)
    return coords
end

---Fertilizes the ground whenever straw is being chopped (if enabled)
---@param superFunc function @The base game function 
---@param workArea table @The work area which is being processed
function ChopperFertilizerSpecialization:processCombineChopperArea(superFunc, workArea)
    local combineSpec = self.spec_combine
    local strawGroundType = combineSpec.workAreaParameters.strawGroundType

    local numPixelsBefore = nil
    local workAreaCoords, sprayTypeModifier, sprayTypeFilter

    if not combineSpec.isSwathActive and strawGroundType ~= nil then
        --- Find out the current number of pixels which are straw
        workAreaCoords = toCoords(workArea)
        sprayTypeModifier = CoverCropUtils.getDensityMapModifier(workAreaCoords, FieldDensityMap.SPRAY_TYPE) -- straw is actually a spray type
        sprayTypeFilter = DensityMapFilter.new(sprayTypeModifier)
        sprayTypeFilter:setValueCompareParams(DensityValueCompareType.EQUAL, strawGroundType)
        _, numPixelsBefore = sprayTypeModifier:executeGet(sprayTypeFilter)
    end

    -- Execute base game behavior
    local lastRealArea, lastArea = superFunc(self, workArea)

    if numPixelsBefore ~= nil then
        -- Find out if there are more straw pixels now
        local _, numPixelsAfter = sprayTypeModifier:executeGet(sprayTypeFilter)

        if numPixelsAfter > numPixelsBefore then
            -- Fertilize the field
            local sprayLevelModifier = CoverCropUtils.getDensityMapModifier(workAreaCoords, FieldDensityMap.SPRAY_LEVEL)
            local sprayLevelFilter = DensityMapFilter.new(sprayLevelModifier)

            -- Don't modify anything outside of fields
            local onFieldFilter = DensityMapFilter.new(CoverCropUtils.getDensityMapModifier(workAreaCoords, FieldDensityMap.GROUND_TYPE))
            onFieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

            -- Fertilize the work area which was sprayed
            CoverCropUtils.applyFertilizer(workAreaCoords, sprayLevelModifier, sprayLevelFilter, onFieldFilter, nil)
        end
    end

    return lastRealArea, lastArea
end