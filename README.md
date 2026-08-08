# Kestrel

Kestrel is an experimental programmable parametric 3D CAD system.

The long-term architecture combines a Haskell model/DSL core with a Qt frontend and Open CASCADE (OCCT) geometry kernel.

## Current milestone: M2

M2 makes Haskell the source of truth for the first CAD model:

- the model is defined as a Haskell AST
- Haskell emits a small versioned JSON IR
- the Qt application loads that IR
- OCCT constructs the corresponding B-Rep box
- orbit, zoom, hover and selection remain available

The current model is defined in `core/app/Main.hs`.

## Requirements (macOS)

- Apple Silicon macOS
- Xcode / Apple Clang
- CMake
- GHC + Cabal
- Qt 6
- Open CASCADE 7.9+

With Homebrew for the native dependencies:

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

During the build, CMake invokes `cabal run kestrel-model` and generates:

```text
build/generated/model.json
```

The generated IR is copied into the application bundle at:

```text
build/app/kestrel.app/Contents/Resources/model.json
```

You can also inspect the Haskell output directly:

```sh
cabal run kestrel-model
```

## Architecture

```text
Haskell DSL / AST
       |
       v
 versioned JSON IR
       |
       v
  Qt frontend
       |
       v
  native C++ / OCCT
       |
       v
 Open CASCADE B-Rep
```

The process boundary is intentional: the versioned IR keeps the Haskell model layer independent from the GUI process and will support CLI use, model regeneration, and later live reload. A direct FFI can still be added for operations where avoiding serialization is materially useful.
