qt_add_executable(kestrel
    MACOSX_BUNDLE
    src/main.cpp
    src/MainWindow.cpp
    src/MainWindow.hpp
)

add_dependencies(kestrel kestrel_model_ir)

target_link_libraries(kestrel
    PRIVATE
        Qt6::Widgets
        kestrel_native
)

set_target_properties(kestrel PROPERTIES
    MACOSX_BUNDLE_BUNDLE_NAME "Kestrel"
    MACOSX_BUNDLE_GUI_IDENTIFIER "dev.kestrel.cad"
)

set(KESTREL_BUNDLE_RESOURCES
    "${CMAKE_CURRENT_BINARY_DIR}/kestrel.app/Contents/Resources"
)

# Keep the Haskell-generated model IR in the application bundle synchronized
# even when only Haskell sources change and the C++ executable does not relink.
add_custom_target(kestrel_bundle_model ALL
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${KESTREL_BUNDLE_RESOURCES}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${KESTREL_MODEL_IR}"
            "${KESTREL_BUNDLE_RESOURCES}/model.json"
    DEPENDS
        kestrel
        kestrel_model_ir
    COMMENT "Synchronizing Haskell-generated model IR into Kestrel.app"
    VERBATIM
)
