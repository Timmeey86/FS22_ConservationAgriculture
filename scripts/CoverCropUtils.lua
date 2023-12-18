CoverCropUtils = {}

function CoverCropUtils.getDensityMapModifier(coords, densityMapType)
    -- Prepare a modifier for testing for specific ground data
    local densityMapMapId, densityMapFirstChannel, densityMapNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(densityMapType)
    local densityMapModifier = DensityMapModifier.new(densityMapMapId, densityMapFirstChannel, densityMapNumChannels, g_currentMission.terrainRootNode)

    -- Configure the modifier to analyze or modify the given rectangle (defined through 3 corner points)
    densityMapModifier:setParallelogramWorldCoords(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, DensityCoordType.POINT_POINT_POINT)

    return densityMapModifier
end

--- Creates a lookup table from a list in order to simulate a "contains" function
---@param list table    a one-dimensional list
function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
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

    -- Allow setting to a mulched state (by setting the stubble shred flag and "spraying" straw across the ground)
    local stubbleShredModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.STUBBLE_SHRED)
    local strawSprayType = g_currentMission.fieldGroundSystem:getChopperTypeValue(FieldChopperType.CHOPPER_STRAW)

    -- Exclude fruit types which wouldn't be cover crops. They don't seem to share common properties which separate them from the other types.
    local excludedFruitTypes = Set {
        FruitType.COTTON,
        FruitType.GRAPE,
        FruitType.OLIVE,
        FruitType.POPLAR
    }

    -- For every possible fruit:
    for _, desc in pairs(g_fruitTypeManager:getFruitTypes()) do

        -- Read as: "if excluded fruit types does not contain desc.index then"
        if not excludedFruitTypes[desc.index] then

            -- Set up modifiers and filters so we modify only the state of this fruit type
            fruitModifier:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
            fruitFilter:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
            -- If a crop has a "forage" state, allow only that one, otherwise allow min
            local minForageState = desc.minForageGrowthState
            local maxForageState = desc.minHarvestingGrowthState
            if desc.maxPreparingGrowthState > 0 then
                -- root crops: Mulch only before haulm topping
                minForageState = desc.maxPreparingGrowthState
                maxForageState = minForageState
            elseif maxForageState > minForageState then
                -- grains etc: Mulch one stage before harvesting
                maxForageState = maxForageState - 1 -- exclude the "ready to harvest" state
            elseif desc.index == FruitType.GRASS or desc.index == FruitType.MEADOW then
                -- grass/meadow: Mulch any ready-to-harvest stage
                maxForageState = desc.maxHarvestingGrowthState
            end
            fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, minForageState, maxForageState)


            -- if possible, use the mulched fruit state, otherwise use the cut state
            local mulchedFruitState = desc.cutState or 0
            if desc.mulcher ~= nil and desc.mulcher.hasChopperGroundLayer then
                mulchedFruitState = desc.mulcher.state
            end
            
            -- Cut (mulch) any pixels which match the fruit type (including growth stage) and haven't had their stubble level set to max
            local _, numPixelsAffected, _ = fruitModifier:executeSet(mulchedFruitState, fruitFilter, onFieldFilter)
            if numPixelsAffected > 0 then

                -- since we cut the ground, we need to filter for a cut fruit now
                fruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, mulchedFruitState)

                -- Set the "mulched" flag
                stubbleShredModifier:executeSet(1, fruitFilter, onFieldFilter)
                
                -- Set the spray level to max for any pixel which was just mulched
                sprayTypeModifier:executeSet(strawSprayType, fruitFilter, onFieldFilter)
                sprayLevelModifier:executeSet(maxSprayLevel, fruitFilter, onFieldFilter)

                -- precision farming: modify the nitrogen map
                local precisionFarming = FS22_precisionFarming.g_precisionFarming
                if precisionFarming ~= nil then
                    local nitrogenMap = precisionFarming.nitrogenMap
                    local sprayAuto = true
                    local defaultNitrogenRequirementIndex = 1

                    -- The nitrogen map has a 2m x 2m resolution, while mulching can occur multiple times within each cell
                    -- Therefore, we simply fertilize the whole work area to the target level of sunflowers on the current soil type
                    -- This way, the player will never overshoot fertilization, no matter what is planted afterwards, since sunflower has the lowest requirements
                    -- We need to use FERTILIZER rather than MANURE here since the automode wouldn't work otherwise
                    nitrogenMap:updateSprayArea(
                        coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3,
                        SprayType.FERTILIZER, SprayType.FERTILIZER, sprayAuto, 0, FruitType.SUNFLOWER, 0, defaultNitrogenRequirementIndex)
                end
            end
        end
    end
end