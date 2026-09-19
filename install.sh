#!/usr/bin/env bash
# SPDX-License-Identifier: MPL-2.0
#
# KDEGlobalMenu 小部件 —— 安装 / 升级 / 卸载
#
# 用法：
#   ./install.sh            安装（已安装则自动升级）
#   ./install.sh --uninstall  卸载
#   ./install.sh --panel      安装后把部件加到面板最左侧（macOS 菜单位置）
#
# 说明：
#   * 安装到用户级目录 ~/.local/share/plasma/plasmoids/，无需 root。
#   * kpackagetool6 不会保留可执行位，因此安装后需为助手脚本补 chmod +x。
#   * --panel 会通过 Plasma 的脚本接口把部件加进面板；这一步会先清空
#     该面板的对齐设置，使部件落在最左侧（Plasma 没有"插入到指定位置"的
#     公开接口，这是可靠的做法）。

set -euo pipefail

PLUGIN_ID="org.murasaki.kdeglobalmenu"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PACKAGE_DIR="$SCRIPT_DIR/package"
INSTALL_DIR="$HOME/.local/share/plasma/plasmoids/$PLUGIN_ID"
HELPER="$INSTALL_DIR/contents/tools/kdeglobalmenu-helper.py"

die() { echo "错误：$*" >&2; exit 1; }

command -v kpackagetool6 >/dev/null 2>&1 \
    || die "找不到 kpackagetool6，请先安装 plasma-workspace / kpackage。"

# ------------------------------------------------------------------ 卸载
if [[ "${1:-}" == "--uninstall" ]]; then
    if [[ -d "$INSTALL_DIR" ]]; then
        kpackagetool6 --type Plasma/Applet --remove "$PLUGIN_ID"
        echo "已卸载 $PLUGIN_ID"
    else
        echo "$PLUGIN_ID 未安装，无需卸载"
    fi

    # 一并清掉安装时放进用户级 locale 目录的翻译
    removed=0
    for mo in "$HOME"/.local/share/locale/*/LC_MESSAGES/"$PLUGIN_ID".mo; do
        [[ -f "$mo" ]] || continue
        rm -f "$mo"
        removed=$((removed + 1))
    done
    [[ $removed -gt 0 ]] && echo "已清理 $removed 份翻译文件"

    echo "提示：若已把它加到面板，请右键面板 → 编辑面板，手动移除残留的图标。"
    exit 0
fi

# ------------------------------------------------------------------ 安装
[[ -f "$PACKAGE_DIR/metadata.json" ]] || die "找不到 $PACKAGE_DIR/metadata.json"

if [[ -d "$INSTALL_DIR" ]]; then
    echo "检测到已安装，执行升级…"
    kpackagetool6 --type Plasma/Applet --upgrade "$PACKAGE_DIR"
else
    echo "安装到 $INSTALL_DIR …"
    kpackagetool6 --type Plasma/Applet --install "$PACKAGE_DIR"
fi

# kpackagetool6 复制后不保留可执行位，这里补上，否则「最近使用的项目」无法读取
chmod +x "$HELPER"
echo "已就绪：$HELPER"

# -------------------------------------------------- 图标选择器（KIconDialog 助手）
# 配置页的「浏览图标…」调用 KDE 原生的图标选择对话框；因为它是 QWidget 对话框、
# 不能塞进 plasmashell 的 QML 进程，所以编译成独立可执行文件放进包内 contents/bin/。
# 若构建环境不全（缺 cmake / kiconthemes 开发包），只跳过图标对话框，
# 其余功能（含手动输入图标名）不受影响。
build_icon_chooser() {
    local src_dir="$SCRIPT_DIR/tools/iconchooser"
    local prebuilt="$src_dir/build/kdeglobalmenu-iconchooser"
    local dest_dir="$INSTALL_DIR/contents/bin"

    [[ -d "$src_dir" ]] || {
        echo "提示：未找到 tools/iconchooser，跳过图标对话框。"
        return 0
    }

    # 源码比已有二进制新时重新编译
    if [[ -x "$prebuilt" && "$src_dir/main.cpp" -ot "$prebuilt" ]]; then
        echo "复用已编译的图标选择器。"
    else
        if ! command -v cmake >/dev/null 2>&1; then
            echo "提示：未安装 cmake，跳过图标对话框（可手动输入图标名）。"
            echo "      需要时安装：sudo pacman -S cmake kiconthemes"
            return 0
        fi
        echo "编译图标选择器…"
        local generator=()
        command -v ninja >/dev/null 2>&1 && generator=(-G Ninja)
        if ! cmake -S "$src_dir" -B "$src_dir/build" "${generator[@]}" \
                   -DCMAKE_BUILD_TYPE=Release >/dev/null 2>&1 \
           || ! cmake --build "$src_dir/build" >/dev/null 2>&1; then
            echo "提示：图标选择器编译失败（可能缺 kiconthemes 开发包），"
            echo "      跳过图标对话框；仍可在配置里手动输入图标名。"
            echo "      需要时安装：sudo pacman -S cmake ninja kiconthemes"
            return 0
        fi
    fi

    mkdir -p "$dest_dir"
    cp "$prebuilt" "$dest_dir/kdeglobalmenu-iconchooser"
    chmod +x "$dest_dir/kdeglobalmenu-iconchooser"
    echo "图标选择器已就绪：$dest_dir/kdeglobalmenu-iconchooser"
}
build_icon_chooser

# ------------------------------------------------------------ 安装翻译（i18n）
# 部件用 i18nd() 查自己的翻译域；KDE 会按系统语言在 XDG 数据目录里找
# <locale>/LC_MESSAGES/<domain>.mo。这里把随包分发的预编译 .mo 放到用户级
# locale 目录（~/.local/share/locale），不需要 root。
# 显示哪种语言完全由系统设置决定：中文环境显示中文，其它环境回落到英文原文。
DOMAIN="plasma_applet_org.murasaki.kdeglobalmenu"
install_translations() {
    local src_root="$PACKAGE_DIR/locale"
    [[ -d "$src_root" ]] || return 0
    local count=0 mo lang dest_dir
    for mo in "$src_root"/*/LC_MESSAGES/*.mo; do
        [[ -f "$mo" ]] || continue
        lang="$(basename "$(dirname "$(dirname "$mo")")")"
        dest_dir="$HOME/.local/share/locale/$lang/LC_MESSAGES"
        mkdir -p "$dest_dir"
        cp "$mo" "$dest_dir/$DOMAIN.mo"
        count=$((count + 1))
    done
    echo "已安装 $count 份翻译到 ~/.local/share/locale/"
}
install_translations

# 让 plasmashell 重新加载部件。
# 注意：这里不能加 `if pgrep -x plasmashell` 守卫——若 plasmashell 恰好没在运行，
# 守卫会让脚本直接跳过，安装完面板是黑的（实测踩过）。所以无论它是否在运行，
# 最后都要把它拉起来；--replace 对"已有实例"和"全新启动"两种情况都适用。
if pgrep -x plasmashell >/dev/null 2>&1; then
    echo "重启 plasmashell 以加载新部件…"
    if command -v kquitapp6 >/dev/null 2>&1; then
        kquitapp6 plasmashell >/dev/null 2>&1 || true
        # 等它真正退出，避免新旧实例互相抢占
        for _ in $(seq 1 20); do
            pgrep -x plasmashell >/dev/null 2>&1 || break
            sleep 0.5
        done
    fi
else
    echo "启动 plasmashell 以加载新部件…"
fi
setsid plasmashell --replace >/dev/null 2>&1 &
sleep 2

# 确认真的起来了，避免静默失败
if pgrep -x plasmashell >/dev/null 2>&1; then
    echo "plasmashell 已就绪。"
else
    echo "警告：plasmashell 似乎没有启动，请手动执行：plasmashell --replace &" >&2
fi

echo
echo "安装完成。接下来："
echo "  1) 右键面板 → 编辑面板 → 添加部件 → 搜索「KDEGlobalMenu」"
echo "  2) 或直接运行：$0 --panel  （自动加到面板最左侧）"
echo "  3) 图标可在部件设置里更换（配置页内置系统图标选择器）"
echo "  4) 界面语言跟随系统设置，无需在部件里切换"

# ------------------------------------------------------- 可选：加到面板
if [[ "${1:-}" == "--panel" ]]; then
    command -v qdbus6 >/dev/null 2>&1 || die "找不到 qdbus6，无法自动添加。"
    command -v python3 >/dev/null 2>&1 || die "找不到 python3，无法自动添加。"

    PANEL_INFO=$(python3 - "$HOME/.config/plasma-org.kde.plasma.desktop-appletsrc" <<'PYEOF'
import re, sys
# 找出顶部/底部面板的 containment id（location 3=上, 4=下）
path = sys.argv[1]
section = None
data = {}
with open(path, encoding="utf-8") as f:
    for line in f:
        line = line.rstrip("\n")
        if line.startswith("[") and line.endswith("]"):
            section = line[1:-1]
            data.setdefault(section, {})
        elif "=" in line and section:
            k, v = line.split("=", 1)
            data[section].setdefault(k, v)

best = None
for s, kv in data.items():
    m = re.fullmatch(r"Containments\]\[(\d+)", s)
    if m and kv.get("plugin") == "org.kde.panel":
        loc = kv.get("location", "")
        if loc == "3":
            best = m.group(1)
            break
        if loc == "4" and best is None:
            best = m.group(1)
print(best or "")
PYEOF
)

    [[ -n "$PANEL_INFO" ]] || die "没找到面板 containment，请手动添加部件。"
    echo "把部件加到面板 $PANEL_INFO 的最左侧…"

    # 用 Plasma 脚本接口添加；先把 alignment 设为空以让部件顺序从最左开始
    SCRIPT=$(cat <<JSEOF
var p = panelById($PANEL_INFO);
p.alignment = "";
var w = p.addWidget("$PLUGIN_ID");
print("added widget id=" + w.id);
JSEOF
)
    qdbus6 org.kde.plasmashell /PlasmaShell org.kde.PlasmaShell.evaluateScript "$SCRIPT" \
        || die "通过 Plasma 脚本接口添加失败，请手动添加。"

    echo "已加入面板。若位置不是最左侧，可右键面板 → 编辑面板 拖动调整。"
fi
