Config = {}

Config.Command = "carry"
Config.EnableKeybind = false
Config.DefaultKey = "G"
Config.StopCommand = "carrydrop"
Config.EnableStopKey = true
Config.StopKey = "X"
Config.StopControl = 73

Config.Radial = {
    enabled = true,
    id = "carry_people",
    label = "背人",
    icon = "user-group",
}

Config.Target = {
    enabled = true,
    carry = {
        name = "carry_people_carry",
        label = "背起/放下玩家",
        icon = "fa-solid fa-user-group",
    },
    putInVehicle = {
        name = "carry_people_put_vehicle",
        label = "把背着的人放进车里",
        icon = "fa-solid fa-car-side",
    },
    removeDeadFromVehicle = {
        name = "carry_people_remove_dead_vehicle",
        label = "把死亡玩家从车上放下",
        icon = "fa-solid fa-person-falling",
    },
}

Config.Vehicle = {
    enabled = true,
    command = "putincar",
    removeDeadCommand = "pulloutdead",
    distance = 3.0,
    removeDeadDistance = 3.0,
    allowDriverSeat = false,
    seatOrder = { 1, 2, 0 },
    removeOffset = {
        x = -1.2,
        y = -2.0,
        z = 0.0,
    },
}

Config.MaxDistance = 3.0

Config.Text = {
    noPlayer = "附近没有可以背起的玩家",
    inVehicle = "车内不能使用背人",
    busy = "你现在不能这么做",
    carrying = "已背起玩家，按 X 或再次输入 /carry 放下",
    carried = "你被背起来了，按 X 可以下来",
    stopped = "已放下",
    targetBusy = "对方现在不能被背起",
    notCarrying = "你现在没有背着玩家",
    noVehicle = "附近没有可用车辆",
    vehicleFull = "这辆车没有空座位",
    putInVehicle = "已把玩家放进车里",
    putInVehicleTarget = "你已被放进车里",
    noDeadPlayerInVehicle = "这辆车上没有死亡玩家",
    removedDeadFromVehicle = "已把死亡玩家从车上放下",
    removedDeadFromVehicleTarget = "你已被从车上放下"
}

Config.Me = {
    enabled = true,
    useCommand = true,
    command = "me",
    distance = 20.0,
    prefix = "/me",
    color = { 180, 120, 255 },
    duration = 5000,
    zOffset = 1.0,
    scale = 0.38,
    textColor = { 220, 180, 255, 230 },
    carry = "背起了一名玩家",
    drop = "放下了背着的人",
    dropCarried = "从背着自己的人身上下来",
    putInVehicle = "把背着的人放进车里",
    removeDeadFromVehicle = "把车上的死亡玩家放了下来"
}

Config.Animations = {
    carrier = {
        dict = "missfinale_c2mcs_1",
        anim = "fin_c2_mcs_1_camman",
        flag = 49,
    },
    carried = {
        dict = "nm",
        anim = "firemans_carry",
        flag = 33,
        offset = {
            x = 0.27,
            y = 0.15,
            z = 0.63,
            rx = 0.5,
            ry = 0.5,
            rz = 180.0,
        }
    }
}
