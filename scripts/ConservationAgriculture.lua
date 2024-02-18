local modDirectory = g_currentModDirectory or ""
MOD_NAME = g_currentModName or "unknown"

-- Dynamically load the specializations
source(modDirectory .. "scripts/specializations/MulcherFertilizerSpecialization.lua")
source(modDirectory .. "scripts/specializations/RollerFertilizerSpecialization.lua")
source(modDirectory .. "scripts/specializations/SeederFertilizerSpecialization.lua")
source(modDirectory .. "scripts/specializations/CultivatorFertilizerSpecialization.lua")
source(modDirectory .. "scripts/specializations/ChopperFertilizerSpecialization.lua")

---Registers the specializations for this mod
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
        g_specializationManager:addSpecialization(
            "CA_CultivatorSpecialization", "CultivatorFertilizerSpecialization", modDirectory .. "scripts/specializations/CultivatorFertilizerSpecialization.lua", nil)
        g_specializationManager:addSpecialization(
            "CA_ChopperSpecialization", "ChopperFertilizerSpecialization", modDirectory .. "scripts/specializations/ChopperFertilizerSpecialization.lua", nil)

        -- Add the specializations to vehicles based on which kind of specializations they already have
        for typeName, typeEntry in pairs(g_vehicleTypeManager:getTypes()) do
			if typeEntry ~= nil then
                -- Allow any mulcher to mulch forageable crops
				if SpecializationUtil.hasSpecialization(Mulcher, typeEntry.specializations)  then
					g_vehicleTypeManager:addSpecialization(typeName, MOD_NAME .. ".CA_MulcherSpecialization")
				end
                -- Allow any roller to mulch forageable crops, except for "FertilizingRollerCultivator"
                if SpecializationUtil.hasSpecialization(Roller, typeEntry.specializations) and
                    not SpecializationUtil.hasSpecialization(Sprayer, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, MOD_NAME .. ".CA_RollerSpecialization")
                end
                -- Modify any sowing machine (including ExtendedSowingMachine) to adapt the nitrogen behavior when seeding into cover crops
                if SpecializationUtil.hasSpecialization(SowingMachine, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, MOD_NAME .. ".CA_SeederSpecialization")
                end
                -- Allow any cultivator to mulch cover crops
                if SpecializationUtil.hasSpecialization(Cultivator, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, MOD_NAME .. ".CA_CultivatorSpecialization")
                end
                -- Extend combines so straw chopping can fertilize the field if desired
                if SpecializationUtil.hasSpecialization(Combine, typeEntry.specializations) then
                    g_vehicleTypeManager:addSpecialization(typeName, MOD_NAME .. ".CA_ChopperSpecialization")
                end
            end
        end
    end
end

---Registers straw as an additional spray type for precision farming, so we can fertilize the ground by applying straw
local function registerStrawAsPrecisionFarmingSprayType(nitrogenMap)
    if nitrogenMap ~= nil then
        -- Act as if the following values were in the precision farming XML:
        local strawApplicationRate = {
            fillTypeIndex = g_fillTypeManager:getFillTypeIndexByName("STRAW"),
            autoAdjustToFruit = false,
            regularRate = 40,
            ratesBySoilType = { { 1, 40 }, { 2, 40 }, { 3, 40 }, { 4, 40 } } -- fixed ratio on all soils
        }
        table.insert(nitrogenMap.applicationRates, strawApplicationRate)
    end
end

---Creates a settings object which can be accessed from the UI and the rest of the code
---@param   mission     table   @The object which is later available as g_currentMission
local function createModSettings(mission)
    mission.conservationAgricultureSettings = CASettings:new()
    addModEventListener(mission.conservationAgricultureSettings)
end

---Destroys the settings object when it is no longer needed.
local function destroyModSettings()
    if g_currentMission ~= nil and g_currentMission.conservationAgricultureSettings ~= nil then
        removeModEventListener(g_currentMission.conservationAgricultureSettings)
        g_currentMission.conservationAgricultureSettings = nil
    end
end

-- Register specializations before type validation
TypeManager.validateTypes = Utils.prependedFunction(TypeManager.validateTypes, registerSpecialization)

-- Do one-time calculations when the map is about to finish loading, and allow global access to the results
g_rollerCrimpingData = RollerCrimpingData.new()
BaseMission.loadMapFinished = Utils.prependedFunction(BaseMission.loadMapFinished, function(...)
        CASettingsRepository.restoreSettings()
        -- for some reason the nitrogen map isn't loaded when loading the map has finished, so we register an override now 
        -- that we can at least be sure that precision farming was loaded        
        if g_modIsLoaded["FS22_precisionFarming"] then
            FS22_precisionFarming.NitrogenMap.loadFromXML = Utils.overwrittenFunction(FS22_precisionFarming.NitrogenMap.loadFromXML, function(nitrogenMap, superFunc, ...)
                local result = superFunc(nitrogenMap, ...)
                registerStrawAsPrecisionFarmingSprayType(nitrogenMap)
                return result
            end)
        end
    end)

-- Create (and cleanup) a global settings object
Mission00.load = Utils.prependedFunction(Mission00.load, createModSettings)
FSBaseMission.delete = Utils.appendedFunction(FSBaseMission.delete, destroyModSettings)
FSBaseMission.onConnectionReady = Utils.appendedFunction(FSBaseMission.onConnectionReady, function(...) CASettings.publishNewSettings() end )

-- Add elements to the settings UI
InGameMenuGeneralSettingsFrame.onFrameOpen = Utils.appendedFunction(InGameMenuGeneralSettingsFrame.onFrameOpen, CASettingsGUI.inj_onFrameOpen)
InGameMenuGeneralSettingsFrame.updateGameSettings = Utils.appendedFunction(InGameMenuGeneralSettingsFrame.updateGameSettings, CASettingsGUI.inj_updateGameSettings)

-- Save and load settings (loading is done in loadMapFinished)
FSBaseMission.saveSavegame = Utils.appendedFunction(FSBaseMission.saveSavegame, CASettingsRepository.storeSettings)