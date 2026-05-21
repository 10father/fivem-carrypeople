local activeCarries = {}
local carryRoles = {}

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
    if paired then
        activeCarries[paired] = nil
        carryRoles[paired] = nil
    end

    activeCarries[playerId] = nil
    carryRoles[playerId] = nil

    return paired
end

local function stopCarry(playerId, showNotify)
    local role = carryRoles[playerId]
    local paired = clearPair(playerId)

    if isPlayerOnline(playerId) then
        TriggerClientEvent("carry_people:client:stop", playerId, showNotify == true)
    end

    if paired and isPlayerOnline(paired) then
        TriggerClientEvent("carry_people:client:stop", paired, showNotify == true)
    end

    if showNotify == true and role then
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

    if not isPlayerOnline(sourceId) or not isPlayerOnline(targetId) then return end
    if sourceId == targetId then return end

    if activeCarries[sourceId] or activeCarries[targetId] then
        TriggerClientEvent("carry_people:client:targetBusy", sourceId)
        return
    end

    local sourcePed = GetPlayerPed(sourceId)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed <= 0 or targetPed <= 0 then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    if #(sourceCoords - targetCoords) > (Config.MaxDistance + 1.0) then return end

    activeCarries[sourceId] = targetId
    activeCarries[targetId] = sourceId
    carryRoles[sourceId] = "carrier"
    carryRoles[targetId] = "carried"

    TriggerClientEvent("carry_people:client:startCarrier", sourceId, targetId)
    TriggerClientEvent("carry_people:client:startCarried", targetId, sourceId)
    sendMe(sourceId, getMeText("carry"))
end)

RegisterNetEvent("carry_people:server:stop", function()
    stopCarry(source, true)
end)

RegisterNetEvent("carry_people:server:putInVehicle", function(vehicleNetId, seat)
    local sourceId = source
    vehicleNetId = tonumber(vehicleNetId)
    seat = tonumber(seat)

    if not vehicleNetId or not seat then return end
    if seat < -1 or seat > 16 then return end
    if seat == -1 and not (Config.Vehicle and Config.Vehicle.allowDriverSeat == true) then return end
    if carryRoles[sourceId] ~= "carrier" then return end

    local targetId = activeCarries[sourceId]
    if not isPlayerOnline(sourceId) or not isPlayerOnline(targetId) then
        stopCarry(sourceId, false)
        return
    end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if GetEntityType(vehicle) ~= 2 then return end

    local sourcePed = GetPlayerPed(sourceId)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed <= 0 or targetPed <= 0 then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleDistance = ((Config.Vehicle and Config.Vehicle.distance) or Config.MaxDistance) + 2.0

    if #(sourceCoords - targetCoords) > (Config.MaxDistance + 2.0) then return end
    if #(sourceCoords - vehicleCoords) > vehicleDistance then return end

    clearPair(sourceId)

    TriggerClientEvent("carry_people:client:putInVehicleDone", sourceId)
    TriggerClientEvent("carry_people:client:putInVehicle", targetId, vehicleNetId, seat)
    sendMe(sourceId, getMeText("putInVehicle"))
end)

RegisterNetEvent("carry_people:server:removeDeadFromVehicle", function(targetId, vehicleNetId)
    local sourceId = source
    targetId = tonumber(targetId)
    vehicleNetId = tonumber(vehicleNetId)

    if not targetId or not vehicleNetId then return end
    if not isPlayerOnline(sourceId) or not isPlayerOnline(targetId) then return end
    if sourceId == targetId then return end
    if not isPlayerDeadLike(targetId) then return end

    local vehicle = NetworkGetEntityFromNetworkId(vehicleNetId)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return end
    if GetEntityType(vehicle) ~= 2 then return end

    local sourcePed = GetPlayerPed(sourceId)
    local targetPed = GetPlayerPed(targetId)
    if sourcePed <= 0 or targetPed <= 0 then return end

    local sourceCoords = GetEntityCoords(sourcePed)
    local targetCoords = GetEntityCoords(targetPed)
    local vehicleCoords = GetEntityCoords(vehicle)
    local vehicleDistance = ((Config.Vehicle and (Config.Vehicle.removeDeadDistance or Config.Vehicle.distance)) or Config.MaxDistance) + 2.0

    if #(sourceCoords - vehicleCoords) > vehicleDistance then return end
    if #(targetCoords - vehicleCoords) > vehicleDistance then return end

    local targetVehicle = GetVehiclePedIsIn(targetPed, false)
    if targetVehicle ~= 0 and targetVehicle ~= vehicle then return end

    if activeCarries[sourceId] or activeCarries[targetId] then
        stopCarry(sourceId, false)
    end

    TriggerClientEvent("carry_people:client:removeFromVehicleDone", sourceId)
    TriggerClientEvent("carry_people:client:removeFromVehicle", targetId, vehicleNetId)
    sendMe(sourceId, getMeText("removeDeadFromVehicle"))
end)

AddEventHandler("playerDropped", function()
    stopCarry(source, false)
end)
