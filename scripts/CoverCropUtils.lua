CoverCropUtils = {}

--- Creates a modifier for the density map of the given type and restricts it to the given coordinates
---@param coords            table       @The coordinates to modify
---@params densityMapType   integer     @The type of the density map to modify
---@return  table   @A modifier for the given type and coordinates 
function CoverCropUtils.getDensityMapModifier(coords, densityMapType)
    -- Prepare a modifier for testing for specific ground data
    local densityMapMapId, densityMapFirstChannel, densityMapNumChannels = g_currentMission.fieldGroundSystem:getDensityMapData(densityMapType)
    local densityMapModifier = DensityMapModifier.new(densityMapMapId, densityMapFirstChannel, densityMapNumChannels, g_currentMission.terrainRootNode)

    -- Configure the modifier to analyze or modify the given rectangle (defined through 3 corner points)
    densityMapModifier:setParallelogramWorldCoords(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, DensityCoordType.POINT_POINT_POINT)

    return densityMapModifier
end

--- Creates a lookup table from a list in order to simulate a "contains" function
---@param list table    @a one-dimensional list
---@return table    @A table which allows lookup like if myTable["myElement"] do
function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

--- Sets up the fruit filter to filter for the forageable growth stages
---@param fruitFilter table @the fruit filter to be modifeid
---@param fruitDescription table @provides information about the current fruit
function CoverCropUtils.filterForForageableFruit(fruitFilter, fruitDescription)
    -- If a crop has a "forage" state, allow only that one, otherwise allow min
    local minForageState = fruitDescription.minForageGrowthState
    local maxForageState = fruitDescription.minHarvestingGrowthState
    if fruitDescription.maxPreparingGrowthState > 0 then
        -- root crops: Mulch only before haulm topping
        minForageState = fruitDescription.maxPreparingGrowthState
        maxForageState = minForageState
    elseif maxForageState > minForageState then
        -- grains etc: Mulch one stage before harvesting
        maxForageState = maxForageState - 1 -- exclude the "ready to harvest" state
    elseif fruitDescription.index == FruitType.GRASS or fruitDescription.index == FruitType.MEADOW then
        -- grass/meadow: Mulch any ready-to-harvest stage
        maxForageState = fruitDescription.maxHarvestingGrowthState
    end
    fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, minForageState, maxForageState)
end

--- Mulches the area at the given coordinates in case there is a crop which matches the supplied ground filter
---@param   workArea    table   @A rectangle defined through three points which determines the area to be processed
---@param   groundShallBeMulched    boolean     @True if a mulching bonus shall be applied to the ground
function CoverCropUtils.mulchAndFertilizeCoverCrops(workArea, groundShallBeMulched)

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
    local sprayLevelFilter = DensityMapFilter.new(sprayLevelModifier)

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

            CoverCropUtils.filterForForageableFruit(fruitFilter, desc)

            -- if possible, use the mulched fruit state, otherwise use the cut state
            local mulchedFruitState = desc.cutState or 0
            if groundShallBeMulched and desc.mulcher ~= nil and desc.mulcher.hasChopperGroundLayer then
                mulchedFruitState = desc.mulcher.state
            end

            -- Cut (mulch) any pixels which match the fruit type (including growth stage) and haven't had their stubble level set to max
            local _, numPixelsAffected, _ = fruitModifier:executeSet(mulchedFruitState, fruitFilter, onFieldFilter)
            if numPixelsAffected > 0 then

                -- since we cut the ground, we need to filter for a cut fruit now
                fruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, mulchedFruitState)

                -- Set the "mulched" flag
                if groundShallBeMulched then
                    stubbleShredModifier:executeSet(1, fruitFilter, onFieldFilter)
                end

                -- "Spray" straw on the ground
                sprayTypeModifier:executeSet(strawSprayType, fruitFilter, onFieldFilter)

                -- Increase the spray level up to 1 below max
                for i = 1, maxSprayLevel - 1 do
                    local targetSprayLevel = maxSprayLevel - i
                    local currentSprayLevel = targetSprayLevel - 1
                    sprayLevelFilter:setValueCompareParams(DensityValueCompareType.EQUAL, currentSprayLevel)
                    sprayLevelModifier:executeSet(targetSprayLevel, sprayLevelFilter, fruitFilter, onFieldFilter)
                end

                -- precision farming: modify the nitrogen map
                local precisionFarming = FS22_precisionFarming.g_precisionFarming
                if precisionFarming ~= nil then
                    local nitrogenMap = precisionFarming.nitrogenMap
                    local soilMap = precisionFarming.soilMap
                    local sprayAuto = true
                    local defaultNitrogenRequirementIndex = 1

                    -- Fertilize only if soil sampling has been done. Otherwise the player would end up with max nitrogen level every time
                    -- We only check if at least one corner is on sampled soil to not make the check too expensive
                    if soilMap:getTypeIndexAtWorldPos(coords.x1, coords.z1) > 0 or
                       soilMap:getTypeIndexAtWorldPos(coords.x2, coords.z2) > 0 or
                       soilMap:getTypeIndexAtWorldPos(coords.x3, coords.z3) > 0 then
                       
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
end