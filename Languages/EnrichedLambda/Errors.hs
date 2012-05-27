module Languages.EnrichedLambda.Errors (
  unbound_variable,
  cannot_unify,
  cannot_compare,
  memory_full,
  division_by_0,
  match_failure,
  parse_error,
  typing_error,
  eval_error) where
  unbound_variable v = "Unbound variable: " ++ show v
  
  cannot_unify te1 te2 = "Cannot unify: " ++ show te1 ++ "\n\twith: " ++ show te2
  
  cannot_compare te = "Cannot compare expressions of non simple type: " ++ show te
  
  memory_full = "Memory full"
  
  division_by_0 = "Division by 0"
  
  match_failure = "Match failure"
  
  parse_error err ex = Languages.EnrichedLambda.Errors.error "Parse" (show err) "expression" (show ex)
  
  typing_error err ex = Languages.EnrichedLambda.Errors.error "Typing" err "expression" (show ex)
  
  eval_error err ex = Languages.EnrichedLambda.Errors.error "Evaluation" err "expression" (show ex)
  
  error tp err wh w = tp ++ " error:\n" ++ err ++ "\nin " ++ wh ++ "\n\t" ++ w