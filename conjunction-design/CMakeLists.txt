cmake_minimum_required(VERSION 3.16)
project(conjunction-design LANGUAGES CXX)

set(CMAKE_CXX_STANDARD 17)
set(CMAKE_CXX_STANDARD_REQUIRED ON)

find_package(Qt6 REQUIRED COMPONENTS Core Gui Quick Qml DBus ShaderTools)
find_program(QT_QSB_EXECUTABLE NAMES qsb qsb-qt6 HINTS /usr/lib64/qt6/bin /usr/bin REQUIRED)

qt_standard_project_setup()

set(SHADER_SRC_DIR "${CMAKE_CURRENT_SOURCE_DIR}/shaders")
set(SHADER_OUT_DIR "${CMAKE_CURRENT_BINARY_DIR}/qml/Conjunction/Design/shaders")
file(MAKE_DIRECTORY "${SHADER_OUT_DIR}")

set(SHADER_FILES
    glass_blur.vert
    glass_blur_h.frag
    glass_blur_v.frag
    liquid_glass.vert
    liquid_glass.frag
    squircle_shape.vert
    squircle_shape.frag
    morph_glass.vert
    morph_glass.frag
)

set(GENERATED_QSB_FILES)
foreach(SHADER_FILE ${SHADER_FILES})
    set(IN_SHADER "${SHADER_SRC_DIR}/${SHADER_FILE}")
    set(OUT_QSB "${SHADER_OUT_DIR}/${SHADER_FILE}.qsb")
    add_custom_command(
        OUTPUT "${OUT_QSB}"
        COMMAND "${QT_QSB_EXECUTABLE}" --glsl "100 es,120,330" --hlsl 50 --msl 12 -o "${OUT_QSB}" "${IN_SHADER}"
        DEPENDS "${IN_SHADER}"
        COMMENT "Compiling QML RHI shader ${SHADER_FILE}"
        VERBATIM
    )
    list(APPEND GENERATED_QSB_FILES "${OUT_QSB}")
endforeach()

add_custom_target(conjunction-design-shaders ALL
    DEPENDS ${GENERATED_QSB_FILES}
    COMMAND ${CMAKE_COMMAND} -E copy_directory "${CMAKE_CURRENT_SOURCE_DIR}/qml" "${CMAKE_CURRENT_BINARY_DIR}/qml"
)

add_executable(conjunction-design-gallery
    gallery/main.cpp
)
add_dependencies(conjunction-design-gallery conjunction-design-shaders)

target_link_libraries(conjunction-design-gallery PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
)

add_executable(conjunction-reference-app
    reference_app/main.cpp
)
add_dependencies(conjunction-reference-app conjunction-design-shaders)

target_link_libraries(conjunction-reference-app PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::Quick
    Qt6::Qml
    Qt6::DBus
)

install(TARGETS conjunction-design-gallery conjunction-reference-app DESTINATION bin)
install(DIRECTORY qml/Conjunction DESTINATION share/conjunction/qml)
install(FILES ${GENERATED_QSB_FILES} DESTINATION share/conjunction/qml/Conjunction/Design/shaders)
install(DIRECTORY gallery DESTINATION share/conjunction)
install(DIRECTORY reference_app DESTINATION share/conjunction)
if(EXISTS "${CMAKE_CURRENT_SOURCE_DIR}/../data/icons/phosphor")
    install(DIRECTORY "${CMAKE_CURRENT_SOURCE_DIR}/../data/icons/phosphor" DESTINATION share/conjunction/icons)
endif()
