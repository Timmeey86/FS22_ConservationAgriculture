--- This class is responsible for adding a specialization to sprayers which allows developers to debug precision farming internals
PrecisionFarmingDebuggingSpec = {
}

--- Checks for other required specializations
---@param   specializations     table   @A table of existing specializations (unused).
---@return  boolean     @True if the ExtendedSprayer spec (= Precision Farming Sprayer) is available
function PrecisionFarmingDebuggingSpec.prerequisitesPresent(specializations)
    return true
end

--- Overrides the processSprayerArea function so we can read the specializations
---@param   vehicleType     table     @Provides information about the current vehicle (or rather implement) type.
function PrecisionFarmingDebuggingSpec.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSprayerArea", PrecisionFarmingDebuggingSpec.processSprayerArea)
    print("PrecisionFarmingDebuggingSpec: Hooked into vehicle type " .. vehicleType.name)
end

--- This method is mainly there so you can set breakpoints in it and inspect certain parameters
---@param   superFunc   function        @The GIANTS implementation of the method.
---@param   workArea    table           @Provides information about the area to be mulched.
---@param   dt          table           @delta time? Not used here.
---@return  integer     @The amount of pixels which were processed
---@return  integer     @The amount of pixels in the work area
function PrecisionFarmingDebuggingSpec:processSprayerArea(superFunc, workArea, dt)

    local baseGameSpec = self.spec_sprayer
    local pfSpec = self.spec_extendedSprayer

    local workAreaParams = baseGameSpec.workAreaParameters
    local isLiming = pfSpec.isLiming
    local isFertilizing = pfSpec.isFertilizing

    local isServer = self.isServer
    local pHMap = pfSpec.pHMap
    local nitrogenMap = pfSpec.nitrogenMap

    return superFunc(self, workArea, dt)
end