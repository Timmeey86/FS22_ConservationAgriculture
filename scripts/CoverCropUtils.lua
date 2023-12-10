CoverCropUtils = {}

--- Creates a DensityMapModifier which can identify pixels which count as "Cover Crop".
---Currently, this is: 
--- - Anything which is ready-to-harvest, including oilseed radish
--- - Anything which is withered (actually, "ready-to-harvest oildseed radish shares the same ground type as withered crops")
---@param   startX      integer     @the X coordinate of the first corner point of the work area
---@param   startZ      integer     @the Z coordinate of the first corner point of the work area
---@param   widthZ      integer     @the Z coordinate of the second corner point of the work area
---@param   widthX      integer     @the X coordinate of the second corner point of the work area
---@param   heightX     integer     @the X coordinate of the third corner point of the work area
---@param   heightZ     integer     @the Z coordinate of the third corner point of the work area
---@return  table   @the object used for testing or modifying groundType
---@return  table   @used for filtering for pixels which are HARVEST_READY or HARVEST_READY_OTHER (e.g. withered or oilseed radish)    
function CoverCropUtils.getCoverCropModifierAndFilter(startX, startZ, widthX, widthZ, heightX, heightZ)
    -- Prepare a modifier for testing for specific ground data
    local groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(FieldDensityMap.GROUND_TYPE)
    local groundTypeModifier = DensityMapModifier.new(groundTypeMapId, groundTypeFirstChannel, groundTypeNumChannels, g_currentMission.terrainRootNode)

    -- Analyze the supplied area
    groundTypeModifier:setParallelogramWorldCoords(startX,startZ, widthX,widthZ, heightX,heightZ, DensityCoordType.POINT_POINT_POINT)

    -- ... and filter for oilseed radish, ready-to-harvest crops and withered crops
    local groundTypeFilter = DensityMapFilter.new(groundTypeModifier)
    groundTypeFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, FieldGroundType.HARVEST_READY, FieldGroundType.HARVEST_READY_OTHER)

    return groundTypeModifier, groundTypeFilter
end

--- Finds out the amount of pixels which are considered "cover crop" which can be mulched/rolled
---@param   groundTypeModifier  table       a modifier which has been preferred for the work area to be analyzed
---@param   groundTypeFilter    table       the filter for cover crops which can be mulched/rolled
---@return  integer     @the amount of pixels which match the filter
---@return  integer     @the amount of pixels which were analyzed
function CoverCropUtils.getCoverCropPixels(groundTypeModifier, groundTypeFilter)
    
    -- Check if any pixels within the work area match the filter
    -- First return parameter is an unknown number, but looks like we don't need it (other mods call it density or acc)
    local _, numOfPixelsMatchingFilter, numOfPixelsAnalyzed = groundTypeModifier:executeGet(groundTypeFilter)

    return numOfPixelsMatchingFilter, numOfPixelsAnalyzed
end

--- Applies fertilizer to the given area
---@param   startX      integer     @the X coordinate of the first corner point of the work area
---@param   startZ      integer     @the Z coordinate of the first corner point of the work area
---@param   widthZ      integer     @the Z coordinate of the second corner point of the work area
---@param   widthX      integer     @the X coordinate of the second corner point of the work area
---@param   heightX     integer     @the X coordinate of the third corner point of the work area
---@param   heightZ     integer     @the Z coordinate of the third corner point of the work area
function CoverCropUtils.applyFertilizer(startX, startZ, widthX, widthZ, heightX, heightZ)

    -- Fertilizer Stage. We apply manure rather than fertilizer since that's the closest thing to biological fertilizer in the base game
    local sprayType = FieldSprayType.MANURE
    local sprayLevels = 2
    FSDensityMapUtil.updateSprayArea(startX, startZ, widthX, widthZ, heightX, heightZ, sprayType, sprayLevels)
end

--- Sets the ground to stubble tillage
---@param   groundTypeModifier  table   @the modifier used for changing the ground. Must be prepared with the work area's parallelogram.
---@param   groundTypeFilter    table   @the filter used for changing the ground. Must already contain conditions which filter for cover crops
function CoverCropUtils.setGroundToStubbleTillage(groundTypeModifier, groundTypeFilter)
    -- Change the ground to be stubble tillage (updateMulcherArea doesn't seem to do this). That's the closest thing to a terminated mulch layer currently.
    groundTypeModifier:executeSet(FieldGroundType.STUBBLE_TILLAGE, groundTypeFilter)
end