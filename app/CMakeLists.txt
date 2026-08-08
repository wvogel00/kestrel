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

add_custom_command(TARGET kestrel POST_BUILD
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${KESTREL_BUNDLE_RESOURCES}"
    COMMAND "${CMAKE_COMMAND}" -E copy_if_different
            "${KESTREL_MODEL_IR}"
            "${KESTREL_BUNDLE_RESOURCES}/model.json"
    COMMENT "Embedding Haskell-generated model IR in Kestrel.app"
)
