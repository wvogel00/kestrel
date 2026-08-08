cmake_minimum_required(VERSION 3.24)

# M0/M1 currently targets Apple Silicon macOS explicitly.
# Set this before project() so compiler checks and every generated target use arm64.
if(APPLE)
    set(CMAKE_OSX_ARCHITECTURES "arm64" CACHE STRING "macOS target architectures" FORCE)
endif()

project(Kestrel VERSION 0.0.1 LANGUAGES CXX OBJCXX)

set(CMAKE_CXX_STANDARD 20)
set(CMAKE_CXX_STANDARD_REQUIRED ON)
set(CMAKE_CXX_EXTENSIONS OFF)

set(CMAKE_AUTOMOC ON)

find_package(Qt6 REQUIRED COMPONENTS Widgets)
find_package(OpenCASCADE REQUIRED)

add_subdirectory(native)
add_subdirectory(app)
