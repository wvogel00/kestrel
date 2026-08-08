module Main where

import System.Environment (getArgs)

import Kestrel.Geometry (box)
import Kestrel.Model (encodeModelJson, model)
import Kestrel.Units (mm)

kestrelModel =
    model $
        box
            (mm 50)
            (mm 30)
            (mm 20)

main :: IO ()
main = do
    args <- getArgs
    let json = encodeModelJson kestrelModel

    case args of
        [] -> putStr json
        [outputPath] -> writeFile outputPath json
        _ -> error "usage: kestrel-model [output.json]"
