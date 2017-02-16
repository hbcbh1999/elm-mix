module Atom exposing ( Sign(..)
                     , baseExpand
                     , baseContract
                     , Byte
                     , byte
                     , value
                     , mixBase
                     )

type alias Base = Int
type Sign = Pos | Neg
    
baseExpandUnsigned : Base -> Int -> List Int
baseExpandUnsigned b n = if n < b
                         then [n]
                         else let r    = n % b
                                  q    = n // b
                                  rest = baseExpandUnsigned b q
                              in r :: rest

baseExpand : Base -> Int -> (Sign,List Int)
baseExpand b n = if n < 0
                 then (Neg, baseExpandUnsigned b <| -n)
                 else (Pos, baseExpandUnsigned b n)
                                  
baseContractUnsigned : Base -> List Int -> Int
baseContractUnsigned b ns = let l = List.length ns
                                is = List.range 0 <| l - 1
                                ps = List.map ( (^) b ) is
                            in List.sum <| List.map2 (*) ns ps


baseContract : Base -> (Sign,List Int) -> Int
baseContract b (s,ns) = case s of
                            Pos -> baseContractUnsigned b ns
                            Neg -> negate <| baseContractUnsigned b ns


-- each byte can hold 100 distinct values
mixBase = 10^2

{-
Note:
Using mixBase = 10^2 seems like a good design choice.
It allows us to gauge the value of a register by inspecting the sequence of bytes.
-}

type Byte = Byte Int

byte : Int -> Byte
byte n = Byte <| n % mixBase

value : Byte -> Int
value (Byte v) = v
