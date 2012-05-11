{-# LANGUAGE
  FlexibleContexts,
  NoMonomorphismRestriction
  #-}
module Compiler.Translations where
  import qualified Languages.MiniML.Syntax as ML
  import Languages.MiniML.PrettyPrint
  import qualified Languages.EnrichedLambda.Syntax as EL
  import Languages.EnrichedLambda.PrettyPrint
  
  constant_to_enriched_lambda :: ML.Constant -> EL.Constant
  constant_to_enriched_lambda (ML.C_Int n) = EL.C_Int n
  constant_to_enriched_lambda ML.C_False   = EL.C_False
  constant_to_enriched_lambda ML.C_True    = EL.C_True
  constant_to_enriched_lambda ML.C_Nil     = EL.C_Nil
  constant_to_enriched_lambda ML.C_Unit    = EL.C_Unit
  
  unary_prim_to_enriched_lambda :: ML.UnaryPrim -> EL.Expr
  unary_prim_to_enriched_lambda ML.U_Not     = EL.E_Function "v" (EL.E_Not $ EL.E_Var "v")
  unary_prim_to_enriched_lambda ML.U_Ref     = EL.E_Function "v" (EL.E_Ref $ EL.E_Var "v")
  unary_prim_to_enriched_lambda ML.U_Deref   = EL.E_Function "v" (EL.E_Deref $ EL.E_Var "v")
  unary_prim_to_enriched_lambda ML.U_I_Minus = EL.E_Function "v" (EL.E_Minus (EL.E_Const $ EL.C_Int 0) $ EL.E_Var "v")
  
  binary_prim_to_enriched_lambda :: ML.BinaryPrim -> EL.Expr
  binary_prim_to_enriched_lambda ML.B_Eq      = EL.E_Function "v1" $ EL.E_Function "v2" $ EL.E_Eq (EL.E_Var "v1") (EL.E_Var "v2")
  binary_prim_to_enriched_lambda ML.B_I_Plus  = EL.E_Function "v1" $ EL.E_Function "v2" $ EL.E_Plus (EL.E_Var "v1") (EL.E_Var "v2")
  binary_prim_to_enriched_lambda ML.B_I_Minus = EL.E_Function "v1" $ EL.E_Function "v2" $ EL.E_Minus (EL.E_Var "v1") (EL.E_Var "v2")
  binary_prim_to_enriched_lambda ML.B_I_Mult  = EL.E_Function "v1" $ EL.E_Function "v2" $ EL.E_Mult (EL.E_Var "v1") (EL.E_Var "v2")
  binary_prim_to_enriched_lambda ML.B_I_Div   = EL.E_Function "v1" $ EL.E_Function "v2" $ EL.E_Div (EL.E_Var "v1") (EL.E_Var "v2")
  binary_prim_to_enriched_lambda ML.B_Assign  = EL.E_Function "v1" $ EL.E_Function "v2" $ EL.E_Assign (EL.E_Var "v1") (EL.E_Var "v2")
  
  pattern_to_test :: ML.Pattern -> EL.Expr -> EL.Expr
  pattern_to_test (ML.P_Val _) _        = EL.E_Const EL.C_True
  pattern_to_test ML.P_Wildcard _       = EL.E_Const EL.C_True
  pattern_to_test (ML.P_Const c) e      = EL.E_Apply (EL.E_Function "v" $ EL.E_Eq (EL.E_Var "v") (EL.E_Const $ constant_to_enriched_lambda c)) e
  pattern_to_test (ML.P_Tuple [a,b]) e  = EL.E_ITE (pattern_to_test a (EL.E_Fst e)) (pattern_to_test b (EL.E_Snd e)) (EL.E_Const EL.C_False)
  pattern_to_test (ML.P_Tuple (p:ps)) e = EL.E_ITE (pattern_to_test p (EL.E_Fst e)) (pattern_to_test (ML.P_Tuple ps) (EL.E_Snd e)) (EL.E_Const EL.C_False)
  pattern_to_test (ML.P_Cons p1 p2) e   = EL.E_ITE (pattern_to_test p1 (EL.E_Head e)) (pattern_to_test p2 (EL.E_Tail e)) (EL.E_Const EL.C_False)
  
  pattern_to_variables :: ML.Pattern -> EL.Expr -> [(String, EL.Expr)]
  pattern_to_variables (ML.P_Val s) e        = [(s, e)]
  pattern_to_variables (ML.P_Wildcard) _     = []
  pattern_to_variables (ML.P_Const _) _      = []
  pattern_to_variables (ML.P_Tuple [a, b]) e = pattern_to_variables a (EL.E_Fst e) ++ pattern_to_variables b (EL.E_Snd e)
  pattern_to_variables (ML.P_Tuple (p:ps)) e = pattern_to_variables p (EL.E_Fst e) ++ pattern_to_variables (ML.P_Tuple ps) (EL.E_Snd e)
  pattern_to_variables (ML.P_Cons p1 p2) e   = pattern_to_variables p1 (EL.E_Head e) ++ pattern_to_variables p2 (EL.E_Tail e)
  
  expression_to_enriched_lambda :: ML.Expr -> EL.Expr
  expression_to_enriched_lambda (ML.E_UPrim up) = unary_prim_to_enriched_lambda up
  expression_to_enriched_lambda (ML.E_BPrim bp) = binary_prim_to_enriched_lambda bp
  expression_to_enriched_lambda (ML.E_Val vn) = EL.E_Var vn
  expression_to_enriched_lambda (ML.E_Const c) = EL.E_Const $ constant_to_enriched_lambda c
  expression_to_enriched_lambda (ML.E_Apply e1 e2) = EL.E_Apply (expression_to_enriched_lambda e1) (expression_to_enriched_lambda e2)
  expression_to_enriched_lambda (ML.E_Cons e1 e2) = EL.E_Cons (expression_to_enriched_lambda e1) (expression_to_enriched_lambda e2)
  expression_to_enriched_lambda (ML.E_Tuple ts) = tuple_to_pairs ts where
    tuple_to_pairs [a, b] = EL.E_Pair (expression_to_enriched_lambda a) (expression_to_enriched_lambda b)
    tuple_to_pairs (a:as) = EL.E_Pair (expression_to_enriched_lambda a) $ tuple_to_pairs as
  expression_to_enriched_lambda (ML.E_And e1 e2) = EL.E_ITE (expression_to_enriched_lambda e1) (expression_to_enriched_lambda e2) (EL.E_Const EL.C_False)
  expression_to_enriched_lambda (ML.E_Or e1 e2) = EL.E_ITE (expression_to_enriched_lambda e1) (EL.E_Const EL.C_True) (expression_to_enriched_lambda e2)
  expression_to_enriched_lambda (ML.E_ITE e1 e2 e3) = EL.E_ITE (expression_to_enriched_lambda e1) (expression_to_enriched_lambda e2) (expression_to_enriched_lambda e3)
  expression_to_enriched_lambda (ML.E_Seq e1 e2) = EL.E_Seq (expression_to_enriched_lambda e1) (expression_to_enriched_lambda e1)
  expression_to_enriched_lambda (ML.E_Function pms) = EL.E_Function v $ pm_to_ifs pms where
    v = "Arg"
    pm_to_ifs []          = EL.E_MatchFailure
    pm_to_ifs ((p,e):pms) = EL.E_ITE  (pattern_to_test p (EL.E_Var v)) (variables_to_application (expression_to_enriched_lambda e) (pattern_to_variables p (EL.E_Var v))) $ pm_to_ifs pms
    variables_to_application e []           = e
    variables_to_application e ((v, e'):vs) = variables_to_application (EL.E_Apply (EL.E_Function v e) e') vs
  expression_to_enriched_lambda (ML.E_Let (p, e1) e2) = EL.E_Let v (expression_to_enriched_lambda e1) $ to_lets $ pattern_to_variables p (EL.E_Var v) where
    v = "Let"
    to_lets []          = expression_to_enriched_lambda e2
    to_lets ((v, e):es) = EL.E_Let v e $ to_lets es
  expression_to_enriched_lambda (ML.E_LetRec [(s, pms)] e) = EL.E_Letrec s (expression_to_enriched_lambda $ ML.E_Function pms) (expression_to_enriched_lambda e)
  expression_to_enriched_lambda (ML.E_LetRec lrbs e) = EL.E_Letrec v (bindings_to_tuple v $ map (ML.E_Function . snd) lrbs) substed_e where
    v = "Letrec"
    substed_e = subst (map fst lrbs) (EL.E_Var v) (expression_to_enriched_lambda e)
    bindings_to_tuple v [a, b] = EL.E_Pair (subst (map fst lrbs) (EL.E_Var v) (expression_to_enriched_lambda a)) (subst (map fst lrbs) (EL.E_Var v) (expression_to_enriched_lambda b))
    bindings_to_tuple v (b:bs) = EL.E_Pair (subst (map fst lrbs) (EL.E_Var v) (expression_to_enriched_lambda b)) $ bindings_to_tuple v bs
    subst [vn] ex e   = apply_subst vn ex e
    subst (v:vs) ex e = subst vs (EL.E_Snd ex) $ apply_subst v (EL.E_Fst ex) e
    apply_subst s e1 (EL.E_Var ss)
      | s == ss   = e1
      | otherwise = (EL.E_Var ss) 
    apply_subst s e1 (EL.E_Not e2)       = EL.E_Not $ apply_subst s e1 e2
    apply_subst s e1 (EL.E_Ref e2)       = EL.E_Ref $ apply_subst s e1 e2
    apply_subst s e1 (EL.E_Deref e2)     = EL.E_Deref $ apply_subst s e1 e2
    apply_subst s e1 (EL.E_Head e2)      = EL.E_Head $ apply_subst s e1 e2
    apply_subst s e1 (EL.E_Tail e2)      = EL.E_Tail $ apply_subst s e1 e2
    apply_subst s e1 (EL.E_Fst e2)       = EL.E_Fst $ apply_subst s e1 e2
    apply_subst s e1 (EL.E_Snd e2)       = EL.E_Snd $ apply_subst s e1 e2
    apply_subst s e1 (EL.E_Plus e2 e3)   = EL.E_Plus (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_Minus e2 e3)  = EL.E_Minus (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_Div e2 e3)    = EL.E_Div (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_Mult e2 e3)   = EL.E_Mult (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_Assign e2 e3) = EL.E_Assign (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_Cons e2 e3)   = EL.E_Cons (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_Seq e2 e3)    = EL.E_Seq (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_Pair e2 e3)   = EL.E_Pair (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_Apply e2 e3)  = EL.E_Apply (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 (EL.E_ITE e2 e3 e4) = EL.E_ITE (apply_subst s e1 e2) (apply_subst s e1 e3) (apply_subst s e1 e4)
    apply_subst s e1 e@(EL.E_Let v e2 e3)
      | s == v    = e
      | otherwise = EL.E_Let v (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 e@(EL.E_Letrec v e2 e3)
      | s == v    = e
      | otherwise = EL.E_Letrec v (apply_subst s e1 e2) (apply_subst s e1 e3)
    apply_subst s e1 e@(EL.E_Function v e2)
      | s == v    = e
      | otherwise = EL.E_Function v (apply_subst s e1 e2)
    apply_subst _ _ e                    = e
  
  program_to_expression :: ML.Program -> ML.Expr
  program_to_expression [ML.IDF (ML.D_Let lb)]           = ML.E_Let lb (ML.E_Const ML.C_Unit)
  program_to_expression [ML.IDF (ML.D_LetRec lrbs)]      = ML.E_LetRec lrbs (ML.E_Const ML.C_Unit)
  program_to_expression [ML.IEX e]                       = e
  program_to_expression ((ML.IDF (ML.D_Let lb)):is)      = ML.E_Let lb $ program_to_expression is
  program_to_expression ((ML.IDF (ML.D_LetRec lrbs)):is) = ML.E_LetRec lrbs $ program_to_expression is
  program_to_expression ((ML.IEX e):is)                  = ML.E_Let (ML.P_Val "it", e) $ program_to_expression is
  
  program_to_enriched_lambda :: ML.Program -> EL.Expr
  program_to_enriched_lambda = expression_to_enriched_lambda . program_to_expression
