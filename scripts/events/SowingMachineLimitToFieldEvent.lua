
---@class SowingMachineLimitToFieldEvent
---This event is sent between client and server when a player changes the "limit to field" option on direct seeders/planters in multiplayer.
---It is a mixture of the PlowLimitToFieldEvent's LUADOC and things seen in other mods (+ documentation).
SowingMachineLimitToFieldEvent = {}
local SowingMachineLimitToFieldEvent_mt = Class(SowingMachineLimitToFieldEvent, Event)

InitEventClass(SowingMachineLimitToFieldEvent, "SowingMachineLimitToFieldEvent")

---Creates an empty event.
---@return table @The new event.
function SowingMachineLimitToFieldEvent.emptyNew()
	return Event.new(SowingMachineLimitToFieldEvent_mt)
end

---Creates a new event for the given seeder or planter.
---@param sowingMachine table @The direct seeder or planter related to the event.
---@param limitToField boolean @True if the seeder or planter shall only operate within field bounds.
---@return table @The new instance
function SowingMachineLimitToFieldEvent.new(sowingMachine, limitToField)
	local self = SowingMachineLimitToFieldEvent.emptyNew()
	self.sowingMachine = sowingMachine
	self.limitToField = limitToField
	return self
end

---Reads event data which was sent by either the client which changed values or the server which distributes them
---@param streamId any @The ID of the stream to read from.
---@param connection any @The connection to use.
function SowingMachineLimitToFieldEvent:readStream(streamId, connection)
	self.sowingMachine = NetworkUtil.readNodeObject(streamId)
	self.limitToField = streamReadBool(streamId)
	self:run(connection)
end

---Sends event data from the client to the server, or from the server to other clients
---@param streamId any @The ID of the stream to write to.
---@param connection any @The connection to use.
function SowingMachineLimitToFieldEvent:writeStream(streamId, connection)
	NetworkUtil.writeNodeObject(streamId, self.sowingMachine)
	streamWriteBool(streamId, self.limitToField)
end

---Runs the event on the receiving side (in this case the server)
---@param connection any @The connection to be used
function SowingMachineLimitToFieldEvent:run(connection)
	if self.sowingMachine ~= nil and self.sowingMachine:getIsSynchronized() then
		self.sowingMachine:setLimitSeederToField(self.limitToField, true)
	end

	local eventWasSentByServer = connection:getIsServer()
	if not eventWasSentByServer then
		-- We are the server. Broadcast the event to other players
		g_server:broadcastEvent(SowingMachineLimitToFieldEvent.new(self.sowingMachine, self.limitToField), nil, connection, self.sowingMachine)
	end
end
