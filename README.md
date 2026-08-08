# Kestrel

Kestrel is an experimental programmable parametric 3D CAD system.

The long-term architecture combines a Haskell model/DSL core with a Qt frontend and Open CASCADE (OCCT) geometry kernel.

## Current milestone: M1

M1 proves the native rendering path on Apple Silicon macOS:

- Qt 6 application shell
- Open CASCADE 3D viewer embedded in a Qt widget
- 50 x 30 x 20 mm OCCT demo box
- basic orbit, zoom, hover and selection

## Requirements (macOS)

- Apple Silicon macOS
- Xcode / Apple Clang
- CMake
- Qt 6
- Open CASCADE 7.9+

With Homebrew:

```sh
brew install cmake qt opencascade
```

## Build

```sh
cmake -S . -B build \
  -DCMAKE_PREFIX_PATH="$(brew --prefix qt);$(brew --prefix opencascade)"

cmake --build build -j
open build/app/kestrel.app
```

If CMake cannot locate Open CASCADE, provide its config directory explicitly:

```sh
find "$(brew --prefix opencascade)" -name OpenCASCADEConfig.cmake
```

and pass the containing directory with `-DOpenCASCADE_DIR=...`.

## Architecture

```text
Haskell core / DSL        Qt frontend
        |                     |
        +----------+----------+
                   |
              native C++
                   |
            Open CASCADE
```

The Haskell core is intentionally not connected during M1. It will be introduced after the Qt/OCCT rendering path is proven.
