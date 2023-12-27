---@class SeederFertilizerSpecialization
---This class is responsible for adding a specialization to Seeders in order to provide a fertilization boost when direct seeding into cover crops
---Note that basegame adds one fertilization stage and precision farming 25kg of nitrogen for oilseed radish.
---This class also contains the "limitToField" mechanic which is available for plows. Unfortunately, the plow would do too much for what we want,
---so this class contains a lot of code similar from the Plow specialization's LUADOC and won't get updated when GIANTS ever changes the PLOW spec.
SeederFertilizerSpecialization = {
}

--- Checks for other required specializations.
---Since this is only added to implements with the SowingMachine specilization anyway, we don't need to check anything here.
---@param   specializations     table   @A table of existing specializations (unused).
---@return  boolean     @Always true
function SeederFertilizerSpecialization.prerequisitesPresent(specializations)
    return true
end

--- Overrides the processRollerArea so we can add fertilizer during the sowing process
---@param   vehicleType     table     @Provides information about the current vehicle (or rather implement) type.
function SeederFertilizerSpecialization.registerOverwrittenFunctions(vehicleType)
    SpecializationUtil.registerOverwrittenFunction(vehicleType, "processSowingMachineArea", SeederFertilizerSpecialization.processSowingMachineArea)
end

--- Registers the "create field" action (which will only be available for direct seeders)
---@param   vehicleType     table     @Provides information about the current vehicle (or rather implement) type.
function SeederFertilizerSpecialization.registerEventListeners(vehicleType)	
    SpecializationUtil.registerEventListener(vehicleType, "onLoad", SeederFertilizerSpecialization)
    SpecializationUtil.registerEventListener(vehicleType, "onRegisterActionEvents", SeederFertilizerSpecialization)
    SpecializationUtil.registerEventListener(vehicleType, "onPreDetach", SeederFertilizerSpecialization)
    SpecializationUtil.registerEventListener(vehicleType, "onStartWorkAreaProcessing", SeederFertilizerSpecialization)
    SpecializationUtil.registerEventListener(vehicleType, "onUpdate", SeederFertilizerSpecialization)
end

--- Registers functions for setting or retrieving the "limit to field" state on seeders
---@param vehicleType table @The vehicle which shall receive the functions
function SeederFertilizerSpecialization.registerFunctions(vehicleType)
    SpecializationUtil.registerFunction(vehicleType, "setLimitToField", SeederFertilizerSpecialization.setLimitToField)
    SpecializationUtil.registerFunction(vehicleType, "getLimitToField", SeederFertilizerSpecialization.getLimitToField)
end

--- One-time initialization of this specialization
---@param savegame table @The save game
function SeederFertilizerSpecialization:onLoad(savegame)
    self.spec_CA_SeederSpecialization = self["spec_FS22_ConservationAgriculture.CA_SeederSpecialization"]
    local spec = self.spec_CA_SeederSpecialization

    -- Prepare the possibility to toggle field creation.
    spec.limitToField = true
    spec.texts = {}
    -- Reuse the basegame texts for plows
    spec.texts.allowCreateFields = g_i18n:getText("action_allowCreateFields")
    spec.texts.limitToField = g_i18n:getText("action_limitToFields")

    spec.workAreaParameters = {}
    spec.workAreaParameters.limitToField = spec.limitToField
end

--- Registers an action for toggling the "allow field creation" option
---@param isActiveForInput boolean @Unused
---@param isActiveForInputIgnoreSelection boolean @Event will only be registered if this is true.
function SeederFertilizerSpecialization:onRegisterActionEvents(isActiveForInput, isActiveForInputIgnoreSelection)
    if self.isClient then
        local spec = self.spec_CA_SeederSpecialization
        local basegameSpec = self.spec_sowingMachine
        self:clearActionEventsTable(spec.actionEvents)

        -- Add an event for toggling the "allow field creation" mode
        -- No idea what most of the bool flags do; settings are copied from what the Plow specialization does
        if isActiveForInputIgnoreSelection and basegameSpec.useDirectPlanting  then
            local _, actionEventId = self:addActionEvent(spec.actionEvents, InputAction.IMPLEMENT_EXTRA4, self, SeederFertilizerSpecialization.actionEventLimitToField, false, true, false, true, nil)
            g_inputBinding:setActionEventTextPriority(actionEventId, GS_PRIO_HIGH)
        end
    end
end

--- Toggles the "limit to field" property every time the user presses the appropriate keybind for it.
---Note: The plow specialization has a "force limit to field" feature, but it looks like this is only used by stump cutters so we don't introduce that here
---@param actionName any @Unused
---@param inputValue any @Unused
---@param callbackState any @Unused
---@param isAnalog any @Unused
function SeederFertilizerSpecialization:actionEventLimitToField(actionName, inputValue, callbackState, isAnalog)
    local spec = self.spec_CA_SeederSpecialization
    self:setLimitToField(not spec.limitToField, false)
end

--- Turns of field creation before detaching the implement
---@param attacherVehicle table @Unusued
---@param implement table @Unused
function SeederFertilizerSpecialization:onPreDetach(attacherVehicle, implement)
    local spec = self.spec_CA_SeederSpecialization
    spec.limitToField = true
end

--- Allows field creation if it is turned on and the player has the permission for it (in multiplayer)
---@param dt any @Unused
function SeederFertilizerSpecialization:onStartWorkAreaProcessing(dt)
    local spec = self.spec_CA_SeederSpecialization
    local limitToField = spec.limitToField
    if not g_currentMission:getHasPlayerPermission("createFields", self:getOwner(), nil, true) then
        limitToField = true
    end
    spec.workAreaParameters.limitToField = limitToField
end

--- Adjusts the text to be displayed for the action to toggle field creation dependent on the current state
---@param dt any @Unused
---@param isActiveForInput any @Unused
---@param isActiveForInputIgnoreSelection any @Unused
---@param isSelected any @Unused
function SeederFertilizerSpecialization:onUpdate(dt, isActiveForInput, isActiveForInputIgnoreSelection, isSelected)
    if self.isClient then
        local spec = self.spec_CA_SeederSpecialization
        local basegameSpec = self.spec_sowingMachine
        local limitToFieldEvent = spec.actionEvents[InputAction.IMPLEMENT_EXTRA4]
        if limitToFieldEvent ~= nil then
            if basegameSpec.useDirectPlanting and g_currentMission:getHasPlayerPermission("createFields", self:getOwner()) then
                -- Allow the player to toggle the event
                g_inputBinding:setActionEventActive(limitToFieldEvent.actionEventId, true)

                -- Display a different text dependent on the state
                if self:getLimitToField() then
                    g_inputBinding:setActionEventText(limitToFieldEvent.actionEventId, spec.texts.allowCreateFields)
                else
                    g_inputBinding:setActionEventText(limitToFieldEvent.actionEventId, spec.texts.limitToField)
                end
            else
                -- Disable the action since the player either doesn't have permissions or doesn't use a direct seeder/planter
                g_inputBinding:setActionEventActive(limitToFieldEvent.actionEventId, false)
            end
        end
    end
end

--- Checks whether or not the direct seeder may only seed within existing field bounds
---@return boolean @True if the seeder may only operate within the field
function SeederFertilizerSpecialization:getLimitToField()
    return self.spec_CA_SeederSpecialization.limitToField
end

--- Enables or disables field creation for direct seeders
---@param newValue boolean @The new "limit to field" value.
---@param noEventSend boolean @True if no event shall be sent.
function SeederFertilizerSpecialization:setLimitToField(newValue, noEventSend)
    local spec = self.spec_CA_SeederSpecialization

    if spec.limitToField ~= newValue then
        if noEventSend == nil or noEventSend == false then
            if g_server ~= nil then
                g_server:broadcastEvent(SowingMachineLimitToFieldEvent.new(self, newValue), nil, nil, self)
            else
                g_client:getServerConnection():sendEvent(SowingMachineLimitToFieldEvent.new(self, newValue))
            end
            spec.limitToField = newValue

            -- This is similar to what onUpdate does, but the Plow spec has it, so there is probably a reason for doing it here (e.g. update otherwise too late)
            local actionEvent = spec.actionEvents[InputAction.IMPLEMENT_EXTRA4]
            if actionEvent ~= nil then
                local text
                if spec.limitToField then
                    text = spec.texts.allowCreateFields
                else
                    text = spec.texts.limitToFields
                end
                g_inputBinding:setActionEventText(actionEvent.actionEventId, text)
            end
        end
    end
end

--- Creates a field area where there is no field area yet
---@param workArea table @the work area to be analyzed
function SeederFertilizerSpecialization:createFieldArea(workArea)
    -- Retrieve world coordinates for the work area
    local coords = CoverCropUtils.getWorldCoords(workArea)

    -- Clear any deco stuff which is in the way
    FSDensityMapUtil.clearDecoArea(coords.x1, coords.z1, coords.x2, coords.z2, coords.x3, coords.z3)

    -- Set any ground which is not on the field to plowed. This is only temporary as that area will be seeded into right after
    local groundTypeModifier = CoverCropUtils.getDensityMapModifier(coords, FieldDensityMap.GROUND_TYPE)
    local notOnFieldFilter = DensityMapFilter.new(groundTypeModifier)
    notOnFieldFilter:setValueCompareParams(DensityValueCompareType.EQUAL, 0)
    groundTypeModifier:executeSet(g_currentMission.fieldGroundSystem:getFieldGroundValue(FieldGroundType.PLOWED), notOnFieldFilter)
end

--- Adds fertilizer when sowing ready-to-harvest cover crops
---@param   superFunc   function        @The GIANTS implementation of the method.
---@param   workArea    table           @Provides information about the area to be mulched.
---@param   dt          table           @delta time? Not used here.
---@return  integer     @The amount of pixels which were processed
---@return  integer     @The amount of pixels in the work area
function SeederFertilizerSpecialization:processSowingMachineArea(superFunc, workArea, dt)

    local spec = self.spec_CA_SeederSpecialization
    local basegameSpec = self.spec_sowingMachine

    -- Skip our own code if:
    -- - The machine is not active
    -- - The machine is stationary
    -- - The currently selected fruit can't be planted in the current month
    -- - There are no seeds and it's the player seeding
    -- - There are no seeds and it's the AI seeding, but the AI is not allowed to buy seeds
    local skipSpecialization =
        not basegameSpec.workAreaParameters.isActive or
        self:getLastSpeed() <= 0.5 or
        not basegameSpec.workAreaParameters.canFruitBePlanted or
        (basegameSpec.workAreaParameters.seedsVehicle == nil and (not self:getIsAIActive() or not g_currentMission.missionInfo.helperBuySeeds))

    if not skipSpecialization then
        -- In case of direct seeders/planters, create fields where necessary if that feature is turned on
        if g_currentMission.conservationAgricultureSettings.directSeederFieldCreationIsEnabled and basegameSpec.useDirectPlanting and not spec.workAreaParameters.limitToField then
            SeederFertilizerSpecialization:createFieldArea(workArea)
        end

        -- Fertilize any cover crops in the work area, but do not set the "mulched" ground
        -- Otherwise, there would be no benefit of mulching/roller crimping before sowing
        CoverCropUtils.mulchAndFertilizeCoverCrops(workArea, g_currentMission.conservationAgricultureSettings.seederMulchBonusIsEnabled)
    end

    -- Execute base game behavior
    return superFunc(self, workArea, dt)
end
