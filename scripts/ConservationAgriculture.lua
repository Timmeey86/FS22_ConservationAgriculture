local modDirectory = g_currentModDirectory or ""
local modName = g_currentModName or "unknown"

-- Dynamically load the specializations
source(modDirectory .. "scripts/MulcherFertilizerSpecialization.lua")
source(modDirectory .. "scripts/RollerFertilizerSpecialization.lua")
source(modDirectory .. "scripts/PrecisionFarmingDebuggingSpec.lua")

---Registers the specializations
-- @param   table   manager     The specialization manager


--- Registers the specializations for this mod
---@param   manager     table       the specialization manager
local function registerSpecialization(manager)
    if manager.typeName == "vehicle" then
        print("validateTypes")
        g_specializationManager:addSpecialization(
            "MulcherFertilizerSpecialization", "MulcherFertilizerSpecialization", modDirectory .. "scripts/MulcherFertilizerSpecialization.lua", nil
        )
        g_specializationManager:addSpecialization(
            "RollerFertilizerSpecialization", "RollerFertilizerSpecialization", modDirectory .. "scripts/RollerFertilizerSpecialization.lua", nil
        )
        g_specializationManager:addSpecialization(
            "PrecisionFarmingDebuggingSpec", "PrecisionFarmingDebuggingSpec", modDirectory .. "scripts/PrecisionFarmingDebuggingSpec.lua", nil
        )

        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
			if typeEntry ~= nil then
                -- Allow any mulcher to mulch forageable crops
				if SpecializationUtil.hasSpecialization(Mulcher, typeEntry.specializations)  then
					g_vehicleTypeManager:addSpecialization(typeName, modName .. ".MulcherFertilizerSpecialization")
				end
                -- Allow any roller to mulch forageable crops, except for "FertilizingRollerCultivator"
                if SpecializationUtil.hasSpecialization(Roller, typeEntry.specializations) and
                    not SpecializationUtil.hasSpecialization(Sprayer, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, modName .. ".RollerFertilizerSpecialization")
                end
                if SpecializationUtil.hasSpecialization(FS22_precisionFarming.ExtendedSprayer, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, modName .. ".PrecisionFarmingDebuggingSpec")
                end
            end
        end
    end
end

-- Register specializations before type finalization. Note that type validation is too early for precision farming
TypeManager.finalizeTypes = Utils.prependedFunction(TypeManager.finalizeTypes, registerSpecialization)
