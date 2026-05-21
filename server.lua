local activeCarries = {}

local function isPlayerOnline(source)
    return source and source > 0 and GetPlayerPing(source) > 0
end

local function clearPair(playerId)
    local paired = activeCarries[playerId]
    if paired then
        activeCarries[paired] = nil
    end

    activeCarries[playerId] = nil
    return paired
end

local function stopCarry(playerId, showNotify)
    local paired = clearPair(playerId)

    if isPlayerOnline(playerId) then
        TriggerClientEvent("carry_people:client:stop", playerId, showNotify == true)
    end

    if paired and isPlayerOnline(paired) then
        TriggerClientEvent("carry_people:client:stop", paired, showNotify == true)
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

    TriggerClientEvent("carry_people:client:startCarrier", sourceId, targetId)
    TriggerClientEvent("carry_people:client:startCarried", targetId, sourceId)
end)

RegisterNetEvent("carry_people:server:stop", function()
    stopCarry(source, true)
end)

AddEventHandler("playerDropped", function()
    stopCarry(source, false)
end)
