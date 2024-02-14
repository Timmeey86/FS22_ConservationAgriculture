CASettings = {
    FERTILIZATION_BEHAVIOR_BASE_GAME_OFF = 1,
    FERTILIZATION_BEHAVIOR_BASE_GAME_FIRST = 2,
    FERTILIZATION_BEHAVIOR_BASE_GAME_FULL = 3,
    FERTILIZATION_BEHAVIOR_PF_OFF = 1,
    FERTILIZATION_BEHAVIOR_PF_MIN_AUTO = 2,
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
    self.fertilizationBehaviorBaseGame = CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_FIRST
    self.fertilizationBehaviorPF = CASettings.FERTILIZATION_BEHAVIOR_PF_MIN_AUTO
    -- v1.0.0.9+
    self.strawChoppingBonusIsEnabled = true
    self.cultivatorBonusIsEnabled = false

    -- Required to avoid mod conflicts
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
function CASettings:onEnableCultivatorBonusChanged(newState)
    self.cultivatorBonusIsEnabled = newState
    CASettings.publishNewSettings()
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
    self.strawChoppingBonusIsEnabled = streamReadBool(streamId)
    self.cultivatorBonusIsEnabled = streamReadBool(streamId)
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
    streamWriteBool(streamId, self.strawChoppingBonusIsEnabled)
    streamWriteBool(streamId, self.cultivatorBonusIsEnabled)
end