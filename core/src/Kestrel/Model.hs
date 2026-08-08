module Kestrel.Model
    ( Model(..)
    , model
    , encodeModelJson
    ) where

import Kestrel.Geometry (Primitive(..))
import Kestrel.Units (toMillimetres)

-- | Root of a Kestrel parametric model.
newtype Model = Model
    { rootPrimitive :: Primitive
    }
    deriving (Eq, Show)

-- | Lift a primitive into a complete model.
model :: Primitive -> Model
model = Model

-- | Encode the current minimal IR as JSON.
--
-- This encoder intentionally has no external package dependencies in M2.
-- It will be replaced by a versioned IR codec once the AST grows beyond
-- primitives.
encodeModelJson :: Model -> String
encodeModelJson (Model primitive) =
    case primitive of
        Box width depth height ->
            concat
                [ "{\n"
                , "  \"version\": 1,\n"
                , "  \"root\": {\n"
                , "    \"type\": \"box\",\n"
                , "    \"width_mm\": ", show (toMillimetres width), ",\n"
                , "    \"depth_mm\": ", show (toMillimetres depth), ",\n"
                , "    \"height_mm\": ", show (toMillimetres height), "\n"
                , "  }\n"
                , "}\n"
                ]
