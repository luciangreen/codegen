:- begin_tests(stage7_loop2).

:- use_module('../src/optimiser').

%% -------------------------------------------------------
%% Feature 1: findall/3 over facts / simple member
%% -------------------------------------------------------

test(findall_member_identity) :-
    loop2_convert_goal(
        findall(X, member(X, [a,b,c]), R),
        LoopCall, Helpers
    ),
    LoopCall = call(_, [a,b,c], R),
    length(Helpers, 2).   % base + recursive clause

%% -------------------------------------------------------
%% Feature 2: findall/3 over member/2
%% -------------------------------------------------------

test(findall_member_generates_loop_name) :-
    loop2_convert_goal(
        findall(X, member(X, [1,2,3]), _R),
        call(LoopAtom, _, _), _Helpers
    ),
    atom(LoopAtom),
    atom_string(LoopAtom, LoopStr),
    sub_string(LoopStr, 0, 4, _, "loop").

%% -------------------------------------------------------
%% Feature 3: Simple transformation inside findall
%% -------------------------------------------------------

test(findall_with_body_creates_body_loop) :-
    X = x,
    loop2_convert_goal(
        findall([X,X], member(X, [a,b,c]), _R),
        call(LoopAtom, [a,b,c], _R), Helpers
    ),
    atom(LoopAtom),
    length(Helpers, 2).

test(findall_body_goal_included_in_rec_clause) :-
    loop2_convert_goal(
        findall(Y, (member(X, [1,2,3]), Y is X * 2), _R),
        _LoopCall, Helpers
    ),
    member((_ :- Body), Helpers),
    Body \= true,      % recursive clause has a body
    !.

%% -------------------------------------------------------
%% Feature 4: Nested findall (flattening)
%% -------------------------------------------------------

test(nested_findall_creates_multiple_loops) :-
    reset_loop_counter,
    loop2_convert(
        (p(R) :- findall(Y, (member(X, [1,2,3]), Y is X+1), R)),
        Clauses
    ),
    length(Clauses, N),
    N >= 3.   % main + at least 2 loop clauses

%% -------------------------------------------------------
%% Feature 5: Flattening nested findall + member
%% -------------------------------------------------------

test(outer_findall_member_converted) :-
    reset_loop_counter,
    loop2_convert(
        (p(R) :- findall(X, member(X, [a,b,c]), R)),
        [MainClause | LoopClauses]
    ),
    MainClause = (p(_) :- _),
    LoopClauses \= [].

%% -------------------------------------------------------
%% Feature 6: Splicing simple nested predicates
%% -------------------------------------------------------

test(body_with_arithmetic_spliced) :-
    loop2_convert_goal(
        findall(Y, (member(X, [1,2,3]), Y is X * X), _),
        call(LoopAtom, _, _), Helpers
    ),
    atom(LoopAtom),
    member(( _ :- Body ), Helpers),
    Body \= true,
    !.

%% -------------------------------------------------------
%% Feature 7: Converting fact generators into list generators
%% (identity pass-through when no body transformation needed)
%% -------------------------------------------------------

test(identity_template_generated) :-
    loop2_convert_goal(
        findall(X, member(X, [a,b,c]), _),
        call(_, [a,b,c], _), Helpers
    ),
    member((BaseHead :- true), Helpers),
    BaseHead =.. [_LoopAtom, [], []].

%% -------------------------------------------------------
%% Feature 8: Explicit recursive loops produced
%% -------------------------------------------------------

test(recursive_loop_has_base_and_step) :-
    loop2_convert_goal(
        findall(X, member(X, [1,2,3]), _),
        _, Helpers
    ),
    member((_Base :- true), Helpers),      % base case
    member((_Step :- _Body), Helpers), !.  % recursive step

%% -------------------------------------------------------
%% Feature 9: Unsupported constructs reported
%% -------------------------------------------------------

test(cut_reported_as_unsupported) :-
    Goal = findall(X, (member(X,[a,b]), !), _),
    loop2_unsupported_reason(Goal, Reason),
    assertion(Reason == cut).

test(negation_reported_as_unsupported) :-
    Goal = findall(X, (member(X,[a,b]), \+(X == a)), _),
    loop2_unsupported_reason(Goal, Reason),
    assertion(Reason == negation_as_failure).

test(assert_reported_as_unsupported) :-
    Goal = findall(X, (member(X,[a,b]), assert(seen(X))), _),
    loop2_unsupported_reason(Goal, Reason),
    assertion(Reason == dynamic_predicate).

%% -------------------------------------------------------
%% loop2_supported/1
%% -------------------------------------------------------

test(supported_simple_member) :-
    assertion(loop2_supported(findall(X, member(X,[1,2,3]), _R))).

test(supported_body_member) :-
    assertion(loop2_supported(findall(Y, (member(X,[1,2,3]), Y is X+1), _R))).

test(loop2_convert_full_clause) :-
    reset_loop_counter,
    Clause = (double_p(R) :- findall(Y, (member(X, [1,2,3]), Y is X*2), R)),
    loop2_convert(Clause, Clauses),
    Clauses = [MainClause | _LoopClauses],
    MainClause = (double_p(_) :- _),
    length(Clauses, N),
    assertion(N >= 3).

:- end_tests(stage7_loop2).

%% =========================================================
%% Stage 8: PLOP Optimisation tests
%% =========================================================

:- begin_tests(stage8_plop).

:- use_module('../src/optimiser').

%% -------------------------------------------------------
%% Feature 1: Memoisation
%% -------------------------------------------------------

test(memoize_produces_cache_name) :-
    plop_memoize(double_all, 2, memo(double_all, 2, CacheName, _)),
    assertion(CacheName == double_all_cache).

test(memoize_records_arity) :-
    plop_memoize(my_pred, 3, memo(my_pred, Arity, _, _)),
    assertion(Arity == 3).

test(memoize_allocates_arg_vars) :-
    plop_memoize(foo, 2, memo(foo, 2, _, memo_wrapper(foo, _, ArgVars))),
    assertion(length(ArgVars, 2)).

%% -------------------------------------------------------
%% Feature 3: Subterm-with-address
%% -------------------------------------------------------

test(subterm_empty_address_is_identity) :-
    plop_subterm_with_address(f(a,b), [], T),
    assertion(T == f(a,b)).

test(subterm_first_arg) :-
    plop_subterm_with_address(f(hello, world), [1], T),
    assertion(T == hello).

test(subterm_second_arg) :-
    plop_subterm_with_address(f(hello, world), [2], T),
    assertion(T == world).

test(subterm_nested_address) :-
    plop_subterm_with_address(f(g(x, y), z), [1, 2], T),
    assertion(T == y).

test(subterm_deep_nested_address) :-
    plop_subterm_with_address(a(b(c(deep))), [1,1,1], T),
    assertion(T == deep).

test(subterm_list_head_by_address) :-
    %% [C,D] is the list ./2 = .(C,.(D,[])), so [1] gives C
    plop_subterm_with_address([alpha, beta], [1], T),
    assertion(T == alpha).

test(subterm_matrix_example_from_spec) :-
    %% Stage 8 target: subterm_with_address(A,[1],[C,D])
    %% A = [[c,d], f(x)]  -> address [1] -> [c,d]
    A = [[c,d], some_term],
    plop_subterm_with_address(A, [1], Sub1),
    assertion(Sub1 == [c,d]).

%% -------------------------------------------------------
%% Feature 2: Indexical optimisation
%% -------------------------------------------------------

test(index_optimise_known_first_arg_already_indexed) :-
    Clauses = [
        (foo([]) :- true),
        (foo([_|_]) :- true)
    ],
    plop_index_optimise(Clauses, IClauses),
    forall(member(IC, IClauses),
           (IC = already_indexed(_,_) ; IC = needs_index(_,_))).

test(index_optimise_var_first_arg_needs_index) :-
    Clauses = [(bar(X) :- atom(X))],
    plop_index_optimise(Clauses, [IC]),
    IC = needs_index(_, _).

%% -------------------------------------------------------
%% Feature 10: Invariant extraction
%% -------------------------------------------------------

test(invariant_extracts_independent_goal) :-
    %% N is not part of the recursive argument Xs
    Clause = (sum_all([_X|Xs], N) :- succ_of_n(N, _M), sum_all(Xs, N)),
    plop_extract_invariants([Clause], _, Invariants),
    member(succ_of_n(_, _), Invariants).

test(invariant_keeps_recursive_goal_in_body) :-
    Clause = (double_all([X|Xs], [Y|Ys]) :- Y is X * 2, double_all(Xs, Ys)),
    plop_extract_invariants([Clause], [(double_all([_|_],[_|_]) :- NewBody)|_], _),
    NewBody \== true.

test(extract_invariants_empty_input) :-
    plop_extract_invariants([], [], []).

%% -------------------------------------------------------
%% Feature 6: Eliminate duplicate subcalls
%% -------------------------------------------------------

test(eliminate_dupes_removes_second_occurrence) :-
    Body = (length(Xs, N), foo(N), length(Xs, N), bar(N)),
    plop_eliminate_duplicate_subcalls(Body, NewBody, Bindings),
    \+ (NewBody = (_A, _B, _C, _D)),   % one goal was removed
    length(Bindings, _),
    Bindings \= [].

test(eliminate_dupes_no_change_when_unique) :-
    Body = (foo(1), bar(2), baz(3)),
    plop_eliminate_duplicate_subcalls(Body, NewBody, Bindings),
    NewBody == Body,
    Bindings == [foo(1), bar(2), baz(3)].

test(eliminate_dupes_single_goal) :-
    plop_eliminate_duplicate_subcalls(foo(x), foo(x), [foo(x)]).

%% -------------------------------------------------------
%% Feature 9: Predicate dependency analysis
%% -------------------------------------------------------

test(dependency_analysis_finds_direct_call) :-
    Clauses = [(main(X) :- helper(X))],
    plop_dependency_analysis(Clauses, Deps),
    member(dep(main/1, helper/1), Deps).

test(dependency_analysis_finds_multiple_callees) :-
    Clauses = [(foo(X, Y) :- bar(X), baz(Y))],
    plop_dependency_analysis(Clauses, Deps),
    member(dep(foo/2, bar/1), Deps),
    member(dep(foo/2, baz/1), Deps).

test(dependency_analysis_empty_clauses) :-
    plop_dependency_analysis([], []).

%% -------------------------------------------------------
%% plop_optimise/2 integration test
%% -------------------------------------------------------

test(plop_optimise_preserves_clause_count) :-
    Clauses = [
        (foo([]) :- true),
        (foo([X|Xs]) :- Y is X * 2, foo(Xs))
    ],
    plop_optimise(Clauses, Opt),
    length(Clauses, N),
    length(Opt, N).

test(plop_optimise_empty_list) :-
    plop_optimise([], []).

:- end_tests(stage8_plop).
