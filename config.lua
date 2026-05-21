Config = {}

Config.Command = "carry"
Config.EnableKeybind = false
Config.DefaultKey = "G"

Config.Radial = {
    enabled = true,
    id = "carry_people",
    label = "背人",
    icon = "user-group",
}

Config.MaxDistance = 3.0

Config.Text = {
    noPlayer = "附近没有可以背起的玩家",
    inVehicle = "车内不能使用背人",
    busy = "你现在不能这么做",
    carrying = "已背起玩家，再次输入 /carry 放下",
    carried = "你被背起来了",
    stopped = "已放下",
    targetBusy = "对方现在不能被背起"
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
