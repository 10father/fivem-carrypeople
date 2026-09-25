local function vector(x, y, z)
    return setmetatable({ x = x, y = y, z = z }, {
        __sub = function(a, b) return vector(a.x - b.x, a.y - b.y, a.z - b.z) end,
        __len = function(a) return math.sqrt(a.x * a.x + a.y * a.y + a.z * a.z) end,
    })
end

local function harness(overrides)
    local h = {
        events = {}, sent = {}, threads = {}, keyMappings = 0,
        attached = false, vehicle = 0, seat = nil,
        carrierExists = true, dead = false, seatFree = true,
        commands = {}, occupiedSeats = {}, maxPassengers = 3, distance = 0,
        notifications = {}, clock = 10000, vehicleExists = true,
    }
    local env = setmetatable({}, { __index = _G })
    h.env = env

    env.RegisterNetEvent = function(name, callback) h.events[name] = callback end
    env.AddEventHandler = function(name, callback) h.events[name] = callback end
    env.RegisterCommand = function(name, callback) h.commands[name] = callback end
    env.RegisterKeyMapping = function() h.keyMappings = h.keyMappings + 1 end
    env.CreateThread = function(callback) h.threads[#h.threads + 1] = callback end
    env.TriggerServerEvent = function(name, ...)
        h.sent[#h.sent + 1] = { name = name, args = { ... } }
    end
    env.GetGameTimer = function() return h.clock end
    env.Wait = function(ms) h.clock = h.clock + ms end
    env.PlayerPedId = function() return 2 end
    env.PlayerId = function() return 2 end
    env.GetPlayerFromServerId = function() return h.carrierExists and 1 or -1 end
    env.GetPlayerPed = function(id) return id end
    env.DoesEntityExist = function(id) return id == 1 or id == 2 or (id == 100 and h.vehicleExists) end
    env.GetEntityCoords = function(id) return vector(id == 100 and h.distance or 0, 0, 0) end
    env.GetGamePool = function() return { 100 } end
    env.NetworkGetEntityIsNetworked = function() return true end
    env.VehToNet = function(id) return id end
    env.SetNetworkIdCanMigrate = function() end
    env.IsPedInAnyVehicle = function() return h.vehicle ~= 0 end
    env.lib = {
        registerContext = function(menu) h.menu = menu end,
        showContext = function(id) h.openMenu = id end,
        getOpenContextMenu = function() return h.openMenu end,
        hideContext = function() h.openMenu = nil end,
    }
    env.HasAnimDictLoaded = function() return true end
    env.TaskPlayAnim = function() end
    env.AttachEntityToEntity = function() h.attached = true end
    env.DetachEntity = function() h.attached = false end
    env.StopAnimTask = function() end
    env.ClearPedSecondaryTask = function() end
    env.ClearPedTasks = function() end
    env.ClearPedTasksImmediately = function() end
    env.BeginTextCommandThefeedPost = function() end
    env.AddTextComponentSubstringPlayerName = function(text) h.notifications[#h.notifications + 1] = text end
    env.EndTextCommandThefeedPostTicker = function() end
    env.NetToVeh = function(id) return id == 100 and 100 or 0 end
    env.GetVehicleMaxNumberOfPassengers = function() return h.maxPassengers end
    env.IsVehicleSeatFree = function(_, seat, checkEntering)
        assert(checkEntering == true, 'entering passengers must also reserve their seats')
        return h.seatFree and not h.occupiedSeats[seat]
    end
    env.GetVehiclePedIsIn = function() return h.vehicle end
    env.SetPedIntoVehicle = function(_, vehicle, seat)
        h.vehicle = vehicle
        h.seat = seat
    end
    env.GetPedInVehicleSeat = function(_, seat) return h.seat == seat and 2 or 0 end
    env.IsEntityDead = function() return h.dead end
    env.IsPedDeadOrDying = function() return h.dead end
    env.IsPedFatallyInjured = function() return h.dead end
    env.GetEntityHealth = function() return h.dead and 0 or 100 end
    env.GetPlayerServerId = function() return 2 end
    env.Player = function() return { state = {} } end
    env.GetOffsetFromEntityInWorldCoords = function() return { x = 1, y = 2, z = 3 } end
    env.GetGroundZFor_3dCoord = function() return true, 3 end
    env.vector3 = function(x, y, z) return { x = x, y = y, z = z } end
    env.SetEntityCoordsNoOffset = function() h.moved = true; h.vehicle = 0 end
    env.SetEntityHeading = function() end
    env.GetEntityHeading = function() return 0 end
    env.SetPedCanRagdoll = function() end
    env.SetPedToRagdoll = function() end

    assert(loadfile('config.lua', 't', env))()
    for key, value in pairs(overrides or {}) do env.Config[key] = value end
    assert(loadfile('client.lua', 't', env))()

    function h:call(name, ...)
        assert(self.events[name], name)(...)
    end

    function h:find(name)
        for index = #self.sent, 1, -1 do
            if self.sent[index].name == name then return self.sent[index] end
        end
    end

    return h
end

do
    local h = harness()
    h.carrierExists = false
    h:call('carry_people:client:startCarried', 1, 10)
    assert(h:find('carry_people:server:startFailed'), 'missing carrier did not abort start')
    h.carrierExists = true
    h.sent = {}
    h:call('carry_people:client:startCarried', 1, 10)
    assert(not h.attached and not h:find('carry_people:server:startReady'), 'stale start was accepted')
end

do
    local h = harness()
    h:call('carry_people:client:startCarried', 1, 10)
    assert(h.attached and h:find('carry_people:server:startReady'), 'carry did not start')
    h.sent = {}
    h.seatFree = false
    h:call('carry_people:client:putInVehicle', 10, 100, 0)
    local result = assert(h:find('carry_people:server:putInVehicleResult'))
    assert(result.args[2] == false and h.attached, 'full vehicle changed carry state')
end

do
    local h = harness()
    h:call('carry_people:client:startCarried', 1, 10)
    h.sent = {}
    h:call('carry_people:client:putInVehicle', 10, 100, 0)
    local result = assert(h:find('carry_people:server:putInVehicleResult'))
    assert(result.args[2] == true and h.vehicle == 100 and not h.attached, 'valid placement failed')
    assert(h.seat == 0, 'selected front passenger seat was replaced with the first free rear seat')
    h:call('carry_people:client:putInVehicleSuccess', 10)
    h:call('carry_people:client:stop', 10, false)
    assert(h.vehicle == 100, 'stale stop disturbed completed placement')
end

do
    local h = harness()
    h.dead = true
    h:call('carry_people:client:removeFromVehicle', 100, 5)
    local result = assert(h:find('carry_people:server:removeFromVehicleResult'))
    assert(result.args[2] == false and not h.moved, 'target outside vehicle was moved')
    h.sent = {}
    h.vehicle = 100
    h:call('carry_people:client:removeFromVehicle', 100, 6)
    result = assert(h:find('carry_people:server:removeFromVehicleResult'))
    assert(result.args[2] == true and h.moved, 'valid removal failed')
end

do
    local disabled = harness({ EnableStopKey = false, StopControl = 73 })
    assert(disabled.keyMappings == 0 and #disabled.threads == 2, 'disabled stop key still registered control')
    local enabled = harness({ EnableStopKey = true, StopControl = 73 })
    assert(enabled.keyMappings == 1 and #enabled.threads == 3, 'explicit raw control was not registered')
end

do
    local h = harness()
    h:call('carry_people:client:startCarrier', 1, 10)
    h.occupiedSeats[1] = true
    h.commands.putincar()
    assert(h.openMenu and #h.menu.options == 3, 'four-seat vehicle menu is missing')
    assert(h.menu.options[1].title == '后排左座' and h.menu.options[1].disabled, 'occupied rear seat is selectable')
    assert(h.menu.options[2].title == '后排右座' and not h.menu.options[2].disabled, 'right rear seat is missing')
    assert(h.menu.options[3].title == '副驾驶', 'front passenger seat is missing')
    assert(not h:find('carry_people:server:putInVehicle'), 'opening menu placed player before selection')
    h.menu.options[3].onSelect()
    local request = assert(h:find('carry_people:server:putInVehicle'))
    assert(request.args[1] == 100 and request.args[2] == 0, 'selected seat was not sent')
end

do
    for index, seat in ipairs({ 1, 2, 0, -1 }) do
        local h = harness()
        h.env.Config.Vehicle.allowDriverSeat = true
        h:call('carry_people:client:startCarrier', 1, 10)
        h.commands.putincar()
        assert(#h.menu.options == 4 and h.menu.options[4].title == '驾驶位', 'enabled driver seat is missing')
        h.menu.options[index].onSelect()
        assert(h:find('carry_people:server:putInVehicle').args[2] == seat, 'menu callback selected a different seat')
    end
end

do
    local h = harness()
    h:call('carry_people:client:startCarrier', 1, 10)
    h.commands.putincar()
    h.env.lib.hideContext(true)
    assert(not h:find('carry_people:server:putInVehicle') and not h:find('carry_people:server:stop'), 'cancel changed carry state')
    h.commands.putincar()
    local oldOption = h.menu.options[3]
    h:call('carry_people:client:stop', 10, false)
    assert(not h.openMenu, 'stopping carry left seat menu open')
    h:call('carry_people:client:startCarrier', 1, 11)
    oldOption.onSelect()
    assert(not h:find('carry_people:server:putInVehicle'), 'old menu acted on a new carry session')
end

do
    local h = harness()
    h:call('carry_people:client:startCarrier', 1, 10)
    h.commands.putincar()
    h.occupiedSeats[0] = true
    h.menu.options[3].onSelect()
    assert(not h:find('carry_people:server:putInVehicle'), 'seat occupied after menu open was accepted')
    assert(h.notifications[#h.notifications] == h.env.Config.Text.vehicleSeatUnavailable, 'missing occupied-seat feedback')
    h.commands.putincar()
    assert(h.menu.options[3].disabled, 'reopened menu did not refresh seat availability')
end

do
    for _, invalidation in ipairs({ 'distance', 'deleted', 'carrierEntered' }) do
        local h = harness()
        h:call('carry_people:client:startCarrier', 1, 10)
        h.commands.putincar()
        if invalidation == 'distance' then h.distance = 10 end
        if invalidation == 'deleted' then h.vehicleExists = false end
        if invalidation == 'carrierEntered' then h.vehicle = 100 end
        h.menu.options[3].onSelect()
        assert(not h:find('carry_people:server:putInVehicle'), 'stale vehicle menu request passed: ' .. invalidation)
    end
end

do
    local h = harness()
    h:call('carry_people:client:startCarried', 1, 10)
    h.occupiedSeats[0] = true
    h:call('carry_people:client:putInVehicle', 10, 100, 0)
    assert(h:find('carry_people:server:putInVehicleResult').args[2] == false, 'target accepted occupied seat')
    assert(h.attached and h.vehicle == 0, 'target switched to a different free seat')
end

do
    for _, seat in ipairs({ -2, -1, 1.5, 3, 16, '0', false }) do
        local h = harness()
        h:call('carry_people:client:startCarried', 1, 10)
        h:call('carry_people:client:putInVehicle', 10, 100, seat)
        assert(h:find('carry_people:server:putInVehicleResult').args[2] == false and h.attached, 'invalid target seat passed')
    end
    local h = harness()
    h:call('carry_people:client:startCarried', 1, 10)
    h:call('carry_people:client:putInVehicle', 10, 100)
    assert(h:find('carry_people:server:putInVehicleResult').args[2] == false and h.attached, 'missing seat auto-selected a seat')
end

do
    local h = harness()
    h.env.Config.Vehicle.allowDriverSeat = true
    h:call('carry_people:client:startCarried', 1, 10)
    h:call('carry_people:client:putInVehicle', 10, 100, -1)
    assert(h:find('carry_people:server:putInVehicleResult').args[2] == true and h.seat == -1, 'enabled driver placement failed')
end

do
    local h = harness()
    h:call('carry_people:client:startCarrier', 1, 10)
    h.maxPassengers = 1
    h.commands.putincar()
    assert(#h.menu.options == 1 and h.menu.options[1].title == '副驾驶', 'two-seat car menu included nonexistent seats')
    h.maxPassengers = 5
    h.commands.putincar()
    assert(#h.menu.options == 5 and h.menu.options[5].title == '乘客座位 5', 'extra passenger seats are missing')
    h.env.lib.hideContext(false)
    h.seatFree = false
    h.commands.putincar()
    assert(not h.openMenu and h.notifications[#h.notifications] == h.env.Config.Text.vehicleFull, 'full car should show a message')
end

print('client_spec: 14 scenarios passed')
