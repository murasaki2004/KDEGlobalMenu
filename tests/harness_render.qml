// 视觉验证台：在真实 Plasma 会话里渲染 MenuPopup，用于截图确认外观
//
// 需要会话环境（WAYLAND_DISPLAY / XDG_RUNTIME_DIR / DBUS_SESSION_BUS_ADDRESS）：
//   wayland_env=... qml6 tests/harness_render.qml
//
// 注意：这是测试脚手架，不参与小部件运行。

import QtQuick
import QtQuick.Controls as Controls
import org.kde.kirigami as Kirigami
import "../package/contents/ui"

Controls.ApplicationWindow {
    id: harness
    width: 520
    height: 720
    visible: true
    title: "KDEGlobalMenu — 渲染验证"

    // 用 Plasma 主题背景，贴近真实弹窗观感
    color: Kirigami.Theme.backgroundColor

    // 假的 actions：把调用打到窗口标题上，便于截图确认分派
    QtObject {
        id: fakeActions
        property var recentItems: [
            { "id": "Clash Verge.desktop", "name": "Clash Verge", "icon": "clash-verge", "url": "file:///usr/share/applications/Clash Verge.desktop" },
            { "id": "org.kde.dolphin.desktop", "name": "Dolphin 文件管理器", "icon": "org.kde.dolphin", "url": "file:///usr/share/applications/org.kde.dolphin.desktop" },
            { "id": "firefox.desktop", "name": "Firefox", "icon": "firefox", "url": "file:///usr/share/applications/firefox.desktop" },
            { "id": "zcode.desktop", "name": "ZCode", "icon": "zcode", "url": "file:///home/murasaki/.local/share/applications/zcode.desktop" },
            { "id": "steam.desktop", "name": "Steam", "icon": "steam", "url": "file:///usr/share/applications/steam.desktop" }
        ]
        property bool recentLoaded: true
        property string recentError: ""

        function refreshRecent(limit) { console.log("refreshRecent", limit) }
        function about() { console.log("about") }
        function systemSettings() { console.log("systemSettings") }
        function suspend() { console.log("suspend") }
        function reboot() { console.log("reboot") }
        function shutdown() { console.log("shutdown") }
        function lock() { console.log("lock") }
        function logout() { console.log("logout") }
        function openRecent(url) { console.log("openRecent", url) }
    }

    // 真实弹窗底色：Plasma 的对话框背景
    Rectangle {
        id: frame
        anchors.centerIn: parent
        width: menuPopup.implicitWidth + Kirigami.Units.gridUnit
        height: menuPopup.implicitHeight + Kirigami.Units.gridUnit
        radius: Kirigami.Units.cornerRadius
        color: Kirigami.Theme.alternateBackgroundColor
        border.width: 1
        border.color: Qt.rgba(0, 0, 0, 0.25)

        MenuPopup {
            id: menuPopup
            anchors.centerIn: parent
            actions: fakeActions
            recentLimit: 8
        }
    }

    // 视图指示：截图时确认当前处于主菜单还是最近项目
    Controls.Label {
        anchors.top: parent.top
        anchors.horizontalCenter: parent.horizontalCenter
        anchors.topMargin: Kirigami.Units.gridUnit
        text: "currentView = " + menuPopup.currentView
              + "   |   height = " + menuPopup.implicitHeight
        font.bold: true
    }

    // 默认展示主菜单；通过命令行传 --recent 可切到子视图
    Component.onCompleted: {
        var wantRecent = Qt.application.arguments.indexOf("--recent") !== -1;
        menuPopup.prepareForOpen();
        if (wantRecent) {
            menuPopup.currentView = 1;
        }
    }
}
