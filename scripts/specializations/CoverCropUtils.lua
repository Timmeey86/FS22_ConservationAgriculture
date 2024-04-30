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
---@return boolean @True if the filter could be set up properly, false if for example the fruit was added through a script and is missing density information
function CoverCropUtils.filterForForageableFruit(fruitFilter, fruitTypeIndex)
    local rollerCrimpingGrowthStates = g_rollerCrimpingData:getForageableStates(fruitTypeIndex)

    if rollerCrimpingGrowthStates.min ~= nil and rollerCrimpingGrowthStates.max ~= nil then
        fruitFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, rollerCrimpingGrowthStates.min, rollerCrimpingGrowthStates.max)
        return true
    else
        return false
    end
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

---Applies fertilizer to the given coordinates 
---@param coords table @The coordinates to use. Only used for precision farming.
---@param sprayLevelModifier table @The density map modifier for the spray level. Must be limited to the coordinates already
---@param sprayLevelFilter table @The spray level filter to be used. Create this as DensityMapFilter.new(sprayLevelModifier) and reuse on every call
---@param filter2 table @An optional second filter like onFieldFilter
---@param filter3 table @An optional third filter, for example for the fruit type
---@param forceFixedAmount boolean @Set to true in order to force a fixed amount, or to force level 1 in base game
---@param pfNitrogenValue number @The amount of nitrogen to be applied in case of precision farming
function CoverCropUtils.applyFertilizer(coords, sprayLevelModifier, sprayLevelFilter, filter2, filter3, forceFixedAmount, pfNitrogenValue)
    local settings = g_currentMission.conservationAgricultureSettings
    local maxSprayLevel = g_currentMission.fieldGroundSystem:getMaxValue(FieldDensityMap.SPRAY_LEVEL)
    local sprayType = FieldSprayType.FERTILIZER

    if not g_modIsLoaded['FS22_precisionFarming'] then
        -- Increase the spray level to one level below max (Note: It looks like Precision Farming calls base game fertilization methods as well
        -- so we execute this even with Precision Farming active.)
        if forceFixedAmount or settings.fertilizationBehaviorBaseGame == CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_FIRST then
            for i = 1, maxSprayLevel - 1 do
                local targetSprayLevel = maxSprayLevel - i
                local currentSprayLevel = targetSprayLevel - 1
                sprayLevelFilter:setValueCompareParams(DensityValueCompareType.EQUAL, currentSprayLevel)
                sprayLevelModifier:executeSet(targetSprayLevel, sprayLevelFilter, filter2, filter3)
            end
        elseif settings.fertilizationBehaviorBaseGame == CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_FULL then
            sprayLevelFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 0, maxSprayLevel - 1)
            sprayLevelModifier:executeSet(maxSprayLevel, sprayLevelFilter, filter2, filter3)
        elseif settings.fertilizationBehaviorBaseGame == CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_ADD_ONE then
            -- Just pretend we're a fertilizer spreader (which sprays straw)
            FSDensityMapUtil.updateFertilizerArea(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, sprayType, 1)
        end

        -- make the ground look like straw in all base game cases
        if settings.fertilizationBehaviorBaseGame ~= CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_OFF then
            FSDensityMapUtil.setGroundTypeLayerArea(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, sprayType)
        end
    else
        -- precision farming: modify the nitrogen map instead
        local precisionFarming = FS22_precisionFarming.g_precisionFarming
        local nitrogenMap = precisionFarming.nitrogenMap

        local nitrogenValue = pfNitrogenValue
        if settings.fertilizationBehaviorPF == CASettings.FERTILIZATION_BEHAVIOR_PF_OFF then
            nitrogenValue = 0
        end
        local choppedStrawValueBefore = nitrogenMap.choppedStrawStateChange
        nitrogenMap.choppedStrawStateChange = nitrogenValue
        nitrogenMap:preUpdateStrawChopperArea(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, sprayType)
        FSDensityMapUtil.setGroundTypeLayerArea(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, sprayType)
        nitrogenMap:postUpdateStrawChopperArea(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, sprayType)
        nitrogenMap.choppedStrawStateChange = choppedStrawValueBefore
    end
end

---Mulches the area at the given coordinates in case there is a crop which matches the supplied ground filter
---@param   implement   table   @The implement which is currently being used (the "self" instance within a specialization)
---@param   workArea    table   @A rectangle defined through three points which determines the area to be processed
---@param   groundShallBeMulched    boolean     @True if a mulching bonus shall be applied to the ground
---@param   grassShallBeDropped     boolean     @True if grass shall be dropped to simulate terminated biomatter
---@param   pfNitrogenValue         integer     @The amount of nitrogen to be applied in case of precision farming
---@return  table   @A list of rectangles which were processed by the method
function CoverCropUtils.mulchAndFertilizeCoverCrops(implement, workArea, groundShallBeMulched, grassShallBeDropped, pfNitrogenValue)

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

    local processedCoordParts = {}
    -- Repeat the following for each part of the work area
    for _, coords in pairs(coordParts) do

        -- These will be used in the loop later. The parameters will be overriden later
        local fruitModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.GROUND_TYPE)
        local fruitFilter = DensityMapFilter.new(fruitModifier)

        -- Don't modify anything outside of fields
        local onFieldFilter = DensityMapFilter.new(fruitModifier)
        onFieldFilter:setValueCompareParams(DensityValueCompareType.GREATER, 0)

        -- Allow modifying the fertilization amount
        local sprayLevelModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.SPRAY_LEVEL)
        local sprayLevelFilter = DensityMapFilter.new(sprayLevelModifier)

        -- Allow setting to a mulched state (by setting the stubble shred flag and "spraying" straw across the ground)
        local stubbleShredModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.STUBBLE_SHRED)

        -- Exclude fruit types which wouldn't be cover crops. They don't seem to share common properties which separate them from the other types.
        local excludedFruitTypes = Set {
            FruitType.COTTON,
            FruitType.GRAPE,
            FruitType.OLIVE,
            FruitType.POPLAR
        }
        -- Avoid mod conflicts with mods which add fruit types without adding density maps
		local wheatFruitType = g_fruitTypeManager:getFruitTypeByName("WHEAT")
        for _, desc in pairs(g_fruitTypeManager:getFruitTypes()) do
			-- Note about the fourth check: SwathingAddon sets the wheat density map for all fruit types which don't have a density map, but we still need to ignore such fruit types
			-- => We ignore them if they use the wheat density map but are in fact a different fruit type
            if desc.terrainDataPlaneId == nil or desc.startStateChannel == nil or desc.numStateChannels == nil 
				or (desc.terrainDataPlaneId == wheatFruitType.terrainDataPlaneId and desc.index ~= wheatFruitType.index) then
                excludedFruitTypes[desc.index] = true
            end
        end

        -- Determine a safe drop area which won't get caught by the mulcher again
        local dropArea = CoverCropUtils.getSafeDropArea(implement, coords, directionalFactor)

        -- For every possible fruit:
        for fruitTypeIndex, desc in pairs(g_fruitTypeManager:getFruitTypes()) do

            -- Read as: "if excluded fruit types does not contain desc.index then"
            if not excludedFruitTypes[desc.index] then

                -- Set up modifiers and filters so we modify only the state of this fruit type
                fruitModifier:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)
                fruitFilter:resetDensityMapAndChannels(desc.terrainDataPlaneId, desc.startStateChannel, desc.numStateChannels)

                local fruitFilterCouldBeConstructed = CoverCropUtils.filterForForageableFruit(fruitFilter, fruitTypeIndex)

                -- if possible, use the mulched fruit state, otherwise use the cut state
                local mulchedFruitState = desc.cutState or 0
                if groundShallBeMulched and desc.mulcher ~= nil and desc.mulcher.hasChopperGroundLayer then
                    mulchedFruitState = desc.mulcher.state
                end

                -- Cut (mulch) any pixels which match the fruit type (including growth stage) and haven't had their stubble level set to max
                local numPixelsAffected = 0
                if fruitFilterCouldBeConstructed then
                    _, numPixelsAffected, _ = fruitModifier:executeSet(mulchedFruitState, fruitFilter, onFieldFilter)
                end
                if numPixelsAffected > 0 then

                    -- Remember that we processed this part of the work area
                    table.insert(processedCoordParts, coords)

                    -- since we cut the ground, we need to filter for a cut fruit now
                    fruitFilter:setValueCompareParams(DensityValueCompareType.EQUAL, mulchedFruitState)

                    -- Set the "mulched" flag
                    if groundShallBeMulched then
                        stubbleShredModifier:executeSet(1, fruitFilter, onFieldFilter)
                    end

                    if settings.weedSuppressionIsEnabled then
                        local weedSystem = g_currentMission.weedSystem
                        if weedSystem:getMapHasWeed() then
                            -- Fake the usage of a hoe weeder
                            local hoeWeeder = true
                            FSDensityMapUtil.updateWeederArea(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, hoeWeeder)
                            -- prevent future weeds until the next harvest
                            FSDensityMapUtil.setWeedBlockingState(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3, fruitFilter, onFieldFilter)
                        end
                    end

                    -- Fertilize the field in accordance with the fertilization strategy
                    CoverCropUtils.applyFertilizer(coords, sprayLevelModifier, sprayLevelFilter, fruitFilter, onFieldFilter, false, pfNitrogenValue)

                    if grassShallBeDropped then
                        -- Add a thin layer of grass
                        local amount = 10
                        local lineOffset = 0
                        local radius = 10
                        DensityMapHeightUtil.tipToGroundAroundLine(implement, amount, FillType.GRASS_WINDROW,
                            dropArea.x1, dropArea.y1, dropArea.z1, dropArea.x2, dropArea.y2, dropArea.z2,
                            radius, nil, lineOffset, false, nil, false)
                    end
                end
            end
        end
    end

    return processedCoordParts
end