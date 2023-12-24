
---@class SowingMachineLimitToFieldEvent
---This event is sent between client and server when a player changes the "limit to field" option on direct seeders/planters in multiplayer.
---It is a mixture of the PlowLimitToFieldEvent's LUADOC and things seen in other mods (+ documentation).
SowingMachineLimitToFieldEvent = {}
local SowingMachineLimitToFieldEvent_mt = Class(SowingMachineLimitToFieldEvent, Event)

InitEventClass(SowingMachineLimitToFieldEvent, "SowingMachineLimitToFieldEvent")

--- Creates an empty event.
---@return table @The new event.
function SowingMachineLimitToFieldEvent.emptyNew()
	return Event.new(SowingMachineLimitToFieldEvent_mt)
end

--- Creates a new event for the given seeder or planter.
---@param sowingMachine table @The direct seeder or planter related to the event.
---@param limitToField boolean @True if the seeder or planter shall only operate within field bounds.
---@return table
function SowingMachineLimitToFieldEvent.new(sowingMachine, limitToField)
	local self = SowingMachineLimitToFieldEvent.emptyNew()
	self.sowingMachine = sowingMachine
	self.limitToField = limitToField
	return self
end

--- Reads information from the event sent by another game instance in the network.
---@param streamId any @The ID of the stream to read from.
---@param connection any @The connection to use.
function SowingMachineLimitToFieldEvent:readStream(streamId, connection)
	self.object = NetworkUtil.readNodeObject(streamId)
	self.limitToField = streamReadBool(streamId)
	self:run(connection)
end

--- Writes this event instance onto the network.
---@param streamId any @The ID of the stream to write to.
---@param connection any @The connection to use.
function SowingMachineLimitToFieldEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.object)
	streamWriteBool(streamId, self.limitToField)
end

--- Runs the event on the receiving side
---@param connection any @The connection to be used
function SowingMachineLimitToFieldEvent:run(connection)
	if self.object ~= nil and self.object:getIsSynchronized() then
		self.object:setSowingMachineLimitToField(self.limitToField, true)
	end

	if not connection:getIsServer() then
		-- Not sure why the client would broadcast something again, but most events have this line right here
		g_server:broadcastEvent(SowingMachineLimitToFieldEvent.new(self.object, self.limitToField), nil, connection, self.object)
	end
end
