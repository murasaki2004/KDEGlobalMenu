// SPDX-License-Identifier: MPL-2.0
//
// KDEGlobalMenu 小部件 —— 展开后的菜单内容
//
// 菜单结构（macOS KDEGlobalMenu顺序，已按需求去掉 App Store / 强制退出）：
//   关于本机 / 系统设置 ｜ 最近使用的项目 ｜ 睡眠 / 重新启动 / 关机 / 锁定屏幕 / 退出登录
//
// 宽度走固定值：既避免 "行宽依赖菜单宽、菜单宽又依赖行宽" 的循环绑定，
// 也让菜单在切换「最近使用的项目」子视图时不会跳动。

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: root

    // 由 main.qml 注入
    property var actions: null
    property int recentLimit: 8

    // 菜单请求收起（点击动作项或按 Esc）
    signal closeRequested()

    // 固定菜单宽度：约 17 个 gridUnit（默认字体下 ~260px，接近 macOS 观感）
    readonly property int menuWidth: Kirigami.Units.gridUnit * 17

    // 当前鼠标悬停的菜单项，用于高亮。用 key 标识，避免行重建后错位
    property string hoveredKey: ""

    // 当前视图：0 = 主菜单，1 = 最近使用的项目
    property int currentView: 0

    implicitWidth: menuWidth
    // 高度跟随当前视图。不用 StackLayout：它在自动尺寸上下文里算不出隐式高度，
    // 会让弹窗被判为"空对话框"而不显示。
    implicitHeight: currentView === 0 ? mainMenu.implicitHeight : recentPage.implicitHeight

    // 供测试与外部检查使用
    readonly property alias mainMenu: mainMenu
    readonly property alias recentPage: recentPage

    // 供 main.qml 在每次打开时调用，回到主视图并刷新最近项目
    function prepareForOpen() {
        currentView = 0;
        hoveredKey = "";
        if (actions) {
            actions.refreshRecent(recentLimit);
        }
    }

    // 统一的收起入口
    function requestClose() {
        closeRequested();
    }

    // -------------------------------------------------------------- 主菜单
    Column {
        id: mainMenu
        width: root.menuWidth
        visible: root.currentView === 0
        topPadding: Kirigami.Units.smallSpacing
        bottomPadding: Kirigami.Units.smallSpacing

        // key / 图标 / 是否为子菜单入口
        readonly property var entries: [
            { "key": "about",    "icon": "help-about" },
            { "key": "settings", "icon": "systemsettings" },
            { "key": "recent",   "icon": "document-open-recent", "sub": true },
            { "key": "suspend",  "icon": "system-suspend" },
            { "key": "reboot",   "icon": "system-reboot" },
            { "key": "shutdown", "icon": "system-shutdown" },
            { "key": "lock",     "icon": "system-lock-screen" },
            { "key": "logout",   "icon": "system-log-out" }
        ]

        // 这些下标之前插入分组分隔线（对应 macOS 的功能分组）
        readonly property var separatorBefore: [2, 3]

        function labelFor(key) {
            switch (key) {
            case "about":    return i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Open the KDE About System information page", "About This Computer");
            case "settings": return i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Open the KDE system settings application", "System Settings");
            case "recent":   return i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Submenu listing recently used applications", "Recent Items");
            case "suspend":  return i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Power action: put the computer to sleep (suspend)", "Sleep");
            case "reboot":   return i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Power action: reboot the computer", "Restart");
            case "shutdown": return i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Power action: power off the computer", "Shut Down");
            case "lock":     return i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Power action: lock the screen immediately", "Lock Screen");
            case "logout":   return i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Power action: end the current session", "Log Out");
            }
            return key;
        }

        function trigger(key) {
            switch (key) {
            case "about":    actions.about(); break;
            case "settings": actions.systemSettings(); break;
            case "recent":
                // 子菜单入口：只切换视图，不收起菜单
                root.currentView = 1;
                return;
            case "suspend":  actions.suspend(); break;
            case "reboot":   actions.reboot(); break;
            case "shutdown": actions.shutdown(); break;
            case "lock":     actions.lock(); break;
            case "logout":   actions.logout(); break;
            }
            // 其余都是会立刻改变系统状态的动作，触发后收起菜单
            root.requestClose();
        }

        Repeater {
            model: mainMenu.entries

            // 每项 = 可选分隔线 + 菜单行
            delegate: Column {
                id: entryColumn
                required property var modelData
                required property int index

                width: mainMenu.width

                Rectangle {
                    width: parent.width - Kirigami.Units.gridUnit
                    anchors.horizontalCenter: parent.horizontalCenter
                    height: 1
                    visible: mainMenu.separatorBefore.indexOf(entryColumn.index) !== -1
                    color: Kirigami.Theme.disabledTextColor
                    opacity: 0.35
                }

                MenuRow {
                    width: entryColumn.width
                    text: mainMenu.labelFor(entryColumn.modelData.key)
                    iconName: entryColumn.modelData.icon
                    hasSubMenu: entryColumn.modelData.sub === true
                    highlighted: root.hoveredKey === entryColumn.modelData.key
                    onActivated: mainMenu.trigger(entryColumn.modelData.key)
                    onHighlightedChanged: {
                        if (highlighted) {
                            root.hoveredKey = entryColumn.modelData.key;
                        } else if (root.hoveredKey === entryColumn.modelData.key) {
                            root.hoveredKey = "";
                        }
                    }
                }
            }
        }
    }

    // ------------------------------------------------ 最近使用的项目子视图
    Column {
        id: recentPage
        width: root.menuWidth
        visible: root.currentView === 1
        topPadding: Kirigami.Units.smallSpacing
        bottomPadding: Kirigami.Units.smallSpacing

        MenuRow {
            width: parent.width
            text: i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Go back from the Recent Items submenu to the main menu", "Back")
            iconName: "go-previous"
            highlighted: root.hoveredKey === "__back"
            onActivated: {
                root.currentView = 0;
                root.hoveredKey = "";
            }
            onHighlightedChanged: {
                if (highlighted) {
                    root.hoveredKey = "__back";
                }
            }
        }

        Rectangle {
            width: parent.width - Kirigami.Units.gridUnit
            anchors.horizontalCenter: parent.horizontalCenter
            height: 1
            color: Kirigami.Theme.disabledTextColor
            opacity: 0.35
        }

        // 条目可能较多，限制高度并可滚动
        Flickable {
            id: recentFlick
            width: parent.width
            height: Math.min(recentColumn.implicitHeight, Kirigami.Units.gridUnit * 20)
            contentWidth: width
            contentHeight: recentColumn.implicitHeight
            clip: true
            boundsBehavior: Flickable.StopAtBounds

            Column {
                id: recentColumn
                width: recentFlick.width

                // 空状态：加载中 / 无记录 / 出错，都给明确文案
                Text {
                    width: parent.width
                    visible: !root.actions || root.actions.recentItems.length === 0
                    text: {
                        if (!root.actions) {
                            return "";
                        }
                        if (root.actions.recentError !== "") {
                            return i18nd("plasma_applet_org.murasaki.kdeglobalmenu", "Recent items unavailable");
                        }
                        return root.actions.recentLoaded
                               ? i18nd("plasma_applet_org.murasaki.kdeglobalmenu", "No recent applications")
                               : i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Placeholder while the recent items list is being read", "Loading…");
                    }
                    color: Kirigami.Theme.disabledTextColor
                    horizontalAlignment: Text.AlignHCenter
                    topPadding: Kirigami.Units.gridUnit
                    bottomPadding: Kirigami.Units.gridUnit
                }

                Repeater {
                    model: root.actions ? root.actions.recentItems : []

                    delegate: MenuRow {
                        id: recentRow
                        required property var modelData
                        required property int index

                        width: recentFlick.width
                        text: recentRow.modelData.name
                        iconName: recentRow.modelData.icon
                        actionEnabled: recentRow.modelData.url !== ""
                                       || recentRow.modelData.id !== ""
                        highlighted: root.hoveredKey === ("recent:" + recentRow.index)
                        onActivated: {
                            actions.openRecent(recentRow.modelData.url, recentRow.modelData.id);
                            root.requestClose();
                        }
                        onHighlightedChanged: {
                            if (highlighted) {
                                root.hoveredKey = "recent:" + recentRow.index;
                            }
                        }
                    }
                }
            }
        }
    }
}
