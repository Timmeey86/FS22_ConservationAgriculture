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

    -- Exclude fruit types which wouldn't be cover crops. They don't seem to share common properties which separate them from the other types.
    local excludedFruitTypes = Set {
        FruitType.COTTON,
        FruitType.GRAPE,
        FruitType.OLIVE,
        FruitType.POPLAR
    }

    --[[
    -- The game stores nitrogen levels, especially for precision farming, in a 2m x 2m grid.
    -- Since it's unclear how precision farming works internally, we can't use the DensityMapModifier objects for modifying the nitrogen map.
    -- Therefore the current approach is to analyze each 2m x 2m cell which intersects the work area independently

    -- Retrieve the minimum/maximum X and Z values
    local minX = math.min(coords.x1, coords.x2, coords.x3)
    local maxX = math.max(coords.x1, coords.x2, coords.x3)
    local minZ = math.min(coords.z1, coords.z2, coords.z3)
    local maxZ = math.max(coords.z1, coords.z2, coords.z3)

    -- Round the X/Z values outwards to a 2 meter resolution
    minX = math.floor(minX / 2) * 2
    maxX = math.floor((maxX + 1.99999) / 2) * 2
    minZ = math.floor(minZ / 2) * 2
    maxZ = math.floor((maxZ + 1.99999) / 2) * 2

    -- Build a list of squares to be analyzed and use their center coordinate
    local nearbySquares = {}
    for x = minX, maxX, 2  do
        for z = minZ, maxZ, 2 do
            table.insert(nearbySquares, {x + 1, z + 1})
        end
    end

    -- Analyze each square separately
    for _, currentSquare in pairs(nearbySquares) do
        ]]
        
    -- For every possible fruit:
    for _, desc in pairs(g_fruitTypeManager:getFruitTypes()) do
        -- With the table above, this is technically O(n³). 
        -- With a 48m wide roller and a modded map, this would be e.g. 20 * 20 * 25 = 10,000 iterations, which should still be alright

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

            -- Cut (mulch) any pixels which match the fruit type (including growth stage) and haven't had their stubble level set to max
            local _, numPixelsAffected, _ = fruitModifier:executeSet(desc.cutState, fruitFilter, onFieldFilter)
            if numPixelsAffected > 0 then

                -- since we cut the ground, we need to filter for a cut fruit now
                fruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, desc.cutState)

                -- Set the spray type to MANURE (since it's basically biological fertilizer) and the spray level to max for any pixel which were just mulched
                sprayTypeModifier:executeSet(FieldSprayType.MANURE, fruitFilter, onFieldFilter)
                sprayLevelModifier:executeSet(maxSprayLevel, fruitFilter, onFieldFilter)

                -- precision farming: modify the nitrogen map
                local nitrogenMap = FS22_precisionFarming.g_precisionFarming.nitrogenMap
                if nitrogenMap ~= nil then
                    local noSprayAuto = false
                    local sprayAmountManual = 10
                    local forcedFruitType = nil
                    local nitrogenLevelOffset = 0
                    local defaultNitrogenRequirementIndex = 1

                    -- TODO: Iterate over the work area, find out if it's gonna be mulched and fertilize only if so


                    --[[local nitrogenLevelBefore = nitrogenMap:getLevelAtWorldPos(coords.x1, coords.z1)
                    nitrogenMap:updateSprayArea(coords.x1, coords.z1, coords.x1, coords.z1, coords.x1, coords.z1, SprayType.MANURE, SprayType.MANURE, false, 10, nil, 0, 1)
                    local nitrogenLevelAfter = nitrogenMap:getLevelAtWorldPos(coords.x1, coords.z1)
                    print(tostring(nitrogenLevelBefore) .. "->" .. tostring(nitrogenLevelAfter))
                    for i = -100, 100, 1 do
                        local xOffset = i / 50
                        print(tostring(xOffset) .. ": " .. tostring(nitrogenMap:getLevelAtWorldPos(coords.x1 + xOffset, coords.z1)))
                    end
                    print("Done")]]--


                    -- TODO: This will always affect the whole work area
                    local numPixelsChanged, unknown, autoSoilTypeIndex, foundLevel, targetLevel, changeLevel =
                        nitrogenMap:updateSprayArea(
                            coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3,
                            SprayType.MANURE, SprayType.MANURE, noSprayAuto, sprayAmountManual,forcedFruitType, nitrogenLevelOffset, defaultNitrogenRequirementIndex)
                    --print(tostring(numPixelsChanged) .. " / " .. tostring(unknown) .. " / " .. tostring(autoSoilTypeIndex) .. " / " ..
                    --      tostring(foundLevel) .. " / " .. tostring(targetLevel) .. " / " .. tostring(changeLevel))
                end

                -- TODO: Rolling does not create a mulch layer despite being in a cut state. We probably need to modify a different layer

            end

        end
    end
end