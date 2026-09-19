// SPDX-License-Identifier: MPL-2.0
//
// KDEGlobalMenu 小部件 —— 弹出菜单里的一行
//
// 配色全部取自 Kirigami 主题（即 Plasma 主题），保证跟随系统配色方案、
// 深浅色自动切换，不硬编码颜色。

import QtQuick
import org.kde.kirigami as Kirigami

Item {
    id: row

    property string text: ""
    property string iconName: ""
    // 用 actionEnabled 而不是 enabled：后者是 QQuickItem 的既有属性，
    // 在 Qt6 里覆盖基类成员会导致该类型注册失败
    property bool actionEnabled: true
    // 子菜单指示：显示右侧小箭头
    property bool hasSubMenu: false
    // 键盘/鼠标高亮
    property bool highlighted: false

    signal activated()

    implicitHeight: Math.max(Kirigami.Units.gridUnit * 1.6, label.implicitHeight + Kirigami.Units.smallSpacing)
    implicitWidth: Math.max(label.implicitWidth + Kirigami.Units.gridUnit * 2.6, Kirigami.Units.gridUnit * 12)

    Rectangle {
        id: background
        anchors.fill: parent
        anchors.leftMargin: Kirigami.Units.smallSpacing
        anchors.rightMargin: Kirigami.Units.smallSpacing
        radius: Kirigami.Units.smallSpacing

        // 高亮色跟随系统主题强调色
        color: row.actionEnabled && row.highlighted
               ? Kirigami.Theme.highlightColor
               : "transparent"

        Behavior on color {
            ColorAnimation { duration: Kirigami.Units.shortDuration }
        }
    }

    Kirigami.Icon {
        id: icon
        anchors.left: parent.left
        anchors.leftMargin: Kirigami.Units.gridUnit * 0.7
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.small
        height: width
        source: row.iconName
        // 未启用时压暗，和 macOS 的置灰一致
        opacity: row.actionEnabled ? 1.0 : 0.4
        visible: row.iconName !== ""
    }

    Text {
        id: label
        anchors.left: icon.visible ? icon.right : parent.left
        anchors.leftMargin: icon.visible
                            ? Kirigami.Units.gridUnit * 0.7
                            : Kirigami.Units.gridUnit * 0.9
        anchors.right: subMenuArrow.visible ? subMenuArrow.left : parent.right
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.verticalCenter: parent.verticalCenter
        text: row.text
        elide: Text.ElideRight
        color: {
            if (!row.actionEnabled) {
                return Kirigami.Theme.disabledTextColor;
            }
            return row.highlighted
                   ? Kirigami.Theme.highlightedTextColor
                   : Kirigami.Theme.textColor;
        }
    }

    // 子菜单箭头：直接用主题自带的箭头图标，不手绘
    Kirigami.Icon {
        id: subMenuArrow
        anchors.right: parent.right
        anchors.rightMargin: Kirigami.Units.smallSpacing
        anchors.verticalCenter: parent.verticalCenter
        width: Kirigami.Units.iconSizes.smallMedium
        height: width
        source: "arrow-right"
        visible: row.hasSubMenu
        opacity: row.actionEnabled ? 1.0 : 0.4
    }

    MouseArea {
        id: mouseArea
        anchors.fill: parent
        hoverEnabled: true
        enabled: row.actionEnabled
        cursorShape: Qt.PointingHandCursor
        onEntered: row.highlighted = true
        onExited: row.highlighted = false
        onClicked: row.activated()
    }
}
