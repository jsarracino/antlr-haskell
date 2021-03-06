{-# LANGUAGE DeriveAnyClass, DeriveGeneric, FlexibleContexts #-}
{-|
  Module      : Text.ANTLR.Allstar
  Description : Entrypoint for using the ALL(*) parsing algorithm
  Copyright   : (c) Karl Cronburg, 2018
  License     : BSD3
  Maintainer  : karl@cs.tufts.edu
  Stability   : experimental
  Portability : POSIX

  This module contains the glue code for hooking Sam's
  'Text.ANTLR.Allstar.ParserGenerator' implementation into the rest of
  this package.
-}
module Text.ANTLR.Allstar
  ( parse, parse', atnOf
  , ALL.GrammarSymbol(..)
  , ALL.ATNEnv
  ) where

import qualified Text.ANTLR.Allstar.ParserGenerator as ALL

import qualified Text.ANTLR.Parser as P
import qualified Text.ANTLR.Grammar as G
import qualified Text.ANTLR.Allstar.ATN as ATN

import qualified Data.Set as DS
import qualified Text.ANTLR.Set as S

import Text.ANTLR.Pretty (Prettify(..))

-- | Go from an Allstar AST to the AST type used internally in this package
fromAllstarAST :: ALL.AST nts t -> P.AST nts t
fromAllstarAST (ALL.Node nt ruleFired asts) = P.AST nt (map fromAllstarSymbol ruleFired) (map fromAllstarAST asts)
fromAllstarAST (ALL.Leaf tok)     = P.Leaf tok

--   TODO: Handle predicate and mutator state during the conversion
-- | Go from an antlr-haskell Grammar to an Allstar ATNEnv. ALL(*) does not
--   currently support predicates and mutators.
atnOf :: (Ord nt, Ord t, S.Hashable nt, S.Hashable t) => G.Grammar s nt t dt -> ALL.ATNEnv nt t
atnOf g = DS.fromList (map convTrans (S.toList (ATN._Δ (ATN.atnOf g))))

-- | ATN Transition to AllStar version
convTrans (st0, e, st1) = (convState st0, convEdge e, convState st1)

-- | ATN State to AllStar version
convState (ATN.Start nt)        = ALL.Init nt
convState (ATN.Middle nt i0 i1) = ALL.Middle nt i0 i1
convState (ATN.Accept nt)       = ALL.Final nt

-- | ATN Edge to AllStar version
convEdge (ATN.NTE nt) = ALL.GS (ALL.NT nt)
convEdge (ATN.TE t)   = ALL.GS (ALL.T t)
convEdge (ATN.PE p)   = ALL.PRED True -- TODO
convEdge (ATN.ME m)   = ALL.PRED True -- TODO
convEdge ATN.Epsilon  = ALL.GS ALL.EPS

-- | Entrypoint to the ALL(*) parsing algorithm.
parse'
  :: ( P.CanParse nts tok, Prettify chr )
  => ALL.Tokenizer chr tok
  -> [chr]
  -> ALL.GrammarSymbol nts (ALL.Label tok)
  -> ALL.ATNEnv nts (ALL.Label tok)
  -> Bool
  -> Either String (P.AST nts tok)
parse' tokenizer inp s0 atns cache = fromAllstarAST <$> ALL.parse tokenizer inp s0 atns cache

-- | No tokenizer required (chr == tok):
parse
  :: ( P.CanParse nts tok )
  => [tok]
  -> ALL.GrammarSymbol nts (ALL.Label tok)
  -> ALL.ATNEnv nts (ALL.Label tok)
  -> Bool
  -> Either String (P.AST nts tok)
parse = let
    tokenizer [] = []
    tokenizer (t:ts) = [(t,ts)]
  in parse' tokenizer

convSymbol s = ALL.NT s

toAllstarSymbol :: G.ProdElem nts ts -> ALL.GrammarSymbol nts ts
toAllstarSymbol (G.NT nts) = ALL.NT nts
toAllstarSymbol (G.T  ts)  = ALL.T  ts
toAllstarSymbol (G.Eps)    = ALL.EPS

fromAllstarSymbol :: ALL.GrammarSymbol nts ts -> G.ProdElem nts ts
fromAllstarSymbol (ALL.NT nts) = (G.NT nts)
fromAllstarSymbol (ALL.T ts) = (G.T  ts)
fromAllstarSymbol ALL.EPS = G.Eps

