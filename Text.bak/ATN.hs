module Text.ATN where

-- ATN        - graph represented by type Transition and datatype State
-- Transition - represents ContextFree, Predicated, Mutated, Epsilon transitions
--              using ProdElem datatype used in Grammar
-- State      - Start, Branch, and Final states all contain name of submachine
--              nonterminal (the production rule name). Start has list of 
--              branches represented as transitions. Each branch contains all
--              states in submachine until Final, since by invariant of ATN
--              construction, branching only happens from start node.

type Transition = ProdElem
type Edge = (NonTerminal, State, State)

type AtnE = [(NonTerminal, [Transition])]

data ATN =

-- !!! Find a better way to deal with this!!! I don't think we even need index
-- Return to this with SLLPredict
-- !!! Include checks for edge cases !!!!!!
getBranch       (Start (nt, branches)) i = (Branch nt (branches!!i))
getName state = case of (Start (nt, branches))  -> nt
                        (Branch (nt, trans))    -> nt
                        (Final nt)              -> nt
mapBranches     (Start (nt, branches)) f = map f branches
existsBranches  (Start (nt, branches)) f = exists f branches
-- INPUT: Grammar g
-- OUTPUT: ATN corresponding to g. Internally, we only need set of starting 
--         nodes E, represented as [(NonTerminal, [Transition])]
toAtn :: Grammar -> atnE
toAtn g = (gP g)

getTransitions :: ATN -> NonTerminal -> [Edge]
getTransitions = undefined

getStartState :: ATN -> NonTerminal -> State
getStartState = undefined

getNextState :: ATN -> State -> State
getNextState = undefined