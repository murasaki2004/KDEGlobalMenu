#!/usr/bin/env python3
# SPDX-License-Identifier: MPL-2.0
#
# KDEGlobalMenu 小部件 —— 最近使用程序助手
#
# 只做一件事：读 KDE 自己的活动数据库（kactivitymanagerd），取出最近启动过的
# 程序，并补上 desktop 文件里的显示名与图标名。
#
# 说明：图标选择已经改由 KDE 原生的 KIconDialog 负责（见 contents/bin/ 下的
# kdeglobalmenu-iconchooser），因此这里不再需要扫描图标主题。
#
# 用法：
#   kdeglobalmenu-helper.py recent [条数]
#
# 输出：JSON —— {"ok": true, "items": [...]} 或 {"ok": false, "error": "..."}

import configparser
import json
import os
import sqlite3
import sys
from urllib.parse import quote


def desktop_dirs():
    """XDG 应用目录搜索路径。"""
    data_home = os.environ.get("XDG_DATA_HOME", os.path.expanduser("~/.local/share"))
    data_dirs = os.environ.get("XDG_DATA_DIRS", "/usr/local/share:/usr/share")
    result = [os.path.join(data_home, "applications")]
    for d in data_dirs.split(":"):
        if d.strip():
            result.append(os.path.join(d.strip(), "applications"))
    return result


def locale_name_keys():
    """当前语言的 Name 本地化键，从具体到宽泛。

    "zh_CN.UTF-8@variant" -> ["Name[zh_CN]", "Name[zh]"]；
    LANGUAGE 可能是 "zh_CN:en" 这样的优先级列表，只取第一个。
    """
    raw = ""
    for name in ("LANGUAGE", "LC_ALL", "LC_MESSAGES", "LANG"):
        value = os.environ.get(name, "")
        if not value or value in ("C", "POSIX"):
            continue
        raw = value.split(":")[0].split(".")[0].split("@")[0]
        if raw:
            break
    if not raw:
        return []
    raw = raw.replace("-", "_")
    language = raw.split("_")[0]
    return ["Name[%s]" % raw] if language == raw else ["Name[%s]" % raw, "Name[%s]" % language]


def desktop_entry(app_id):
    """按 desktop 文件 id 查找文件，返回 (路径, Name, Icon)。

    支持 Name[zh_CN] 之类的本地化名字；路径用于后续给 QML 启动应用。
    """
    if not app_id:
        return None, None, None
    relative = app_id if app_id.endswith(".desktop") else app_id + ".desktop"
    for directory in desktop_dirs():
        path = os.path.join(directory, relative)
        if not os.path.isfile(path):
            continue
        name = icon = None
        try:
            cp = configparser.ConfigParser(strict=False, interpolation=None)
            cp.read(path, encoding="utf-8")
            if not cp.has_section("Desktop Entry"):
                continue
            for key in locale_name_keys() + ["Name"]:
                if cp.has_option("Desktop Entry", key):
                    name = cp.get("Desktop Entry", key).strip()
                    break
            if cp.has_option("Desktop Entry", "Icon"):
                icon = cp.get("Desktop Entry", "Icon").strip()
        except Exception:
            continue
        if name:
            return path, name, icon or app_id
    return None, None, None


def cmd_recent(argv):
    """读 KActivities 数据库，取最近使用的应用。

    KDE 把「最近使用的程序」记在 kactivitymanagerd 的 database 里：
      ResourceLink 记录资源与活动的关联，ResourceEvent 记录使用时间。
    应用类资源的 targettedResource 形如 "applications:org.kde.dolphin.desktop"。
    """
    limit = int(argv[0]) if argv else 8
    db_path = os.path.expanduser("~/.local/share/kactivitymanagerd/resources/database")
    if not os.path.isfile(db_path):
        return {"ok": False, "error": "KActivities database not found"}

    query = """
        SELECT l.targettedResource, MAX(e.start) AS last_used
        FROM ResourceLink l
        JOIN ResourceEvent e ON e.targettedResource = l.targettedResource
        WHERE l.targettedResource LIKE 'applications:%'
        GROUP BY l.targettedResource
        ORDER BY last_used DESC
        LIMIT ?
    """
    try:
        # 只读打开，避免干扰正在运行的 kactivitymanagerd
        connection = sqlite3.connect("file:%s?mode=ro" % db_path, uri=True, timeout=5)
        rows = connection.execute(query, (limit,)).fetchall()
        connection.close()
    except Exception as exc:
        return {"ok": False, "error": "query failed: %s" % exc}

    items = []
    for resource, last_used in rows:
        # "applications:firefox.desktop" -> "firefox.desktop"
        app_id = resource.split(":", 1)[1] if ":" in resource else resource
        path, name, icon = desktop_entry(app_id)
        if not name:
            # desktop 文件缺失（比如已卸载）时，用去掉后缀的 id 兜个名字
            name = app_id[:-8] if app_id.endswith(".desktop") else app_id
            icon = icon or "application-x-executable"
        items.append({
            "id": app_id,
            "name": name,
            "icon": icon,
            # desktop 文件的 URI（按 URI 规则转义，文件名里的空格/中文才合法）。
            # QML 侧解码出路径后交给 gio/gtk-launch 启动应用。
            "url": "file://" + quote(path) if path else "",
            "lastUsed": last_used,
        })
    return {"ok": True, "items": items}


def main():
    if len(sys.argv) < 2:
        print(json.dumps({"ok": False, "error": "usage: helper.py recent [count]"}))
        return 1
    command, argv = sys.argv[1], sys.argv[2:]
    try:
        if command == "recent":
            result = cmd_recent(argv)
        else:
            result = {"ok": False, "error": "unknown command: %s" % command}
    except Exception as exc:
        result = {"ok": False, "error": str(exc)}
    print(json.dumps(result, ensure_ascii=False))
    return 0


if __name__ == "__main__":
    sys.exit(main())
