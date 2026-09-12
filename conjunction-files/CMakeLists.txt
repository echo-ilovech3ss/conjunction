cmake_minimum_required(VERSION 3.16)
project(conjunction-files LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml DBus)
find_package(KF6KIO REQUIRED)

qt_standard_project_setup()

add_executable(conjunction-files
    src/main.cpp
    src/file_item.cpp
    src/files_model.cpp
    src/sidebar_model.cpp
    src/column_model.cpp
    src/file_operations.cpp
    src/quicklook_service.cpp
)

target_link_libraries(conjunction-files PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
    KF6::KIOCore
    KF6::KIOGui
    KF6::KIOFileWidgets
)

target_include_directories(conjunction-files PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

install(TARGETS conjunction-files DESTINATION bin)
install(DIRECTORY qml/ DESTINATION share/conjunction/files)
