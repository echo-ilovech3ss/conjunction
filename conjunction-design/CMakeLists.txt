cmake_minimum_required(VERSION 3.16)
project(conjunction-design LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml)

qt_standard_project_setup()

add_executable(conjunction-design-gallery
    gallery/main.cpp
)

target_link_libraries(conjunction-design-gallery PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
)

install(TARGETS conjunction-design-gallery DESTINATION bin)
install(DIRECTORY qml/Conjunction DESTINATION share/conjunction/qml)
install(DIRECTORY gallery DESTINATION share/conjunction)
