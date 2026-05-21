# carry_people

独立背人插件，无 qb/qbx/esx 依赖。

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

如果服务器有 `ox_lib`，默认也会在径向菜单里显示 `背人`。

## 配置

在 `config.lua` 里可以改：

- `Config.Command`: 命令名
- `Config.Radial`: ox_lib 径向菜单配置
- `Config.EnableKeybind`: 是否启用按键绑定
- `Config.DefaultKey`: 默认按键
- `Config.MaxDistance`: 最大交互距离
- `Config.Text`: 中文提示文字
