local function vector(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, {
        __sub = function(a, b) return vector(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
    })
end

local function harness()
    local h = {
        events = {}, sent = {}, timers = {}, clock = 10000,
        buckets = { [1] = 0, [2] = 0 },
        vehicleBuckets = { [100] = 0 },
        vehicles = { [1] = 0, [2] = 0 },
        health = { [1] = 100, [2] = 0 },
        online = { [1] = true, [2] = true },
        occupiedSeats = {}, targetSeat = 0,
    }
    local env = setmetatable({}, { __index = _G })
    h.env = env

    env.RegisterNetEvent = function(name, callback) h.events[name] = callback end
    env.AddEventHandler = function(name, callback) h.events[name] = callback end
    env.TriggerClientEvent = function(name, target, ...)
        h.sent[#h.sent + 1] = { name = name, target = target, args = { ... } }
    end
    env.SetTimeout = function(delay, callback)
        h.timers[#h.timers + 1] = { due = h.clock + delay, callback = callback }
    end
    env.GetGameTimer = function() return h.clock end
    env.GetPlayerPing = function(id) return h.online[id] and 50 or 0 end
    env.GetPlayerPed = function(id) return h.online[id] and id or 0 end
    env.GetEntityHealth = function(ped) return h.health[ped] end
    env.Player = function() return { state = {} } end
    env.GetEntityCoords = function() return vector(0, 0, 0) end
    env.GetPlayerRoutingBucket = function(id) return h.buckets[id] end
    env.GetEntityRoutingBucket = function(id) return h.vehicleBuckets[id] end
    env.GetVehiclePedIsIn = function(ped) return h.vehicles[ped] or 0 end
    env.GetPedInVehicleSeat = function(vehicle, seat)
        return h.occupiedSeats[seat] or (h.vehicles[2] == vehicle and h.targetSeat == seat and 2 or 0)
    end
    env.NetworkGetEntityFromNetworkId = function(id) return id == 100 and 100 or 0 end
    env.DoesEntityExist = function(id) return id == 100 end
    env.GetEntityType = function() return 2 end

    assert(loadfile('config.lua', 't', env))()
    env.Config.Me.enabled = false
    assert(loadfile('server.lua', 't', env))()

    function h:trigger(name, actor, ...)
        env.source = actor
        assert(self.events[name], name)(...)
        env.source = nil
    end

    function h:advance(milliseconds)
        self.clock = self.clock + milliseconds
        while true do
            local dueIndex
            for index, timer in ipairs(self.timers) do
                if timer.due <= self.clock then dueIndex = index break end
            end
            if not dueIndex then break end
            local timer = table.remove(self.timers, dueIndex)
            timer.callback()
        end
    end

    function h:find(name, target)
        for index = #self.sent, 1, -1 do
            local item = self.sent[index]
            if item.name == name and (not target or item.target == target) then return item end
        end
    end

    function h:start()
        self:trigger('carry_people:server:request', 1, 2)
        local item = assert(self:find('carry_people:client:startCarrier', 1))
        local sessionId = item.args[2]
        self:trigger('carry_people:server:startReady', 1, sessionId)
        self:trigger('carry_people:server:startReady', 2, sessionId)
        return sessionId
    end

    return h
end

do
    local h = harness()
    h:trigger('carry_people:server:removeDeadFromVehicle', 1, 2, 100)
    assert(not h:find('carry_people:client:removeFromVehicle'), 'outside target was removed')
    h.vehicles[2] = 100
    h.buckets[2] = 1
    h:trigger('carry_people:server:removeDeadFromVehicle', 1, 2, 100)
    assert(not h:find('carry_people:client:removeFromVehicle'), 'cross-bucket removal passed')
end

do
    local h = harness()
    h.vehicles[2] = 100
    h:trigger('carry_people:server:removeDeadFromVehicle', 1, 2, 100)
    local item = assert(h:find('carry_people:client:removeFromVehicle', 2))
    assert(not h:find('carry_people:client:removeFromVehicleDone'), 'premature removal success')
    h.vehicles[2] = 0
    h:trigger('carry_people:server:removeFromVehicleResult', 2, item.args[2], true)
    assert(h:find('carry_people:client:removeFromVehicleDone', 1), 'confirmed removal did not finish')
end

do
    local h = harness()
    h.buckets[2] = 1
    h:trigger('carry_people:server:request', 1, 2)
    assert(not h:find('carry_people:client:startCarrier'), 'cross-bucket carry passed')
    h.buckets[2] = 0
    h.vehicles[2] = 100
    h:trigger('carry_people:server:request', 1, 2)
    assert(not h:find('carry_people:client:startCarrier'), 'occupied target was carried')
end

do
    local h = harness()
    h:start()
    h.env.Config.Vehicle.enabled = false
    h:trigger('carry_people:server:putInVehicle', 1, 100, 0)
    assert(not h:find('carry_people:client:putInVehicle'), 'disabled vehicle action passed')
    h.vehicles[2] = 100
    h:trigger('carry_people:server:removeDeadFromVehicle', 1, 2, 100)
    assert(not h:find('carry_people:client:removeFromVehicle'), 'disabled removal passed')
    h.vehicles[2] = 0
    h.env.Config.Vehicle.enabled = true
    h:trigger('carry_people:server:putInVehicle', 1, 100, 2)
    local item = assert(h:find('carry_people:client:putInVehicle', 2))
    assert(item.args[3] == 2, 'selected seat was not forwarded')
end

do
    local h = harness()
    local sessionId = h:start()
    h:trigger('carry_people:server:putInVehicle', 1, 100, 0)
    assert(h:find('carry_people:client:putInVehicle', 2), 'placement was not requested')
    assert(not h:find('carry_people:client:putInVehicleDone'), 'premature placement success')
    h.vehicles[2] = 100
    h:trigger('carry_people:server:putInVehicleResult', 2, sessionId, true)
    assert(h:find('carry_people:client:putInVehicleDone', 1), 'confirmed placement did not finish')
    assert(h:find('carry_people:client:putInVehicleSuccess', 2), 'target was not notified')
end

do
    local h = harness()
    local sessionId = h:start()
    h:trigger('carry_people:server:putInVehicle', 1, 100, 0)
    h:trigger('carry_people:server:putInVehicleResult', 2, sessionId, false)
    assert(h:find('carry_people:client:startCarried', 2), 'failed placement did not restore carry')
    assert(h:find('carry_people:client:putInVehicleFailed', 1), 'carrier was not notified')
    h:trigger('carry_people:server:stop', 1)
    assert(h:find('carry_people:client:stop', 2), 'failed placement lost the pair')
end

do
    local h = harness()
    local sessionId = h:start()
    h:trigger('carry_people:server:putInVehicle', 1, 100, 0)
    h.sent = {}
    h:trigger('carry_people:server:putInVehicleResult', 2, sessionId, false, true)
    assert(h:find('carry_people:client:stop', 2), 'seat mismatch did not end the pair')
    assert(not h:find('carry_people:client:startCarried', 2), 'target in vehicle was reattached')
end

do
    local h = harness()
    local sessionId = h:start()
    h:trigger('carry_people:server:putInVehicle', 1, 100, 0)
    h:advance(h.env.Config.VehiclePlacementTimeout)
    assert(h:find('carry_people:client:stop', 2), 'placement timeout did not clear pair')
    h.sent = {}
    h.vehicles[2] = 100
    h:trigger('carry_people:server:putInVehicleResult', 2, sessionId, true)
    assert(not h:find('carry_people:client:putInVehicleDone'), 'late placement result was accepted')
end

do
    local h = harness()
    h:trigger('carry_people:server:request', 1, 2)
    h:advance(h.env.Config.CarryStartTimeout)
    assert(h:find('carry_people:client:stop', 1), 'start timeout did not clear pair')
    h.sent = {}
    h:trigger('carry_people:server:request', 1, 2)
    assert(h:find('carry_people:client:startCarrier', 1), 'player remained busy after timeout')
end

do
    local h = harness()
    h:start()
    h:trigger('carry_people:server:stop', 1)
    h.sent = {}
    h:trigger('carry_people:server:request', 1, 2)
    assert(not h:find('carry_people:client:startCarrier'), 'request cooldown was bypassed')
    h:advance(1500)
    h:trigger('carry_people:server:request', 1, 2)
    assert(h:find('carry_people:client:startCarrier', 1), 'request cooldown did not expire')
end

do
    local h = harness()
    h:start()
    for _, seat in ipairs({ -2, -1, 1.5, 16, '0', false }) do
        h:trigger('carry_people:server:putInVehicle', 1, 100, seat)
        assert(not h:find('carry_people:client:putInVehicle'), 'invalid server seat passed')
    end
    h:trigger('carry_people:server:putInVehicle', 1, 100)
    assert(not h:find('carry_people:client:putInVehicle'), 'missing server seat passed')
    h.env.Config.Vehicle.allowDriverSeat = true
    h:trigger('carry_people:server:putInVehicle', 1, 100, -1)
    assert(h:find('carry_people:client:putInVehicle').args[3] == -1, 'enabled driver request was not forwarded')
end

do
    local h = harness()
    h:start()
    h.occupiedSeats[0] = 99
    h:trigger('carry_people:server:putInVehicle', 1, 100, 0)
    assert(not h:find('carry_people:client:putInVehicle'), 'server forwarded occupied seat')
    assert(h:find('carry_people:client:putInVehicleFailed', 1), 'occupied seat had no failure feedback')
    h:advance(500)
    h:trigger('carry_people:server:putInVehicle', 1, 100, 2)
    assert(h:find('carry_people:client:putInVehicle').args[3] == 2, 'occupied seat failure did not preserve carry')
end

do
    local h = harness()
    h.env.Config.VehiclePlacementTimeout = 1750
    local sessionId = h:start()
    h:trigger('carry_people:server:putInVehicle', 1, 100, 2)
    h.vehicles[2] = 100
    h.targetSeat = 0
    h:trigger('carry_people:server:putInVehicleResult', 2, sessionId, true)
    for _ = 1, 5 do h:advance(250) end
    assert(not h:find('carry_people:client:putInVehicleDone'), 'server confirmed the wrong seat')
    assert(not h:find('carry_people:client:putInVehicleFailed', 1), 'seat verification ended before the placement timeout')
    for _ = 1, 2 do h:advance(250) end
    assert(h:find('carry_people:client:putInVehicleFailed', 1), 'seat mismatch had no feedback')
    assert(h:find('carry_people:client:stop', 2), 'seat mismatch did not clear the pair at timeout')
end

do
    local h = harness()
    local sessionId = h:start()
    h:trigger('carry_people:server:putInVehicle', 1, 100, 2)
    h.vehicles[2] = 100
    h.targetSeat = 0
    h:trigger('carry_people:server:putInVehicleResult', 2, sessionId, true)
    assert(not h:find('carry_people:client:putInVehicleDone'), 'server skipped seat replication check')
    h.targetSeat = 2
    h:advance(250)
    assert(h:find('carry_people:client:putInVehicleDone', 1), 'delayed selected seat replication was not confirmed')
end

do
    local h = harness()
    local sessionId = h:start()
    h:trigger('carry_people:server:putInVehicle', 1, 100, 2)
    h.vehicles[2] = 100
    h.targetSeat = 0
    h:trigger('carry_people:server:putInVehicleResult', 2, sessionId, true)
    for _ = 1, 5 do h:advance(250) end
    assert(not h:find('carry_people:client:putInVehicleFailed', 1), 'verification failed after only one second')
    h.targetSeat = 2
    h:advance(250)
    assert(h:find('carry_people:client:putInVehicleDone', 1), 'seat replication after one second was rejected')
    h:advance(h.env.Config.VehiclePlacementTimeout)
    assert(not h:find('carry_people:client:putInVehicleFailed', 1), 'placement timeout fired after success')
end

print('server_spec: 15 scenarios passed')
