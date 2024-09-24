---@class CANitrogenLockMap
---This class is responsible for tracking custom changes to the Precision Farming Nitrogen map
CANitrogenLockMap = {
    NAME = "caNitrogenLockMap",
    GRLEFILE = "ConservationAgriculture_NitrogenLockMap.grle",
    SIZE = 1024,
    LOCK_STATES = {
        ELIGIBLE_FOR_BONUS = 0,
        BONUS_APPLIED = 1
    }
}

-- This class doesn't make sense without Precision Farming
if not g_modIsLoaded["FS22_precisionFarming"] then
    return
end

local CANitrogenLockMap_mt = Class(CANitrogenLockMap, FS22_precisionFarming.ValueMap)

---Creates a new bit vector map which stores pixels which have already received a nitrogen boost since sowing.
---@param pfModule table @The precision farming module
---@return table @the new instance
function CANitrogenLockMap.new(pfModule)
    local self = FS22_precisionFarming.ValueMap.new(pfModule, CANitrogenLockMap_mt)
    self.name = CANitrogenLockMap.NAME
    self.nitrogenMap = FS22_precisionFarming.g_precisionFarming.nitrogenMap
    self.functionCaches = {}
    self.functionCaches.applyNitrogenAmount = nil
    self.functionCaches.resetLock = nil
    -- Stores the work areas which shall have their lock bits reset when sleeping
    self.pendingWorkAreas = {}
    return self
end

---Initializes the class
function CANitrogenLockMap:initialize()
    CANitrogenLockMap:superClass().initialize(self)
end

---Deletes the cache object which represents the bit vector map (but not the GRLE/XML files in the save game)
function CANitrogenLockMap:delete()
    CANitrogenLockMap:superClass().delete(self)
end

---Restores a nitrogen lock map from the savegame. XML parameters are ignored because there is nothing in the PrecisionFarming.xml
---for our custom bit vector map, of course
---@param ... unknown @Unused parameters
---@return boolean @Currently always true (since failing to load the bit vector map would lead to an unrecoverable error anyway)
function CANitrogenLockMap:loadFromXML(...)
    self.sizeX = CANitrogenLockMap.SIZE
    self.sizeY = CANitrogenLockMap.SIZE
    self.firstChannel = 0
    self.numChannels = 1
    self.maxValue = 1
    self.bitVectorMap = self:loadSavedBitVectorMap(CANitrogenLockMap.NAME, CANitrogenLockMap.GRLEFILE, self.numChannels, self.sizeX)

    self:addBitVectorMapToSync(self.bitVectorMap)
    self:addBitVectorMapToSave(self.bitVectorMap, CANitrogenLockMap.GRLEFILE)
    self:addBitVectorMapToDelete(self.bitVectorMap)

    return true
end

---Converts a single coordinate (X or Z dimension) to a local bit vector map coordinate
---@param coord number @The coordinate
---@param terrainSize number @The size of the terrain
---@return number @The local coordinate
local function worldCoordToLocalCoord(coord, terrainSize)
    return CANitrogenLockMap.SIZE * (coord + terrainSize * .5) / terrainSize
end

---Converts world coordinates to local bit vector map coordinates
---@param startWorldX number @The X world coordinate of the first corner
---@param startWorldZ number @The Z world coordinate of the first corner
---@param widthWorldX number @The X world coordinate of the second corner
---@param widthWorldZ number @The Z world coordinate of the second corner
---@param heightWorldX number @The X world coordinate of the third corner
---@param heightWorldZ number @The Z world coordinate of the third corner
---@param terrainSize number @The size of the world terrain (either dimension, assuming it's a square)
---@return number @The X local coordinate of the first corner
---@return number @The Z local coordinate of the first corner
---@return number @The X local coordinate of the second corner
---@return number @The Z local coordinate of the second corner
---@return number @The X local coordinate of the third corner
---@return number @The Z local coordinate of the third corner
local function worldCoordsToLocalCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, terrainSize)
    return
        worldCoordToLocalCoord(startWorldX, terrainSize),
        worldCoordToLocalCoord(startWorldZ, terrainSize),
        worldCoordToLocalCoord(widthWorldX, terrainSize),
        worldCoordToLocalCoord(widthWorldZ, terrainSize),
        worldCoordToLocalCoord(heightWorldX, terrainSize),
        worldCoordToLocalCoord(heightWorldZ, terrainSize)
end

---Overwrites additional game functions when necessary
---@param pfModule table @The precision farming module
function CANitrogenLockMap:overwriteGameFunctions(pfModule)
    CANitrogenLockMap:superClass().overwriteGameFunctions(self, pfModule)
end

---Prevent the lock map from being displayed in the PF menu
---@return boolean @Always false
function CANitrogenLockMap:getShowInMenu()
    return false
end

---Applies a fixed nitrogen amount on the field. This can only be done once per day, in order to prevent overfertilization
---@param startWorldX number @The X world coordinate of the first corner
---@param startWorldZ number @The Z world coordinate of the first corner
---@param widthWorldX number @The X world coordinate of the second corner
---@param widthWorldZ number @The Z world coordinate of the second corner
---@param heightWorldX number @The X world coordinate of the third corner
---@param heightWorldZ number @The Z world coordinate of the third corner
---@param nitrogenAmount number @The amount of nitrogen which shall be applied
---@param filter1 table @An optional DensityMapFilter used for limiting where nitrogen shall be applied
---@param filter2 table @An second optional DensityMapFilter used for limiting where nitrogen shall be applied
---@return integer @The amount of pixels which were affected
function CANitrogenLockMap:applyNitrogenAmount(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, nitrogenAmount, filter1, filter2)
    if self.nitrogenMap == nil then
        return 0 -- shouldn't happen
    end

    local functionCache
    if self.functionCaches.applyNitrogenAmount == nil then
        functionCache = {}

        -- Create a modifier for setting and resetting bits on spots where a cover crop nitrogen bonus was applied
        functionCache.lockMapModifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
        functionCache.lockMapModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
        functionCache.lockMapModifier:setDensityMapChannels(0, 1)

        -- Filter only for pixels which are eligible for a cover crop nitrogen bonus
        functionCache.notLockedFilter = DensityMapFilter.new(functionCache.lockMapModifier)
        functionCache.notLockedFilter:setValueCompareParams(DensityValueCompareType.EQUAL, CANitrogenLockMap.LOCK_STATES.ELIGIBLE_FOR_BONUS)
        functionCache.lockedFilter = DensityMapFilter.new(functionCache.lockMapModifier)
        functionCache.lockedFilter:setValueCompareParams(DensityValueCompareType.EQUAL, CANitrogenLockMap.LOCK_STATES.BONUS_APPLIED)

        -- This modifier will modify the Precision Farming nitrogen amount directly
        functionCache.nitrogenMapModifier = DensityMapModifier.new(self.nitrogenMap.bitVectorMap, self.nitrogenMap.firstChannel, self.nitrogenMap.numChannels)
        functionCache.nitrogenMapModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
        functionCache.nearMaxNitrogenFilter = DensityMapFilter.new(functionCache.nitrogenMapModifier)
        functionCache.regularNitrogenFilter = DensityMapFilter.new(functionCache.nitrogenMapModifier)

        self.functionCaches.applyNitrogenAmount = functionCache
    else
        functionCache = self.functionCaches.applyNitrogenAmount
    end

    -- Transform the coordinates to density map coords
    local startLocalX, startLocalZ, widthLocalX, widthLocalZ, heightLocalX, heightLocalZ = worldCoordsToLocalCoords(
        startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, g_currentMission.terrainSize)

    -- Limit the modifiers to the coordinates which correspond to the current work area
    functionCache.lockMapModifier:setParallelogramDensityMapCoords(startLocalX, startLocalZ, widthLocalX, widthLocalZ, heightLocalX, heightLocalZ, DensityCoordType.POINT_POINT_POINT)
    functionCache.nitrogenMapModifier:setParallelogramDensityMapCoords(startLocalX, startLocalZ, widthLocalX, widthLocalZ, heightLocalX, heightLocalZ, DensityCoordType.POINT_POINT_POINT)

    -- Track the amount of pixels which may still receive a nitrogen bonus
    local _, eligiblePixelsBefore, _ = functionCache.lockMapModifier:executeGet(functionCache.notLockedFilter, filter1, filter2)

    if eligiblePixelsBefore == 0 then
        return 0 -- no bonus will be applied in this area
    end

    -- Add nitrogen amount. We need to do this in two steps in order to prevent the code from setting the nitrogen amount too high
    functionCache.nearMaxNitrogenFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, self.nitrogenMap.maxValue - nitrogenAmount + 1, self.nitrogenMap.maxValue)
    functionCache.regularNitrogenFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, self.nitrogenMap.maxValue - nitrogenAmount)
    functionCache.nitrogenMapModifier:executeAdd(nitrogenAmount,functionCache.regularNitrogenFilter, functionCache.notLockedFilter, filter1, filter2)
    functionCache.nitrogenMapModifier:executeSet(self.nitrogenMap.maxValue, functionCache.nearMaxNitrogenFilter, functionCache.notLockedFilter, filter1, filter2)
    -- Lock any pixels which match the filters
    functionCache.lockMapModifier:executeSet(CANitrogenLockMap.LOCK_STATES.BONUS_APPLIED, functionCache.notLockedFilter, filter1, filter2)

    -- Check how many pixels are still eligible (will be larger than zero if the fruit filter or on field filter excluded some bits)
    local _, eligiblePixelsAfter, _ = functionCache.lockMapModifier:executeGet(functionCache.notLockedFilter, filter1, filter2)

    -- Remember the work area
    self.pendingWorkAreas[#self.pendingWorkAreas + 1] = {
        x1 = startLocalX,
        z1 = startLocalZ,
        x2 = heightLocalX,
        z2 = heightLocalZ,
        x3 = widthLocalX,
        z3 = widthLocalZ
    }

    return eligiblePixelsBefore - eligiblePixelsAfter
end

---Resets any lock bits in the given area
---@param startLocalX  number @The X local coordinate of the first corner
---@param startLocalZ  number @The Z local coordinate of the first corner
---@param widthLocalX  number @The X local coordinate of the second corner
---@param widthLocalZ  number @The Z local coordinate of the second corner
---@param heightLocalX number @The X local coordinate of the third corner
---@param heightLocalZ number @The Z local coordinate of the third corner
---@return integer @The amount of affected pixels
function CANitrogenLockMap:resetLock(startLocalX, startLocalZ, widthLocalX, widthLocalZ, heightLocalX, heightLocalZ)
    if self.nitrogenMap == nil then
        return 0 -- shouldn't happen
    end

    local functionCache
    if self.functionCaches.resetLock == nil then
        functionCache = {}

        -- Create a modifier for setting and resetting bits on spots where a cover crop nitrogen bonus was applied
        functionCache.lockMapModifier = DensityMapModifier.new(self.bitVectorMap, self.firstChannel, self.numChannels)
        functionCache.lockMapModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
        functionCache.lockMapModifier:setDensityMapChannels(0, 1)

        -- Filter only for pixels where the nitrogen bonus has been applied already
        functionCache.lockedFilter = DensityMapFilter.new(functionCache.lockMapModifier)
        functionCache.lockedFilter:setValueCompareParams(DensityValueCompareType.EQUAL, CANitrogenLockMap.LOCK_STATES.BONUS_APPLIED)

        self.functionCaches.resetLock = functionCache
    else
        functionCache = self.functionCaches.resetLock
    end

    -- Limit the modifiers to the coordinates which correspond to the current work area
    functionCache.lockMapModifier:setParallelogramDensityMapCoords(startLocalX, startLocalZ, widthLocalX, widthLocalZ, heightLocalX, heightLocalZ, DensityCoordType.POINT_POINT_POINT)

    -- Track the amount of pixels which have already received a nitrogen bonus
    local _, lockedPixelsBefore, _ = functionCache.lockMapModifier:executeGet(functionCache.lockedFilter)

    if lockedPixelsBefore == 0 then
        return 0 -- nothing needs to be unlocked
    end

    -- Unlock any pixels which match the filters
    functionCache.lockMapModifier:executeSet(CANitrogenLockMap.LOCK_STATES.ELIGIBLE_FOR_BONUS, functionCache.notLockedFilter)

    -- Check how many pixels are still locked (probably always zero)
    local _, lockedPixelsAfter, _ = functionCache.lockMapModifier:executeGet(functionCache.lockedFilter)

    return lockedPixelsBefore - lockedPixelsAfter
end

---Resets the locks in any pending work areas
function CANitrogenLockMap:resetLocksInPendingWorkAreas()
    local time = netGetTime()
    local amount = #self.pendingWorkAreas
    for i, coords in ipairs(self.pendingWorkAreas) do
        self:resetLock(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3)
    end
    self.pendingWorkAreas = {}

    if DEBUG_CA_PERFORMANCE then
        CA_PRINT_DEBUG_TIME(("Resetting lock bits in %d work areas"):format(amount), netGetTime() - time)
    end
end

--- Reset lock bits whenever the growth states are advancing
GrowthSystem.performScriptBasedGrowth = Utils.appendedFunction(GrowthSystem.performScriptBasedGrowth, function(...)
    -- Reset all the lock bits in any pending work areas
    if not g_modIsLoaded["FS22_precisionFarming"] then
        return
    end

    local lockMap = FS22_precisionFarming.g_precisionFarming.caNitrogenLockMap
    lockMap:resetLocksInPendingWorkAreas()
end)

function CANitrogenLockMap.debugPlayerUpdate(player)
    -- Get the player position
    local x, y, z = localToWorld(player.rootNode, 0, 0, 0)
    CANitrogenLockMap.debugLockMap(x, y, z)
end
Player.update = Utils.appendedFunction(Player.update, CANitrogenLockMap.debugPlayerUpdate)

function CANitrogenLockMap.debugVehicleUpdate(vehicle)
    if not g_currentMission or vehicle ~= g_currentMission.controlledVehicle then
        return
    end

    -- Get the vehicle root node position
    local x, y, z = localToWorld(vehicle.rootNode, 0, 0, 0)
    CANitrogenLockMap.debugLockMap(x, y, z)
end
Vehicle.update = Utils.appendedFunction(Vehicle.update, CANitrogenLockMap.debugVehicleUpdate)

function CANitrogenLockMap.debugLockMap(x, y, z)
    if not g_modIsLoaded["FS22_precisionFarming"] then
        return
    end

    local lockMap = FS22_precisionFarming.g_precisionFarming.caNitrogenLockMap

    local lockMapModifier = DensityMapModifier.new(lockMap.bitVectorMap, lockMap.firstChannel, lockMap.numChannels)
    lockMapModifier:setPolygonRoundingMode(DensityRoundingMode.INCLUSIVE)
    lockMapModifier:setDensityMapChannels(0, 1)

    local lockedFilter = DensityMapFilter.new(lockMapModifier)
    lockedFilter:setValueCompareParams(DensityValueCompareType.EQUAL, CANitrogenLockMap.LOCK_STATES.BONUS_APPLIED)

    -- Round X/Z to a 1m resolution
    x = math.floor( x )
    z = math.floor( z )
    local terrainSize = g_currentMission.terrainSize

    -- Draw 24m around the player
    for xWorld = x - 24, x + 24, 1 do
        for zWorld = z - 24, z + 24, 1 do
            -- Get the value at this area
            local xBitMap, zBitMap = worldCoordToLocalCoord(xWorld, terrainSize), worldCoordToLocalCoord(zWorld, terrainSize)

            lockMapModifier:setParallelogramDensityMapCoords(xBitMap, zBitMap, xBitMap, zBitMap, xBitMap, zBitMap, DensityCoordType.POINT_POINT_POINT)
            local numLockedPixels = lockMapModifier:executeGet(lockedFilter)

            local yWorld = getTerrainHeightAtWorldPos(g_currentMission.terrainRootNode, xWorld, 0, zWorld) + .5
            Utils.renderTextAtWorldPosition(xWorld, yWorld, zWorld, tostring(numLockedPixels), getCorrectTextSize(.02), 0)
        end
    end
end