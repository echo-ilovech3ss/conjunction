cmake_minimum_required(VERSION 3.20)
project(conjunction-kwin LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 23)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_AUTOMOC ON)
list(APPEND CMAKE_AUTOMOC_MACRO_NAMES
    KWIN_EFFECT_FACTORY
    KWIN_EFFECT_FACTORY_SUPPORTED
    KWIN_EFFECT_FACTORY_ENABLED
    KWIN_EFFECT_FACTORY_SUPPORTED_ENABLED
)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

set(QT_MAJOR_VERSION 6)
find_package(ECM REQUIRED NO_MODULE)
set(CMAKE_MODULE_PATH ${ECM_MODULE_PATH})
set(KDE_INSTALL_USE_QT_SYS_PATHS ON CACHE BOOL "Install Qt plugins in Qt plugin dir" FORCE)
include(KDEInstallDirs)
include(KDECMakeSettings)
include(KDECompilerSettings NO_POLICY_SCOPE)
set(CMAKE_LIBRARY_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/lib")
set(CMAKE_RUNTIME_OUTPUT_DIRECTORY "${CMAKE_BINARY_DIR}/bin")

find_package(Qt6 REQUIRED COMPONENTS Core Gui DBus OpenGL Widgets)
find_package(KF6 REQUIRED COMPONENTS CoreAddons Config I18n WindowSystem)
find_package(KDecoration3 REQUIRED)
find_package(KWin REQUIRED)
find_package(KWinDBusInterface CONFIG QUIET)
find_package(epoxy REQUIRED)

add_subdirectory(decoration)
add_subdirectory(effects/liquidglass)
add_subdirectory(effects/motion)
