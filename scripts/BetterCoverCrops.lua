local modDirectory = g_currentModDirectory or ""
local modName = g_currentModName or "unknown"

source(modDirectory .. "scripts/MulcherFertilizerSpecialization.lua")

local function registerSpecialization(manager)
    if manager.typeName == "vehicle" then
        g_specializationManager:addSpecialization("MulcherFertilizerSpecialization", "MulcherFertilizerSpecialization", modDirectory .. "scripts/MulcherFertilizerSpecialization.lua", nil)

        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
			if typeEntry ~= nil then
				if SpecializationUtil.hasSpecialization(Mulcher, typeEntry.specializations)  then
					g_vehicleTypeManager:addSpecialization(typeName, modName .. ".MulcherFertilizerSpecialization")
				end
            end
        end
    end
end

BetterCoverCrops = {}
function BetterCoverCrops.updateMulcherArea(xs, superFunc, zs, xw, zw, xh, zh)
    print("-- Works")
    return superFunc(xs, zs, xw, zw, xh, zh)
end

TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, registerSpecialization)
--FSDensityMapUtil.updateMulcherArea = Utils.overwrittenFunction(FSDensityMapUtil.updateMulcherArea, BetterCoverCrops.updateMulcherArea)
