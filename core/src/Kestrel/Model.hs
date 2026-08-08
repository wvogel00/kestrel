module Kestrel.Model
    ( Model(..)
    , model
    , encodeModelJson
    ) where

import Kestrel.Geometry (Geometry(..))
import Kestrel.Units (toMillimetres)

newtype Model = Model
    { rootGeometry :: Geometry
    }
    deriving (Eq, Show)

model :: Geometry -> Model
model = Model

encodeModelJson :: Model -> String
encodeModelJson (Model root) =
    concat
        [ "{\n"
        , "  \"version\": 2,\n"
        , "  \"root\": "
        , encodeGeometry 2 root
        , "\n}\n"
        ]

encodeGeometry :: Int -> Geometry -> String
encodeGeometry indentLevel geometry =
    case geometry of
        Box width depth height ->
            object indentLevel
                [ field "type" "\"box\""
                , field "width_mm" (show $ toMillimetres width)
                , field "depth_mm" (show $ toMillimetres depth)
                , field "height_mm" (show $ toMillimetres height)
                ]
        Cylinder radius height ->
            object indentLevel
                [ field "type" "\"cylinder\""
                , field "radius_mm" (show $ toMillimetres radius)
                , field "height_mm" (show $ toMillimetres height)
                ]
        Translate x y z child ->
            object indentLevel
                [ field "type" "\"translate\""
                , field "x_mm" (show $ toMillimetres x)
                , field "y_mm" (show $ toMillimetres y)
                , field "z_mm" (show $ toMillimetres z)
                , field "child" (encodeGeometry (indentLevel + 2) child)
                ]
        Union left right ->
            binaryNode indentLevel "union" left right
        Cut left right ->
            binaryNode indentLevel "cut" left right

binaryNode :: Int -> String -> Geometry -> Geometry -> String
binaryNode indentLevel nodeType left right =
    object indentLevel
        [ field "type" (show nodeType)
        , field "left" (encodeGeometry (indentLevel + 2) left)
        , field "right" (encodeGeometry (indentLevel + 2) right)
        ]

field :: String -> String -> (String, String)
field = (,)

object :: Int -> [(String, String)] -> String
object indentLevel fields =
    concat
        [ "{\n"
        , concatMap encodeField (zip [0 :: Int ..] fields)
        , spaces indentLevel
        , "}"
        ]
  where
    encodeField (index, (name, value)) =
        concat
            [ spaces (indentLevel + 2)
            , show name
            , ": "
            , value
            , if index + 1 < length fields then "," else ""
            , "\n"
            ]

spaces :: Int -> String
spaces count = replicate count ' '
