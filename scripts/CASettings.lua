CASettings = {}
local CASettings_mt = Class(CASettings)

--- Creates a new instance of this class
---@return table @A new class instance
function CASettings.new()
    local self = setmetatable({}, CASettings_mt)
    -- Default settings. Will be overridden by settings stored in XML if available
    self.rollerCrimpingIsEnabled = true
    return self
end

--- Updates the "enable roller crimping" setting when the user changes it
---@param   newState    boolean @the new state
function CASettings:onEnableRollerCrimpingChanged(newState)
    self.rollerCrimpingIsEnabled = (newState == CheckedOptionElement.STATE_CHECKED)
end