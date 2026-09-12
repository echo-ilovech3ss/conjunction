cmake_minimum_required(VERSION 3.16)
project(conj-notificationd LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core DBus Gui)

qt_standard_project_setup()

set(SOURCES
    src/main.cpp
    src/notification_manager.cpp
    tests/test_notificationd.cpp
)

set(HEADERS
    src/notification_manager.h
)

add_executable(conj-notificationd
    ${SOURCES}
    ${HEADERS}
)

target_link_libraries(conj-notificationd PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
)

target_include_directories(conj-notificationd PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

# Standalone test binary
add_executable(test-conj-notificationd
    tests/test_notificationd.cpp
    src/notification_manager.cpp
)

target_compile_definitions(test-conj-notificationd PRIVATE TEST_STANDALONE_MAIN)

target_link_libraries(test-conj-notificationd PRIVATE
    Qt6::Core
    Qt6::DBus
    Qt6::Gui
)

target_include_directories(test-conj-notificationd PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)
