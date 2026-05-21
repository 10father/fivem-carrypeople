# carry_people

独立背人插件，无 qb/qbx/esx 依赖。作者：kongcheng。

## 安装

1. 把 `carry_people` 文件夹放进服务器资源目录。
2. 在 `server.cfg` 添加：

```cfg
ensure carry_people
```

## 使用

默认命令：

```text
/carry
```

靠近玩家输入一次背起，再输入一次放下。
背人或被背时，按 `X` 也可以放下/下来。
背着玩家靠近车辆时，可以输入 `/putincar` 把人放进车里。
靠近有死亡玩家的车辆，可以输入 `/pulloutdead` 把死亡玩家从车上放下。

如果服务器有 `ox_lib`，默认也会在径向菜单里显示 `背人`。
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
- `Config.Vehicle`: 放进车里的命令、距离和座位配置
- `Config.MaxDistance`: 最大交互距离
- `Config.Text`: 中文提示文字
- `Config.Me`: `/me` 命令和动作文本配置
