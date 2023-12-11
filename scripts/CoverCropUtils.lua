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

    -- Don't modify anything outside of fields
    local onFieldFilter = DensityMapFilter.new(fruitModifier)
    onFieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

    -- Allow modifying the fertilization type (manure, slurry, ...)
    local sprayTypeModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.SPRAY_TYPE)

    -- Allow modifying the fertilization amount
    local sprayLevelModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.SPRAY_LEVEL)
    local maxSprayLevel = g_currentMission.fieldGroundSystem:getMaxValue(FieldDensityMap.SPRAY_LEVEL)

    -- For every possible fruit:
    for _, desc in pairs(g_fruitTypeManager:getFruitTypes()) do

        -- Set up modifiers and filters so we modify only the state of this fruit type
        fruitModifier:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
        fruitFilter:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
        -- Filter for forageable and harvestable crops
        fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, desc.minForageGrowthState, desc.minHarvestingGrowthState)

        -- Cut (mulch) any pixels which match the fruit type (including growth stage) and haven't had their stubble level set to max
        local _, numPixelsAffected, _ = fruitModifier:executeSet(desc.cutState, fruitFilter, onFieldFilter)
        if numPixelsAffected > 0 then

            -- since we cut the ground, we need to filter for a cut fruit now
            fruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, desc.cutState)

            -- Set the spray type to MANURE (since it's basically biological fertilizer) and the spray level to max for any pixel which were just mulched
            sprayTypeModifier:executeSet(FieldSprayType.MANURE, fruitFilter, onFieldFilter)
            sprayLevelModifier:executeSet(maxSprayLevel, fruitFilter, onFieldFilter)
        end
    end

end