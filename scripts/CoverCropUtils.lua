CoverCropUtils = {}

function CoverCropUtils.getDensityMapModifier(coords, densityMapType)
    -- Prepare a modifier for testing for specific ground data
    local densityMapMapId, densityMapFirstChannel, densityMapNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(densityMapType)
    local densityMapModifier = DensityMapModifier.new(densityMapMapId, densityMapFirstChannel, densityMapNumChannels, g_currentMission.terrainRootNode)

    -- Configure the modifier to analyze or modify the given rectangle (defined through 3 corner points)
    densityMapModifier:setParallelogramWorldCoords(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, DensityCoordType.POINT_POINT_POINT)

    return densityMapModifier
end

--- Mulches the area at the given coordinates in case there is a crop which matches the supplied ground filter
---@param   workArea    table   @A rectangle defined through three points which determines the area to be processed
function CoverCropUtils.mulchAndFertilizeCoverCrops(workArea)

    -- Retrieve the world coordinates for the current Roller area (a subset of the Roller's extents)
    local startX,_,startZ = getWorldTranslation(workArea.start)
    local widthX,_,widthZ = getWorldTranslation(workArea.width)
    local heightX,_,heightZ = getWorldTranslation(workArea.height)
    local coords = {
        x1 = startX,
        z1 = startZ,
        x2 = widthX,
        z2 = widthZ,
        x3 = heightX,
        z3 = heightZ
    }

    -- These will be used in the loop later. The parameters will be overriden later
    local fruitModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.GROUND_TYPE)
    local fruitFilter = DensityMapFilter.new(fruitModifier)

    -- filter for oilseed radish, ready-to-harvest crops and withered crops
    local groundTypeFilter = DensityMapFilter.new(fruitModifier)
    groundTypeFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, FieldGroundType.HARVEST_READY, FieldGroundType.HARVEST_READY_OTHER)

    -- Allow modifying the fertilization type (manure, slurry, ...)
    local sprayTypeModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.SPRAY_TYPE)

    -- Allow modifying the fertilization amount
    local sprayLevelModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.SPRAY_LEVEL)
    local maxSprayLevel = g_currentMission.fieldGroundSystem:getMaxValue(FieldDensityMap.SPRAY_LEVEL)

    -- Allow modifying the stubble shred amount
    local stubbleShredModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.STUBBLE_SHRED)
    local maxStubbleLevel = g_currentMission.fieldGroundSystem:getMaxValue(FieldDensityMap.STUBBLE_SHRED)

    -- Filter for an area which hasn't received max stubble level yet
    local stubbleFilter = DensityMapFilter.new(stubbleShredModifier)
    stubbleFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, maxStubbleLevel - 1)

    -- For every possible fruit:
    for _, desc in pairs(g_fruitTypeManager:getFruitTypes()) do

        -- Set up modifiers and filters so we modify only the state of this fruit type
        fruitModifier:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
        fruitFilter:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
        fruitFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

        -- Cut (mulch) any pixels which match the fruit type, the ground type, and haven't had their stubble level set to max 
        local _, numPixelsAffected, _ = fruitModifier:executeSet(desc.cutState, groundTypeFilter, fruitFilter, stubbleFilter)
        if numPixelsAffected > 0 then
            -- Set the spray type to MANURE (since it's basically biological fertilizer) and the spray level to max for any pixel which was just mulched
            -- There's no need to use the stubble filter now, the worst which can happen is changing the same pixels to the same values again
            sprayTypeModifier:executeSet(FieldSprayType.MANURE, groundTypeFilter, fruitFilter)
            sprayLevelModifier:executeSet(maxSprayLevel, groundTypeFilter, fruitFilter)
            -- Set the stubble level to maximum to mark the field as processed
            stubbleShredModifier:executeSet(maxStubbleLevel, groundTypeFilter, fruitFilter)
        end
    end

end