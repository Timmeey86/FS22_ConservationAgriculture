---@class RollerCrimpingData
---This class provides information about the growth states which allow roller crimping
RollerCrimpingData = {}
local RollerCrimpingData_mt = Class(RollerCrimpingData)

---Creates a new instance of this class
---@return table @A new class instance
function RollerCrimpingData.new()
    local self = setmetatable({}, RollerCrimpingData_mt)
    return self
end

---Initializes forage data based on the provided table of fruit types
---@param fruitTypes table  @Provides information about growth states of fruit types
function RollerCrimpingData:init(fruitTypes)
    self.forageableStatesPerFruit = {}
    for index, fruitDescription in pairs(fruitTypes) do
        -- For grains and anything else not specially handled: allow from "half grown" (rounded down) to the last state before "ready to harvest"
        local growthStatesWithoutSownState = fruitDescription.numGrowthStates - 1
        local midGrowthState = math.floor(growthStatesWithoutSownState / 2)
        local minForageState = midGrowthState + 1 -- state 1 = sown state, so the first growth state is 2
        local maxForageState = fruitDescription.minHarvestingGrowthState - 1

        -- root crops: Mulch only before haulm topping
        if fruitDescription.maxPreparingGrowthState > 0 then
            maxForageState = fruitDescription.maxPreparingGrowthState
        -- Oilseed radish, grass, meadow, alfalfa, clover, ...: Allow all "ready to harvest" states
        elseif fruitDescription.minForageGrowthState == fruitDescription.minHarvestingGrowthState then
            minForageState = fruitDescription.minHarvestingGrowthState
            maxForageState = fruitDescription.maxHarvestingGrowthState
        end

        -- Store the information for fast lookup later
        self.forageableStatesPerFruit[index] = { min = minForageState, max = maxForageState }
    end
end

---Provides fast lookup of the growth states which allow roller crimping
---@param fruitTypeIndex integer @The index of the fruit type in the global list of fruit types
---@return table @A pair of minimum and maximum growth states indexed by "min" and "max"
function RollerCrimpingData:getForageableStates(fruitTypeIndex)
    return self.forageableStatesPerFruit[fruitTypeIndex] or { min = 0, max = 0 }
end