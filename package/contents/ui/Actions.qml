// SPDX-License-Identifier: MPL-2.0
//
// KDEGlobalMenu 小部件 —— 会话与系统动作封装
//
// 设计原则：能用 KDE 原生就绝不自造。动作全部按「原生优先、失败回落」编排：
//   1) org.kde.plasma.private.sessions 的 SessionManagement —— Plasma 自己的
//      会话管理器，会遵循系统设置里的「关机/注销是否需要确认」等策略；
//   2) 回落：D-Bus 上的 org.kde.Shutdown / org.freedesktop.ScreenSaver /
//      org.freedesktop.login1（关机走 Systemd 后端），或 xdg-open 打开 KCM。
// 这样即使私有插件将来改名/缺失，功能也不会失效。
//
// 缩进与命名遵循工程既有风格。

import QtQuick
import org.kde.plasma.plasma5support as Plasma5Support
import org.kde.plasma.private.sessions as Sessions

QtObject {
    id: actions

    // ---------------------------------------------------------------- 最近程序
    // 最近使用的程序优先用 KDE 自己的 KActivities 数据库，
    // 由 kdeglobalmenu-helper.py 读取（见 contents/tools/）。
    property var recentItems: []
    property bool recentLoaded: false
    property string recentError: ""

    function refreshRecent(limit) {
        // 注意要带上助手脚本的绝对路径；路径可能含空格，因此加引号
        helper.connectSource("'" + helperPath + "' recent " + Math.max(1, limit || 8));
    }

    // ------------------------------------------------------------ 原生动作后端
    // SessionManagement 不可用时置空，全部动作自动走 D-Bus 回落分支。
    // 这里用 Loader 动态加载：私有插件万一改名或缺失，也只是 session 为 null，
    // 而不是整个部件加载失败。
    readonly property var session: sessionLoader.item

    property Loader sessionLoader: Loader {
        id: sessionLoader
        sourceComponent: Component {
            Sessions.SessionManagement {}
        }
    }

    // 统一的命令执行：用 Plasma5Support 的 executable 引擎（KDE 原生），
    // 所有需要外部命令的动作都经这里，便于集中处理输出
    property Plasma5Support.DataSource helper: Plasma5Support.DataSource {
        id: helper
        engine: "executable"
        connectedSources: []
        onNewData: function (sourceName, data) {
            helper.disconnectSource(sourceName);
            var stdout = (data["stdout"] || "").trim();
            var stderr = (data["stderr"] || "").trim();

            // sourceName 是实际执行的命令串（含脚本绝对路径），因此只做包含判断
            var isRecent = sourceName.indexOf(" recent ") !== -1;
            if (!stdout) {
                console.warn("KDEGlobalMenu: 助手无输出。command=[" + sourceName + "] stderr=" + stderr);
                if (isRecent) {
                    actions.recentLoaded = true;
                    actions.recentError = "no output: " + stderr;
                }
                return;
            }
            var parsed;
            try {
                parsed = JSON.parse(stdout);
            } catch (e) {
                console.warn("KDEGlobalMenu: 解析助手输出失败:", e, stdout);
                if (isRecent) {
                    actions.recentLoaded = true;
                    actions.recentError = "bad json";
                }
                return;
            }
            if (isRecent) {
                actions.recentLoaded = true;
                if (parsed.ok) {
                    actions.recentItems = parsed.items;
                    actions.recentError = "";
                } else {
                    actions.recentItems = [];
                    actions.recentError = parsed.error || "unknown";
                }
            }
        }
    }

    // 助手脚本的绝对路径。
    // 小部件实例在 Plasma 里拿不到 Plasmoid.filePath（该属性不存在），
    // 因此直接由本文件自身的 URL 推导：本文件位于 <包>/contents/ui/ 下，
    // 助手脚本在 <包>/contents/tools/ 下。
    // 注意必须是文件系统路径（shell 用），不能带 file:// 前缀。
    readonly property string helperPath: {
        var selfUrl = Qt.resolvedUrl(".").toString();      // file:///.../contents/ui/
        var contentsUrl = selfUrl.replace(/\/ui\/$/, "");  // file:///.../contents
        return decodeURIComponent(contentsUrl.replace(/^file:\/\//, "")) + "/tools/kdeglobalmenu-helper.py";
    }

    // ---------------------------------------------------------------- 关于本机
    // KDE 原生「关于此系统」KCM
    function about() {
        run("kcmshell6 kcm_about-distro");
    }

    // ---------------------------------------------------------------- 系统设置
    function systemSettings() {
        run("systemsettings");
    }

    // ------------------------------------------------------------ 最近使用的项目
    function openRecent(url) {
        if (!url) {
            return;
        }
        // 交由系统默认方式启动（KDE 原生关联）
        Qt.openUrlExternally(url);
    }

    // -------------------------------------------------------------------- 睡眠
    function suspend() {
        if (session && typeof session.suspend === "function") {
            session.suspend();
        } else {
            // logind 原生：Sleep 会按 /etc/systemd/sleep.conf 的 Allow* 自动选择
            // suspend / hibernate / suspend-then-hibernate
            run("dbus-send --system --print-reply --dest=org.freedesktop.login1 " +
                "/org/freedesktop/login1 org.freedesktop.login1.Manager.Suspend boolean:true");
        }
    }

    // ------------------------------------------------------------------ 重新启动
    function reboot() {
        if (session && typeof session.requestReboot === "function") {
            // 0 = ConfirmationMode.Default：遵循系统设置里的"是否需要确认"策略
            session.requestReboot(0);
        } else {
            logoutAndReboot();
        }
    }

    // -------------------------------------------------------------------- 关机
    function shutdown() {
        if (session && typeof session.requestShutdown === "function") {
            // 0 = ConfirmationMode.Default：遵循系统设置里的"是否需要确认"策略
            session.requestShutdown(0);
        } else {
            logoutAndShutdown();
        }
    }

    // ---------------------------------------------------------------- 锁定屏幕
    function lock() {
        if (session && typeof session.lock === "function") {
            session.lock();
        } else {
            // KDE 屏保原生接口
            run("dbus-send --session --print-reply --dest=org.kde.screensaver " +
                "/ScreenSaver org.freedesktop.ScreenSaver.Lock");
        }
    }

    // ---------------------------------------------------------------- 退出登录
    function logout() {
        if (session && typeof session.requestLogout === "function") {
            // 走 Plasma 原生注销流程：会弹确认框并保存会话
            // 0 = ConfirmationMode.Default：遵循系统设置里的"是否需要确认"策略
            session.requestLogout(0);
        } else {
            // org.kde.Shutdown 是 Plasma 6 的原生注销服务，同样会触发确认对话框
            run("dbus-send --session --print-reply --dest=org.kde.Shutdown " +
                "/Shutdown org.kde.Shutdown.logout");
        }
    }

    // 关掉 Plasma 自己之后再关机/重启：交给 org.kde.Shutdown 原生服务
    function logoutAndReboot() {
        run("dbus-send --session --print-reply --dest=org.kde.Shutdown " +
            "/Shutdown org.kde.Shutdown.logoutAndReboot");
    }

    function logoutAndShutdown() {
        run("dbus-send --session --print-reply --dest=org.kde.Shutdown " +
            "/Shutdown org.kde.Shutdown.logoutAndShutdown");
    }

    // --------------------------------------------------------------------- 工具
    function run(command) {
        if (!command) {
            return;
        }
        helper.connectSource(command);
    }

    // 折叠态图标缺失时的兜底：记录一次，方便排查主题问题
    function warnMissingIcon(name) {
        console.warn("KDEGlobalMenu: 图标未找到:", name);
    }
}
