module Main where

import System.Environment (getArgs)

import Kestrel.Geometry (box, cut, cylinder, translate)
import Kestrel.Model (encodeModelJson, model)
import Kestrel.Units (mm)

-- | M3 demonstration model: a rectangular solid with a through-hole.
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
