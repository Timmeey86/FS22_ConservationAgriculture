CASettingsGUI = {
    -- Static definitions
    MOD_NAME = g_currentModName or "Conservation Agriculture",
    I18N_IDS = {
        GROUP_TITLE = 'ca_group_title',
        ENABLE_ROLLER_CRIMPING = 'ca_enable_roller_crimping',
        ENABLE_ROLLER_MULCH_BONUS = 'ca_enable_roller_mulch_bonus',
        ENABLE_SEEDER_MULCH_BONUS = 'ca_enable_seeder_mulch_bonus',
        FERTILIZATION_BEHAVIOR_BASE_GAME = 'ca_fertilization_behavior_base_game',
        FERTILIZATION_BEHAVIOR_PF = 'ca_fertilization_behavior_pf',
        ENABLE_WEED_SUPPRESSION = 'ca_enable_weed_suppression',
        ALLOW_DIRECT_SEEDER_FIELD_CREATION = 'ca_allow_direct_seeder_field_creation'
    },
    -- Order must correspond to the enum in CASettings. We can't reuse it unfortunately
    FERTILIZATION_BEHAVIOR_BASE_GAME_I18N_IDS = {
        { index = 1, i18nTextId = 'ca_fertilization_behavior_base_game_off' },
        { index = 2, i18nTextId = 'ca_fertilization_behavior_base_game_first' },
        { index = 3, i18nTextId = 'ca_fertilization_behavior_base_game_full' }
    },
    FERTILIZATION_BEHAVIOR_PF_I18N_IDS = {
        { index = 1, i18nTextId = 'ca_fertilization_behavior_pf_off' },
        { index = 2, i18nTextId = 'ca_fertilization_behavior_pf_min_auto' }
        -- This could be extended by "fixed value" if we can get it to work
    }
}

--- Adds a simple yes/no switch to the UI
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function CASettingsGUI.createBoolElement(generalSettingsPage, id, i18nTextId, callbackFunc)
    -- Most other mods seem to clone an element rather than creating a new one
    local boolElement = generalSettingsPage.checkUseEasyArmControl:clone()
    -- Assign the object which shall receive change events
    boolElement.target = g_currentMission.conservationAgricultureSettings
    -- Change relevant values
    boolElement.id = id
    boolElement:setLabel(g_i18n:getText(i18nTextId .. "_short"))
    -- Element #6 is the tool tip. Maybe we can find a more robust way to get this in future
    boolElement.elements[6]:setText(g_i18n:getText(i18nTextId .. "_long"))
    boolElement:setCallback("onClickCallback", callbackFunc)
    generalSettingsPage.boxLayout:addElement(boolElement)

    return boolElement
end

--- Creates an element which allows choosing one out of several values
---@param generalSettingsPage   table       @The base game object for the settings page
---@param id                    string      @The unique ID of the new element
---@param i18nTextId            string      @The key in the internationalization XML (must be two keys with a _short and _long suffix)
---@param i18nValueMap          table       @An map of values containing translation IDs for the possible values
---@param callbackFunc          string      @The name of the function to call when the value changes
---@return                      table       @The created object
function CASettingsGUI.createChoiceElement(generalSettingsPage, id, i18nTextId, i18nValueMap, callbackFunc)
    -- Create a bool element and then change its values
    local choiceElement = CASettingsGUI.createBoolElement(generalSettingsPage, id, i18nTextId, callbackFunc)

    local texts = {}
    for _, valueEntry in pairs(i18nValueMap) do
        table.insert(texts, g_i18n:getText(valueEntry.i18nTextId))
    end
    choiceElement:setTexts(texts)

    return choiceElement
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
    groupTitle:setText(CASettingsGUI.I18N_IDS.GROUP_TITLE)
    generalSettingsPage.boxLayout:addElement(groupTitle)

    -- Create yes/no settings
    generalSettingsPage.ca_enableRollerCrimping = CASettingsGUI.createBoolElement(
        generalSettingsPage,
        "ca_enableRollerCrimping",                      -- ID
        CASettingsGUI.I18N_IDS.ENABLE_ROLLER_CRIMPING,  -- Translatable Text
        "onEnableRollerCrimpingChanged")                -- Callback function (in the CASettings class)
    generalSettingsPage.ca_enableRollerMulchBonus = CASettingsGUI.createBoolElement(
        generalSettingsPage,
        "ca_enableRollerMulchBonus",
        CASettingsGUI.I18N_IDS.ENABLE_ROLLER_MULCH_BONUS,
        "onEnableRollerMulchBonusChanged")
    generalSettingsPage.ca_enableSeederMulchBonus = CASettingsGUI.createBoolElement(
        generalSettingsPage,
        "ca_enableSeederMulchBonus",
        CASettingsGUI.I18N_IDS.ENABLE_SEEDER_MULCH_BONUS,
        "onEnableSeederMulchBonus")
    generalSettingsPage.ca_enableWeedSuppression = CASettingsGUI.createBoolElement(
        generalSettingsPage,
        "ca_enableWeedSuppression",
        CASettingsGUI.I18N_IDS.ENABLE_WEED_SUPPRESSION,
        "onEnableWeedSuppression")
    generalSettingsPage.ca_enableDirectSeederFieldCreation = CASettingsGUI.createBoolElement(
        generalSettingsPage,
        "ca_enableDirectSeederFieldCreation",
        CASettingsGUI.I18N_IDS.ALLOW_DIRECT_SEEDER_FIELD_CREATION,
        "onEnableDirectSeederFieldCreation")

    -- The list of active mods doesn't change in the same playthrough so it's enough to show either base game or precision farming
    if FS22_precisionFarming.g_precisionFarming then
        generalSettingsPage.ca_fertilizationBehavioPF= CASettingsGUI.createChoiceElement(
            generalSettingsPage,
            "ca_fertilizationBehaviorPF",
            CASettingsGUI.I18N_IDS.FERTILIZATION_BEHAVIOR_PF,
            CASettingsGUI.FERTILIZATION_BEHAVIOR_PF_I18N_IDS,
            "onFertilizationBehaviorPFChanged")
    else
        generalSettingsPage.ca_fertilizationBehaviorBaseGame = CASettingsGUI.createChoiceElement(
            generalSettingsPage,
            "ca_fertilizationBehaviorBaseGame",
            CASettingsGUI.I18N_IDS.FERTILIZATION_BEHAVIOR_BASE_GAME,
            CASettingsGUI.FERTILIZATION_BEHAVIOR_BASE_GAME_I18N_IDS,
            "onFertilizationBehaviorBaseGameChanged")
    end


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
    local settings = g_currentMission.conservationAgricultureSettings
    if not settings then
        return
    end
    generalSettingsPage.ca_enableRollerCrimping:setIsChecked(settings.rollerCrimpingIsEnabled)
    generalSettingsPage.ca_enableRollerMulchBonus:setIsChecked(settings.rollerMulchBonusIsEnabled)
    generalSettingsPage.ca_enableSeederMulchBonus:setIsChecked(settings.seederMulchBonusIsEnabled)
    generalSettingsPage.ca_enableWeedSuppression:setIsChecked(settings.weedSuppressionIsEnabled)
    generalSettingsPage.ca_enableDirectSeederFieldCreation:setIsChecked(settings.directSeederFieldCreationIsEnabled)
    if generalSettingsPage.ca_fertilizationBehaviorPF ~= nil then
        generalSettingsPage.ca_fertilizationBehaviorPF:setState(settings.fertilizationBehaviorPF)
    elseif generalSettingsPage.ca_fertilizationBehaviorBaseGame ~= nil then
        generalSettingsPage.ca_fertilizationBehaviorBaseGame:setState(settings.fertilizationBehaviorBaseGame)
    end
end