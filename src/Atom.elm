module Atom exposing ( Base
                     , Sign(..)
                     , swap
                     , baseExpand
                     , baseExpandPad
                     , baseContract
                     , mixBase
                     , Byte
                     , byte
                     , zero
                     , value
                     , SmallWord
                     , Word
                     , wordExpand
                     , wordContract
                     , Mask(..)
                     , Masks
                     , maskFilter
                     , copy
                     , wordValue
                     , smallWordValue
                     )

type alias Base = Int
type Sign = Pos | Neg

swap : Sign -> Sign
swap s = case s of
             Pos -> Neg
             Neg -> Pos

-- little endian
baseExpandUnsignedLittle : Base -> Int -> List Int
baseExpandUnsignedLittle b n = if n < b
                               then [n]
                               else let r    = n % b
                                        q    = n // b
                                        rest = baseExpandUnsignedLittle b q
                                    in r :: rest

-- big endian
baseExpandUnsigned b n = List.reverse <| baseExpandUnsignedLittle b n

baseExpandUnsignedPad b n l = let u = baseExpandUnsigned b n
                                  len = List.length u
                              in (List.repeat (l - len) 0) ++ u
                         
baseExpand : Base -> Int -> (Sign,List Int)
baseExpand b n = if n < 0
                 then (Neg, baseExpandUnsigned b <| -n)
                 else (Pos, baseExpandUnsigned b n)

baseExpandPad : Base -> Int -> Int -> (Sign,List Int)
baseExpandPad b n l = if n < 0
                 then (Neg, baseExpandUnsignedPad b (-n) l)
                 else (Pos, baseExpandUnsignedPad b n l)

-- little endian
baseContractUnsignedLittle : Base -> List Int -> Int
baseContractUnsignedLittle b ns = let l = List.length ns
                                      is = List.range 0 <| l - 1
                                      ps = List.map ( (^) b ) is
                                  in List.sum <| List.map2 (*) ns ps

-- big endian
baseContractUnsigned b ns = baseContractUnsignedLittle b <| List.reverse ns

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

Also, our implementation is big endian. That is, in base 10

[7,0,1] --> 701

-}

type Byte = Byte Int

byte : Int -> Byte
byte n = Byte <| n % mixBase

zero = byte 0
         
value : Byte -> Int
value (Byte v) = v


-- Mix words
type alias SmallWord = ( Sign, Byte, Byte )
type alias Word      = ( Sign, Byte, Byte, Byte, Byte, Byte )

-- We need to be precise about casting between words and small words
wordExpand : SmallWord -> Word
wordExpand (s,i1,i2) = (s,zero,zero,zero,i1,i2)

wordContract : Word -> SmallWord
wordContract (s,a1,a2,a3,a4,a5) = (s,a4,a5)

{-

Knuth uses a somewhat strange masking convention. We can do better!
A word contains 6 fields. To get all possible masks, we need 64 different values. 
This fits into one Knuth byte.
To extract the mask, expand base 2.

-}

type Mask = On | Off
type alias Masks = (Mask,Mask,Mask,Mask,Mask,Mask)

maskFilter : Mask -> a -> a -> a
maskFilter m x y = case m of
                       On -> y
                       Off -> x

    
wordValue : Word -> Int
wordValue (s,b1,b2,b3,b4,b5) =
    baseContract mixBase (s, List.map value [b1,b2,b3,b4,b5])
            
smallWordValue : SmallWord -> Int
smallWordValue (s,b1,b2) =
    baseContract mixBase (s,List.map value [b1,b2])
   
{-

In copy ms w1 w2, we are imprinting w1 onto w2.
If a mask is on, the corresponding field in w2 is unchanged.

-}

copy : Masks -> Word -> Word -> Word
copy (m1,m2,m3,m4,m5,m6) w1 w2 =
    map62
    (maskFilter m1)
    (maskFilter m2)
    (maskFilter m3)
    (maskFilter m4)
    (maskFilter m5)
    (maskFilter m6) w1 w2

map3 : (a1 -> b1) -> (a2 -> b2) -> (a3 -> b3) -> (a1,a2,a3) -> (b1,b2,b3)
map3 f g h (x,y,z) = (f x, g y, h z)

map6 : (a1 -> b1)
     -> (a2 -> b2)
     -> (a3 -> b3)
     -> (a4 -> b4)
     -> (a5 -> b5)
     -> (a6 -> b6)
     -> (a1,a2,a3,a4,a5,a6) -> (b1,b2,b3,b4,b5,b6)   
map6 f g h i j k (x,y,z,w,p,q) = (f x, g y, h z, i w, j p, k q)

map62 : (a1 -> b1 -> c1)
     -> (a2 -> b2 -> c2)
     -> (a3 -> b3 -> c3)
     -> (a4 -> b4 -> c4)
     -> (a5 -> b5 -> c5)
     -> (a6 -> b6 -> c6)
     -> (a1,a2,a3,a4,a5,a6) -> (b1,b2,b3,b4,b5,b6) -> (c1,c2,c3,c4,c5,c6)   
map62 f g h i j k (x,y,z,w,p,q) (xx,yy,zz,ww,pp,qq)
    = (f x xx, g y yy, h z zz, i w ww, j p pp, k q qq)
