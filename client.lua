local isCarrying = false
local isCarried = false
local carryTarget = nil
local carriedBy = nil
local radialAdded = false
local targetAdded = false
local lastStopRequest = -1000
local activeMeTexts = {}

local function notify(message)
    if not message or message == "" then return end

    BeginTextCommandThefeedPost("STRING")
    AddTextComponentSubstringPlayerName(message)
    EndTextCommandThefeedPostTicker(false, false)
end

local function loadAnimDict(dict)
    if HasAnimDictLoaded(dict) then return true end

    RequestAnimDict(dict)

    local timeout = GetGameTimer() + 5000
    while not HasAnimDictLoaded(dict) do
        Wait(10)
        if GetGameTimer() > timeout then
            return false
        end
    end

    return true
end

local function getClosestPlayer(maxDistance)
    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = -1
    local closestDistance = maxDistance or Config.MaxDistance

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() then
            local targetPed = GetPlayerPed(player)
            if DoesEntityExist(targetPed) then
                local distance = #(playerCoords - GetEntityCoords(targetPed))
                if distance < closestDistance then
                    closestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end

    return closestPlayer, closestDistance
end

local function getPlayerFromEntity(entity)
    if not entity or entity == 0 then return -1 end

    local player = NetworkGetPlayerIndexFromPed(entity)
    if player and player ~= -1 and player ~= PlayerId() then
        return player
    end

    for _, activePlayer in ipairs(GetActivePlayers()) do
        if activePlayer ~= PlayerId() and GetPlayerPed(activePlayer) == entity then
            return activePlayer
        end
    end

    return -1
end

local function isPlayerDeadLike(player)
    if not player or player == -1 then return false end

    local ped = GetPlayerPed(player)
    if not DoesEntityExist(ped) then return false end

    if IsEntityDead(ped) or IsPedDeadOrDying(ped, true) or IsPedFatallyInjured(ped) or GetEntityHealth(ped) <= 0 then
        return true
    end

    local serverId = GetPlayerServerId(player)
    local state = Player(serverId).state

    return state.isDead == true
        or state.dead == true
        or state.inlaststand == true
        or state.inLaststand == true
        or state.laststand == true
        or state.isIncapacitated == true
end

local function stopCarryAnimations()
    local playerPed = PlayerPedId()
    local animations = Config.Animations or {}

    for _, anim in pairs(animations) do
        if anim.dict and anim.anim then
            StopAnimTask(playerPed, anim.dict, anim.anim, 2.0)
        end
    end

    ClearPedSecondaryTask(playerPed)
end

local function clearCarryState()
    isCarrying = false
    isCarried = false
    carryTarget = nil
    carriedBy = nil

    DetachEntity(PlayerPedId(), true, false)
    stopCarryAnimations()
    ClearPedTasks(PlayerPedId())

    CreateThread(function()
        Wait(250)
        stopCarryAnimations()
    end)
end

local function drawText3d(coords, text)
    local onScreen, screenX, screenY = World3dToScreen2d(coords.x, coords.y, coords.z)
    if not onScreen then return end

    local meConfig = Config.Me or {}
    local color = meConfig.textColor or { 220, 180, 255, 230 }
    local scale = meConfig.scale or 0.38

    SetTextScale(scale, scale)
    SetTextFont(0)
    SetTextProportional(1)
    SetTextCentre(true)
    SetTextColour(color[1] or 220, color[2] or 180, color[3] or 255, color[4] or 230)
    SetTextDropshadow(1, 0, 0, 0, 160)
    SetTextEdge(1, 0, 0, 0, 120)
    SetTextOutline()
    BeginTextCommandDisplayText("STRING")
    AddTextComponentSubstringPlayerName(text)
    EndTextCommandDisplayText(screenX, screenY)
end

local function addMeText(serverId, text)
    if not serverId or not text or text == "" then return end

    local meConfig = Config.Me or {}
    activeMeTexts[#activeMeTexts + 1] = {
        serverId = serverId,
        text = ("* %s *"):format(text),
        expiresAt = GetGameTimer() + (meConfig.duration or 5000),
    }
end

CreateThread(function()
    while true do
        if #activeMeTexts == 0 then
            Wait(500)
        else
            Wait(0)

            local now = GetGameTimer()
            local myCoords = GetEntityCoords(PlayerPedId())
            local meConfig = Config.Me or {}
            local drawDistance = meConfig.distance or 20.0
            local zOffset = meConfig.zOffset or 1.0

            for index = #activeMeTexts, 1, -1 do
                local item = activeMeTexts[index]

                if now >= item.expiresAt then
                    table.remove(activeMeTexts, index)
                else
                    local player = GetPlayerFromServerId(item.serverId)
                    if player ~= -1 then
                        local ped = GetPlayerPed(player)
                        if DoesEntityExist(ped) then
                            local coords = GetEntityCoords(ped)
                            if #(myCoords - coords) <= drawDistance then
                                drawText3d(vector3(coords.x, coords.y, coords.z + zOffset), item.text)
                            end
                        end
                    end
                end
            end
        end
    end
end)

local function canStartCarry()
    if IsPedInAnyVehicle(PlayerPedId(), false) then
        notify(Config.Text.inVehicle)
        return false
    end

    if isCarried then
        notify(Config.Text.busy)
        return false
    end

    return true
end

local function requestStopCarry()
    if not isCarrying and not isCarried then return end

    local now = GetGameTimer()
    if now - lastStopRequest < 800 then return end

    lastStopRequest = now
    TriggerServerEvent("carry_people:server:stop")
end

local function requestCarryPlayer(player)
    if not player or player == -1 then
        notify(Config.Text.noPlayer)
        return
    end

    local targetPed = GetPlayerPed(player)
    if not DoesEntityExist(targetPed) then
        notify(Config.Text.noPlayer)
        return
    end

    local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(targetPed))
    if distance > Config.MaxDistance then
        notify(Config.Text.noPlayer)
        return
    end

    TriggerServerEvent("carry_people:server:request", GetPlayerServerId(player))
end

local function requestCarry()
    if isCarrying or isCarried then
        requestStopCarry()
        return
    end

    if not canStartCarry() then return end

    local closestPlayer = getClosestPlayer(Config.MaxDistance)
    requestCarryPlayer(closestPlayer)
end

local function requestCarryFromEntity(entity)
    if isCarrying or isCarried then
        requestStopCarry()
        return
    end

    if not canStartCarry() then return end

    requestCarryPlayer(getPlayerFromEntity(entity))
end

local function getClosestVehicle(maxDistance)
    local playerCoords = GetEntityCoords(PlayerPedId())
    local closestVehicle = 0
    local closestDistance = maxDistance or ((Config.Vehicle and Config.Vehicle.distance) or Config.MaxDistance)

    for _, vehicle in ipairs(GetGamePool("CVehicle")) do
        if DoesEntityExist(vehicle) then
            local distance = #(playerCoords - GetEntityCoords(vehicle))
            if distance < closestDistance then
                closestDistance = distance
                closestVehicle = vehicle
            end
        end
    end

    return closestVehicle, closestDistance
end

local function buildSeatCandidates(vehicle)
    local maxPassengers = GetVehicleMaxNumberOfPassengers(vehicle)
    local configuredSeats = (Config.Vehicle and Config.Vehicle.seatOrder) or {}
    local allowDriverSeat = Config.Vehicle and Config.Vehicle.allowDriverSeat == true
    local seats = {}
    local used = {}

    local function addSeat(seat)
        seat = tonumber(seat)
        if not seat or used[seat] then return end

        if seat == -1 then
            if allowDriverSeat then
                seats[#seats + 1] = seat
                used[seat] = true
            end
            return
        end

        if seat >= 0 and seat < maxPassengers then
            seats[#seats + 1] = seat
            used[seat] = true
        end
    end

    for _, seat in ipairs(configuredSeats) do
        addSeat(seat)
    end

    for seat = 0, maxPassengers - 1 do
        addSeat(seat)
    end

    addSeat(-1)

    return seats
end

local function getFreePassengerSeat(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return nil end

    for _, seat in ipairs(buildSeatCandidates(vehicle)) do
        if IsVehicleSeatFree(vehicle, seat) then
            return seat
        end
    end

    return nil
end

local function getVehicleNetId(vehicle)
    if not NetworkGetEntityIsNetworked(vehicle) then
        NetworkRegisterEntityAsNetworked(vehicle)
    end

    local netId = VehToNet(vehicle)
    if netId and netId ~= 0 then
        SetNetworkIdCanMigrate(netId, true)
    end

    return netId
end

local function requestPutInVehicle(vehicle)
    if Config.Vehicle and Config.Vehicle.enabled == false then return end

    if not isCarrying then
        notify(Config.Text.notCarrying)
        return
    end

    local maxDistance = (Config.Vehicle and Config.Vehicle.distance) or Config.MaxDistance
    if not vehicle or vehicle == 0 then
        vehicle = getClosestVehicle(maxDistance)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(Config.Text.noVehicle)
        return
    end

    local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle))
    if distance > maxDistance then
        notify(Config.Text.noVehicle)
        return
    end

    local seat = getFreePassengerSeat(vehicle)
    if seat == nil then
        notify(Config.Text.vehicleFull)
        return
    end

    local netId = getVehicleNetId(vehicle)
    if not netId or netId == 0 then
        notify(Config.Text.noVehicle)
        return
    end

    TriggerServerEvent("carry_people:server:putInVehicle", netId, seat)
end

local function findDeadPlayerInVehicle(vehicle)
    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then return -1 end

    local playerPed = PlayerPedId()
    local playerCoords = GetEntityCoords(playerPed)
    local closestPlayer = -1
    local closestDistance = 999.0

    for _, player in ipairs(GetActivePlayers()) do
        if player ~= PlayerId() and isPlayerDeadLike(player) then
            local targetPed = GetPlayerPed(player)
            if DoesEntityExist(targetPed) and GetVehiclePedIsIn(targetPed, false) == vehicle then
                local distance = #(playerCoords - GetEntityCoords(targetPed))
                if distance < closestDistance then
                    closestDistance = distance
                    closestPlayer = player
                end
            end
        end
    end

    return closestPlayer, closestDistance
end

local function requestRemoveDeadFromVehicle(vehicle)
    if Config.Vehicle and Config.Vehicle.enabled == false then return end

    local maxDistance = (Config.Vehicle and (Config.Vehicle.removeDeadDistance or Config.Vehicle.distance)) or Config.MaxDistance
    if not vehicle or vehicle == 0 then
        vehicle = getClosestVehicle(maxDistance)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(Config.Text.noVehicle)
        return
    end

    local distance = #(GetEntityCoords(PlayerPedId()) - GetEntityCoords(vehicle))
    if distance > maxDistance then
        notify(Config.Text.noVehicle)
        return
    end

    local targetPlayer = findDeadPlayerInVehicle(vehicle)
    if targetPlayer == -1 then
        notify(Config.Text.noDeadPlayerInVehicle)
        return
    end

    local netId = getVehicleNetId(vehicle)
    if not netId or netId == 0 then
        notify(Config.Text.noVehicle)
        return
    end

    TriggerServerEvent("carry_people:server:removeDeadFromVehicle", GetPlayerServerId(targetPlayer), netId)
end

RegisterCommand(Config.Command, requestCarry, false)

if Config.EnableKeybind and Config.DefaultKey and Config.DefaultKey ~= "" then
    RegisterKeyMapping(Config.Command, "背起/放下最近玩家", "keyboard", Config.DefaultKey)
end

RegisterCommand(Config.StopCommand or "carrydrop", requestStopCarry, false)

if Config.EnableStopKey ~= false and Config.StopKey and Config.StopKey ~= "" then
    RegisterKeyMapping(Config.StopCommand or "carrydrop", "放下背着/被背的人", "keyboard", Config.StopKey)
end

RegisterCommand((Config.Vehicle and Config.Vehicle.command) or "putincar", function()
    requestPutInVehicle()
end, false)

RegisterCommand((Config.Vehicle and Config.Vehicle.removeDeadCommand) or "pulloutdead", function()
    requestRemoveDeadFromVehicle()
end, false)

CreateThread(function()
    while true do
        if isCarrying or isCarried then
            Wait(0)

            local stopControl = Config.StopControl or 73
            if stopControl and (IsControlJustPressed(0, stopControl) or IsDisabledControlJustPressed(0, stopControl)) then
                requestStopCarry()
            end
        else
            Wait(500)
        end
    end
end)

local function hasOxRadial()
    return GetResourceState("ox_lib") == "started"
        and lib ~= nil
        and type(lib.addRadialItem) == "function"
        and type(lib.removeRadialItem) == "function"
end

local function addCarryRadial()
    if radialAdded then return end
    if not Config.Radial or Config.Radial.enabled == false then return end
    if not hasOxRadial() then return end

    lib.addRadialItem({
        id = Config.Radial.id or "carry_people",
        label = Config.Radial.label or "背人",
        icon = Config.Radial.icon or "user-group",
        onSelect = requestCarry,
    })

    radialAdded = true
end

local function removeCarryRadial()
    if radialAdded and hasOxRadial() then
        lib.removeRadialItem((Config.Radial and Config.Radial.id) or "carry_people")
    end

    radialAdded = false
end

local function hasOxTarget()
    return Config.Target
        and Config.Target.enabled ~= false
        and GetResourceState("ox_target") == "started"
end

local function addCarryTarget()
    if targetAdded then return end
    if not hasOxTarget() then return end

    local targetConfig = Config.Target or {}
    local carryConfig = targetConfig.carry or {}
    local vehicleConfig = targetConfig.putInVehicle or {}
    local removeDeadConfig = targetConfig.removeDeadFromVehicle or {}
    local vehicleDistance = (Config.Vehicle and Config.Vehicle.distance) or Config.MaxDistance
    local removeDeadDistance = (Config.Vehicle and (Config.Vehicle.removeDeadDistance or Config.Vehicle.distance)) or Config.MaxDistance

    local ok, err = pcall(function()
        exports.ox_target:addGlobalPlayer({
            {
                name = carryConfig.name or "carry_people_carry",
                label = carryConfig.label or "背起/放下玩家",
                icon = carryConfig.icon or "fa-solid fa-user-group",
                distance = Config.MaxDistance,
                canInteract = function(entity, distance)
                    return entity ~= PlayerPedId()
                        and not isCarrying
                        and not isCarried
                        and distance <= Config.MaxDistance
                        and not IsPedInAnyVehicle(PlayerPedId(), false)
                end,
                onSelect = function(data)
                    requestCarryFromEntity(data.entity)
                end,
            }
        })

        if not Config.Vehicle or Config.Vehicle.enabled ~= false then
            exports.ox_target:addGlobalVehicle({
                {
                    name = vehicleConfig.name or "carry_people_put_vehicle",
                    label = vehicleConfig.label or "把背着的人放进车里",
                    icon = vehicleConfig.icon or "fa-solid fa-car-side",
                    distance = vehicleDistance,
                    canInteract = function(entity, distance)
                        return isCarrying
                            and DoesEntityExist(entity)
                            and distance <= vehicleDistance
                    end,
                    onSelect = function(data)
                        requestPutInVehicle(data.entity)
                    end,
                }
            })

            exports.ox_target:addGlobalVehicle({
                {
                    name = removeDeadConfig.name or "carry_people_remove_dead_vehicle",
                    label = removeDeadConfig.label or "把死亡玩家从车上放下",
                    icon = removeDeadConfig.icon or "fa-solid fa-person-falling",
                    distance = removeDeadDistance,
                    canInteract = function(entity, distance)
                        return not isCarrying
                            and not isCarried
                            and DoesEntityExist(entity)
                            and distance <= removeDeadDistance
                            and findDeadPlayerInVehicle(entity) ~= -1
                    end,
                    onSelect = function(data)
                        requestRemoveDeadFromVehicle(data.entity)
                    end,
                }
            })
        end
    end)

    if not ok then
        print(("[carry_people] ox_target setup failed: %s"):format(err))
        return
    end

    targetAdded = true
end

local function removeCarryTarget()
    if targetAdded and GetResourceState("ox_target") == "started" then
        local targetConfig = Config.Target or {}
        local carryConfig = targetConfig.carry or {}
        local vehicleConfig = targetConfig.putInVehicle or {}
        local removeDeadConfig = targetConfig.removeDeadFromVehicle or {}

        pcall(function()
            exports.ox_target:removeGlobalPlayer(carryConfig.name or "carry_people_carry")
        end)

        pcall(function()
            exports.ox_target:removeGlobalVehicle(vehicleConfig.name or "carry_people_put_vehicle")
        end)

        pcall(function()
            exports.ox_target:removeGlobalVehicle(removeDeadConfig.name or "carry_people_remove_dead_vehicle")
        end)
    end

    targetAdded = false
end

local function addIntegrations()
    addCarryRadial()
    addCarryTarget()
end

CreateThread(function()
    Wait(1500)
    addIntegrations()
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= "ox_lib" and resourceName ~= "ox_target" and resourceName ~= GetCurrentResourceName() then return end
    Wait(1000)
    addIntegrations()
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName == "ox_target" then
        targetAdded = false
        return
    end

    if resourceName ~= GetCurrentResourceName() then return end

    removeCarryRadial()
    removeCarryTarget()
    clearCarryState()
end)

RegisterNetEvent("carry_people:client:startCarrier", function(targetId)
    local anim = Config.Animations.carrier
    if not loadAnimDict(anim.dict) then return end

    isCarrying = true
    isCarried = false
    carryTarget = targetId

    TaskPlayAnim(PlayerPedId(), anim.dict, anim.anim, 8.0, -8.0, -1, anim.flag, 0.0, false, false, false)
    notify(Config.Text.carrying)

    CreateThread(function()
        while isCarrying do
            Wait(1000)
            if not isCarrying then break end

            if not IsEntityPlayingAnim(PlayerPedId(), anim.dict, anim.anim, 3) then
                TaskPlayAnim(PlayerPedId(), anim.dict, anim.anim, 8.0, -8.0, -1, anim.flag, 0.0, false, false, false)
            end
        end
    end)
end)

RegisterNetEvent("carry_people:client:startCarried", function(carrierId)
    local carrierPlayer = GetPlayerFromServerId(carrierId)
    if carrierPlayer == -1 then return end

    local carrierPed = GetPlayerPed(carrierPlayer)
    if not DoesEntityExist(carrierPed) then return end

    local anim = Config.Animations.carried
    local offset = anim.offset
    if not loadAnimDict(anim.dict) then return end

    isCarried = true
    isCarrying = false
    carriedBy = carrierId

    AttachEntityToEntity(
        PlayerPedId(),
        carrierPed,
        0,
        offset.x,
        offset.y,
        offset.z,
        offset.rx,
        offset.ry,
        offset.rz,
        false,
        false,
        false,
        false,
        2,
        false
    )

    TaskPlayAnim(PlayerPedId(), anim.dict, anim.anim, 8.0, -8.0, -1, anim.flag, 0.0, false, false, false)
    notify(Config.Text.carried)

    CreateThread(function()
        while isCarried do
            Wait(0)
            DisableControlAction(0, 21, true)
            DisableControlAction(0, 22, true)
            DisableControlAction(0, 24, true)
            DisableControlAction(0, 25, true)
            DisableControlAction(0, 37, true)
            DisableControlAction(0, 44, true)
            DisableControlAction(0, 140, true)
            DisableControlAction(0, 141, true)
            DisableControlAction(0, 142, true)
            DisableControlAction(0, 143, true)
            DisableControlAction(0, 257, true)
            DisableControlAction(0, 263, true)
            DisableControlAction(0, 264, true)
        end
    end)

    CreateThread(function()
        while isCarried do
            Wait(1000)
            if not isCarried then break end

            local currentCarrier = GetPlayerFromServerId(carriedBy or -1)
            if currentCarrier == -1 or not DoesEntityExist(GetPlayerPed(currentCarrier)) then
                TriggerServerEvent("carry_people:server:stop")
                return
            end

            if not IsEntityPlayingAnim(PlayerPedId(), anim.dict, anim.anim, 3) then
                TaskPlayAnim(PlayerPedId(), anim.dict, anim.anim, 8.0, -8.0, -1, anim.flag, 0.0, false, false, false)
            end
        end
    end)
end)

RegisterNetEvent("carry_people:client:stop", function(showNotify)
    local hadState = isCarrying or isCarried
    clearCarryState()

    if showNotify and hadState then
        notify(Config.Text.stopped)
    end
end)

RegisterNetEvent("carry_people:client:putInVehicleDone", function()
    clearCarryState()
    notify(Config.Text.putInVehicle)
end)

RegisterNetEvent("carry_people:client:putInVehicle", function(vehicleNetId, seat)
    clearCarryState()

    local timeout = GetGameTimer() + 3000
    local vehicle = NetToVeh(vehicleNetId)
    while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and GetGameTimer() < timeout do
        Wait(50)
        vehicle = NetToVeh(vehicleNetId)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(Config.Text.noVehicle)
        return
    end

    SetPedIntoVehicle(PlayerPedId(), vehicle, tonumber(seat) or 0)
    notify(Config.Text.putInVehicleTarget)
end)

RegisterNetEvent("carry_people:client:removeFromVehicleDone", function()
    notify(Config.Text.removedDeadFromVehicle)
end)

RegisterNetEvent("carry_people:client:removeFromVehicle", function(vehicleNetId)
    local ped = PlayerPedId()
    local timeout = GetGameTimer() + 3000
    local vehicle = NetToVeh(vehicleNetId)

    while (not vehicle or vehicle == 0 or not DoesEntityExist(vehicle)) and GetGameTimer() < timeout do
        Wait(50)
        vehicle = NetToVeh(vehicleNetId)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        vehicle = GetVehiclePedIsIn(ped, false)
    end

    if not vehicle or vehicle == 0 or not DoesEntityExist(vehicle) then
        notify(Config.Text.noVehicle)
        return
    end

    local offset = (Config.Vehicle and Config.Vehicle.removeOffset) or { x = -1.2, y = -2.0, z = 0.0 }
    local coords = GetOffsetFromEntityInWorldCoords(vehicle, offset.x or -1.2, offset.y or -2.0, offset.z or 0.0)
    local foundGround, groundZ = GetGroundZFor_3dCoord(coords.x, coords.y, coords.z + 2.0, false)

    if foundGround then
        coords = vector3(coords.x, coords.y, groundZ + 0.15)
    end

    clearCarryState()
    ClearPedTasksImmediately(ped)
    SetEntityCoordsNoOffset(ped, coords.x, coords.y, coords.z, false, false, false)
    SetEntityHeading(ped, GetEntityHeading(vehicle))
    SetPedCanRagdoll(ped, true)
    SetPedToRagdoll(ped, 2500, 2500, 0, false, false, false)
    notify(Config.Text.removedDeadFromVehicleTarget)
end)

RegisterNetEvent("carry_people:client:runMe", function(text)
    local meConfig = Config.Me or {}
    if meConfig.enabled == false or not text or text == "" then return end

    ExecuteCommand(("%s %s"):format(meConfig.command or "me", text))
end)

RegisterNetEvent("carry_people:client:showMe", function(sourceId, playerName, text)
    local meConfig = Config.Me or {}
    local prefix = meConfig.prefix or "/me"
    local message = ("%s %s"):format(playerName or ("ID " .. tostring(sourceId)), text or "")
    local color = meConfig.color or { 180, 120, 255 }
    local template = ('<div><span style="color: rgb(%d, %d, %d);">{0}</span>{1}</div>'):format(
        color[1] or 180,
        color[2] or 120,
        color[3] or 255
    )

    TriggerEvent("chat:addMessage", {
        template = template,
        color = color,
        multiline = true,
        args = { prefix, message }
    })

    addMeText(tonumber(sourceId), text)
end)

RegisterNetEvent("carry_people:client:targetBusy", function()
    notify(Config.Text.targetBusy)
end)
