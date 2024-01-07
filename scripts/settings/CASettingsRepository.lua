---@class CASettingsRepository
---This class is responsible for reading and writing settings
CASettingsRepository = {
    CA_KEY = "conservationAgriculture",
    ROLLER_CRIMPING_KEY = "rollerCrimping",
    ROLLER_MULCH_BONUS_KEY = "rollerMulchBonus",
    SEEDER_MULCH_BONUS_KEY = "seederMulchBonus",
    WEED_SUPPRESSION_KEY = "weedSuppression",
    SEEDER_FIELD_CREATION_KEY = "seederFieldCreation",
    FERTILIZATION_BEHAVIOR_KEY = "fertilizationBehavior",
    GRASS_DROPPING_KEY = "grassDropping",
    BASE_GAME_KEY = "baseGame",
    PF_KEY = "precisionFarming",
    STATE_ATTRIBUTE = "state"
}

---Creates and returns an XML schema for the settings.
---@return  table   @the XML schema
function CASettingsRepository.createXmlSchema()
    local xmlSchema = XMLSchema.new(CASettingsRepository.CA_KEY)

    xmlSchema.register(XmlValueType.BOOL, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.ROLLER_CRIMPING_KEY))
    xmlSchema.register(XmlValueType.BOOL, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.ROLLER_MULCH_BONUS_KEY))
    xmlSchema.register(XmlValueType.BOOL, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.SEEDER_MULCH_BONUS_KEY))
    xmlSchema.register(XmlValueType.BOOL, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.WEED_SUPPRESSION_KEY))
    xmlSchema.register(XmlValueType.BOOL, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.SEEDER_FIELD_CREATION_KEY))
    xmlSchema.register(XmlValueType.BOOL, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.GRASS_DROPPING_KEY))

    local fertilizationBehaviorPath = CASettingsRepository.CA_KEY .. "." .. CASettingsRepository.FERTILIZATION_BEHAVIOR_KEY

    xmlSchema.register(XmlValueType.INT, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.BASE_GAME_KEY, fertilizationBehaviorPath))
    xmlSchema.register(XmlValueType.INT, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.PF_KEY, fertilizationBehaviorPath))

    return xmlSchema
end

---Writes the settings to a separate XML file in the save game folder
function CASettingsRepository.storeSettings()
    local xmlPath = CASettingsRepository.getXmlFilePath()
    local settings = g_currentMission.conservationAgricultureSettings
    if xmlPath == nil or settings == nil then return end

    -- Create an empty XML file
    local settingsXmlId = createXMLFile("CASettings", xmlPath, CASettingsRepository.CA_KEY)

    -- Add XML data in memory
    setXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.ROLLER_CRIMPING_KEY), settings.rollerCrimpingIsEnabled)
    setXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.ROLLER_MULCH_BONUS_KEY), settings.rollerMulchBonusIsEnabled)
    setXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.SEEDER_MULCH_BONUS_KEY), settings.seederMulchBonusIsEnabled)
    setXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.WEED_SUPPRESSION_KEY), settings.weedSuppressionIsEnabled)
    setXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.SEEDER_FIELD_CREATION_KEY), settings.directSeederFieldCreationIsEnabled)
    setXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.GRASS_DROPPING_KEY), settings.grassDroppingIsEnabled)

    local fertilizationBehaviorPath = CASettingsRepository.CA_KEY .. "." .. CASettingsRepository.FERTILIZATION_BEHAVIOR_KEY

    setXMLInt(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.BASE_GAME_KEY, fertilizationBehaviorPath), settings.fertilizationBehaviorBaseGame)
    setXMLInt(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.PF_KEY, fertilizationBehaviorPath), settings.fertilizationBehaviorPF)

    -- Write the XML file to the disk
    saveXMLFile(settingsXmlId)
end

---Reads the settings from an existing XML file (or leaves them at default if there is none yet)
function CASettingsRepository.restoreSettings()
    local xmlPath = CASettingsRepository.getXmlFilePath()
    local settings = g_currentMission.conservationAgricultureSettings
    if xmlPath == nil or settings == nil then return end

    if not fileExists(xmlPath) then
        print(MOD_NAME .. ": No settings found, using default settings")
        return
    end

    -- Load the XML if possible
    local settingsXmlId = loadXMLFile("CASettings", xmlPath)
    if settingsXmlId == 0 then return end

    -- Read XML from memory
    settings.rollerCrimpingIsEnabled = getXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.ROLLER_CRIMPING_KEY))
    settings.rollerMulchBonusIsEnabled = getXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.ROLLER_MULCH_BONUS_KEY))
    settings.seederMulchBonusIsEnabled = getXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.SEEDER_MULCH_BONUS_KEY))
    settings.weedSuppressionIsEnabled = getXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.WEED_SUPPRESSION_KEY))
    settings.directSeederFieldCreationIsEnabled = getXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.SEEDER_FIELD_CREATION_KEY))

    -- This value was added in 0.7 so older save games might not have it
    settings.grassDroppingIsEnabled = getXMLBool(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.GRASS_DROPPING_KEY))
    if settings.grassDroppingIsEnabled == nil then
        settings.grassDroppingIsEnabled = false
    end

    local fertilizationBehaviorPath = CASettingsRepository.CA_KEY .. "." .. CASettingsRepository.FERTILIZATION_BEHAVIOR_KEY

    settings.fertilizationBehaviorBaseGame = getXMLInt(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.BASE_GAME_KEY, fertilizationBehaviorPath))
    settings.fertilizationBehaviorPF = getXMLInt(settingsXmlId, CASettingsRepository.getXmlStateAttributePath(CASettingsRepository.PF_KEY, fertilizationBehaviorPath))
end


---Builds an XML path for the given parameters
---@param   attribute       string      @the XML attribute
---@param   property        string      @the XML property which contains the attribute
---@param   parentProperty  any         @the parent property (if this is empty, the root node will be used)
---@return  string      @the XML path
function CASettingsRepository.getXmlAttributePath(attribute, property, parentProperty)
    local parentProp = parentProperty or CASettingsRepository.CA_KEY
    return parentProp .. "." .. property .. "#" .. attribute
end

---Builds an XML path for "state" values like bool or enums
---@param   property        string      @the XML property which contains the attribute
---@param   parentProperty  any         @the parent property (if this is empty, the root node will be used)
---@return  string      @the XML path
function CASettingsRepository.getXmlStateAttributePath(property, parentProperty)
    return CASettingsRepository.getXmlAttributePath(CASettingsRepository.STATE_ATTRIBUTE, property, parentProperty)
end

---Builds a path to the XML file which contains the settings
---@return  any      @The path to the XML or nil
function CASettingsRepository.getXmlFilePath()
    if g_currentMission.missionInfo and g_currentMission.missionInfo.savegameDirectory ~= nil then
        return g_currentMission.missionInfo.savegameDirectory .. "/" .. MOD_NAME .. ".xml"
    end
    return nil
end