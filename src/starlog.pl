:- module(starlog, [
    starlog_emit/2,
    starlog_emit_code/2,
    starlog_expand/2,
    starlog_expand_code/2,
    starlog_full/3,
    emit_from_relation_op/4
]).

%% =========================================================
%% Stage 6: Starlog Integration
%%
%% Starlog AST term types:
%%   Goals (clause body):
%%     is(LHS, RHS)           - LHS is RHS  (feature 1)
%%     bound(Var, Goal)       - variable-bound goal (feature 7)
%%     goal_call(Name, Args)  - plain predicate call
%%
%%   Expressions (RHS of is/2, or nested):
%%     var(Name)              - variable (input/output/result/...)
%%     chain(Expr, Method)    - Expr >> Method  (feature 6)
%%     concat(A, B)           - A : B  (feature 2)
%%     append(A, B)           - A & B  (feature 3)
%%     call(Name, Args)       - Name(Args) value-returning (features 1, 10)
%%     eval(Expr)             - eval(Expr) selective eval (feature 8)
%%     no_eval(Expr)          - no_eval(Expr) selective no-eval (feature 8)
%%     arith(Expr)            - arithmetic expression preserved (feature 9)
%%     lit(Value)             - literal atom/number
%%
%%   Nested expressions (features 4, 5):
%%     Nested RHS: chain(chain(E, M1), M2)
%%     Nested LHS: is(call(f,[var(x)]), chain(var(input), map(Op)))
%%
%%   Methods (used in chain/2):
%%     map(Op)                - map operation
%%     filter(Op)             - filter operation
%%     fold(Op, Init)         - fold/reduce
%%     method(Name)           - generic method
%%
%%   Clause:
%%     starlog_pred(Name, Params, Goals)
%%       Params: list of atom names (input, output, result, a, b, ...)
%%
%% =========================================================

%% =========================================================
%% Emission: Spec → Starlog AST
%% =========================================================

%% starlog_emit(+Spec, -StarlogPred)
starlog_emit(spec(Name, Dict), starlog_pred(Name, Params, Goals)) :-
    Relation = Dict.get(relation),
    Operation = Dict.get(operation),
    emit_pred_body(Name, Relation, Operation, Params, Goals).

%% Emit from relation + operation (used by caw_codegen)
emit_from_relation_op(Name, Relation, Operation, Code) :-
    emit_pred_body(Name, Relation, Operation, Params, Goals),
    params_str(Params, ParamsStr),
    goals_str(Goals, GoalsStr),
    format(string(Code),
        "~w(~w) :-~n    ~w.",
        [Name, ParamsStr, GoalsStr]).

%% Emission rules per relation
emit_pred_body(_Name, map, Op, [input, output],
    [is(var(output), chain(var(input), map(Op)))]) :- !.

emit_pred_body(_Name, filter, Op, [input, output],
    [is(var(output), chain(var(input), filter(Op)))]) :- !.

emit_pred_body(_Name, fold, Op, [input, output],
    [is(var(output), chain(var(input), fold(Op, 0)))]) :- !.

emit_pred_body(_Name, _Relation, _Op, [input, output],
    [is(var(output), call(transform, [var(input)]))]).

%% =========================================================
%% Emission: Starlog AST → Code String
%% =========================================================

%% starlog_emit_code(+Spec, -Code)
starlog_emit_code(Spec, Code) :-
    starlog_emit(Spec, AST),
    starlog_ast_to_string(AST, Code).

%% starlog_ast_to_string(+StarlogPred, -Code)
starlog_ast_to_string(starlog_pred(Name, Params, Goals), Code) :-
    params_str(Params, ParamsStr),
    goals_str(Goals, GoalsStr),
    format(string(Code),
        "~w(~w) :-~n    ~w.",
        [Name, ParamsStr, GoalsStr]).

%% params_str(+ParamList, -String)
params_str([], '').
params_str(Params, Str) :-
    Params \= [],
    maplist(param_to_str, Params, Strs),
    atomic_list_concat(Strs, ', ', Str).

param_to_str(input,  'Input').
param_to_str(output, 'Output').
param_to_str(result, 'Result').
param_to_str(acc,    'Acc').
param_to_str(a,      'A').
param_to_str(b,      'B').
param_to_str(V, VS) :-
    atom(V),
    upcase_atom(V, VS).

%% goals_str(+GoalList, -String)
goals_str(Goals, Str) :-
    maplist(goal_to_str, Goals, Strs),
    atomic_list_concat(Strs, ',\n    ', Str).

%% goal_to_str(+Goal, -String)

% Feature 1: Result is Expr  (value-returning)
goal_to_str(is(LHS, RHS), Str) :-
    expr_to_str(LHS, LStr),
    expr_to_str(RHS, RStr),
    format(string(Str), "~w is ~w", [LStr, RStr]).

% Feature 7: variable-bound goal
goal_to_str(bound(Var, Goal), Str) :-
    param_to_str(Var, VStr),
    goal_to_str(Goal, GStr),
    format(string(Str), "(~w = ~w)", [VStr, GStr]).

goal_to_str(goal_call(Name, Args), Str) :-
    maplist(expr_to_str, Args, ArgStrs),
    atomic_list_concat(ArgStrs, ', ', ArgsStr),
    format(string(Str), "~w(~w)", [Name, ArgsStr]).

%% expr_to_str(+Expr, -String)

% Feature 6: method chain A >> M
expr_to_str(chain(E, Method), Str) :-
    expr_to_str(E, EStr),
    method_to_str(Method, MStr),
    format(string(Str), "~w >> ~w", [EStr, MStr]).

% Feature 2: string concat A : B
expr_to_str(concat(A, B), Str) :-
    expr_to_str(A, AStr),
    expr_to_str(B, BStr),
    format(string(Str), "~w : ~w", [AStr, BStr]).

% Feature 3: list append A & B
expr_to_str(append(A, B), Str) :-
    expr_to_str(A, AStr),
    expr_to_str(B, BStr),
    format(string(Str), "~w & ~w", [AStr, BStr]).

% Features 1, 10: value-returning call Name(Args)
expr_to_str(call(Name, Args), Str) :-
    maplist(expr_to_str, Args, ArgStrs),
    atomic_list_concat(ArgStrs, ', ', ArgsStr),
    format(string(Str), "~w(~w)", [Name, ArgsStr]).

% Feature 8: selective eval
expr_to_str(eval(E), Str) :-
    expr_to_str(E, EStr),
    format(string(Str), "eval(~w)", [EStr]).

% Feature 8: selective no_eval
expr_to_str(no_eval(E), Str) :-
    expr_to_str(E, EStr),
    format(string(Str), "no_eval(~w)", [EStr]).

% Feature 9: preserved arithmetic
expr_to_str(arith(E), Str) :-
    format(string(Str), "~w", [E]).

expr_to_str(lit(V), Str) :-
    format(string(Str), "~w", [V]).

expr_to_str(var(V), Str) :-
    param_to_str(V, Str).

expr_to_str(A, Str) :-
    atom(A),
    atom_string(A, Str).

expr_to_str(N, Str) :-
    number(N),
    number_string(N, Str).

%% method_to_str(+Method, -String)
method_to_str(map(Op),      Str) :- format(string(Str), "map(~w)",        [Op]).
method_to_str(filter(Op),   Str) :- format(string(Str), "filter(~w)",     [Op]).
method_to_str(fold(Op,Init),Str) :- format(string(Str), "fold(~w, ~w)",   [Op, Init]).
method_to_str(method(Name), Str) :- format(string(Str), "~w",             [Name]).
method_to_str(M,            Str) :- format(string(Str), "~w",             [M]).

%% =========================================================
%% Expansion: Starlog AST → Prolog Code
%% =========================================================

%% starlog_expand(+StarlogPred, -expanded(Name, PrologCode))
starlog_expand(starlog_pred(Name, _Params, Goals),
               expanded(Name, Code)) :-
    expand_goals(Name, Goals, Code).

%% starlog_expand_code(+Spec, -PrologCode)
starlog_expand_code(Spec, Code) :-
    starlog_emit(Spec, AST),
    starlog_expand(AST, expanded(_, Code)).

%% =========================================================
%% Combined: Spec → (Starlog Code, Prolog Code)
%% =========================================================

%% starlog_full(+Spec, -StarlogCode, -PrologCode)
starlog_full(Spec, StarlogCode, PrologCode) :-
    starlog_emit(Spec, AST),
    starlog_ast_to_string(AST, StarlogCode),
    starlog_expand(AST, expanded(_, PrologCode)).

%% =========================================================
%% Expansion rules: Goals → Prolog code string
%% =========================================================

% Feature 6 + map: Output is Input >> map(Op)
% Expands to standard recursive predicate
expand_goals(Name,
    [is(var(output), chain(var(input), map(Op)))],
    Code) :-
    !,
    op_arith_goal(Op, OpGoal),
    format(string(Code),
        "~w([], []).~n~w([X|Xs], [Y|Ys]) :-~n    ~w,~n    ~w(Xs, Ys).",
        [Name, Name, OpGoal, Name]).

% Feature 6 + filter: Output is Input >> filter(Op)
expand_goals(Name,
    [is(var(output), chain(var(input), filter(Op)))],
    Code) :-
    !,
    op_test_goal(Op, TestGoal),
    format(string(Code),
        "~w([], []).~n~w([X|Xs], Ys) :-~n    ( ~w~n    -> Ys = [X|Ys1]~n    ;  Ys = Ys1~n    ),~n    ~w(Xs, Ys1).",
        [Name, Name, TestGoal, Name]).

% Feature 6 + fold: Output is Input >> fold(Op, Init)
expand_goals(Name,
    [is(var(output), chain(var(input), fold(Op, Init)))],
    Code) :-
    !,
    atom_concat(Name, '_acc', LoopName),
    op_fold_goal(Op, FoldGoal),
    format(string(Code),
        "~w(Input, Output) :-~n    ~w(Input, ~w, Output).~n~w([], Acc, Acc).~n~w([X|Xs], Acc, Result) :-~n    ~w,~n    ~w(Xs, Acc1, Result).",
        [Name, LoopName, Init, LoopName, LoopName, FoldGoal, LoopName]).

% Nested method chain: Output is Input >> M1 >> M2 (feature 4, nested RHS)
expand_goals(Name,
    [is(var(output), chain(chain(var(input), M1), M2))],
    Code) :-
    !,
    atom_concat(Name, '_step1', Intermediate),
    expand_goals(Intermediate, [is(var(output), chain(var(input), M1))], Code1),
    expand_goals(Name,         [is(var(output), chain(var(input), M2))], Code2),
    format(string(Code),
        "% Step 1~n~w~n% Step 2~n~w~n~w(Input, Output) :-~n    ~w(Input, Mid),~n    ~w(Mid, Output).",
        [Code1, Code2, Name, Intermediate, Name]).

% Feature 2: Result is A : B  (string concatenation)
expand_goals(Name,
    [is(var(result), concat(var(a), var(b)))],
    Code) :-
    !,
    format(string(Code),
        "~w(A, B, Result) :-~n    atom_concat(A, B, Result).",
        [Name]).

% Feature 2: Result is Expr : Literal (partial concat)
expand_goals(Name,
    [is(var(result), concat(var(a), lit(Suffix)))],
    Code) :-
    !,
    format(string(Code),
        "~w(A, Result) :-~n    atom_concat(A, ~w, Result).",
        [Name, Suffix]).

% Feature 3: Result is A & B  (list append)
expand_goals(Name,
    [is(var(result), append(var(a), var(b)))],
    Code) :-
    !,
    format(string(Code),
        "~w(A, B, Result) :-~n    append(A, B, Result).",
        [Name]).

% Feature 1 + 10: Result is user_func(Args) (value-returning user predicate)
expand_goals(Name,
    [is(var(result), call(FuncName, ArgExprs))],
    Code) :-
    FuncName \= transform,
    !,
    maplist(expr_expand_param, ArgExprs, ArgVars),
    atomic_list_concat(ArgVars, ', ', ArgsStr),
    format(string(Code),
        "~w(~w, Result) :-~n    ~w(~w, Result).",
        [Name, ArgsStr, FuncName, ArgsStr]).

% Feature 8: eval wrapper — expand inner expression, force evaluation
expand_goals(Name,
    [is(var(Res), eval(InnerExpr))],
    Code) :-
    !,
    expand_goals(Name, [is(var(Res), InnerExpr)], InnerCode),
    format(string(Code),
        "% eval: force evaluation~n~w",
        [InnerCode]).

% Feature 8: no_eval wrapper — treat expression as data, unify
expand_goals(Name,
    [is(var(Res), no_eval(InnerExpr))],
    Code) :-
    !,
    expr_to_str(InnerExpr, ExprStr),
    param_to_str(Res, ResStr),
    format(string(Code),
        "~w(~w) :-~n    ~w = ~w.",
        [Name, ResStr, ResStr, ExprStr]).

% Feature 7: variable-bound goal
expand_goals(Name,
    [bound(BoundVar, InnerGoal)],
    Code) :-
    !,
    param_to_str(BoundVar, VStr),
    goal_to_str(InnerGoal, GStr),
    format(string(Code),
        "~w(Input, Output) :-~n    ~w = ~w,~n    Output = Input.",
        [Name, VStr, GStr]).

% Feature 5 + nested LHS: f(X) is Expr (nested LHS value-returning)
expand_goals(Name,
    [is(call(FuncName, ArgExprs), RhsExpr)],
    Code) :-
    !,
    maplist(expr_expand_param, ArgExprs, ArgVars),
    atomic_list_concat(ArgVars, ', ', ArgsStr),
    expand_goals(Name, [is(var(result), RhsExpr)], InnerCode),
    format(string(Code),
        "% nested LHS: ~w(~w) is Expr~n~w~n~w(~w, Result) :-~n    ~w_result(~w, Result).~n~w_result(~w, Result) :-~n    ~w(~w, Result).",
        [FuncName, ArgsStr, InnerCode, Name, ArgsStr, Name, ArgsStr, Name, ArgsStr, FuncName, ArgsStr]).

% Feature 9: arithmetic preservation — plain arithmetic goal
expand_goals(Name,
    [is(var(output), arith(ArithExpr))],
    Code) :-
    !,
    format(string(Code),
        "~w(X, Output) :-~n    Output is ~w.",
        [Name, ArithExpr]).

% Fallback: unrecognised goal structure — emit identity and warn
expand_goals(Name, Goals, Code) :-
    format(atom(Warning),
        "starlog: unrecognised goal structure for ~w: ~w",
        [Name, Goals]),
    print_message(warning, format(Warning, [])),
    format(string(Code),
        "~w(Input, Output) :-~n    Output = Input.",
        [Name]).

%% expr_expand_param(+Expr, -VarName) — turn expr to a var name string
expr_expand_param(var(V), VS) :- param_to_str(V, VS).
expr_expand_param(lit(V), VS) :- format(string(VS), "~w", [V]).
expr_expand_param(A, AS) :- atom(A), atom_string(A, AS).

%% =========================================================
%% Operation helpers
%% =========================================================

%% op_arith_goal(+Op, -GoalString)
%% Feature 9: arithmetic preserved
op_arith_goal(double,    "Y is X * 2") :- !.
op_arith_goal(triple,    "Y is X * 3") :- !.
op_arith_goal(square,    "Y is X * X") :- !.
op_arith_goal(increment, "Y is X + 1") :- !.
op_arith_goal(decrement, "Y is X - 1") :- !.
op_arith_goal(_,         "Y = X").

%% op_test_goal(+Op, -TestGoalString)
op_test_goal(positive, "X > 0") :- !.
op_test_goal(negative, "X < 0") :- !.
op_test_goal(even,     "0 is X mod 2") :- !.
op_test_goal(odd,      "1 is X mod 2") :- !.
op_test_goal(_,        "X \\= []").

%% op_fold_goal(+Op, -FoldGoalString)
op_fold_goal(add,      "Acc1 is Acc + X") :- !.
op_fold_goal(multiply, "Acc1 is Acc * X") :- !.
op_fold_goal(_,        "Acc1 is Acc + X").
