# Kestrel architecture

## Current data flow

```text
Haskell DSL / Geometry AST
          |
          v
   versioned JSON IR
          |
          v
    Qt model loader
          |
          v
   native NodeSpec AST
          |
          v
   recursive OCCT evaluator
          |
          v
      TopoDS_Shape
          |
          v
     AIS presentation
```

## M3 geometry language

The M3 AST supports:

- `Box`
- `Cylinder`
- `Translate`
- `Union`
- `Cut`

The Haskell AST is the model definition authority. The native layer evaluates the serialized IR into OCCT B-Rep geometry.

## Selection and measurement requirement

Kestrel should eventually support selecting a topological edge in the viewport and reporting its geometric length. This requirement affects future selection and topology-reference design.

A likely OCCT implementation path is:

1. enable edge-level selection in `AIS_InteractiveContext`,
2. obtain the selected `TopoDS_Edge`,
3. calculate curve length from the selected edge,
4. show the result in the UI using millimetres by default.

For straight edges this is endpoint distance; for arcs and splines it must be true curve length rather than chord length.

This should be implemented after the basic modeling AST and before stable topology references are considered complete, because selection, feature history, and topological naming need to share a coherent identity model.
