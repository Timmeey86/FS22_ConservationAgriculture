--- This file injects a couple of things into the precision farming module if it is loaded, so we can have our own
--- bit vector map which keeps track of which parts of the field had a CA nitrogen bonus applied already

local function beforeValidateTypes(typeManager)
    -- The following code will not work unless precision farming is loaded, obviously
    if typeManager.typeName == "vehicle" and g_modIsLoaded["FS22_precisionFarming"] and g_iconGenerator == nil then

        -- Load our own nitrogen lock map source now. This must be done *after* loading PF
        source(MOD_DIR .. "scripts/pfext/CANitrogenLockMap.lua")

        -- Note that PF prepends to validateTypes *after* CA so we can't hook to PrecisionFarming:initialize()
        -- Therefore we need to call the initialization methods ourselves
        local pfModule = FS22_precisionFarming.g_precisionFarming
        local caNitrogenLockMap = CANitrogenLockMap.new(pfModule)
        pfModule:registerValueMap(caNitrogenLockMap)
        caNitrogenLockMap:initialize(pfModule)
        -- This hook ensures our own bit vector map will be saved
        caNitrogenLockMap:overwriteGameFunctions(pfModule)
    else
        print(MOD_NAME .. ": Skipping PF specializations since PF is not active.")
    end
end
TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, beforeValidateTypes)

