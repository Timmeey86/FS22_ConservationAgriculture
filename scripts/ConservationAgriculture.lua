local modDirectory = g_currentModDirectory or ""
local modName = g_currentModName or "unknown"

-- Dynamically load the specializations
source(modDirectory .. "scripts/specializations/MulcherFertilizerSpecialization.lua")
source(modDirectory .. "scripts/specializations/RollerFertilizerSpecialization.lua")
source(modDirectory .. "scripts/specializations/SeederFertilizerSpecialization.lua")

--- Registers the specializations for this mod
---@param   manager     table       the specialization manager
local function registerSpecialization(manager)
    if manager.typeName == "vehicle" then

        -- Register the specialization types in the specialization manager (this also allows other mods to extend them)
        g_specializationManager:addSpecialization(
            "CA_MulcherSpecialization", "MulcherFertilizerSpecialization", modDirectory .. "scripts/specializations/MulcherFertilizerSpecialization.lua", nil)
        g_specializationManager:addSpecialization(
            "CA_RollerSpecialization", "RollerFertilizerSpecialization", modDirectory .. "scripts/specializations/RollerFertilizerSpecialization.lua", nil)
        g_specializationManager:addSpecialization(
            "CA_SeederSpecialization", "SeederFertilizerSpecialization", modDirectory .. "scripts/specializations/SeederFertilizerSpecialization.lua", nil)

        -- Add the specializations to vehicles based on which kind of specializations they already have
        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
			if typeEntry ~= nil then
                -- Allow any mulcher to mulch forageable crops
				if SpecializationUtil.hasSpecialization(Mulcher, typeEntry.specializations)  then
					g_vehicleTypeManager:addSpecialization(typeName, modName .. ".CA_MulcherSpecialization")
				end
                -- Allow any roller to mulch forageable crops, except for "FertilizingRollerCultivator"
                if SpecializationUtil.hasSpecialization(Roller, typeEntry.specializations) and
                    not SpecializationUtil.hasSpecialization(Sprayer, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, modName .. ".CA_RollerSpecialization")
                end
                -- Modify any sowing machine (including ExtendedSowingMachine) to adapt the nitrogen behavior when seeding into cover crops
                if SpecializationUtil.hasSpecialization(SowingMachine, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, modName .. ".CA_SeederSpecialization")
                end
            end
        end
    end
end

-- Register specializations before type validation
TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, registerSpecialization)

-- Do one-time calculations when the map is about to finish loading, and allow global access to the results
g_rollerCrimpingData = RollerCrimpingData.new()
BaseMission.loadMapFinished = Utils.prependedFunction(BaseMission.loadMapFinished, function(...)
        g_rollerCrimpingData:init(g_fruitTypeManager:getFruitTypes())
    end)