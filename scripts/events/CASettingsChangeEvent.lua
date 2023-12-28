
---@class CASettingsChangeEvent
---This event is sent between client and server when a player changes any Conservation Agriculture setting in multiplayer
---It is also sent once when a client joins the server
CASettingsChangeEvent = {}
local CASettingsChangeEvent_mt = Class(CASettingsChangeEvent, Event)

InitEventClass(CASettingsChangeEvent, "CASettingsChangeEvent")

---Creates a new empty event
---@return table @The new instance
function CASettingsChangeEvent.emptyNew()
	return Event.new(CASettingsChangeEvent_mt)
end

---Creates a new event
---@return table @The new instance
function CASettingsChangeEvent.new()
	return CASettingsChangeEvent.emptyNew()
end

---Reads settings which were sent by another network participant and then applies them locally
---@param streamId any @The ID of the stream to read from.
---@param connection any @The connection to use.
function CASettingsChangeEvent:readStream(streamId, connection)
	if g_currentMission and g_currentMission.conservationAgricultureSettings then
		g_currentMission.conservationAgricultureSettings:onReadStream(streamId, connection)

		local eventWasSentByServer = connection:getIsServer()
		if not eventWasSentByServer then
			-- We are the server. Broadcast the event to other players
			g_server:broadcastEvent(CASettingsChangeEvent.new(), nil, connection, nil)
		end
	end
end

---Sends event data to another network participant
---@param streamId any @The ID of the stream to write to.
---@param connection any @The connection to use.
function CASettingsChangeEvent:writeStream(streamId, connection)
	if g_currentMission and g_currentMission.conservationAgricultureSettings then
		g_currentMission.conservationAgricultureSettings:onWriteStream(streamId, connection)
	end
end