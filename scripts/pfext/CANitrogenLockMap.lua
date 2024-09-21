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

---Restores a nitrogen lock map from an XML and GRLE file
---@param xmlFile number @A handle to the XML file
---@param key string @The base key in the XML, in case more than one thing is stored in the same file
---@param ... unknown @Unused parameters
---@return boolean @Currently always true (since failing to load the bit vector map would lead to an unrecoverable error anyway)
function CANitrogenLockMap:loadFromXML(xmlFile, key, ...)
    key = key .. "." .. CANitrogenLockMap.NAME
    self.sizeX = getXMLInt(xmlFile, key .. "#sizeX") or CANitrogenLockMap.SIZE
    self.sizeY = getXMLInt(xmlFile, key .. "#sizeY") or CANitrogenLockMap.SIZE
    self.firstChannel = 0
    self.numChannels = 1
    self.maxValue = 1
    self.bitVectorMap = self:loadSavedBitVectorMap(CANitrogenLockMap.NAME, CANitrogenLockMap.GRLEFILE, self.numChannels, self.sizeX)

    self:addBitVectorMapToSync(self.bitVectorMap)
    self:addBitVectorMapToSave(self.bitVectorMap, CANitrogenLockMap.GRLEFILE)
    self:addBitVectorMapToDelete(self.bitVectorMap)

    return true
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
        CANitrogenLockMap.SIZE * (startWorldX + terrainSize * 0.5) / terrainSize,
        CANitrogenLockMap.SIZE * (startWorldZ + terrainSize * 0.5) / terrainSize,
        CANitrogenLockMap.SIZE * (widthWorldX + terrainSize * 0.5) / terrainSize,
        CANitrogenLockMap.SIZE * (widthWorldZ + terrainSize * 0.5) / terrainSize,
        CANitrogenLockMap.SIZE * (heightWorldX + terrainSize * 0.5) / terrainSize,
        CANitrogenLockMap.SIZE * (heightWorldZ + terrainSize * 0.5) / terrainSize
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
    startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ = worldCoordsToLocalCoords(
        startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, g_currentMission.terrainSize)

    -- Limit the modifiers to the coordinates which correspond to the current working area
    functionCache.lockMapModifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)
    functionCache.nitrogenMapModifier:setParallelogramDensityMapCoords(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, DensityCoordType.POINT_POINT_POINT)

    -- Track the amount of pixels which may still receive a nitrogen bonus
    local _, eligiblePixelsBefore, _ = functionCache.lockMapModifier:executeGet(functionCache.notLockedFilter)

    if eligiblePixelsBefore == 0 then
        return 0 -- no bonus will be applied in this area
    end

    local _, eligibleTEMP1, _ = functionCache.lockMapModifier:executeGet(functionCache.notLockedFilter, filter1, filter2)
    local _, eligibleTEMP2, _ = functionCache.lockMapModifier:executeGet(functionCache.lockedFilter, filter1, filter2)

    -- Create a multi modifier which updates both the PF nitrogen map and our lock map at the same time
    local multiModifier = DensityMapMultiModifier.new()

    -- Add nitrogen amount. We need to do this in two steps in order to prevent the code from setting the nitrogen amount too high
    functionCache.nearMaxNitrogenFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, self.nitrogenMap.maxValue - nitrogenAmount + 1, self.nitrogenMap.maxValue)
    functionCache.regularNitrogenFilter:setValueCompareParams(DensityValueCompareType.BETWEEN, 1, self.nitrogenMap.maxValue - nitrogenAmount)
    multiModifier:addExecuteAdd(nitrogenAmount, functionCache.nitrogenMapModifier, functionCache.regularNitrogenFilter, functionCache.notLockedFilter, filter1, filter2)
    multiModifier:addExecuteSet(self.nitrogenMap.maxValue, functionCache.nitrogenMapModifier, functionCache.nearMaxNitrogenFilter, functionCache.notLockedFilter, filter1, filter2)
    -- Lock any pixels which match the filters
    multiModifier:addExecuteSet(CANitrogenLockMap.LOCK_STATES.BONUS_APPLIED, functionCache.lockMapModifier, functionCache.notLockedFilter, filter1, filter2)

    -- Execute the modifier now
    multiModifier:execute(false)

    -- TODO: Multi modifier does not work like I think it does
    local _, eligibleTEMP3, _ = functionCache.lockMapModifier:executeGet(functionCache.notLockedFilter, filter1, filter2)
    local _, eligibleTEMP4, _ = functionCache.lockMapModifier:executeGet(functionCache.lockedFilter, filter1, filter2)
    print((">>>>>>>>>> %d, %d -> %d, %d"):format(eligibleTEMP1, eligibleTEMP2, eligibleTEMP3, eligibleTEMP4))

    -- Check how many pixels are still eligible (will be larger than zero if the fruit filter or on field filter excluded some bits)
    local _, eligiblePixelsAfter, _ = functionCache.lockMapModifier:executeGet(functionCache.notLockedFilter)

    print(">>>>>>>>>>>" .. tostring(eligiblePixelsBefore) .. " -> " .. tostring(eligiblePixelsAfter))
    return eligiblePixelsBefore - eligiblePixelsAfter
end
function CANitrogenLockMap:resetLock(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    if self.nitrogenMap == nil then
        return 0 -- shouldn't happen
    end

end