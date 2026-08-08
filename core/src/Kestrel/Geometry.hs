module Kestrel.Geometry
    ( Geometry(..)
    , box
    , cylinder
    , translate
    , union
    , cut
    ) where

import Kestrel.Units (Length)

-- | Geometry expression tree evaluated by the native OCCT backend.
--
-- M3 deliberately keeps the language small: two primitives, a transform,
-- and two boolean operators. New CAD operations can be added as additional
-- constructors without changing how models are composed.
data Geometry
    = Box
        { boxWidth  :: Length
        , boxDepth  :: Length
        , boxHeight :: Length
        }
    | Cylinder
        { cylinderRadius :: Length
        , cylinderHeight :: Length
        }
    | Translate
        { translateX     :: Length
        , translateY     :: Length
        , translateZ     :: Length
        , translateChild :: Geometry
        }
    | Union Geometry Geometry
    | Cut Geometry Geometry
    deriving (Eq, Show)

box :: Length -> Length -> Length -> Geometry
box = Box

cylinder :: Length -> Length -> Geometry
cylinder = Cylinder

translate :: Length -> Length -> Length -> Geometry -> Geometry
translate = Translate

union :: Geometry -> Geometry -> Geometry
union = Union

cut :: Geometry -> Geometry -> Geometry
cut = Cut
