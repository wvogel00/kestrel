cmake_minimum_required(VERSION 3.24)

project(Kestrel VERSION 0.0.3 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

# Current target: Apple Silicon macOS.
set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "Build architectures" FORCE)

set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)
find_package(OpenCASCADE REQUIRED)
find_program(CABAL_EXECUTABLE cabal REQUIRED)

set(KESTREL_MODEL_IR "${CMAKE_BINARY_DIR}/generated/model.json")

add_custom_command(
    OUTPUT "${KESTREL_MODEL_IR}"
    COMMAND "${CMAKE_COMMAND}" -E make_directory "${CMAKE_BINARY_DIR}/generated"
    COMMAND "${CABAL_EXECUTABLE}"
            run
            "--project-file=${CMAKE_SOURCE_DIR}/cabal.project"
            kestrel-model
            --
            "${KESTREL_MODEL_IR}"
    WORKING_DIRECTORY "${CMAKE_SOURCE_DIR}"
    DEPENDS
        core/kestrel-core.cabal
        core/app/Main.hs
        core/src/Kestrel/Geometry.hs
        core/src/Kestrel/Model.hs
        core/src/Kestrel/Units.hs
    COMMENT "Generating Kestrel model IR with Haskell"
    VERBATIM
)

add_custom_target(kestrel_model_ir ALL
    DEPENDS "${KESTREL_MODEL_IR}"
)

add_subdirectory(native)
add_subdirectory(app)
