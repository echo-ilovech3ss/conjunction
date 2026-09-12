cmake_minimum_required(VERSION 3.16)
project(conjunction-terminal LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Widgets DBus)
find_package(KF6Parts REQUIRED)
find_package(KF6XmlGui REQUIRED)
find_package(KF6CoreAddons REQUIRED)

qt_standard_project_setup()

set(SOURCES
    src/main.cpp
    src/shell_escape.cpp
    src/theme_bridge.cpp
    src/terminal_session.cpp
    src/terminal_find_bar.cpp
    src/terminal_window.cpp
    tests/test_terminal.cpp
)

set(HEADERS
    src/shell_escape.h
    src/theme_bridge.h
    src/terminal_session.h
    src/terminal_find_bar.h
    src/terminal_window.h
)

add_executable(conjunction-terminal
    ${SOURCES}
    ${HEADERS}
)

target_link_libraries(conjunction-terminal PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Widgets
    Qt6::DBus
    KF6::Parts
    KF6::XmlGui
    KF6::CoreAddons
)

target_include_directories(conjunction-terminal PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
    /usr/include/KF6/KParts
    /usr/include/KF6
)

# Standalone test executable
add_executable(test-conjunction-terminal
    tests/test_terminal.cpp
    src/shell_escape.cpp
)

target_compile_definitions(test-conjunction-terminal PRIVATE TEST_STANDALONE_MAIN)

target_link_libraries(test-conjunction-terminal PRIVATE
    Qt6::Core
)

target_include_directories(test-conjunction-terminal PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

install(TARGETS conjunction-terminal DESTINATION bin)
