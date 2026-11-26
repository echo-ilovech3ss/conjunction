cmake_minimum_required(VERSION 3.16)
project(conj-shelld LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml DBus)
find_package(LayerShellQt QUIET)

qt_standard_project_setup()

add_executable(conj-shelld
    src/main.cpp
    src/shell_state.cpp
    src/menu_registrar.cpp
    src/window_manager.cpp
)

target_link_libraries(conj-shelld PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
)

if(LayerShellQt_FOUND)
    target_link_libraries(conj-shelld PRIVATE LayerShellQt::Interface)
    target_compile_definitions(conj-shelld PRIVATE HAVE_LAYERSHELLQT=1)
endif()

target_include_directories(conj-shelld PRIVATE
    ${CMAKE_CURRENT_SOURCE_DIR}/src
)

install(TARGETS conj-shelld DESTINATION bin)
install(DIRECTORY qml/ DESTINATION share/conjunction/shell)
install(FILES ../data/icons/conjunction-mark.svg DESTINATION share/conjunction/icons)
