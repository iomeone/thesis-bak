{-# LANGUAGE 
  FlexibleInstances,
  TypeSynonymInstances,
  IncoherentInstances
  #-}

module Languages.EnrichedLambda.PrettyPrint () where 
  import Utils.Iseq

  import Languages.EnrichedLambda.Syntax

  isInfix :: BinaryPrim -> Bool
  isInfix _ = True

  isAtomicExpr :: Expr -> Bool
  isAtomicExpr (E_Val _)      = True
  isAtomicExpr (E_Num _)      = True
  isAtomicExpr (E_Location _) = True
  isAtomicExpr _              = False

  isAtomicValue :: Value -> Bool
  isAtomicValue (V_UPrim _)    = True
  isAtomicValue (V_BPrim _)    = True
  isAtomicValue V_Unit         = True
  isAtomicValue (V_Int _)      = True
  isAtomicValue (V_Bool _)     = True
  isAtomicValue (V_List [])    = True
  isAtomicValue (V_List (_:_)) = False
  isAtomicValue (V_Pair _ _)   = True
  isAtomicValue (V_Fun _)      = True

  isAtomicType :: Type -> Bool
  isAtomicType (T_Arrow _ _)        = False
  isAtomicType (T_Defined 2 [_])    = False
  isAtomicType (T_Ref _)            = False
  isAtomicType _                    = True

  pprUnaryPrim :: UnaryPrim -> Iseq
  pprUnaryPrim U_Not    = iStr "not"
  pprUnaryPrim U_Ref    = iStr "!"
  pprUnaryPrim U_Deref  = iStr "&"
  pprUnaryPrim U_Head   = iStr "hd"
  pprUnaryPrim U_Tail   = iStr "tl"
  pprUnaryPrim U_Fst    = iStr "fst"
  pprUnaryPrim U_Snd    = iStr "snd"
  
  instance Show UnaryPrim where
    show = show . pprUnaryPrim

  pprBinaryPrim :: BinaryPrim -> Iseq
  pprBinaryPrim B_Eq      = iStr "=="
  pprBinaryPrim B_Plus    = iStr "+"
  pprBinaryPrim B_Minus   = iStr "-"
  pprBinaryPrim B_Mult    = iStr "*"
  pprBinaryPrim B_Div     = iStr "/"
  pprBinaryPrim B_Assign  = iStr ":="
  pprBinaryPrim B_And     = iStr "&&"
  pprBinaryPrim B_Or      = iStr "||"

  instance Show BinaryPrim where
    show = show . pprBinaryPrim

  pprAExpr :: Expr -> Iseq
  pprAExpr e
    | isAtomicExpr e = pprExpr e
    | otherwise      = iStr "(" `iAppend` pprExpr e `iAppend` iStr ")"

  pprLetBindings :: [LetBinding] -> Iseq
  pprLetBindings defns = iInterleave sep (map pprLetBinding defns) where
    sep = iConcat [ iStr " and", iNewline ]
  
  pprLetBinding :: LetBinding -> Iseq
  pprLetBinding (n, e) = iConcat [ iStr n, iStr " = ", iIndent (pprExpr e) ]

  pprClause :: Clause -> Iseq
  pprClause (typeTag, constrTag, vars, expr) = 
    iConcat [iStr "<", iStr $ show typeTag, iStr ",", iStr $ show constrTag,
             iInterleave (iStr " ") $ (iStr ">") : map iStr vars,
             iStr " -> ", pprExpr expr]

  pprClauses :: [Clause] -> Iseq
  pprClauses cls = iInterleave iNewline (map pprClause cls)

  pprExpr :: Expr -> Iseq
  pprExpr (E_UPrim up)                           =
    pprUnaryPrim up
  pprExpr (E_BPrim bp)                           =
    pprBinaryPrim bp
  pprExpr (E_Val ident)                          =
    iStr ident
  pprExpr (E_Num n)                              =
    iStr $ show n
  pprExpr (E_Location n)                         =
    (iStr "Mem@") `iAppend` (iStr $ show n)
  pprExpr (E_Constr tp t a)                      =
    iStr "Pack{" `iAppend` 
    iInterleave (iStr ",") [iStr $ show tp, iStr $ show t, iStr $ show a] `iAppend`
    iStr "}"
  pprExpr (E_Seq e1 e2)                          =
    iConcat [ iNewline, indentation, iIndent $ pprExpr e1, iStr ";", 
              iNewline, indentation, iIndent $ pprExpr e2]
  pprExpr (E_Apply (E_Apply (E_BPrim bp) e1) e2)
    | isInfix bp                                 =
      iConcat [ pprAExpr e1, iStr " ", pprBinaryPrim bp, 
                iStr " ", pprAExpr e2]
  pprExpr (E_Apply e1 e2)                        =
    (pprExpr e1) `iAppend` (iStr " ") `iAppend` (pprAExpr e2)
  pprExpr (E_Rescue e1 e2)                       =
    iConcat [ iStr "try", iNewline,
              indentation, iIndent $ pprExpr e1, iNewline,
              iStr "rescue", iNewline,
              indentation, iIndent $ pprExpr e2 ]
  pprExpr (E_Let bs e)                           =
    iConcat [ iStr "let", iNewline,
              indentation, iIndent $ pprLetBindings bs,
              iNewline, iStr "in", iNewline,
              indentation, iIndent $ pprExpr e ]
  pprExpr (E_LetRec bs e)                        =
    iConcat [ iStr "letrec", iNewline,
              indentation, iIndent $ pprLetBindings bs,
              iNewline, iStr "in ",
              indentation, iIndent $ pprExpr e ]
  pprExpr (E_Case e cs)                          =
    iConcat [ iStr "case ", pprExpr e, iStr " of", iNewline,
              indentation, iIndent $ pprClauses cs]
  pprExpr (E_Function var e)                     =
    iConcat [ iStr "function ", iStr var, 
              iStr " -> ", pprExpr e]
  pprExpr E_MatchFailure                         =
    iStr "Match_Failure"

  instance Show Expr where
    show = show . pprExpr

  pprAValue :: Value -> Iseq
  pprAValue v
    | isAtomicValue v = pprValue v
    | otherwise       = iStr "(" `iAppend` pprValue v `iAppend` iStr ")"

  pprValue :: Value -> Iseq
  pprValue (V_UPrim up)     = iConcat [ iStr "<", 
                                        pprUnaryPrim up,
                                        iStr ">" ]
  pprValue (V_BPrim bp)     = iConcat [ iStr "<",
                                        pprBinaryPrim bp,
                                        iStr ">" ]
  pprValue V_Unit           = iStr . show $ ()
  pprValue (V_Int n)        = iStr . show $ n
  pprValue (V_Bool b)       = iStr . show $ b
  pprValue (V_List [])      = iStr "[]"
  pprValue (V_List (v:vs))  = pprAValue v `iAppend` 
                              iStr "::" `iAppend`
                              (pprAValue $ V_List vs)
  pprValue (V_Pair a b)     = iConcat [ iStr "(",  
                                        pprAValue a,
                                        iStr ", ",
                                        pprAValue b,
                                        iStr ")" ]
  pprValue (V_Fun _)        = iStr "Function."

  instance Show Value where
    show = show . pprValue

  pprBinding :: Binding -> Iseq
  pprBinding (ident, vars, e) =
    iConcat [ iStr ident, 
              iInterleave (iStr " ") $ map iStr vars,
              iStr " = ", pprExpr e]

  pprBindings :: Bool -> [Binding] -> Iseq
  pprBindings recursive bs = iInterleave sep $ map pprBinding bs where
    sep
      | not recursive = iNewline `iAppend` iStr "and "
      | recursive     = iNewline `iAppend` iStr "   and "

  pprDefinition :: Definition -> Iseq
  pprDefinition (D_Let bs) = 
    iConcat [ iStr "let ", pprBindings False bs]
  pprDefinition (D_LetRec bs) = 
    iConcat [ iStr "letrec ", pprBindings False bs]

  instance Show Definition where
    show = show . pprDefinition

  pprProgram :: Program -> Iseq
  pprProgram ([],   expr) =
    iConcat [pprExpr expr, iStr ";;", iNewline]
  pprProgram (defs, expr) = 
    iConcat [ iInterleave sep (map pprDefinition defs), sep,
              pprExpr expr, sep] where
                sep = iConcat [iStr ";;", iNewline]

  instance Show Program where
    show = show . pprProgram

  pprAType :: Type -> Iseq
  pprAType te
    | isAtomicType te = pprType te
    | otherwise       = iStr "(" `iAppend` pprType te `iAppend` iStr ")"

  pprType :: Type -> Iseq
  pprType (T_Var v)              =
    iStr v
  pprType (T_Arrow tp1 tp2)      =
    pprAType tp1 `iAppend` iStr " -> " `iAppend` pprType tp2
  pprType (T_Ref tp)             =
    pprAType tp `iAppend` iStr " ref"
  pprType (T_Defined 0 [])       =
    iStr "Bool"
  pprType (T_Defined 1 [])       =
    iStr "Unit"
  pprType (T_Defined 2 [t])      =
    pprAType t `iAppend` iStr " list"
  pprType (T_Defined 3 [t1, t2]) =
    iConcat [ iStr "(", pprType t1,
              iStr ", ", pprType t2,
              iStr ")" ]


  instance Show Type where
    show = show . pprType
