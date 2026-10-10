# KDEGlobalMenu —— KDE Plasma 桌面小部件

模仿 macOS 系统菜单的 Plasma 6 面板部件：点击后展开
macOS 风格的竖向菜单。图标可在部件设置里替换。

## 菜单结构

```
关于本机
系统设置
──────────────
最近使用的项目  ›
──────────────
睡眠
重新启动
关机
锁定屏幕
退出登录
```

## 每一项用的原生能力

| 菜单项 | 实现方式 | 说明 |
|---|---|---|
| 关于本机 | `kcmshell6 kcm_about-distro` | KDE 原生「关于此系统」页面 |
| 系统设置 | `systemsettings` | 系统设置主程序 |
| 最近使用的项目 | KActivities 使用数据库 + desktop 文件 | 子菜单，列出最近启动的程序（真实图标 + 按系统语言本地化的名称），与 KDE「最近使用」同源；点击用 `gio launch` 启动程序，失败回落 `gtk-launch` |
| 睡眠 | `SessionManagement.suspend()` | Plasma 会话管理；回落 logind `Manager.Suspend` |
| 重新启动 | `SessionManagement.requestReboot()` | 遵循系统设置里的「是否需要确认」策略 |
| 关机 | `SessionManagement.requestShutdown()` | 同上 |
| 锁定屏幕 | `SessionManagement.lock()` | 回落 `org.freedesktop.ScreenSaver.Lock` |
| 退出登录 | `SessionManagement.requestLogout()` | Plasma 原生注销流程（含会话保存/确认） |

`SessionManagement` 来自 `org.kde.plasma.private.sessions`，就是 Plasma 自己「离开」菜单用的
那个后端。若该插件将来改名或缺失，所有动作会自动回落到 D-Bus 分支，功能不会失效。

## 安装

```bash
./install.sh              # 安装（已安装则升级）
./install.sh --panel      # 安装后自动加到面板最左侧
./install.sh --uninstall  # 卸载
```

安装到用户级目录 `~/.local/share/plasma/plasmoids/org.murasaki.kdeglobalmenu/`，不需要 root。

装好后：**右键面板 → 编辑面板 → 添加部件 → 搜索「KDEGlobalMenu」**，然后拖到面板最左侧
（macOS 菜单位置）。

## 文件结构

```
install.sh                            # 安装/升级/卸载（含编译图标选择器、安装翻译）
package/
├── metadata.json                     # 部件元数据（含 zh_CN 名称/描述）
├── locale/                           # 预编译翻译（按系统语言自动选用）
│   ├── en/LC_MESSAGES/…
│   └── zh_CN/LC_MESSAGES/…
└── contents/
    ├── bin/                          # install.sh 的编译产物：kdeglobalmenu-iconchooser
    ├── config/
    │   ├── main.xml                  # 配置项定义（KConfig XT）
    │   └── config.qml                # 配置对话框入口
    ├── tools/
    │   └── kdeglobalmenu-helper.py       # 读 KActivities 数据库取「最近使用的程序」
    └── ui/
        ├── main.qml                  # 主入口：面板图标 + 弹出层
        ├── MenuPopup.qml             # 菜单内容（主菜单 / 最近项目两个视图）
        ├── MenuRow.qml               # 单行菜单项（图标 + 文字 + 子菜单箭头）
        └── Actions.qml               # 动作层（原生优先、失败回落）
po/                                   # 翻译源文件
tools/iconchooser/                    # 图标选择器（C++，调用 KIconDialog）
tests/
├── harness_menupopup.qml             # 离屏/渲染测试台：遍历触发所有菜单项
└── harness_render.qml                # 视觉验证台：单独渲染菜单外观
```

## 依赖

- Plasma 6 / KF6（开发与验证环境为 Plasma 6.7.5）
- `plasma-workspace`：提供 `org.kde.plasma.private.sessions`、`org.kde.plasma.plasma5support`
- `python3`：读取「最近使用的程序」（仅用标准库）
- `glib2`：提供 `gio`（启动最近使用的程序，回落 `gtk-launch`）
- 可选：`kcmutils`（提供「关于此系统」KCM）、`systemsettings`
- 可选：`cmake` + `kiconthemes`（含开发头文件）+ `ninja` —— 编译图标选择器；
  缺失时安装仍然成功，只是配置页的图形化图标选择不可用
- 可选：`gettext`（仅修改翻译时需要；运行时不需要）
