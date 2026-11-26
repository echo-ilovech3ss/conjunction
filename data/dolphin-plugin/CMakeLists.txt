cmake_minimum_required(VERSION 3.20)
project(conjunction-dolphin-plugin LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)

find_package(ECM 6.0.0 REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
set(QT_MAJOR_VERSION 6)

include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)

find_package(Qt6 REQUIRED COMPONENTS Gui Widgets)
find_package(KF6 REQUIRED COMPONENTS CoreAddons KIO)

kcoreaddons_add_plugin(conjunction_app_action
    SOURCES conjunction_app_action.cpp
    INSTALL_NAMESPACE "kf6/kfileitemaction"
)
target_link_libraries(conjunction_app_action
    Qt6::Widgets
    KF6::CoreAddons
    KF6::KIOCore
    KF6::KIOWidgets
)

kcoreaddons_add_plugin(conjunction_app_thumbnailer
    SOURCES conjunction_app_thumbnailer.cpp
    INSTALL_NAMESPACE "kf6/thumbcreator"
)
target_link_libraries(conjunction_app_thumbnailer
    Qt6::Gui
    KF6::CoreAddons
    KF6::KIOGui
)
