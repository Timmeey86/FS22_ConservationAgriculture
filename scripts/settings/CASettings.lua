CASettings = {
    FERTILIZATION_BEHAVIOR_BASE_GAME_OFF = 1,
    FERTILIZATION_BEHAVIOR_BASE_GAME_FIRST = 2,
    FERTILIZATION_BEHAVIOR_BASE_GAME_FULL = 3,
    FERTILIZATION_BEHAVIOR_BASE_GAME_ADD_ONE = 4,
    FERTILIZATION_BEHAVIOR_PF_OFF = 1,
    FERTILIZATION_BEHAVIOR_PF_FIXED_AMOUNT = 2, -- replaces "SUNFLOWERS" strategy
    NITROGEN_MIN = 0,
    NITROGEN_MAX = 100,
    NITROGEN_STEP = 10
}
local CASettings_mt = Class(CASettings)

---Creates a new instance of this class
---@return table @A new class instance
function CASettings.new()
    local self = setmetatable({}, CASettings_mt)
    -- Default settings. Will be overridden by settings stored in XML if available
    self.rollerCrimpingIsEnabled = true
    self.rollerMulchBonusIsEnabled = true
    self.seederMulchBonusIsEnabled = false
    self.weedSuppressionIsEnabled = true
    self.directSeederFieldCreationIsEnabled = true
    self.grassDroppingIsEnabled = false
    self.fertilizationBehaviorBaseGame = CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_ADD_ONE
    self.fertilizationBehaviorPF = CASettings.FERTILIZATION_BEHAVIOR_PF_FIXED_AMOUNT
    -- v1.0.0.9+ (basegame only settings)
    self.strawChoppingBonusIsEnabled = true
    self.cultivatorBonusIsEnabled = true
    -- v1.0.1.0+ (precision farming only settings)
    self.strawChoppingNitrogenBonus = 50 / CASettings.NITROGEN_STEP -- kg/ha
    self.cultivatorNitrogenBonus = 50 / CASettings.NITROGEN_STEP -- kg/ha
    self.rollerCrimpingNitrogenBonus = 80 / CASettings.NITROGEN_STEP -- kg/ha
    self.directSeedingNitrogenBonus = 60 / CASettings.NITROGEN_STEP -- kg/ha

    -- Required to work around mod conflicts
    self.preventWeeding = false
    return self
end

---Converts STATE_CHECKED and STATE_UNCHECKED values to bool
---@param checkState    integer     @the check state
---@return boolean @true if checkState is STATE_CHECKED
function CASettings.checkStateToBool(checkState)
    return checkState == CheckedOptionElement.STATE_CHECKED
end

-- These functions react to changes by the user in the settings dialog

function CASettings:onEnableRollerCrimpingChanged(newState)
    self.rollerCrimpingIsEnabled = CASettings.checkStateToBool(newState)
    CASettings.publishNewSettings()
end
function CASettings:onEnableRollerMulchBonusChanged(newState)
    self.rollerMulchBonusIsEnabled = CASettings.checkStateToBool(newState)
    CASettings.publishNewSettings()
end
function CASettings:onEnableSeederMulchBonusChanged(newState)
    self.seederMulchBonusIsEnabled = CASettings.checkStateToBool(newState)
    CASettings.publishNewSettings()
end
function CASettings:onEnableWeedSuppressionChanged(newState)
    self.weedSuppressionIsEnabled = CASettings.checkStateToBool(newState)
    CASettings.publishNewSettings()
end
function CASettings:onEnableDirectSeederFieldCreationChanged(newState)
    self.directSeederFieldCreationIsEnabled = CASettings.checkStateToBool(newState)
    CASettings.publishNewSettings()
end
function CASettings:onEnableGrassDroppingChanged(newState)
    self.grassDroppingIsEnabled = CASettings.checkStateToBool(newState)
    CASettings.publishNewSettings()
end
function CASettings:onFertilizationBehaviorPFChanged(newState)
    self.fertilizationBehaviorPF = newState
    CASettings.publishNewSettings()
end
function CASettings:onFertilizationBehaviorBaseGameChanged(newState)
    self.fertilizationBehaviorBaseGame = newState
    CASettings.publishNewSettings()
end
function CASettings:onEnableStrawChoppingBonusChanged(newState)
    self.strawChoppingBonusIsEnabled = newState
    CASettings.publishNewSettings()
end
function CASettings:onStrawChoppingNitrogenBonusChanged(newState)
    self.strawChoppingNitrogenBonus = newState
    CASettings.publishNewSettings()
end
function CASettings:onCultivatorNitrogenBonusChanged(newState)
    self.cultivatorNitrogenBonus = newState
    CASettings.publishNewSettings()
end
function CASettings:onRollerCrimpingNitrogenBonusChanged(newState)
    self.rollerCrimpingNitrogenBonus = newState
    CASettings.publishNewSettings()
end
function CASettings:onDirectSeedingNitrogenBonusChanged(newState)
    self.directSeedingNitrogenBonus = newState
    CASettings.publishNewSettings()
end

---Retrieves the amount of nitrogen to be applied, as internal precision farming units
---@return number @The nitrogen amount
function CASettings:getStrawChoppingNitrogenValue()
    return self.strawChoppingNitrogenBonus * CASettings.NITROGEN_STEP / 5
end
---Retrieves the amount of nitrogen to be applied, as internal precision farming units
---@return number @The nitrogen amount
function CASettings:getCultivatorNitrogenValue()
    return self.cultivatorNitrogenBonus * CASettings.NITROGEN_STEP / 5
end

---Retrieves the amount of nitrogen to be applied, as internal precision farming units
---@return number @The nitrogen amount
function CASettings:getRollerCrimpingNitrogenValue()
    return self.rollerCrimpingNitrogenBonus * CASettings.NITROGEN_STEP / 5
end

---Retrieves the amount of nitrogen to be applied, as internal precision farming units
---@return number @The nitrogen amount
function CASettings:getDirectSeedingNitrogenValue()
    return self.directSeedingNitrogenBonus * CASettings.NITROGEN_STEP / 5
end


---Sends the new settings to the server, or from the server to all other clients
function CASettings.publishNewSettings()
    if g_server ~= nil then
        -- The call came from the server in multiplayer or from the client in singleplayer.
        -- Broadcast to all connected clients (will do nothing in singleplayer)
        g_server:broadcastEvent(CASettingsChangeEvent.new())
    else
        -- We are a client. Send the event to the server so the server can broadcast it to all other clients
        g_client:getServerConnection():sendEvent(CASettingsChangeEvent.new())
    end
end

---Receives the initial settings from the server when joining a multiplayer game
---@param streamId any @The ID of the stream to read from
---@param connection any @Unused
function CASettings:onReadStream(streamId, connection)
    print(MOD_NAME .. ": Receiving new settings")
    self.rollerCrimpingIsEnabled = streamReadBool(streamId)
    self.rollerMulchBonusIsEnabled = streamReadBool(streamId)
    self.seederMulchBonusIsEnabled = streamReadBool(streamId)
    self.weedSuppressionIsEnabled = streamReadBool(streamId)
    self.directSeederFieldCreationIsEnabled = streamReadBool(streamId)
    self.grassDroppingIsEnabled = streamReadBool(streamId)
    self.fertilizationBehaviorPF = streamReadInt8(streamId)
    self.fertilizationBehaviorBaseGame = streamReadInt8(streamId)
    -- v1.0.9.0+
    self.strawChoppingBonusIsEnabled = streamReadBool(streamId)
    self.cultivatorBonusIsEnabled = streamReadBool(streamId)
    -- v1.0.1.0+
    self.strawChoppingNitrogenBonus = streamReadInt8(streamId)
    self.cultivatorNitrogenBonus = streamReadInt8(streamId)
    self.rollerCrimpingNitrogenBonus = streamReadInt8(streamId)
    self.directSeedingNitrogenBonus = streamReadInt8(streamId)
end

---Sends the current settings to a client which is connecting to a multiplayer game
---@param streamId any @The ID of the stream to write to
---@param connection any @Unused
function CASettings:onWriteStream(streamId, connection)
    print(MOD_NAME .. ": Sending new settings")
    streamWriteBool(streamId, self.rollerCrimpingIsEnabled)
    streamWriteBool(streamId, self.rollerMulchBonusIsEnabled)
    streamWriteBool(streamId, self.seederMulchBonusIsEnabled)
    streamWriteBool(streamId, self.weedSuppressionIsEnabled)
    streamWriteBool(streamId, self.directSeederFieldCreationIsEnabled)
    streamWriteBool(streamId, self.grassDroppingIsEnabled)
    streamWriteInt8(streamId, self.fertilizationBehaviorPF)
    streamWriteInt8(streamId, self.fertilizationBehaviorBaseGame)
    -- v1.0.9.0+
    streamWriteBool(streamId, self.strawChoppingBonusIsEnabled)
    streamWriteBool(streamId, self.cultivatorBonusIsEnabled)
    -- v1.0.1.0+
    streamWriteInt8(streamId, self.strawChoppingNitrogenBonus)
    streamWriteInt8(streamId, self.cultivatorNitrogenBonus)
    streamWriteInt8(streamId, self.rollerCrimpingNitrogenBonus)
    streamWriteInt8(streamId, self.directSeedingNitrogenBonus)
end