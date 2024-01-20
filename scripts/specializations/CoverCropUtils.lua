CoverCropUtils = {}

---Creates a modifier for the density map of the given type and restricts it to the given coordinates
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

---Creates a lookup table from a list in order to simulate a "contains" function
---@param list table    @a one-dimensional list
---@return table    @A table which allows lookup like if myTable["myElement"] do
function Set(list)
    local set = {}
    for _, l in ipairs(list) do set[l] = true end
    return set
end

---Sets up the fruit filter to filter for the forageable growth stages. We consider "half grown" forageable for most things.
---We can't be too restrictive, as otherwise some things like wheat or barley would never be ready in time for the next crop.
---@param fruitFilter table @the fruit filter to be modifeid
---@param fruitTypeIndex integer @the index of the fruit type in the global list of fruit types
function CoverCropUtils.filterForForageableFruit(fruitFilter, fruitTypeIndex)
    local rollerCrimpingGrowthStates = g_rollerCrimpingData:getForageableStates(fruitTypeIndex)

    fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, rollerCrimpingGrowthStates.min, rollerCrimpingGrowthStates.max)
end

---Retrieves the world coordinates for the given work area, split into ten parts
---@param workArea table @The work area to be analyzed
---@return table @A coordinates structure consisting of x1..x3 and z1..z3 for several parts of the work area
function CoverCropUtils.getWorldCoordParts(workArea)

    -- Translate the work area into world coordinates. The coordinates are three corner points of a rectangle, each defined by (X|Y|Z)
    local startX,startY,startZ = getWorldTranslation(workArea.start)
    local widthX,widthY,widthZ = getWorldTranslation(workArea.width)
    local heightX,heightY,heightZ = getWorldTranslation(workArea.height)

    -- Calculate the distances between the three points and the number of parts to split the work area into
    -- We need to split it as rollers can have pretty large work areas and would affect too much of an area when doing overlapping runs
    local xDiff = widthX - startX
    local yDiff = widthY - startY
    local zDiff = widthZ - startZ
    local numberOfParts = math.max(1, math.floor(MathUtil.vector2Length(xDiff, zDiff))) -- one part per 1 world coord, but at least one part
    local fractionMultiplier = 1 / numberOfParts

    -- Split the work area into several smaller rectangles
    local workAreaCoordParts = {}
    for i = 0, numberOfParts - 1 do
        workAreaCoordParts[i] = {
            x1 = startX + i * fractionMultiplier * xDiff,
            y1 = startY + i * fractionMultiplier * yDiff,
            z1 = startZ + i * fractionMultiplier * zDiff,
            x2 = startX + (i + 1) * fractionMultiplier * xDiff,
            y2 = startY + (i + 1) * fractionMultiplier * yDiff,
            z2 = startZ + (i + 1) * fractionMultiplier * zDiff,
            x3 = heightX + i * fractionMultiplier * xDiff,
            y3 = heightY + i * fractionMultiplier * yDiff,
            z3 = heightZ + i * fractionMultiplier * zDiff
        }
    end

    return workAreaCoordParts
end

--- Calculates a drop area behind the work area so that e.g. a mulcher does not instantly remove dropped grass again
---@param implement table @The current implement which called this code
---@param coords table @The coordinates of the work area (or part)
---@param shiftingFactor integer @The factor to shift the work area by, where + means towards the back and - means towards the front
---@return table @The coordinate parts shifted in accordance with the factor
function CoverCropUtils.getSafeDropArea(implement, coords, shiftingFactor)

    if shiftingFactor == 0 then
        return coords
    end

    local xDiffFrontBack = coords.x3 - coords.x1
    local yDiffFrontBack = coords.y3 - coords.y1
    local zDiffFrontBack = coords.z3 - coords.z1

    local xOffset = shiftingFactor * xDiffFrontBack
    local yOffset = shiftingFactor * yDiffFrontBack
    local zOffset = shiftingFactor * zDiffFrontBack


    return {
        x1 = coords.x1 - xOffset,
        x2 = coords.x2 - xOffset,
        x3 = coords.x3 - xOffset,
        y1 = coords.y1 - yOffset,
        y2 = coords.y2 - yOffset,
        y3 = coords.y3 - yOffset,
        z1 = coords.z1 - zOffset,
        z2 = coords.z2 - zOffset,
        z3 = coords.z3 - zOffset
    }
end

---Retrieves a directional factor for the drop area which can be used to shift the drop area so that it always drops "behind" the implement
---Dependent on the current direction of the vehicle, and the fact if the implement is attached to the front or back, this can mean a shift in 
---positive or negative direction.
---@param implement table @The implement (roller, mulcher, ...) which called this code
---@param coordPart table @Any part of the work area
---@return integer @A factor which can be used for shifting the work area, or 0 if it shall not be moved
function CoverCropUtils.getDirectionalFactorForDropArea(implement, coordPart)

    local factor = 0
    if implement.lastSpeedReal > 0.001 then

        -- Invert the direction when going backwards
        if implement.lastSignedSpeedReal > 0 then
            factor = 2.0
        else
            factor = -2.0
        end

        local _, _, zFrontLocal = worldToLocal(implement.components[1].node, coordPart.x1, coordPart.y1, coordPart.z1)
        local _, _, zBackLocal = worldToLocal(implement.components[1].node, coordPart.x3, coordPart.y3, coordPart.z3)

        if zFrontLocal > zBackLocal then
            -- This is an implement which is meant to be attached to the front. Directions will be inverted for this one
            factor = factor * -1
        end
    end
    return factor
end

---Mulches the area at the given coordinates in case there is a crop which matches the supplied ground filter
---@param   implement   table   @The implement which is currently being used (the "self" instance within a specialization)
---@param   workArea    table   @A rectangle defined through three points which determines the area to be processed
---@param   groundShallBeMulched    boolean     @True if a mulching bonus shall be applied to the ground
---@param   grassShallBeDropped     boolean     @True if grass shall be dropped to simulate terminated biomatter
function CoverCropUtils.mulchAndFertilizeCoverCrops(implement, workArea, groundShallBeMulched, grassShallBeDropped)

    local settings = g_currentMission.conservationAgricultureSettings

    -- Translate work area coordinates to world coordinates
    local coordParts = CoverCropUtils.getWorldCoordParts(workArea)

    -- Get a factor required for a safe drop area
    local directionalFactor
    if grassShallBeDropped then
        directionalFactor = CoverCropUtils.getDirectionalFactorForDropArea(implement, coordParts[0])
    else
        directionalFactor = 0 -- No benefit in calculating that in this case
    end

    -- Repeat the following for each part of the work area
    for _, coords in pairs(coordParts) do

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

        -- Determine a safe drop area which won't get caught by the mulcher again
        local dropArea = CoverCropUtils.getSafeDropArea(implement, coords, directionalFactor)

        -- For every possible fruit:
        for fruitTypeIndex, desc in pairs(g_fruitTypeManager:getFruitTypes()) do

            -- Read as: "if excluded fruit types does not contain desc.index then"
            if not excludedFruitTypes[desc.index] then

                -- Set up modifiers and filters so we modify only the state of this fruit type
                fruitModifier:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
                fruitFilter:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)

                CoverCropUtils.filterForForageableFruit(fruitFilter, fruitTypeIndex)

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

                    if settings.weedSuppressionIsEnabled then
                        -- prevent weeds
                        FSDensityMapUtil.setWeedBlockingState(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, fruitFilter, onFieldFilter)
                    end

                    -- "Spray" straw on the ground
                    sprayTypeModifier:executeSet(strawSprayType, fruitFilter, onFieldFilter)

                    if grassShallBeDropped then
                        -- Add a thin layer of grass
                        local amount = 10
                        local lineOffset = 0
                        local radius = 10
                        DensityMapHeightUtil.tipToGroundAroundLine(implement, amount, FillType.GRASS_WINDROW,
                            dropArea.x1, dropArea.y1, dropArea.z1, dropArea.x2, dropArea.y2, dropArea.z2,
                            radius, nil, lineOffset, false, nil, false)
                    end

                    -- Increase the spray level to one level below max (Note: It looks like Precision Farming calls base game fertilization methods as well
                    -- so we execute this even with Precision Farming active.)
                    if settings.fertilizationBehaviorBaseGame == CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_FIRST then
                        for i = 1, maxSprayLevel - 1 do
                            local targetSprayLevel = maxSprayLevel - i
                            local currentSprayLevel = targetSprayLevel - 1
                            sprayLevelFilter:setValueCompareParams(DensityValueCompareType.EQUAL, currentSprayLevel)
                            sprayLevelModifier:executeSet(targetSprayLevel, sprayLevelFilter, fruitFilter, onFieldFilter)
                        end
                    elseif settings.fertilizationBehaviorBaseGame == CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_FULL then
                        sprayLevelFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, maxSprayLevel - 1)
                        sprayLevelModifier:executeSet(maxSprayLevel, sprayLevelFilter, fruitFilter, onFieldFilter)
                    end

                    -- precision farming: modify the nitrogen map
                    if FS22_precisionFarming ~= nil and FS22_precisionFarming.g_precisionFarming ~= nil and settings.fertilizationBehaviorPF == CASettings.FERTILIZATION_BEHAVIOR_PF_MIN_AUTO then
                        local precisionFarming = FS22_precisionFarming.g_precisionFarming
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
end