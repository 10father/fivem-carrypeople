local activeCarries = {}
local carryRoles = {}
local carrySessions = {}
local carryReady = {}
local carryAnnounced = {}
local pendingVehicles = {}
local pendingRemovals = {}
local removalBySource = {}
local lastActionAt = {}
local nextSessionId = 0
local nextRemovalId = 0

local function isIntegerInRange(value, minimum, maximum)
    return type(value) == "number" and value == math.floor(value)
        and value >= minimum and value <= maximum
end

local function cooldownAllows(playerId, action, interval)
    local now = GetGameTimer()
    local actions = lastActionAt[playerId]
    if not actions then
        actions = {}
        lastActionAt[playerId] = actions
    end

    local previous = actions[action]
    if previous and now - previous < interval then return false end
    actions[action] = now
    return true
end

local function sameBucket(first, second)
    return GetPlayerRoutingBucket(first) == GetPlayerRoutingBucket(second)
end

local function vehicleInBucket(vehicle, playerId)
    return GetEntityRoutingBucket(vehicle) == GetPlayerRoutingBucket(playerId)
end

local function clearRemoval(pending)
    if not pending then return end
    if pendingRemovals[pending.targetId] == pending then pendingRemovals[pending.targetId] = nil end
    if removalBySource[pending.sourceId] == pending then removalBySource[pending.sourceId] = nil end
end

local function isPlayerOnline(source)
    return source and source > 0 and GetPlayerPing(source) > 0
end

local function getMeText(key, fallbackKey)
    local me = Config.Me or {}
    return me[key] or (fallbackKey and me[fallbackKey]) or nil
end

local function isPlayerDeadLike(playerId)
    if not isPlayerOnline(playerId) then return false end

    local ped = GetPlayerPed(playerId)
    if not ped or ped <= 0 then return false end

    if GetEntityHealth(ped) <= 0 then
        return true
    end

    local state = Player(playerId).state

    return state.isDead == true
        or state.dead == true
        or state.inlaststand == true
        or state.inLaststand == true
        or state.laststand == true
        or state.isIncapacitated == true
end

local function sendMe(sourceId, text)
    local me = Config.Me or {}
    if me.enabled == false or not text or text == "" then return end

    if me.useCommand ~= false then
        TriggerClientEvent("carry_people:client:runMe", sourceId, text)
        return
    end

    local sourcePed = GetPlayerPed(sourceId)
    if not sourcePed or sourcePed <= 0 then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local maxDistance = me.distance or 20.0
    local playerName = GetPlayerName(sourceId) or ("ID " .. sourceId)
    for _, player in ipairs(GetPlayers()) do
        local playerId = tonumber(player)
        local playerPed = playerId and GetPlayerPed(playerId) or 0

        if playerPed and playerPed > 0 then
            local playerCoords = GetEntityCoords(playerPed)
            if #(sourceCoords - playerCoords) <= maxDistance then
                TriggerClientEvent("carry_people:client:showMe", playerId, sourceId, playerName, text)
            end
        end
    end
end

local function clearPair(playerId)
    local paired = activeCarries[playerId]
    local sessionId = carrySessions[playerId]
    if paired then
        activeCarries[paired] = nil
        carryRoles[paired] = nil
        carrySessions[paired] = nil
        carryReady[paired] = nil
        pendingVehicles[paired] = nil
    end

    activeCarries[playerId] = nil
    carryRoles[playerId] = nil
    carrySessions[playerId] = nil
    carryReady[playerId] = nil
    pendingVehicles[playerId] = nil
    if sessionId then carryAnnounced[sessionId] = nil end

    return paired, sessionId
end

local function stopCarry(playerId, showNotify)
    if not carrySessions[playerId] then return end
    local role = carryRoles[playerId]
    local wasStarted = carryAnnounced[carrySessions[playerId]] == true
    local paired, sessionId = clearPair(playerId)

    if isPlayerOnline(playerId) then
        TriggerClientEvent("carry_people:client:stop", playerId, sessionId, showNotify == true)
    end

    if paired and isPlayerOnline(paired) then
        TriggerClientEvent("carry_people:client:stop", paired, sessionId, showNotify == true)
    end

    if showNotify == true and role and wasStarted then
        if role == "carried" then
            sendMe(playerId, getMeText("dropCarried", "drop"))
        else
            sendMe(playerId, getMeText("drop"))
        end
    end
end

RegisterNetEvent("carry_people:server:request", function(targetId)
    local sourceId = source
    targetId = tonumber(targetId)

    if not isIntegerInRange(targetId, 1, 65535) then return end
    if not isPlayerOnline(sourceId) or not isPlayerOnline(targetId) then return end
    if sourceId == targetId then return end
    if not sameBucket(sourceId, targetId) then return end

    if activeCarries[sourceId] or activeCarries[targetId] then
        TriggerClientEvent("carry_people:client:targetBusy", sourceId)
        return
    end

    local sourcePed = GetPlayerPed(sourceId)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed <= 0 or targetPed <= 0 then return end
    if isPlayerDeadLike(sourceId) then return end
    if GetVehiclePedIsIn(sourcePed, false) ~= 0 or GetVehiclePedIsIn(targetPed, false) ~= 0 then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(sourceCoords - targetCoords) > (Config.MaxDistance + 1.0) then return end
    if not cooldownAllows(sourceId, "request", 1500) then return end

    nextSessionId = nextSessionId + 1
    local sessionId = nextSessionId

    activeCarries[sourceId] = targetId
    activeCarries[targetId] = sourceId
    carryRoles[sourceId] = "carrier"
    carryRoles[targetId] = "carried"
    carrySessions[sourceId] = sessionId
    carrySessions[targetId] = sessionId

    TriggerClientEvent("carry_people:client:startCarrier", sourceId, targetId, sessionId)
    TriggerClientEvent("carry_people:client:startCarried", targetId, sourceId, sessionId)

    SetTimeout(Config.CarryStartTimeout or 6000, function()
        if carrySessions[sourceId] == sessionId and not carryAnnounced[sessionId] then
            stopCarry(sourceId, false)
        end
    end)
end)

RegisterNetEvent("carry_people:server:startReady", function(sessionId)
    local playerId = source
    if carrySessions[playerId] ~= sessionId then return end
    carryReady[playerId] = true

    local paired = activeCarries[playerId]
    if not paired or not carryReady[paired] or carryAnnounced[sessionId] then return end

    carryAnnounced[sessionId] = true
    local carrierId = carryRoles[playerId] == "carrier" and playerId or paired
    sendMe(carrierId, getMeText("carry"))
end)

RegisterNetEvent("carry_people:server:startFailed", function(sessionId)
    if carrySessions[source] == sessionId then
        stopCarry(source, false)
    end
end)

RegisterNetEvent("carry_people:server:stop", function()
    stopCarry(source, true)
end)

RegisterNetEvent("carry_people:server:putInVehicle", function(vehicleNetId, seatNumber)
    local sourceId = source
    vehicleNetId = tonumber(vehicleNetId)

    if not Config.Vehicle or Config.Vehicle.enabled == false then return end
    if not isIntegerInRange(vehicleNetId, 1, 65535) then return end
    if not isIntegerInRange(seatNumber, -1, 15) then return end
    if seatNumber == -1 and Config.Vehicle.allowDriverSeat ~= true then return end
    if carryRoles[sourceId] ~= "carrier" then return end
    if pendingVehicles[sourceId] then return end

    local targetId = activeCarries[sourceId]
    if not isPlayerOnline(sourceId) or not isPlayerOnline(targetId) then
        stopCarry(sourceId, false)
        return
    end
    if not sameBucket(sourceId, targetId) then
        stopCarry(sourceId, false)
        return
    end

    local sessionId = carrySessions[sourceId]
    if not carryAnnounced[sessionId] then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if GetEntityType(vehicle) ~= 2 then return end
    if not vehicleInBucket(vehicle, sourceId) then return end

    local sourcePed = GetPlayerPed(sourceId)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed <= 0 or targetPed <= 0 then return end
    if GetVehiclePedIsIn(sourcePed, false) ~= 0 or GetVehiclePedIsIn(targetPed, false) ~= 0 then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleDistance = ((Config.Vehicle and Config.Vehicle.distance) or Config.MaxDistance) + 2.0

    if #(sourceCoords - targetCoords) > (Config.MaxDistance + 2.0) then return end
    if #(sourceCoords - vehicleCoords) > vehicleDistance then return end
    if not cooldownAllows(sourceId, "vehicle", 500) then return end

    if GetPedInVehicleSeat(vehicle, seatNumber) ~= 0 then
        TriggerClientEvent("carry_people:client:putInVehicleFailed", sourceId, sessionId)
        return
    end

    local placementTimeout = Config.VehiclePlacementTimeout or 6000
    local pending = {
        sessionId = sessionId,
        targetId = targetId,
        vehicleNetId = vehicleNetId,
        seat = seatNumber,
        expiresAt = GetGameTimer() + placementTimeout,
    }
    pendingVehicles[sourceId] = pending
    TriggerClientEvent("carry_people:client:putInVehicle", targetId, sessionId, vehicleNetId, seatNumber)

    SetTimeout(placementTimeout, function()
        if pendingVehicles[sourceId] == pending and not pending.verifying then
            if isPlayerOnline(sourceId) then
                TriggerClientEvent("carry_people:client:putInVehicleFailed", sourceId, sessionId)
            end
            stopCarry(sourceId, false)
        end
    end)
end)

RegisterNetEvent("carry_people:server:putInVehicleResult", function(sessionId, success, enteredVehicle)
    local targetId = source
    if carryRoles[targetId] ~= "carried" or carrySessions[targetId] ~= sessionId then return end

    local carrierId = activeCarries[targetId]
    local pending = carrierId and pendingVehicles[carrierId]
    if not pending or pending.sessionId ~= sessionId or pending.targetId ~= targetId or pending.verifying then return end

    if success ~= true then
        pendingVehicles[carrierId] = nil
        TriggerClientEvent("carry_people:client:putInVehicleFailed", carrierId, sessionId)
        if enteredVehicle == true then
            stopCarry(carrierId, false)
        else
            TriggerClientEvent("carry_people:client:startCarried", targetId, carrierId, sessionId)
        end
        return
    end

    pending.verifying = true
    local function verifyPlacement()
        if pendingVehicles[carrierId] ~= pending or carrySessions[targetId] ~= sessionId then return end

        local now = GetGameTimer()
        local vehicle = NetworkGetEntityFromNetworkId(pending.vehicleNetId)
        local targetPed = GetPlayerPed(targetId)
        if now <= pending.expiresAt and vehicle and vehicle ~= 0 and DoesEntityExist(vehicle) and targetPed > 0
            and GetVehiclePedIsIn(targetPed, false) == vehicle
            and GetPedInVehicleSeat(vehicle, pending.seat) == targetPed then
            clearPair(carrierId)
            TriggerClientEvent("carry_people:client:putInVehicleDone", carrierId, sessionId)
            TriggerClientEvent("carry_people:client:putInVehicleSuccess", targetId, sessionId)
            sendMe(carrierId, getMeText("putInVehicle"))
            return
        end

        if now >= pending.expiresAt then
            TriggerClientEvent("carry_people:client:putInVehicleFailed", carrierId, sessionId)
            stopCarry(carrierId, false)
        else
            SetTimeout(math.min(250, pending.expiresAt - now), verifyPlacement)
        end
    end

    verifyPlacement()
end)

RegisterNetEvent("carry_people:server:removeDeadFromVehicle", function(targetId, vehicleNetId)
    local sourceId = source
    targetId = tonumber(targetId)
    vehicleNetId = tonumber(vehicleNetId)

    if not Config.Vehicle or Config.Vehicle.enabled == false then return end
    if not isIntegerInRange(targetId, 1, 65535) or not isIntegerInRange(vehicleNetId, 1, 65535) then return end
    if not isPlayerOnline(sourceId) or not isPlayerOnline(targetId) then return end
    if sourceId == targetId then return end
    if not sameBucket(sourceId, targetId) then return end
    if activeCarries[sourceId] or activeCarries[targetId] then return end
    if removalBySource[sourceId] or pendingRemovals[targetId] then return end
    if isPlayerDeadLike(sourceId) then return end
    if not isPlayerDeadLike(targetId) then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if GetEntityType(vehicle) ~= 2 then return end
    if not vehicleInBucket(vehicle, sourceId) then return end

    local sourcePed = GetPlayerPed(sourceId)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed <= 0 or targetPed <= 0 then return end
    if GetVehiclePedIsIn(sourcePed, false) ~= 0 then return end
    if GetVehiclePedIsIn(targetPed, false) ~= vehicle then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleDistance = ((Config.Vehicle and (Config.Vehicle.removeDeadDistance or Config.Vehicle.distance)) or Config.MaxDistance) + 2.0

    if #(sourceCoords - vehicleCoords) > vehicleDistance then return end
    if #(targetCoords - vehicleCoords) > vehicleDistance then return end

    if not cooldownAllows(sourceId, "removeDead", 1500) then return end

    nextRemovalId = nextRemovalId + 1
    local pending = {
        id = nextRemovalId,
        sourceId = sourceId,
        targetId = targetId,
        vehicleNetId = vehicleNetId,
    }
    pendingRemovals[targetId] = pending
    removalBySource[sourceId] = pending
    TriggerClientEvent("carry_people:client:removeFromVehicle", targetId, vehicleNetId, pending.id)

    SetTimeout(Config.VehiclePlacementTimeout or 6000, function()
        if pendingRemovals[targetId] ~= pending then return end
        clearRemoval(pending)
        if isPlayerOnline(sourceId) then
            TriggerClientEvent("carry_people:client:removeFromVehicleFailed", sourceId)
        end
    end)
end)

RegisterNetEvent("carry_people:server:removeFromVehicleResult", function(removalId, success)
    local targetId = source
    local pending = pendingRemovals[targetId]
    if not pending or pending.id ~= removalId or pending.verifying then return end

    local sourceId = pending.sourceId
    if success ~= true then
        clearRemoval(pending)
        if isPlayerOnline(sourceId) then
            TriggerClientEvent("carry_people:client:removeFromVehicleFailed", sourceId)
        end
        return
    end

    pending.verifying = true
    local function verifyRemoval(attemptsLeft)
        if pendingRemovals[targetId] ~= pending then return end

        local vehicle = NetworkGetEntityFromNetworkId(pending.vehicleNetId)
        local targetPed = GetPlayerPed(targetId)
        if vehicle and vehicle ~= 0 and targetPed > 0
            and GetVehiclePedIsIn(targetPed, false) ~= vehicle then
            clearRemoval(pending)
            if isPlayerOnline(sourceId) then
                TriggerClientEvent("carry_people:client:removeFromVehicleDone", sourceId)
                sendMe(sourceId, getMeText("removeDeadFromVehicle"))
            end
            return
        end

        if attemptsLeft > 0 then
            SetTimeout(250, function() verifyRemoval(attemptsLeft - 1) end)
        else
            clearRemoval(pending)
            if isPlayerOnline(sourceId) then
                TriggerClientEvent("carry_people:client:removeFromVehicleFailed", sourceId)
            end
        end
    end

    verifyRemoval(4)
end)

AddEventHandler("playerDropped", function()
    stopCarry(source, false)
    local pending = pendingRemovals[source] or removalBySource[source]
    if pending then
        clearRemoval(pending)
        if pending.targetId == source and isPlayerOnline(pending.sourceId) then
            TriggerClientEvent("carry_people:client:removeFromVehicleFailed", pending.sourceId)
        end
    end
    lastActionAt[source] = nil
end)
