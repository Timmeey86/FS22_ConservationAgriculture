CASettings = {
    FERTILIZATION_BEHAVIOR_BASE_GAME_OFF = 1,
    FERTILIZATION_BEHAVIOR_BASE_GAME_FIRST = 2,
    FERTILIZATION_BEHAVIOR_BASE_GAME_FULL = 3,
    FERTILIZATION_BEHAVIOR_PF_OFF = 1,
    FERTILIZATION_BEHAVIOR_PF_MIN_AUTO = 2,
}
local CASettings_mt = Class(CASettings)

--- Creates a new instance of this class
---@return table @A new class instance
function CASettings.new()
    local self = setmetatable({}, CASettings_mt)
    -- Default settings. Will be overridden by settings stored in XML if available
    self.rollerCrimpingIsEnabled = true
    self.rollerMulchBonusIsEnabled = true
    self.seederMulchBonusIsEnabled = false
    self.weedSuppressionIsEnabled = true
    self.directSeederFieldCreationIsEnabled = true
    self.fertilizationBehaviorBaseGame = CASettings.FERTILIZATION_BEHAVIOR_BASE_GAME_FIRST
    self.fertilizationBehaviorPF = CASettings.FERTILIZATION_BEHAVIOR_PF_MIN_AUTO
    return self
end

--- Converts STATE_CHECKED and STATE_UNCHECKED values to bool
---@param checkState    integer     @the check state
---@return boolean @true if checkState is STATE_CHECKED
function CASettings.checkStateToBool(checkState)
    return checkState == CheckedOptionElement.STATE_CHECKED
end

-- These functions react to changes by the user in the settings dialog

function CASettings:onEnableRollerCrimpingChanged(newState)
    self.rollerCrimpingIsEnabled = CASettings.checkStateToBool(newState)
end
function CASettings:onEnableRollerMulchBonusChanged(newState)
    self.rollerMulchBonusIsEnabled = CASettings.checkStateToBool(newState)
end
function CASettings:onEnableSeederMulchBonus(newState)
    self.seederMulchBonusIsEnabled = CASettings.checkStateToBool(newState)
end
function CASettings:onEnableWeedSuppression(newState)
    self.weedSuppressionIsEnabled = CASettings.checkStateToBool(newState)
end
function CASettings:onEnableDirectSeederFieldCreation(newState)
    self.directSeederFieldCreationIsEnabled = CASettings.checkStateToBool(newState)
end
function CASettings:onFertilizationBehaviorPFChanged(newState)
    self.fertilizationBehaviorPF = newState
end
function CASettings:onFertilizationBehaviorBaseGameChanged(newState)
    self.fertilizationBehaviorBaseGame = newState
end
