// SPDX-License-Identifier: MPL-2.0
//
// KDEGlobalMenu 小部件 —— 配置页
//
// 图标选择直接调用 KDE 自己的图标选择对话框（KIconDialog），也就是 Kate、Dolphin
// 等 KDE 应用"选择图标"时弹出的同一个对话框：分类浏览、搜索、用户图标目录、
// 主题跟随全部由 KDE 提供，本部件不重复实现。
//
// 之所以经由一个独立可执行文件：KIconDialog 是 QWidget 对话框，而配置页运行在
// plasmashell 进程里（QGuiApplication + QML），不能内嵌 QWidget。这与 KDE 应用
// 的做法一致——对话框放独立进程，选中结果用 stdout 回传。
//
// 注意：配置对话框里的值由 KCM 框架通过 cfg_ 前缀属性读写，
// 属性名必须与 contents/config/main.xml 的 entry 名完全一致。

import QtQuick
import QtQuick.Controls as Controls
import QtQuick.Layouts
import org.kde.kirigami as Kirigami
import org.kde.kcmutils as KCM
import org.kde.plasma.plasma5support as Plasma5Support

KCM.SimpleKCM {
    id: page

    // 配置绑定（名字须与 main.xml 的 entry 一致）
    property alias cfg_icon: page.selectedIcon
    property int cfg_recentItemsLimit: 8

    // 默认图标：与 main.xml 的 default 保持一致
    readonly property string defaultIcon: "start-here-kde"

    // 当前选中的图标（即写回配置的值）
    property string selectedIcon: defaultIcon

    // 图标选择器可执行文件的位置：包内 contents/bin/ 下
    // （由 install.sh 用 tools/iconchooser 编译后放进去）
    readonly property string chooserPath: {
        var uiUrl = Qt.resolvedUrl(".").toString();          // file:///.../contents/ui/
        var contentsUrl = uiUrl.replace(/\/ui\/$/, "");      // file:///.../contents
        return decodeURIComponent(contentsUrl.replace(/^file:\/\//, "")) + "/bin/kdeglobalmenu-iconchooser";
    }

    readonly property bool chooserAvailable: chooserProbe.checked
    property bool chooserMissing: false

    // 探测助手是否存在，缺失时给出明确提示而不是静默失败
    Plasma5Support.DataSource {
        id: chooserProbe
        engine: "executable"
        connectedSources: ["test -x '" + page.chooserPath + "' && echo yes || echo no"]
        property bool checked: false
        property bool found: false
        onNewData: function (sourceName, data) {
            chooserProbe.found = (data["stdout"] || "").trim() === "yes";
            chooserProbe.checked = true;
        }
    }

    // 运行图标选择对话框。这是一个会阻塞的模态对话框，因此用异步 DataSource：
    // 对话框关闭前不返回。stdout 第一行是当前图标，若有第二行则是用户新选的图标。
    Plasma5Support.DataSource {
        id: chooser
        engine: "executable"
        connectedSources: []

        onNewData: function (sourceName, data) {
            chooser.disconnectSource(sourceName);
            var stdout = (data["stdout"] || "").trim();
            if (stdout === "") {
                console.warn("KDEGlobalMenu 配置页: 图标选择器没有输出，"
                             + "stderr=" + (data["stderr"] || ""));
                return;
            }
            var lines = stdout.split("\n");
            // 只有一行 = 用户取消了（或没改），保持原值不动
            if (lines.length < 2) {
                return;
            }
            var chosen = lines[lines.length - 1].trim();
            if (chosen !== "") {
                page.selectedIcon = chosen;
            }
        }
    }

    function openIconChooser() {
        chooser.connectSource("'" + page.chooserPath + "' '" + page.selectedIcon + "'");
    }

    Kirigami.FormLayout {
        anchors.left: parent.left
        anchors.right: parent.right

        // ------------------------------------------------------- 当前图标预览
        Item {
            Kirigami.FormData.label: i18nd("plasma_applet_org.murasaki.kdeglobalmenu", "Current icon:")

            implicitWidth: previewRow.implicitWidth
            implicitHeight: previewRow.implicitHeight

            RowLayout {
                id: previewRow
                anchors.fill: parent
                spacing: Kirigami.Units.largeSpacing

                Kirigami.Icon {
                    Layout.preferredWidth: Kirigami.Units.iconSizes.huge
                    Layout.preferredHeight: Kirigami.Units.iconSizes.huge
                    source: page.selectedIcon !== "" ? page.selectedIcon : page.defaultIcon
                }

                ColumnLayout {
                    Layout.fillWidth: true
                    spacing: Kirigami.Units.smallSpacing

                    Controls.Label {
                        text: page.selectedIcon !== "" ? page.selectedIcon : page.defaultIcon
                        font.bold: true
                        elide: Text.ElideRight
                        Layout.fillWidth: true
                    }

                    Controls.Label {
                        visible: page.chooserMissing
                        text: i18nd("plasma_applet_org.murasaki.kdeglobalmenu",
                                    "Icon chooser not found — run install.sh to build it")
                        color: Kirigami.Theme.negativeTextColor
                        font: Kirigami.Theme.smallFont
                        wrapMode: Text.WordWrap
                        Layout.fillWidth: true
                    }
                }
            }
        }

        // ------------------------------------------------- 打开 KDE 图标选择器
        Controls.Button {
            Kirigami.FormData.label: i18nd("plasma_applet_org.murasaki.kdeglobalmenu", "Choose icon:")

            text: i18nd("plasma_applet_org.murasaki.kdeglobalmenu", "Browse Icons…")
            icon.name: "preferences-desktop-icons"
            enabled: page.chooserAvailable
            onClicked: page.openIconChooser()
        }

        Controls.Label {
            text: i18nd("plasma_applet_org.murasaki.kdeglobalmenu",
                        "Opens KDE's own icon picker dialog as used by Kate and Dolphin.")
            font: Kirigami.Theme.smallFont
            opacity: 0.7
            wrapMode: Text.WordWrap
            Layout.maximumWidth: Kirigami.Units.gridUnit * 22
        }

        Controls.Button {
            text: i18ndc("plasma_applet_org.murasaki.kdeglobalmenu",
                         "Reset the icon back to its default value", "Reset")
            icon.name: "edit-undo"
            onClicked: page.selectedIcon = page.defaultIcon
        }

        // --------------------------------------------------- 手动输入图标名
        Controls.TextField {
            id: manualField
            Kirigami.FormData.label: i18nd("plasma_applet_org.murasaki.kdeglobalmenu", "Or enter an icon name:")

            text: page.selectedIcon
            placeholderText: page.defaultIcon
            Layout.fillWidth: true
            onTextEdited: page.selectedIcon = text
        }

        // ----------------------------------------------------- 最近项目条目数
        Controls.SpinBox {
            Kirigami.FormData.label: i18nd("plasma_applet_org.murasaki.kdeglobalmenu", "Recent items shown:")

            from: 1
            to: 30
            value: page.cfg_recentItemsLimit
            onValueModified: page.cfg_recentItemsLimit = value
        }
    }

    // 探测失败（助手不存在）时给出提示
    Connections {
        target: chooserProbe
        function onFoundChanged() {
            page.chooserMissing = chooserProbe.checked && !chooserProbe.found;
        }
    }
}
