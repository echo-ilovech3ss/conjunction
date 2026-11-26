kcoreaddons_add_plugin(conjunctionmotion SOURCES
    motion_effect.cpp
    motion_effect.h
    INSTALL_NAMESPACE "kwin/effects/plugins"
)

target_link_libraries(conjunctionmotion PRIVATE
    KWin::kwin
    KF6::CoreAddons
    KF6::ConfigCore
    Qt6::DBus
    Qt6::Gui
)
