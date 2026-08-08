add_library(kestrel_native STATIC
    src/occt/Viewer.mm
    src/occt/ViewerSketch.mm
    src/occt/ViewerUndo.mm
)

target_include_directories(kestrel_native
    PUBLIC
        ${CMAKE_CURRENT_SOURCE_DIR}/include
        ${OpenCASCADE_INCLUDE_DIR}
)

target_link_libraries(kestrel_native
    PUBLIC
        Qt6::Widgets
        ${OpenCASCADE_LIBRARIES}
        "-framework AppKit"
)
