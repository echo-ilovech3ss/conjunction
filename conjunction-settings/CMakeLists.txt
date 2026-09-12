cmake_minimum_required(VERSION 3.16)
project(conjunction-settings LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml DBus)
find_package(KF6Config REQUIRED)
find_package(KF6Solid REQUIRED)
find_package(KF6NetworkManagerQt REQUIRED)
find_package(KF6Screen QUIET)

qt_standard_project_setup()

set(SOURCES
    src/main.cpp
    src/settings_manager.cpp
    src/system_info.cpp
    src/network_backend.cpp
    src/bluetooth_backend.cpp
    src/display_backend.cpp
    src/audio_backend.cpp
)

set(HEADERS
    src/settings_manager.h
    src/system_info.h
    src/network_backend.h
    src/bluetooth_backend.h
    src/display_backend.h
    src/audio_backend.h
)

add_executable(conjunction-settings
    ${SOURCES}
    ${HEADERS}
)

target_link_libraries(conjunction-settings PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
    KF6::ConfigCore
    KF6::ConfigGui
    KF6::Solid
    KF6::NetworkManagerQt
)

if(TARGET KF6::Screen)
    target_link_libraries(conjunction-settings PRIVATE KF6::Screen)
    target_compile_definitions(conjunction-settings PRIVATE HAVE_KSCREEN)
endif()

target_include_directories(conjunction-settings PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

install(TARGETS conjunction-settings DESTINATION bin)
install(DIRECTORY qml/ DESTINATION share/conjunction/settings)
