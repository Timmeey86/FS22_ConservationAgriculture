---@class CALockMapRepository
---This class is responsible for reading and writing work areas which need to have their lock bits reset after the next crop growth stage
CALockMapRepository = {
    CA_KEY = "conservationAgriculture",
    WORK_AREAS_KEY = "workAreas",
    WORK_AREA_KEY = "workArea",
    X1_KEY = "x1",
    Z1_KEY = "z1",
    X2_KEY = "x2",
    Z2_KEY = "z2",
    X3_KEY = "x3",
    Z3_KEY = "z3"
}

-- TODO This is currently not being used
---Creates and returns an XML schema for the settings
---@eturn table @The XML schema
function CALockMapRepository.createXmlSchema()
    local xmlSchema = XMLSchema.new(CALockMapRepository.CA_KEY)

    local workAreaKey = ("%s.%s.%s(?)#"):format(CALockMapRepository.CA_KEY, CALockMapRepository.WORK_AREAS_KEY, CALockMapRepository.WORK_AREA_KEY)
    xmlSchema:register(XMLValueType.FLOAT, workAreaKey .. CALockMapRepository.X1_KEY)
    xmlSchema:register(XMLValueType.FLOAT, workAreaKey .. CALockMapRepository.Z1_KEY)
    xmlSchema:register(XMLValueType.FLOAT, workAreaKey .. CALockMapRepository.X2_KEY)
    xmlSchema:register(XMLValueType.FLOAT, workAreaKey .. CALockMapRepository.Z2_KEY)
    xmlSchema:register(XMLValueType.FLOAT, workAreaKey .. CALockMapRepository.X3_KEY)
    xmlSchema:register(XMLValueType.FLOAT, workAreaKey .. CALockMapRepository.Z3_KEY)

    return xmlSchema
end

---Writes lock map data to a separate XML file in the save game folder
function CALockMapRepository.storeLockMapData()
    if not g_modIsLoaded["FS22_precisionFarming"] then
        return
    end

    local lockMap = FS22_precisionFarming.g_precisionFarming.caNitrogenLockMap
    local xmlPath = CALockMapRepository.getXmlFilePath()

    -- Create an XML File
    local xmlHandle = createXMLFile("CALockMap", xmlPath, CALockMapRepository.CA_KEY)

    -- Add XML content
    local workAreaKey = ("%s.%s.%s"):format(CALockMapRepository.CA_KEY, CALockMapRepository.WORK_AREAS_KEY, CALockMapRepository.WORK_AREA_KEY)
    for i, coords in ipairs(lockMap.pendingWorkAreas) do
        local paramKey = ("%s(%d)."):format(workAreaKey, i - 1)
        setXMLFloat(xmlHandle, paramKey .. CALockMapRepository.X1_KEY, coords.x1)
        setXMLFloat(xmlHandle, paramKey .. CALockMapRepository.Z1_KEY, coords.z1)
        setXMLFloat(xmlHandle, paramKey .. CALockMapRepository.X2_KEY, coords.x2)
        setXMLFloat(xmlHandle, paramKey .. CALockMapRepository.Z2_KEY, coords.z2)
        setXMLFloat(xmlHandle, paramKey .. CALockMapRepository.X3_KEY, coords.x3)
        setXMLFloat(xmlHandle, paramKey .. CALockMapRepository.Z3_KEY, coords.z3)
    end

    -- Write the XML file to the disk
    saveXMLFile(xmlHandle)
end

---Restores lock map data from an XML file in the save game folder
function CALockMapRepository.restoreLockMapData()
    if not g_modIsLoaded["FS22_precisionFarming"] then
        return
    end

    local lockMap = FS22_precisionFarming.g_precisionFarming.caNitrogenLockMap
    local xmlPath = CALockMapRepository.getXmlFilePath()

    if not fileExists(xmlPath) then
        -- Mod hasn't been active during the last save most likely
        return
    end
    -- Load the XML if possible
    local xmlFile = XMLFile.load("CALockMap", xmlPath, CALockMapRepository.createXmlSchema())
    if xmlFile == nil then
        return
    end

    -- Read XML from memory
    local workAreaKey = ("%s.%s.%s"):format(CALockMapRepository.CA_KEY, CALockMapRepository.WORK_AREAS_KEY, CALockMapRepository.WORK_AREA_KEY)
    xmlFile:iterate(workAreaKey, function (i, workAreaInstanceKey)
        local coords = {
            x1 = xmlFile:getFloat(workAreaInstanceKey .. "." .. CALockMapRepository.X1_KEY),
            z1 = xmlFile:getFloat(workAreaInstanceKey .. "." .. CALockMapRepository.Z1_KEY),
            x2 = xmlFile:getFloat(workAreaInstanceKey .. "." .. CALockMapRepository.X2_KEY),
            z2 = xmlFile:getFloat(workAreaInstanceKey .. "." .. CALockMapRepository.Z2_KEY),
            x3 = xmlFile:getFloat(workAreaInstanceKey .. "." .. CALockMapRepository.X3_KEY),
            z3 = xmlFile:getFloat(workAreaInstanceKey .. "." .. CALockMapRepository.Z3_KEY)
        }
        lockMap.pendingWorkAreas[i] = coords
    end)
end

---Builds a path to the XML file which contains the settings
---@return  any      @The path to the XML or nil
function CALockMapRepository.getXmlFilePath()
    if g_currentMission.missionInfo and g_currentMission.missionInfo.savegameDirectory ~= nil then
        return g_currentMission.missionInfo.savegameDirectory .. "/" .. MOD_NAME .. "_lockMap.xml"
    end
    return nil
end