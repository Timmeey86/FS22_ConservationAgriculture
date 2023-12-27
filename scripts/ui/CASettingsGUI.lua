CASettingsGUI = {
    -- Static definitions
    MOD_NAME = g_currentModName or "Conservation Agriculture",
    I18N_IDS = {
        GROUP_TITLE = 'ca_group_title',
        ENABLE_ROLLER_CRIMPING = 'ca_enable_roller_crimping',
        ENABLE_ROLLER_MULCH_BONUS = 'ca_enable_roller_mulch_bonus',
        FERTILIZATION_BEHAVIOR_BASE_GAME = 'ca_fertilization_behavior_base_game',
        FERTILIZATION_BEHAVIOR_BASE_GAME_OFF = 'ca_fertilization_behavior_base_game_off',
        FERTILIZATION_BEHAVIOR_BASE_GAME_ONE_LEVEL = 'ca_fertilization_behavior_base_game_one_level',
        FERTILIZATION_BEHAVIOR_BASE_GAME_TWO_LEVELS = 'ca_fertilization_behavior_base_game_two_levels',
        FERTILIZATION_BEHAVIOR_PF = 'ca_fertilization_behavior_pf',
        FERTILIZATION_BEHAVIOR_PF_OFF = 'ca_fertilization_behavior_pf_off',
        --FERTILIZATION_BEHAVIOR_PF_FIXED = 'ca_fertilization_behavior_pf_fixed',  <-- Not implemented yet
        FERTILIZATION_BEHAVIOR_PF_MIN_AUTO = 'ca_fertilization_behavior_pf_min_auto',
        ENABLE_WEED_SUPPRESSION = 'ca_enable_weed_suppression',
        ALLOW_DIRECT_SEEDER_FIELD_CREATION = 'ca_allow_direct_seeder_field_creation'
    }
}

--- Adds a simple yes/no switch to the UI
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param label                 string      @The label to be displayed
---@param tooltip               string      @The tooltip to be displayed
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function CASettingsGUI.createBoolElement(generalSettingsPage, id, label, tooltip, callbackFunc)
    -- Most other mods seem to clone an element rather than create a new one
    local boolElement = generalSettingsPage.checkUseEasyArmControl:clone()
    -- Assign the object which shall receive change events
    boolElement.target = g_currentMission.conservationAgricultureSettings
    -- Change relevant values
    boolElement.id = id
    boolElement:setLabel(label)
    boolElement.elements[6]:setText(tooltip)
    boolElement:setCallback("onClickCallback", callbackFunc)
    generalSettingsPage.boxLayout:addElement(boolElement)

    return boolElement
end


--- This gets called every time the settings page gets opened
---@param   generalSettingsPage     table   @The instance of the base game's general settings page
function CASettingsGUI.inj_onFrameOpen(generalSettingsPage)
    if generalSettingsPage.conservationAgricultureInitialized then
        return
    end

    -- Create a text for the title and configure it as subtitle
    local groupTitle = TextElement.new()
    groupTitle:applyProfile("settingsMenuSubtitle", true)
    --groupTitle:setText(g_i18n:getText(CASettingsGUI.I18N_IDS.GROUP_TITLE))
    groupTitle:setText("TEMP")
    generalSettingsPage.boxLayout:addElement(groupTitle)

    -- Create a yes/no setting for roller crimping. The default way of doing this seems to be cloning an existing UI element and modifying its properties
    generalSettingsPage.ca_enableRollerCrimping = CASettingsGUI.createBoolElement(
        generalSettingsPage,
        "ca_enableRollerCrimping",
         "TEMP",
         "TEMP2",
         "onEnableRollerCrimpingChanged")

    -- Apply the initial values
    CASettingsGUI.updateUiElements(generalSettingsPage)

    generalSettingsPage.conservationAgricultureInitialized = true
end

--- This gets called every time the settings page gets updated
---@param   generalSettingsPage     table   @The instance of the base game's general settings page
function CASettingsGUI.inj_updateGameSettings(generalSettingsPage)
    if generalSettingsPage.conservationAgricultureInitialized then
        CASettingsGUI.updateUiElement(generalSettingsPage)
    end
end

--- Updates the UI elements to the current settings
---@param   generalSettingsPage     table   @The instance of the base game's general settings page
function CASettingsGUI.updateUiElements(generalSettingsPage)
    generalSettingsPage.ca_enableRollerCrimping:setIsChecked(g_currentMission.conservationAgricultureSettings.rollerCrimpingIsEnabled)
end