{-# LANGUAGE ScopedTypeVariables, FlexibleInstances, MultiParamTypeClasses
  , DeriveGeneric, DeriveAnyClass #-}
module Text.ANTLR.Allstar.Grammar
  ( Referent(..), sameNTs, sameTerminals
  , ProdElem(..), ProdElems
  , Production(..), ProdRHS(..), StateFncn(..)
  , Predicate(..), Mutator(..)
  , Grammar(..)
  , defaultGrammar
  , isSem, isAction
  , isNT, isT, isEps, getNTs, getTs, getEps
  , prodsFor, getProds
  , validGrammar, hasAllNonTerms, hasAllTerms, startIsNonTerm
  , symbols, Hashable(..), Generic(..)
  ) where
import Prelude hiding (pi)

import qualified Text.ANTLR.Set as S
import Text.ANTLR.Set
  ( Set(..), empty, fromList, member, union
  , Hashable(..), Generic(..)
  )

import Text.ANTLR.Pretty

----------------------------------------------------------------
-- When we *Show* production elements, they should contain source location
-- information, but when we *compare* them, we should ignore the source info.

-- Something is "Referent" if it can be symbolized by some symbol in a set of
-- symbols. Symbols are typically Strings, an enum data type, or some other
-- Eq-able (best if finite) set of things.
class Referent ref where
  getSymbol :: ref -> String

sameNTs :: (Referent nt) => nt -> nt -> Bool
sameNTs nt0 nt1 = getSymbol nt0 == getSymbol nt1

sameTerminals :: (Referent t) => t -> t -> Bool
sameTerminals t0 t1 = getSymbol t0 == getSymbol t1

instance Referent ([] Char) where
  getSymbol = id

instance Referent (String, b) where
  getSymbol = fst

-- Grammar ProdElems:
data ProdElem nt t =
    NT nt
  | T  t
  | Eps
  deriving (Eq, Ord, Generic, Hashable)

instance (Show nt, Show t) => Show (ProdElem nt t) where
  show (NT nt) = show nt
  show (T   t) = show  t
  show Eps     = "ε"

isNT (NT _) = True
isNT _      = False

isT (T _) = True
isT _     = False

isEps Eps = True
isEps _   = False

getNTs = map (\(NT nt) -> nt) . filter isNT
getTs  = map (\(T t) -> t) . filter isT
getEps = map (\Eps -> Eps) . filter isEps -- no

type ProdElems nt t = [ProdElem nt t]

data StateFncn s =
    Pass                   -- No predicate or mutator
  | Sem    (Predicate s)   -- Semantic predicate
  | Action (Mutator s)     -- Mutator, ProdElems is always empty in this one
  deriving (Eq, Ord, Generic, Hashable)

instance Show (StateFncn s) where
  show Pass       = ""
  show (Sem p)    = show p
  show (Action a) = show a

data ProdRHS s nt t = Prod (StateFncn s) (ProdElems nt t)
  deriving (Eq, Ord, Generic, Hashable)

instance (Show s, Show nt, Show t) => Show (ProdRHS s nt t) where
  show (Prod sf ps) = show sf ++ ":" ++ show ps

isSem (Prod (Sem _) _) = True
isSem _ = False

isAction (Prod (Action _) _) = True
isAction _ = False

getProds = map (\(Prod _ ss) -> ss)

type Production s nt t = (nt, ProdRHS s nt t)

-- Get only the productions for the given nonterminal nt:
prodsFor ::
  forall s nt t nts ts. (Referent nt, Referent t)
  => Grammar s nt t -> nt -> [Production s nt t]
prodsFor g nt = let
    matchesNT :: Production s nt t -> Bool
    matchesNT (nt', _) = sameNTs nt' nt
  in filter matchesNT (ps g)

-- TODO: boiler plate auto deriving for "named" of a user defined type?

-- Predicates and Mutators act over some state. The String
-- identifiers should eventually correspond to source-level
-- e.g. location / allocation site information, i.e. two
-- predicates or mutators are equivalent iff they were
-- constructed from the same production rule.
data Predicate s = Predicate String (s -> Bool)

instance Eq (Predicate s) where
  Predicate p1 _ == Predicate p2 _ = p1 == p2

instance Ord (Predicate s) where
  Predicate p1 _ `compare` Predicate p2 _ = p1 `compare` p2

instance Show (Predicate s) where
  show (Predicate p1 _) = "π(" ++ show p1 ++ ")"

instance Hashable (Predicate s) where
  hashWithSalt salt (Predicate p1 _) = salt `hashWithSalt` p1

data Mutator   s = Mutator String (s -> s)

instance Eq (Mutator s) where
  Mutator m1 _ == Mutator m2 _ = m1 == m2

instance Ord (Mutator s) where
  Mutator m1 _ `compare` Mutator m2 _ = m1 `compare` m2

instance Show (Mutator s) where
  show (Mutator m1 _) = "µ(" ++ show m1 ++ ")"

instance Hashable (Mutator s) where
  hashWithSalt salt (Mutator m1 _) = salt `hashWithSalt` m1

data Grammar s nt t = G
  { ns  :: Set nt
  , ts  :: Set t
  , ps  :: [Production s nt t]
  , s0  :: nt
  , _πs :: Set (Predicate s)
  , _μs :: Set (Mutator   s)
  } deriving (Eq)

instance (Show s, Show nt, Show t, Hashable t, Eq t, Hashable nt, Eq nt) => Show (Grammar s nt t) where
  show G {ns = ns, ts = ts, ps = ps, s0 = s0, _πs = _πs, _μs = _μs}
    =    "Grammar: { ns = " ++ show ns
      ++ "           ts = " ++ show ts
      ++ "           ps = " ++ show ps
      ++ "           s0 = " ++ show s0
      ++ "           πs = " ++ show _πs
      ++ "           μs = " ++ show _μs

symbols
  :: (Referent nt, Referent t, Ord nt, Ord t, Hashable s, Hashable nt, Hashable t)
  => Grammar s nt t -> Set (ProdElem nt t)
symbols g = S.insert Eps $ S.map NT (ns g) `union` S.map T (ts g)

defaultGrammar
  :: forall s nt t. (Ord t, Hashable t)
  => Grammar s String t
defaultGrammar = G
  { ns  = empty
  , ts  = empty
  , ps  = []
  , s0  = ""
  , _πs = empty
  , _μs = empty
  }

validGrammar
  :: (Referent nt, Referent t, Eq nt, Ord nt, Eq t, Ord t, Hashable nt, Hashable t)
  => Grammar s nt t -> Bool
validGrammar g =
     hasAllNonTerms g
  && hasAllTerms g
  && startIsNonTerm g
--  && distinctTermsNonTerms g

hasAllNonTerms
  :: (Referent nt, Referent t, Eq nt, Ord nt, Hashable nt, Hashable t)
  => Grammar s nt t -> Bool
hasAllNonTerms g =
  ns g == (fromList . getNTs . concat . getProds . map snd $ ps g)

hasAllTerms
  :: (Referent nt, Referent t, Eq t, Ord t, Hashable nt, Hashable t)
  => Grammar s nt t -> Bool
hasAllTerms g =
  ts g == (fromList . getTs . concat . getProds . map snd $ ps g)

startIsNonTerm
  :: (Referent nt, Referent t, Ord nt, Hashable nt)
  => Grammar s nt t -> Bool
startIsNonTerm g = s0 g `member` ns g

--distinctTermsNonTerms g =
--  (ns g `intersection` ts g) == empty

