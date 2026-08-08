module Kestrel.Units
    ( Length
    , mm
    , toMillimetres
    ) where

-- | A physical length. Kestrel's native geometric unit is millimetres.
newtype Length = Length Double
    deriving (Eq, Ord, Show)

-- | Construct a length in millimetres.
mm :: Double -> Length
mm = Length

-- | Convert a length to Kestrel's native millimetre representation.
toMillimetres :: Length -> Double
toMillimetres (Length value) = value
