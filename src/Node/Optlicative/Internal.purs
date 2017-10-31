module Node.Optlicative.Internal where

import Prelude

import Data.Foreign (MultipleErrors, renderForeignError)
import Data.Function (on)
import Data.List (List(Nil), (:))
import Data.List as List
import Data.List.Types (toList)
import Data.Maybe (Maybe(..))
import Data.String as String
import Data.Tuple (Tuple(..), fst, lookup)
import Data.Validation.Semigroup (invalid)
import Node.Optlicative.Types (ErrorMsg, OptError(..), OptState, Result, Value)

throwSingleError :: forall a. OptError -> Value a
throwSingleError = invalid <<< List.singleton

except :: forall a. OptError -> OptState -> Result a
except e state = {state, val: throwSingleError e}

removeHyphen :: Char -> OptState -> OptState
removeHyphen c os = os {hyphen = List.delete c os.hyphen}

removeDash :: String -> OptState -> OptState
removeDash name os =
  os {dash = List.deleteBy (eq `on` fst) (Tuple name "") os.dash}

removeFlag :: String -> OptState -> OptState
removeFlag name os = os {flags = List.delete name os.flags}

findHyphen :: Char -> OptState -> Boolean
findHyphen c {hyphen} = c `List.elem` hyphen

findFlag :: String -> OptState -> Boolean
findFlag name {flags} = name `List.elem` flags

findDash :: String -> OptState -> Maybe String
findDash name {dash} = lookup name dash

charList :: String -> List Char
charList = charList' Nil where
  charList' acc str = case String.uncons str of
    Just {head, tail} -> charList' (head : acc) tail  
    _ -> acc

initialize :: List String -> OptState
initialize = init {hyphen: Nil, dash: Nil, flags: Nil} where
  init acc (x : xs) = case String.take 2 x of -- case String.uncons x of
    "--" -> ddash (String.drop 2 x) acc xs
    _ -> case String.uncons x of
      Just {head: '-', tail} -> init (acc {hyphen = charList tail <> acc.hyphen}) xs
      _ -> acc
  init acc Nil = acc
  ddash x acc (y : ys) = case String.uncons y of
    Just {head: '-'} -> init (acc {flags = y : acc.flags}) ys
    Just _ -> init (acc {dash = Tuple x y : acc.dash}) ys
    _ -> init acc ys -- this is where we'd put passthrough logic
  ddash _ acc _ = acc

defaultError :: (ErrorMsg -> OptError) -> String -> String -> OptError
defaultError f name expected = case f "" of
  TypeError _ -> TypeError $
    "Option '" <> name <> "' expects an argument of type " <> expected <> "."
  MissingOpt _ -> MissingOpt $
    "Option '" <> name <> "' is required."
  UnrecognizedOpt _ -> UnrecognizedOpt name
  Custom _ -> Custom name

multipleErrorsToOptErrors :: MultipleErrors -> List OptError
multipleErrorsToOptErrors errs =
  let strerrs = map renderForeignError errs
      strlist = toList strerrs
  in  map Custom strlist

unrecognizedOpts :: forall a. OptState -> Value a
unrecognizedOpts {hyphen, dash, flags} =
  let
    hs = map show hyphen
    ds = map (show <<< fst) dash
    fs = map show flags
    all = hs <> ds <> fs
    errors = map UnrecognizedOpt all
  in
    invalid errors