# SPDX-License-Identifier: MPL-2.0
#
# KDEGlobalMenu 小部件 —— 图标选择器助手的构建脚本
#
# 依赖：cmake、g++、qt6-base、kiconthemes、extra-cmake-modules

cmake_minimum_required(VERSION 3.16)

project(kdeglobalmenu-iconchooser VERSION 1.0.0 LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets)
# KIconDialog（KF6::IconWidgets）由 KF6IconThemes 这个 cmake 包导出
find_package(KF6IconThemes REQUIRED)
# 仅用于 KLocalizedString::setApplicationDomain，让对话框跟随 KDE 翻译
find_package(KF6I18n REQUIRED)

add_executable(kdeglobalmenu-iconchooser main.cpp)

target_link_libraries(kdeglobalmenu-iconchooser PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    KF6::IconWidgets
    KF6::I18n
)

# 装到与部件同级的 bin/ 下，便于配置页按相对路径定位
install(TARGETS kdeglobalmenu-iconchooser RUNTIME DESTINATION bin)
