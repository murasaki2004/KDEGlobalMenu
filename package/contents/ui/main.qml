// SPDX-License-Identifier: MPL-2.0
//
// KDEGlobalMenu 小部件 —— 主入口
//
// 折叠态：面板上只有一个图标，图标名来自配置（contents/config/main.xml 的 icon）。
// 展开态：点击图标弹出 macOS 风格的菜单（见 MenuPopup.qml）。
//
// 弹窗用 PlasmaCore.Dialog（AppletPopup 类型）承载：这是 Plasma 面板部件弹出
// 菜单的标准做法，能自动处理相对面板的定位、边缘翻转，以及"点到别处就收起"。

import QtQuick
import org.kde.plasma.plasmoid
import org.kde.plasma.core as PlasmaCore
import org.kde.kirigami as Kirigami

PlasmoidItem {
    id: root

    // 面板里只需要一个图标：
    // compactRepresentation 用于面板上的常态显示，fullRepresentation 用于
    // 部件进入"展开/全视图"时的显示。本部件不使用全视图（菜单走弹出层），
    // 因此全视图也给同一个图标，避免出现空白区域。
    compactRepresentation: panelIconComponent
    fullRepresentation: panelIconComponent

    // 弹窗是否展开（唯一状态源，弹窗 visible 绑定它）
    property bool menuOpen: false

    // 配置项：折叠态图标名
    readonly property string iconName: Plasmoid.configuration.icon

    // ------------------------------------------------------------------ 动作层
    // 所有系统动作与会话动作都封装在 Actions 里（原生优先、失败回落）
    Actions {
        id: actions
    }

    // ------------------------------------------------------------ 折叠态（图标）
    // 图标本体抽成独立组件，供 compact / full 两种表示共用
    Component {
        id: panelIconComponent

        PlasmaCore.ToolTipArea {
            id: compactRoot

            // 面板上的点击区域跟随图标大小
            implicitWidth: Kirigami.Units.iconSizes.smallMedium
            implicitHeight: Kirigami.Units.iconSizes.smallMedium

            // 悬停提示：展开时不再打扰
            mainText: i18nd("plasma_applet_org.murasaki.kdeglobalmenu", "KDEGlobalMenu")
            active: compactMouse.containsMouse && !root.menuOpen

            Kirigami.Icon {
                id: panelIcon
                anchors.fill: parent
                // 配置里的图标名；留空回落为 KDE 默认启动器图标
                source: root.iconName !== "" ? root.iconName : "start-here-kde"
                active: compactMouse.containsMouse
            }

            MouseArea {
                id: compactMouse
                anchors.fill: parent
                hoverEnabled: true
                cursorShape: Qt.PointingHandCursor
                onClicked: root.menuOpen = !root.menuOpen
            }
        }
    }

    // -------------------------------------------------------------- 展开态（菜单）
    PlasmaCore.Dialog {
        id: menuDialog

        // AppletPopup 类型：Plasma 会把它当作部件弹出层处理（定位 + 焦点 + 自动收起）
        type: PlasmaCore.Dialog.AppletPopup
        backgroundHints: PlasmaCore.Dialog.StandardBackground
        hideOnWindowDeactivate: true
        visible: root.menuOpen
        // 注意：compactRepresentation 是 QQmlComponent（组件定义），
        // 实例化后的对象是 compactRepresentationItem，弹窗定位需要后者
        visualParent: root.compactRepresentationItem
        location: Plasmoid.location

        mainItem: MenuPopup {
            id: menuPopup
            actions: actions
            recentLimit: Plasmoid.configuration.recentItemsLimit
            onCloseRequested: root.menuOpen = false
        }
    }

    // 每次展开时回到主视图并刷新最近项目
    onMenuOpenChanged: {
        if (menuOpen) {
            menuPopup.prepareForOpen();
        }
    }

    // 弹窗因点击别处而被 Plasma 收起时，同步回我们的状态
    Connections {
        target: menuDialog
        function onVisibleChanged() {
            if (!menuDialog.visible && root.menuOpen) {
                root.menuOpen = false;
            }
        }
    }



}
