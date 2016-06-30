{-@ LIQUID "--higherorder"     @-}
{-@ LIQUID "--totality"        @-}
{-@ LIQUID "--exact-data-cons" @-}
{-@ LIQUID "--alphaequivalence"  @-}
{-@ LIQUID "--betaequivalence"  @-}


{-# LANGUAGE IncoherentInstances   #-}
{-# LANGUAGE FlexibleContexts      #-}

module MonadReader where

import Prelude hiding (return, Maybe(..), (>>=))

import Proves
import Helper 

-- | Monad Laws :
-- | Left identity:	  return a >>= f  ≡ f a
-- | Right identity:	m >>= return    ≡ m
-- | Associativity:	  (m >>= f) >>= g ≡	m >>= (\x -> f x >>= g)

{-@ data Reader r a = Reader { runIdentity :: r -> a } @-}
data Reader r a     = Reader { runIdentity :: r -> a }

{-@ axiomatize return @-}
return :: a -> Reader r a
return x = Reader (\r -> x)

{-@ axiomatize bind @-}
bind :: Reader r a -> (a -> Reader r b) -> Reader r b
bind (Reader x) f = Reader (\r -> fromReader (f (x r)) r)

{-@ measure fromReader @-}
fromReader :: Reader r a -> r -> a 
fromReader (Reader f) = f

-- NV TODO the following is needed because Reader is not interpreted by
-- Contraints.Generate.lamExpr

{-@ axiomatize reader @-}
reader x = Reader x 

 
{-@ readerId :: f:(Reader r a) -> {f == Reader (fromReader f)} @-} 
readerId :: (Reader r a) -> Proof 
readerId (Reader f)  
  =   Reader (fromReader (Reader f))
  ==! Reader f 
  *** QED 

-- | Left Identity
{-@ left_identity :: x:a -> f:(a -> Reader r b) -> { bind (return x) f == f x } @-}
left_identity :: Arg r => a -> (a -> Reader r b) -> Proof
left_identity x f
  =   bind (return x) f 
  ==! bind (Reader (\r -> x)) f
  ==! Reader (\r' -> fromReader (f ((\r -> x) r')) r')
  ==! Reader (\r' -> fromReader (f x) r')
  ==! Reader (fromReader (f x)) ? lambda_expand (fromReader (f x))
  ==! f x                       ? readerId (f x)
  *** QED 

-- | Right Identity


{-@ right_identity :: x:Reader r a -> { bind x return == x }
 @-}
right_identity :: Arg r => Reader r a -> Proof
right_identity (Reader x)
  =   bind (Reader x) return
  ==! Reader (\r -> fromReader (return (x r)) r)
  ==! Reader (\r -> fromReader (reader (\r' ->  (x r))) (r))
       ? right_identity_helper x 
  ==! Reader (\r -> (\r' ->  (x r)) (r)) 
       ? right_identity_helper1 x 
  ==! Reader (\r -> x r)           
       -- ? right_identity_helper2 x       
  ==! Reader x                           
       ? lambda_expand x 
  *** QED 


right_identity_helper1 :: Arg r => (r -> a) -> Proof 
{-@ right_identity_helper1 :: Arg r => x:(r -> a) 
  -> {(\r:r -> fromReader (reader (\r':r ->  (x r))) (r)) == (\r:r -> (\r':r ->  (x r)) (r))} @-}
right_identity_helper1 x =
  ((\r -> (\r' ->  (x r)) (r)) =*=! (\r -> fromReader (reader (\r' ->  (x r))) (r)))
    (right_identity_helper1_body x) *** QED 


right_identity_helper1_body :: Arg r => (r -> a) -> r -> Proof 
{-@ right_identity_helper1_body :: Arg r => x:(r -> a) -> r:r 
  -> {(fromReader (reader (\r':r ->  (x r))) (r) == (\r':r ->  (x r)) (r))
    && ((\r:r -> fromReader (reader (\r':r ->  (x r))) (r)) (r) == (fromReader (reader (\r':r ->  (x r))) (r))) 
    && ((\r:r -> (\r':r ->  (x r)) (r)) (r) == ((\r':r ->  (x r)) (r)))
    } @-}
right_identity_helper1_body x r
  =  fromReader (reader (\r' -> (x r))) r 
  ==! (\r' -> x r) r 
  *** QED 


right_identity_helper2 :: Arg r => (r -> a) -> Proof 
{-@ right_identity_helper2 :: Arg r => x:(r -> a) 
  -> { (\r:r -> (\r':r ->  (x r)) (r)) ==  (\r:r -> x r) } @-}
right_identity_helper2 _ = simpleProof


right_identity_helper :: Arg r => (r -> a) -> Proof 
{-@ right_identity_helper :: Arg r => x:(r -> a) 
  -> {(\r:r -> fromReader (return (x r)) r) == (\r:r -> fromReader (reader (\r':r ->  (x r))) (r))} @-}
right_identity_helper x
  =  (
     (\r -> fromReader (return (x r)) r)
     =*=! 
     (\r -> fromReader (reader (\r' ->  (x r))) (r))
     )  (right_identity_helper_body x) *** QED 

right_identity_helper_body :: Arg r => (r -> a) -> r -> Proof 
{-@ right_identity_helper_body :: Arg r => x:(r -> a) -> r:r
  -> { (fromReader (return (x r)) r == fromReader (reader (\r':r ->  (x r))) (r))
       && (((\r:r -> fromReader (return (x r)) r)) (r) == (fromReader (return (x r)) r))
       && ((\r:r -> fromReader (reader (\r':r ->  (x r))) (r))(r) == (fromReader (reader (\r':r ->  (x r))) (r)))
      } @-}
right_identity_helper_body x r 
  =   fromReader (return (x r)) r
  ==! fromReader (reader (\r' ->  (x r))) r
  *** QED 

{- 

-- | Associativity:	  (m >>= f) >>= g ≡	m >>= (\x -> f x >>= g)

{- associativity :: m:Reader r a -> f: (a -> Reader r b) -> g:(b -> Reader r c)
  -> {bind (bind m f) g == bind m (\x:a -> (bind (f x) g)) } @-}
associativity :: Reader r a -> (a -> Reader r b) -> (b -> Reader r c) -> Proof
associativity (Reader x) f g
  =   bind (bind (Reader x) f) g
  -- unfold inner bind 
  ==! bind (Reader (\r1 -> fromReader (f (x r1)) r1)) g
  -- unfold outer bind 
  ==! Reader (\r2 -> fromReader (g ((\r1 -> fromReader (f (x r1)) r1) r2)) r2)
  -- apply    r1 := r2
  ==! Reader (\r2 -> fromReader (g (fromReader (f (x r2)) r2) )  r2)
  -- abstract r3 := r2 
  ==! Reader (\r2 -> 
          (\r3 -> fromReader (g ((fromReader (f (x r2))) r3) ) r3)
         r2)
  -- apply measure fromReader (Reader f) == f 
  ==! Reader (\r2 -> fromReader (
          (Reader (\r3 -> fromReader (g ((fromReader (f (x r2))) r3) ) r3))
        ) r2)
  -- abstract r4 := x r2 
  ==! Reader (\r2 -> fromReader ((\r4 -> 
          (Reader (\r3 -> fromReader (g ((fromReader (f r4)) r3) ) r3))
        ) (x r2)) r2)
  -- fold (bind (f r4) g)
  ==! Reader (\r2 -> fromReader ((\r4 -> 
           (bind (f r4) g)
        ) (x r2)) r2)
  -- fold bind 
  ==! bind (Reader x) (\r4 ->(bind (f r4) g))
  *** QED  
-}

{-@ qual :: f:(r -> a) -> {v:Reader r a | v == Reader f} @-}
qual :: (r -> a) -> Reader r a 
qual = Reader 