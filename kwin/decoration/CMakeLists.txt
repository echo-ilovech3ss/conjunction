add_library(org.conjunction.glass MODULE
    glassdecoration.cpp
    glassdecoration.h
)

target_link_libraries(org.conjunction.glass PRIVATE
    Qt6::Core
    Qt6::Gui
    Qt6::DBus
    KF6::CoreAddons
    KF6::ConfigCore
    KF6::I18n
    KDecoration3::KDecoration
    KDecoration3::KDecoration3Private
)

install(TARGETS org.conjunction.glass DESTINATION "${KDE_INSTALL_QTPLUGINDIR}/org.kde.kdecoration3")
