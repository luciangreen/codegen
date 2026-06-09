:- begin_tests(stage6_starlog).

:- use_module('../src/starlog').

%% -------------------------------------------------------
%% Shared test specs
%% -------------------------------------------------------

map_spec(spec(double_all, _{
    name:        double_all,
    inputs:      [list(number)],
    outputs:     [list(number)],
    relation:    map,
    operation:   double,
    examples:    [io([1,2,3], [2,4,6])],
    constraints: [deterministic, order_preserved, same_length],
    warnings:    [],
    classification: code_only
})).

filter_spec(spec(keep_positive, _{
    name:        keep_positive,
    inputs:      [list(number)],
    outputs:     [list(number)],
    relation:    filter,
    operation:   positive,
    examples:    [io([-1, 2, -3, 4], [2, 4])],
    constraints: [deterministic, order_preserved],
    warnings:    [],
    classification: code_only
})).

fold_spec(spec(sum_list, _{
    name:        sum_list,
    inputs:      [list(number)],
    outputs:     [number],
    relation:    fold,
    operation:   add,
    examples:    [io([1,2,3], 6)],
    constraints: [deterministic],
    warnings:    [],
    classification: code_only
})).

%% -------------------------------------------------------
%% Feature 1: Result is function(Args) — value-returning syntax
%% -------------------------------------------------------

test(feature1_emit_produces_is_syntax) :-
    map_spec(Spec),
    starlog_emit_code(Spec, Code),
    sub_string(Code, _, _, _, "Output is"),
    sub_string(Code, _, _, _, "double_all(Input, Output)").

test(feature1_emit_ast_has_is_goal) :-
    map_spec(Spec),
    starlog_emit(Spec, starlog_pred(double_all, _Params, Goals)),
    member(is(var(output), _), Goals).

%% -------------------------------------------------------
%% Feature 2: String concatenation using :
%% -------------------------------------------------------

test(feature2_concat_expr_emits_colon) :-
    Expr = concat(var(a), var(b)),
    starlog:expr_to_str(Expr, Str),
    sub_string(Str, _, _, _, " : ").

test(feature2_concat_expands_to_atom_concat) :-
    AST = starlog_pred(join_atoms, [result, a, b],
            [is(var(result), concat(var(a), var(b)))]),
    starlog_expand(AST, expanded(join_atoms, Code)),
    sub_string(Code, _, _, _, "atom_concat").

%% -------------------------------------------------------
%% Feature 3: List append using &
%% -------------------------------------------------------

test(feature3_append_expr_emits_ampersand) :-
    Expr = append(var(a), var(b)),
    starlog:expr_to_str(Expr, Str),
    sub_string(Str, _, _, _, " & ").

test(feature3_append_expands_to_prolog_append) :-
    AST = starlog_pred(merge_lists, [result, a, b],
            [is(var(result), append(var(a), var(b)))]),
    starlog_expand(AST, expanded(merge_lists, Code)),
    sub_string(Code, _, _, _, "append(A, B, Result)").

%% -------------------------------------------------------
%% Feature 4: Nested RHS expressions
%% -------------------------------------------------------

test(feature4_nested_rhs_chain_emits_double_arrow) :-
    % Output is (Input >> map(double)) >> filter(positive)
    Expr = chain(chain(var(input), map(double)), filter(positive)),
    starlog:expr_to_str(Expr, Str),
    sub_string(Str, _, _, _, ">>"),
    sub_string(Str, _, _, _, "map(double)"),
    sub_string(Str, _, _, _, "filter(positive)").

test(feature4_nested_rhs_expands_to_two_stage_code) :-
    AST = starlog_pred(double_then_filter, [input, output], [
        is(var(output), chain(chain(var(input), map(double)), filter(positive)))
    ]),
    starlog_expand(AST, expanded(double_then_filter, Code)),
    sub_string(Code, _, _, _, "double_then_filter_step1"),
    sub_string(Code, _, _, _, "double_then_filter").

%% -------------------------------------------------------
%% Feature 5: Nested LHS expressions
%% -------------------------------------------------------

test(feature5_nested_lhs_emits_is_with_call_lhs) :-
    Goal = is(call(f, [var(input)]), chain(var(input), map(double))),
    starlog:goal_to_str(Goal, Str),
    sub_string(Str, _, _, _, "f("),
    sub_string(Str, _, _, _, " is ").

test(feature5_nested_lhs_expands_correctly) :-
    AST = starlog_pred(my_pred, [input, result], [
        is(call(f, [var(input)]), chain(var(input), map(double)))
    ]),
    starlog_expand(AST, expanded(my_pred, Code)),
    sub_string(Code, _, _, _, "nested LHS").

%% -------------------------------------------------------
%% Feature 6: Method chains using >>
%% -------------------------------------------------------

test(feature6_map_chain_emits_arrow) :-
    map_spec(Spec),
    starlog_emit_code(Spec, Code),
    sub_string(Code, _, _, _, ">>"),
    sub_string(Code, _, _, _, "map(double)").

test(feature6_filter_chain_emits_filter) :-
    filter_spec(Spec),
    starlog_emit_code(Spec, Code),
    sub_string(Code, _, _, _, ">>"),
    sub_string(Code, _, _, _, "filter(positive)").

test(feature6_fold_chain_emits_fold) :-
    fold_spec(Spec),
    starlog_emit_code(Spec, Code),
    sub_string(Code, _, _, _, ">>"),
    sub_string(Code, _, _, _, "fold(add,").

%% -------------------------------------------------------
%% Feature 7: Variable-bound Starlog goals
%% -------------------------------------------------------

test(feature7_bound_goal_emits_assignment) :-
    Goal = bound(output, is(var(output), chain(var(input), map(double)))),
    starlog:goal_to_str(Goal, Str),
    sub_string(Str, _, _, _, "Output").

test(feature7_bound_goal_expands) :-
    AST = starlog_pred(bound_example, [input, output], [
        bound(output, is(var(output), chain(var(input), map(double))))
    ]),
    starlog_expand(AST, expanded(bound_example, Code)),
    string(Code).

%% -------------------------------------------------------
%% Feature 8: Selective eval and no_eval
%% -------------------------------------------------------

test(feature8_eval_emits_eval_wrapper) :-
    Expr = eval(chain(var(input), map(double))),
    starlog:expr_to_str(Expr, Str),
    sub_string(Str, _, _, _, "eval(").

test(feature8_no_eval_emits_no_eval_wrapper) :-
    Expr = no_eval(chain(var(input), map(double))),
    starlog:expr_to_str(Expr, Str),
    sub_string(Str, _, _, _, "no_eval(").

test(feature8_eval_expands_inner_expression) :-
    AST = starlog_pred(eval_pred, [input, output], [
        is(var(output), eval(chain(var(input), map(double))))
    ]),
    starlog_expand(AST, expanded(eval_pred, Code)),
    sub_string(Code, _, _, _, "Y is X * 2").

test(feature8_no_eval_expands_to_unify) :-
    AST = starlog_pred(noeval_pred, [output], [
        is(var(output), no_eval(chain(var(input), map(double))))
    ]),
    starlog_expand(AST, expanded(noeval_pred, Code)),
    sub_string(Code, _, _, _, "Output = ").

%% -------------------------------------------------------
%% Feature 9: Arithmetic preservation
%% -------------------------------------------------------

test(feature9_arith_expr_preserved_in_emit) :-
    Expr = arith('X * 2'),
    starlog:expr_to_str(Expr, Str),
    sub_string(Str, _, _, _, "X * 2").

test(feature9_arith_goal_expands_with_is) :-
    AST = starlog_pred(scale, [input, output], [
        is(var(output), arith('X * 5'))
    ]),
    starlog_expand(AST, expanded(scale, Code)),
    sub_string(Code, _, _, _, "Output is").

test(feature9_map_expand_preserves_arith_goal) :-
    map_spec(Spec),
    starlog_expand_code(Spec, Code),
    sub_string(Code, _, _, _, "Y is X * 2").

%% -------------------------------------------------------
%% Feature 10: User-defined value-returning predicates
%% -------------------------------------------------------

test(feature10_user_call_emits_funcall_syntax) :-
    Expr = call(my_func, [var(input)]),
    starlog:expr_to_str(Expr, Str),
    sub_string(Str, _, _, _, "my_func(Input)").

test(feature10_user_call_expands_to_prolog_call) :-
    AST = starlog_pred(use_user_func, [input, result], [
        is(var(result), call(my_func, [var(input)]))
    ]),
    starlog_expand(AST, expanded(use_user_func, Code)),
    sub_string(Code, _, _, _, "my_func(Input, Result)").

%% -------------------------------------------------------
%% Combined: starlog_full/3
%% -------------------------------------------------------

test(starlog_full_returns_both_forms) :-
    map_spec(Spec),
    starlog_full(Spec, StarlogCode, PrologCode),
    sub_string(StarlogCode, _, _, _, ">>"),
    sub_string(PrologCode,  _, _, _, "Y is X * 2"),
    sub_string(PrologCode,  _, _, _, "double_all([], [])").

test(starlog_full_filter_expands_correctly) :-
    filter_spec(Spec),
    starlog_full(Spec, StarlogCode, PrologCode),
    sub_string(StarlogCode, _, _, _, "filter(positive)"),
    sub_string(PrologCode,  _, _, _, "X > 0").

test(starlog_full_fold_expands_correctly) :-
    fold_spec(Spec),
    starlog_full(Spec, StarlogCode, PrologCode),
    sub_string(StarlogCode, _, _, _, "fold(add,"),
    sub_string(PrologCode,  _, _, _, "Acc1 is Acc + X").

%% -------------------------------------------------------
%% emit_from_relation_op/4 (used by caw_codegen)
%% -------------------------------------------------------

test(emit_from_relation_op_map) :-
    emit_from_relation_op(double_all, map, double, Code),
    sub_string(Code, _, _, _, ">>"),
    sub_string(Code, _, _, _, "map(double)").

test(emit_from_relation_op_filter) :-
    emit_from_relation_op(keep_pos, filter, positive, Code),
    sub_string(Code, _, _, _, "filter(positive)").

:- end_tests(stage6_starlog).

