# Kestrel

Kestrel is an experimental programmable parametric 3D CAD system.

The project is built around a Haskell model/DSL core, a Qt desktop frontend, and Open CASCADE (OCCT) as the exact B-Rep geometry kernel. The current target is Apple Silicon macOS.

## Current status

Kestrel can currently:

- define base geometry in Haskell
- generate a versioned JSON intermediate representation (IR)
- evaluate that IR into exact OCCT B-Rep geometry
- display shaded solids with visible edges or wireframe geometry
- orbit and zoom interactively
- switch to orthographic +/-X, +/-Y, and +/-Z views
- select planar faces
- start a GUI sketch on a selected planar face
- draw a rectangular sketch profile by clicking two opposite corners
- use either existing body vertices or arbitrary free points as rectangle corners
- highlight body vertices in sketch mode and snap exactly to them when clicked
- select rectangle edges and assign width/height dimensions with `D`
- leave sketch mode with `Esc`
- extrude an existing planar face or a sketch profile
- use positive extrusion distances to add material
- use negative extrusion distances to cut material
- undo geometry edits with `Cmd+Z`
- construct boxes and cylinders from the Haskell DSL
- translate geometry
- perform Boolean union and cut operations
- export the current evaluated/edited model as STEP
- export the current evaluated/edited model as binary STL

The initial programmable model is defined in:

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
 C++ OCCT evaluator / interactive editor
       |
       v
 Open CASCADE B-Rep
```

Haskell remains the source of truth for the initial model definition. The C++/Qt side evaluates the generated IR and currently also supports interactive in-memory editing for sketch and extrusion operations.

Important current limitation: interactive GUI edits are not yet serialized back into the Haskell AST or JSON IR. They modify the live OCCT B-Rep in memory and are preserved when exporting STEP/STL, but reopening/rebuilding the application starts again from the Haskell-generated model. Unifying programmable and GUI operations into one persistent feature/history representation is a planned architectural step.

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

The IR is currently version 2 and represents geometry as a recursive tree. A Boolean cut contains its left and right operands, while a translation contains a child node.

The generated IR is synchronized into the macOS application bundle at:

```text
build/app/kestrel.app/Contents/Resources/model.json
```

Changing `core/app/Main.hs` and rebuilding changes the initial model displayed by the application without changing C++ code.

You can inspect the Haskell-generated IR directly with:

```sh
cabal run kestrel-model
```

## Viewer and modeling controls

| Input | Action |
|---|---|
| Left-click | Select a face/profile/active sketch entity |
| Left-drag | Orbit the camera when not in sketch mode |
| Mouse wheel | Zoom |
| `P` | Toggle shaded-with-edges / wireframe display |
| `X` | View from +X |
| `X` twice within 400 ms | View from -X |
| `Y` | View from +Y |
| `Y` twice within 400 ms | View from -Y |
| `Z` | View from +Z |
| `Z` twice within 400 ms | View from -Z |
| `S` | Start sketch on the selected planar face |
| `D` | Dimension the selected rectangle edge |
| `Esc` | Exit sketch mode |
| `E` | Extrude the selected planar face or sketch profile |
| `Cmd+Z` | Undo the last geometry edit |
| `Cmd+E` | Open the STEP/STL export dialog |

## Interactive sketch workflow

The current sketch implementation supports an initial Fusion-like workflow for rectangular profiles.

1. Click a planar face of the current solid.
2. Press `S`.
3. Kestrel enters sketch mode on that face.
4. Existing body vertices become optional snap targets. A vertex under the cursor is highlighted in yellow.
5. Click either a highlighted vertex or any arbitrary point on the sketch plane for the first rectangle corner.
6. Click either another valid vertex or an arbitrary free point for the opposite rectangle corner.
7. The resulting profile is displayed as a translucent orange face.
8. Click one of the rectangle edges and press `D` to enter its width/height dimension in millimetres.
9. Press `Esc` to leave sketch mode.
10. Select the orange profile and press `E` to extrude it.

The vertex snap is optional: if no valid sketch-plane vertex is detected at the click location, Kestrel projects the cursor position onto the active sketch plane and uses that as a free point.

Current sketch limitations:

- planar faces only
- rectangle profiles only
- dimensional constraints currently apply to rectangle width/height only
- no full geometric-constraint solver yet
- no persistent feature/history serialization yet

## Extrusion

Press `E` after selecting either an existing planar B-Rep face or a generated sketch profile. Kestrel opens a distance dialog in millimetres.

- positive distance: add material using an OCCT prism + Boolean fuse
- negative distance: remove material using an OCCT prism + Boolean cut

The result becomes the live `currentShape` and is used by subsequent selection, sketching, extrusion, STEP export, and STL export.

## Export

Press `Cmd+E` or choose **File -> Export...**.

Supported formats:

### STEP

- extensions: `.step`, `.stp`
- exports the current OCCT B-Rep directly
- includes live interactive extrusions performed in the current session
- intended for CAD interchange and manufacturing workflows

### STL

- extension: `.stl`
- exports a binary STL
- the current shape is meshed before writing
- includes live interactive extrusions performed in the current session
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

## Build

```sh
cmake -S . -B build \
  -DCMAKE_PREFIX_PATH="$(brew --prefix qt);$(brew --prefix opencascade)"

cmake --build build -j
open build/app/kestrel.app
```

For terminal diagnostics:

```sh
./build/app/kestrel.app/Contents/MacOS/kestrel
```

## Development milestones

Completed foundations:

- **M0** - Apple Silicon development environment
- **M1** - Qt/OCCT viewer displaying an exact B-Rep solid
- **M2** - Haskell as the initial model source of truth through a versioned IR
- **M3** - recursive geometry AST, Boolean operations, viewer controls, STEP/STL export
- **M4 (in progress)** - interactive face selection, sketching, dimensional rectangle constraints, push/pull extrusion, and undo

## Planned work / backlog

Near-term CAD features:

- persistent feature/history representation shared by GUI and programmable models
- full sketch entity/constraint model rather than rectangle-specific state
- sketch line tool: endpoints may snap to existing vertices or use arbitrary free points; dimensions/constraints editable
- sketch circle tool: center and radius points may use vertex snaps or free points; diameter/radius dimensions editable
- on-canvas dimensional annotations and constraint symbols similar to Fusion
- geometric constraints such as coincident, horizontal, vertical, equal, fixed, tangent, and concentric
- fillet / chamfer tools
- shell/thickness operations
- improved menu bar and command organization
- application/tool icons
- stable topological references
- edge/face/vertex selection improvements
- measurement tools, including clicking an edge to display its true curve length
- STEP import

Manufacturing-oriented features:

- configurable hole tool
- arbitrary hole diameter entry
- user-defined preset hole-size lists for frequently used screw holes
- hole presets designed with meviy workflows in mind, including sizes that distinguish plain holes from tapping/thread-processing choices
- PCB/KiCad-oriented enclosure workflows
- sheet-metal support at a later stage

Additional solid modeling:

- revolution
- sweep
- loft
- named parameters and expressions

## Design principles

Kestrel is not intended to reproduce every Fusion feature. The goal is a compact engineering CAD focused on programmable, parametric mechanical design while keeping the model representation inspectable and deterministic.

Key principles are:

1. Haskell represents programmable model intent and parametric structure.
2. OCCT owns exact geometric evaluation and interchange geometry.
3. GUI operations and programmable operations should converge on the same persistent feature/history representation.
4. Manufacturing interchange should preserve B-Rep geometry through STEP whenever possible; STL is treated as a derived mesh format.
5. Selection and topology will be designed with future measurement and feature references in mind rather than added as unrelated viewer-only behavior.
