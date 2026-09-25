# carry_people

独立背人插件，无 qb/qbx/esx 依赖。作者：kongcheng和vance。

## 安装

需要 `ox_lib` 和已开启的 OneSync；`ox_target` 仅用于可选的目标交互。

1. 把 `carry_people` 文件夹放进服务器资源目录。
2. 在 `server.cfg` 先启动 `ox_lib`，再启动本资源：

```cfg
ensure ox_lib
ensure carry_people
```

## 使用

默认命令：

```text
/carry
```

靠近玩家输入一次背起，再输入一次放下。
背人或被背时，按 `X` 也可以放下/下来。
背着玩家靠近车辆时，输入 `/putincar` 或使用车辆目标交互「把背着的人放进车里」，会打开座位选择菜单。点击副驾驶、后排左座或后排右座等可用座位，把人放到所选位置。
菜单按车型显示座位，已占用的座位不可选；按 Esc 取消菜单会继续背人。若选定座位在执行前被占用，操作会失败并保留背人状态，可以重新打开菜单选择，不会自动换座。
靠近有死亡玩家的车辆，可以输入 `/pulloutdead` 把死亡玩家从车上放下。

默认会在 `ox_lib` 径向菜单里显示 `背人`。
如果服务器有 `ox_target`，默认会添加玩家目标选项、放进车选项、死亡玩家下车选项。

动作会像 `origen_police` 一样直接执行服务器现有 `/me 动作` 命令，聊天框和角色旁边 3D 文本由你的 `/me` 聊天资源显示。

## 配置

在 `config.lua` 里可以改：

- `Config.Command`: 命令名
- `Config.Radial`: ox_lib 径向菜单配置
- `Config.Target`: ox_target 玩家/车辆交互配置
- `Config.EnableKeybind`: 是否启用按键绑定
- `Config.DefaultKey`: 默认按键
- `Config.StopKey`: 放下/下来的默认按键，默认 `X`
- `Config.EnableStopKey`: 是否启用放下按键；关闭后按键映射和可选原生控制均停用
- `Config.StopControl`: 可选的原生控制编号，默认关闭；通常只需使用可重映射的 `StopKey`
- `Config.Vehicle`: 放进车里的命令、距离和座位配置
- `Config.Vehicle.seatOrder`: 座位菜单显示顺序，默认后排左座、后排右座、副驾驶；其余乘客座位自动补充
- `Config.Vehicle.allowDriverSeat`: 是否允许选择驾驶位，默认 `false`，改成 `true` 即可开启
- `Config.Vehicle.seatLabels`: 座位名称，`-1` 为驾驶位、`0` 为副驾驶、`1/2` 为普通四座车的后排左/右座；特殊车型可自行调整
- `Config.CarryStartTimeout` / `Config.VehiclePlacementTimeout`: 背人启动和放入车辆的超时毫秒数
- `Config.MaxDistance`: 最大交互距离
- `Config.Text`: 中文提示文字
- `Config.Me`: `/me` 命令和动作文本配置

## 离线检查

安装 Python 的 `lupa` 后运行 `python3 tests/run.py`。测试使用模拟 FiveM API，覆盖事件校验、超时、配对清理和客户端车辆操作；实际服务器仍需验证 OneSync 同步、动作和车辆座位表现。
