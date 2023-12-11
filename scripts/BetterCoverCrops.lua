local modDirectory = g_currentModDirectory or ""
local modName = g_currentModName or "unknown"

-- Dynamically load the specializations
source(modDirectory .. "scripts/MulcherFertilizerSpecialization.lua")
source(modDirectory .. "scripts/RollerFertilizerSpecialization.lua")

---Registers the specializations
-- @param   table   manager     The specialization manager


--- Registers the specializations for this mod
---@param   manager     table       the specialization manager
local function registerSpecialization(manager)
    if manager.typeName == "vehicle" then
        g_specializationManager:addSpecialization(
            "MulcherFertilizerSpecialization", "MulcherFertilizerSpecialization", modDirectory .. "scripts/MulcherFertilizerSpecialization.lua", nil
        )
        g_specializationManager:addSpecialization(
            "RollerFertilizerSpecialization", "RollerFertilizerSpecialization", modDirectory .. "scripts/RollerFertilizerSpecialization.lua", nil
        )

        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
			if typeEntry ~= nil then
				if SpecializationUtil.hasSpecialization(Mulcher, typeEntry.specializations)  then
					g_vehicleTypeManager:addSpecialization(typeName, modName .. ".MulcherFertilizerSpecialization")
				end
                if SpecializationUtil.hasSpecialization(Roller, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, modName .. ".RollerFertilizerSpecialization")
                end
            end
        end
    end
end

-- Register specializations before type validation
TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, registerSpecialization)
