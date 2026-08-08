module Kestrel.Geometry
    ( Primitive(..)
    , box
    ) where

import Kestrel.Units (Length)

-- | Geometric primitives supported by the current Kestrel IR.
data Primitive
    = Box
        { boxWidth  :: Length
        , boxDepth  :: Length
        , boxHeight :: Length
        }
    deriving (Eq, Show)

-- | Construct an axis-aligned box.
box :: Length -> Length -> Length -> Primitive
box = Box
