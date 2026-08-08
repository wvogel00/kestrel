# Kestrel

Kestrel is an experimental programmable parametric 3D CAD system.

The project is intentionally built around a Haskell model/DSL core, a Qt desktop frontend, and Open CASCADE (OCCT) as the exact B-Rep geometry kernel. The current target is Apple Silicon macOS.

## Current status

Kestrel can currently:

- define geometry in Haskell
- generate a versioned JSON intermediate representation (IR)
- evaluate that IR into exact OCCT B-Rep geometry
- display shaded solids with visible edges or wireframe geometry
- orbit and zoom interactively
- switch to orthographic +/-X, +/-Y, and +/-Z views
- construct boxes and cylinders
- translate geometry
- perform Boolean union and cut operations
- export the evaluated model as STEP
- export the evaluated model as binary STL

The current example model is defined in:

```text
core/app/Main.hs
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
 C++ OCCT evaluator
       |
       v
 Open CASCADE B-Rep
```

Haskell is the source of truth for model intent. The C++/Qt side does not contain the dimensions or construction sequence of the model; it parses the generated IR and recursively evaluates the geometry with OCCT.

The process boundary is intentional. A versioned IR keeps the programmable model layer independent from the GUI process and leaves room for future CLI workflows, live reload, alternate frontends, and direct FFI only where serialization would become a material performance cost.

## Haskell geometry DSL

The current geometry AST supports:

- `box width depth height`
- `cylinder radius height`
- `translate x y z geometry`
- `union left right`
- `cut left right`

Example:

```haskell
module Main where

import System.Environment (getArgs)

import Kestrel.Geometry (box, cut, cylinder, translate)
import Kestrel.Model (encodeModelJson, model)
import Kestrel.Units (mm)

kestrelModel =
    model $
        box
            (mm 100)
            (mm 60)
            (mm 20)
        `cut`
        translate
            (mm 50)
            (mm 30)
            (mm (-5))
            (cylinder (mm 5) (mm 30))

main :: IO ()
main = do
    args <- getArgs
    let json = encodeModelJson kestrelModel

    case args of
        [] -> putStr json
        [outputPath] -> writeFile outputPath json
        _ -> error "usage: kestrel-model [output.json]"
```

This produces a 100 x 60 x 20 mm solid with a 10 mm diameter through-hole.

## Model IR

During the build, CMake invokes the Haskell model generator and writes:

```text
build/generated/model.json
```

The IR is currently version 2 and represents geometry as a recursive tree. For example, a Boolean cut contains its left and right operands, while a translation contains a child node.

The generated IR is synchronized into the macOS application bundle at:

```text
build/app/kestrel.app/Contents/Resources/model.json
```

Changing `core/app/Main.hs` and rebuilding therefore changes the model displayed by the application without changing C++ code.

You can inspect the Haskell-generated IR directly with:

```sh
cabal run kestrel-model
```

## Viewer controls

| Input | Action |
|---|---|
| Left-drag | Orbit the camera |
| Mouse wheel | Zoom |
| `P` | Toggle shaded-with-edges / wireframe display |
| `X` | View from +X |
| `X` twice within 400 ms | View from -X |
| `Y` | View from +Y |
| `Y` twice within 400 ms | View from -Y |
| `Z` | View from +Z |
| `Z` twice within 400 ms | View from -Z |
| `Cmd+E` | Open the export dialog |

The same display and export commands are also available through the macOS menu bar.

## Export

Press `Cmd+E` or choose **File -> Export...**.

Supported formats:

### STEP

- extensions: `.step`, `.stp`
- exports the evaluated OCCT B-Rep directly
- intended for CAD interchange and manufacturing workflows

### STL

- extension: `.stl`
- exports a binary STL
- the current shape is meshed before writing
- intended primarily for 3D-printing workflows

If no extension is entered, Kestrel appends one matching the selected export format.

## Requirements

Current supported development target:

- Apple Silicon macOS (`arm64`)
- Xcode / Apple Clang
- CMake
- GHC + Cabal
- Qt 6
- Open CASCADE 7.9+

Install the native dependencies with Homebrew:

```sh
brew install cmake qt opencascade
```

GHC and Cabal are preferably managed with GHCup.

## Build

Configure:

```sh
cmake -S . -B build \
  -DCMAKE_PREFIX_PATH="$(brew --prefix qt);$(brew --prefix opencascade)"
```

Build:

```sh
cmake --build build -j
```

Run:

```sh
open build/app/kestrel.app
```

For terminal diagnostics, run the executable directly:

```sh
./build/app/kestrel.app/Contents/MacOS/kestrel
```

The current build is explicitly configured for `arm64`.

## Repository layout

```text
kestrel/
├── CMakeLists.txt
├── cabal.project
├── app/                    # Qt desktop application
│   └── src/
│       ├── main.cpp
│       ├── MainWindow.cpp
│       └── MainWindow.hpp
├── core/                   # Haskell model / DSL
│   ├── app/Main.hs
│   ├── kestrel-core.cabal
│   └── src/Kestrel/
│       ├── Geometry.hs
│       ├── Model.hs
│       └── Units.hs
├── native/                 # C++ / OCCT integration
│   ├── include/kestrel/
│   │   ├── model/ModelSpec.hpp
│   │   └── occt/Viewer.hpp
│   └── src/occt/Viewer.mm
├── docs/
└── examples/
```

`Viewer.mm` is Objective-C++ because the current macOS implementation attaches OCCT's `Cocoa_Window` to the native Qt `NSView`.

## Development milestones

Completed foundations:

- **M0** - Apple Silicon development environment: GHC/Cabal, CMake, Qt 6, OCCT, Apple Clang
- **M1** - Qt/OCCT viewer displaying an exact B-Rep solid
- **M2** - Haskell as the model source of truth through a versioned IR
- **M3** - recursive geometry AST with primitives, transforms, Boolean operations, shaded/wireframe display, orthographic views, and STEP/STL export

Planned work includes:

- named parameters and expressions
- additional transformations and primitives
- fillet and chamfer
- shell/thickness operations
- sketch representation and constraints
- extrusion and revolution
- feature/history representation
- stable topological references
- edge/face/vertex selection
- measurement tools, including clicking an edge to display its true curve length
- STEP import
- PCB/KiCad-oriented enclosure workflows
- sheet-metal support at a later stage

## Design principles

Kestrel is not intended to reproduce every Fusion feature. The goal is a compact engineering CAD focused on programmable, parametric mechanical design while keeping the model representation inspectable and deterministic.

Key principles are:

1. Haskell represents model intent and parametric structure.
2. OCCT owns exact geometric evaluation and interchange geometry.
3. GUI operations and programmable operations should eventually operate on the same underlying model representation.
4. Manufacturing interchange should preserve B-Rep geometry through STEP whenever possible; STL is treated as a derived mesh format.
5. Selection and topology will be designed with future measurement and feature references in mind rather than added as unrelated viewer-only behavior.
