// SPDX-License-Identifier: MPL-2.0
//
// KDEGlobalMenu 小部件 —— 配置页入口
//
// 只有一个分类：外观与行为

import QtQuick
import org.kde.plasma.configuration as PlasmaConfig

PlasmaConfig.ConfigModel {
    PlasmaConfig.ConfigCategory {
        name: i18ndc("plasma_applet_org.murasaki.kdeglobalmenu", "Name of the configuration category", "Appearance")
        icon: "preferences-desktop-icons"
        source: "config_general.qml"
    }
}
