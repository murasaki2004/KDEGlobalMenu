// SPDX-License-Identifier: MPL-2.0
//
// KDEGlobalMenu 小部件 —— 图标选择器
//
// 直接调用 KDE 自己的图标选择对话框 KIconDialog（由 kiconthemes 提供，
// 也就是 Kate / Dolphin 等 KDE 应用"选择图标"时用的同一个对话框）。
//
// 为什么需要一个独立可执行文件：
//   KIconDialog 是 KWidgetsAddons 里的 QWidget 对话框，而小部件的配置页运行在
//   plasmashell 进程里（QGuiApplication + QML），不能把 QWidget 塞进去。
//   因此按 KDE 一贯做法，把对话框放在独立进程里，选中结果用 stdout 回传。
//
// 用法：kdeglobalmenu-iconchooser [当前图标名]
// 输出：第一行是当前图标名（供调用方判断是否变化），用户确认后再输出选中的图标名。
//       用户取消则只有第一行。两个名字相同即表示没有改动。

#include <QApplication>
#include <QString>
#include <QStringList>
#include <cstdio>

#include <KIconDialog>
#include <KIconLoader>
#include <KLocalizedString>

int main(int argc, char **argv)
{
    QApplication app(argc, argv);
    // 让 KIconDialog 内部的按钮等使用 KDE 自己的翻译
    KLocalizedString::setApplicationDomain("plasma_applet_org.murasaki.kdeglobalmenu");

    const QString current = argc > 1 ? QString::fromUtf8(argv[1]) : QString();

    // 先把"当前值"打出去。用户取消时就没有后续输出，调用方据此保持原值。
    printf("%s\n", qUtf8Printable(current));
    fflush(stdout);

    // 面板图标属于 Desktop 组；context 用 Application 覆盖常用类别。
    KIconDialog dialog;
    dialog.setup(KIconLoader::Desktop, KIconLoader::Application,
                 false /* strictIconSize */, 48 /* iconSize */,
                 false /* user */, false /* lockUser */, false /* lockCustomDir */);
    // 打开时定位到当前图标
    if (!current.isEmpty()) {
        dialog.setSelectedIcon(current);
    }

    const QString chosen = dialog.openDialog();
    if (!chosen.isEmpty()) {
        printf("%s\n", qUtf8Printable(chosen));
    }
    return 0;
}
