// 测试台：离屏加载 MenuPopup，验证 QML 类型与绑定是否正确
//
// offscreen 平台上 console.log 不可靠，因此结果统一用 XMLHttpRequest
// 以 PUT 写进 tests/out_menupopup.txt，由外层脚本读取。
//
// 用法：QT_QPA_PLATFORM=offscreen qml6 tests/harness_menupopup.qml

import QtQuick
import "../package/contents/ui"

Window {
    id: harness
    width: 400
    height: 700
    visible: true

    property var report: []

    function note(line) {
        report.push(line);
    }

    function flush() {
        var xhr = new XMLHttpRequest();
        xhr.open("PUT", "file:///home/murasaki/murasaki/KDEGlobalMenu/tests/out_menupopup.txt");
        xhr.send(report.join("\n") + "\n");
    }

    // 假的 actions：只需要 MenuPopup 会调用到的方法，调用即记录
    QtObject {
        id: fakeActions
        property var recentItems: [
            { "id": "firefox.desktop", "name": "Firefox", "icon": "firefox", "url": "file:///usr/share/applications/firefox.desktop" },
            { "id": "org.kde.dolphin.desktop", "name": "Dolphin 文件管理器", "icon": "org.kde.dolphin", "url": "file:///usr/share/applications/org.kde.dolphin.desktop" }
        ]
        property bool recentLoaded: true
        property string recentError: ""

        function refreshRecent(limit) { harness.note("ACTION refreshRecent(" + limit + ")") }
        function about() { harness.note("ACTION about()") }
        function systemSettings() { harness.note("ACTION systemSettings()") }
        function suspend() { harness.note("ACTION suspend()") }
        function reboot() { harness.note("ACTION reboot()") }
        function shutdown() { harness.note("ACTION shutdown()") }
        function lock() { harness.note("ACTION lock()") }
        function logout() { harness.note("ACTION logout()") }
        function openRecent(url) { harness.note("ACTION openRecent(" + url + ")") }
    }

    MenuPopup {
        id: popup
        anchors.fill: parent
        actions: fakeActions
        recentLimit: 8
        onCloseRequested: harness.note("SIGNAL closeRequested()")

        Component.onCompleted: harness.note("LOADED MenuPopup ok")
    }

    // 事件循环心跳：确认 qml6 真的在跑
    property int ticks: 0
    Timer {
        interval: 100
        repeat: true
        running: true
        onTriggered: {
            harness.ticks++;
            if (harness.ticks === 3) {
                harness.note("HEARTBEAT ticks=" + harness.ticks + " (事件循环正常)");
                harness.probe();
            }
            if (harness.ticks >= 4) {
                harness.flush();
                Qt.quit();
            }
        }
    }

    // 逐项触发菜单项，验证分派与子视图切换
    function probe() {
        note("implicitWidth=" + popup.implicitWidth + " implicitHeight=" + popup.implicitHeight);
        note("entries=" + popup.mainMenu.entries.length + " separators=" + JSON.stringify(popup.mainMenu.separatorBefore));

        var entries = popup.mainMenu.entries;
        for (var i = 0; i < entries.length; i++) {
            var key = entries[i].key;
            note("TRIGGER " + key + " (" + popup.mainMenu.labelFor(key) + ")");
            popup.mainMenu.trigger(key);
            popup.currentView = 0;   // 复位，继续下一项
        }

        // 子视图单独验证
        popup.currentView = 1;
        note("recent view height=" + popup.implicitHeight);
        popup.currentView = 0;

        popup.prepareForOpen();
        note("after prepareForOpen: height=" + popup.implicitHeight + " view=" + popup.currentView);
        note("DONE 全部菜单项触发完毕");
    }
}
