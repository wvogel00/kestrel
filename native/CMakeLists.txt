add_library(kestrel_native STATIC
    src/occt/Viewer.mm
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
