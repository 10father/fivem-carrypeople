local isCarrying = false
local isCarried = false
local carryTarget = nil
local carriedBy = nil
local radialAdded = false

local function notify(message)
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

local function clearCarryState()
    isCarrying = false
    isCarried = false
    carryTarget = nil
    carriedBy = nil

    DetachEntity(PlayerPedId(), true, false)
    ClearPedSecondaryTask(PlayerPedId())
    ClearPedTasks(PlayerPedId())
end

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

local function requestCarry()
    if isCarrying or isCarried then
        TriggerServerEvent("carry_people:server:stop")
        return
    end

    if not canStartCarry() then return end

    local closestPlayer = getClosestPlayer(Config.MaxDistance)
    if closestPlayer == -1 then
        notify(Config.Text.noPlayer)
        return
    end

    TriggerServerEvent("carry_people:server:request", GetPlayerServerId(closestPlayer))
end

RegisterCommand(Config.Command, requestCarry, false)

if Config.EnableKeybind and Config.DefaultKey and Config.DefaultKey ~= "" then
    RegisterKeyMapping(Config.Command, "背起/放下最近玩家", "keyboard", Config.DefaultKey)
end

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

CreateThread(function()
    Wait(1500)
    addCarryRadial()
end)

AddEventHandler("onResourceStart", function(resourceName)
    if resourceName ~= "ox_lib" and resourceName ~= GetCurrentResourceName() then return end
    Wait(1000)
    addCarryRadial()
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

RegisterNetEvent("carry_people:client:targetBusy", function()
    notify(Config.Text.targetBusy)
end)

AddEventHandler("onResourceStop", function(resourceName)
    if resourceName ~= GetCurrentResourceName() then return end
    removeCarryRadial()
    clearCarryState()
end)
