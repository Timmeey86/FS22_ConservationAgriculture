---@class CANitrogenLockMap
---This class is responsible for tracking custom changes to the Precision Farming Nitrogen map
CANitrogenLockMap = {
    NAME = "caNitrogenLockMap",
    GRLEFILE = "ConservationAgriculture_NitrogenLockMap.grle",
    SIZE = 1024
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
    return self
end

---Initializes the class
function CANitrogenLockMap:initialize()
    CANitrogenLockMap:superClass().initialize(self)
    self.densityMapModifier = nil
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
    self.bitVectorMap = self:loadSavedBitVectorMap(CANitrogenLockMap.NAME, CANitrogenLockMap.GRLEFILE, 1, self.sizeX)

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

function CANitrogenLockMap:applyNitrogenAmount(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ, nitrogenAmount)
    -- TODO
end
function CANitrogenLockMap:resetLock(startWorldX, startWorldZ, widthWorldX, widthWorldZ, heightWorldX, heightWorldZ)
    -- TODO
end