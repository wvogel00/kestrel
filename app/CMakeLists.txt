qt_add_executable(kestrel
    MACOSX_BUNDLE
    src/main.cpp
    src/MainWindow.cpp
    src/MainWindow.hpp
)

target_link_libraries(kestrel
    PRIVATE
        Qt6::Widgets
        kestrel_native
)

set_target_properties(kestrel PROPERTIES
    MACOSX_BUNDLE_BUNDLE_NAME "Kestrel"
    MACOSX_BUNDLE_GUI_IDENTIFIER "dev.kestrel.cad"
)
