kcoreaddons_add_plugin(conjunctionglass SOURCES
    liquidglass_effect.cpp
    liquidglass_effect.h
    INSTALL_NAMESPACE "kwin/effects/plugins"
)

target_link_libraries(conjunctionglass PRIVATE
    KWin::kwin
    KF6::CoreAddons
    KF6::ConfigCore
    Qt6::DBus
    Qt6::OpenGL
    epoxy::epoxy
)
