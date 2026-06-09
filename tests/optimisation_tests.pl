:- begin_tests(stage8_plop).

:- use_module('../src/optimiser').

%% -------------------------------------------------------
%% Feature 1: Memoisation
%% -------------------------------------------------------

test(plop_memoize_produces_clauses) :-
    plop_memoize(expensive_pred, 2, Clauses),
    length(Clauses, N),
    assertion(N >= 3),
    member((:- dynamic(_)), Clauses).

test(plop_memoize_cache_name) :-
    plop_memoize(fib, 2, Clauses),
    member((:- dynamic(fib_cache/2)), Clauses).

test(plop_memoize_dispatch_clause_present) :-
    plop_memoize(fib, 2, Clauses),
    member((fib(_,_) :- fib_memo(_,_)), Clauses).

%% -------------------------------------------------------
%% Feature 3: Subterm-with-address
%% -------------------------------------------------------

test(subterm_empty_address_is_term) :-
    plop_subterm_with_address(foo(bar, baz), [], Sub),
    assertion(Sub == foo(bar, baz)).

test(subterm_first_arg) :-
    plop_subterm_with_address(foo(bar, baz), [1], Sub),
    assertion(Sub == bar).

test(subterm_second_arg) :-
    plop_subterm_with_address(foo(bar, baz), [2], Sub),
    assertion(Sub == baz).

test(subterm_nested_address) :-
    plop_subterm_with_address([[c,d], f], [1], Sub),
    assertion(Sub == [c,d]).

test(subterm_deep_nested) :-
    plop_subterm_with_address(a(b(c(x))), [1,1,1], Sub),
    assertion(Sub == x).

%% -------------------------------------------------------
%% Feature 4: Subterm-index looping
%% -------------------------------------------------------

test(subterm_index_loop_two_addresses) :-
    T = foo(a, b),
    plop_subterm_index_loop(T, [[1],[2]], [v1,v2], Goals),
    Goals = [
        plop_subterm_with_address(T, [1], v1),
        plop_subterm_with_address(T, [2], v2)
    ].

test(subterm_index_loop_single) :-
    T = [[c,d], f],
    plop_subterm_index_loop(T, [[1]], [v], Goals),
    Goals = [plop_subterm_with_address(T, [1], v)].

%% -------------------------------------------------------
%% Feature 5: Gaussian reconstruction
%% -------------------------------------------------------

test(gaussian_reconstruct_produces_clause) :-
    plop_gaussian_reconstruct(result_matrix(_, _), [], Clause),
    Clause = (output_matrix(_) :- true).

%% -------------------------------------------------------
%% Feature 6: Repeated subpredicate detection
%% -------------------------------------------------------

test(repeated_goals_found) :-
    Clauses = [
        (p(X) :- foo(X), bar(X), foo(X)),
        (p(Y) :- foo(Y), baz(Y))
    ],
    plop_repeated_goals(Clauses, Repeated),
    assertion(member(foo(_), Repeated)).

%% -------------------------------------------------------
%% Feature 8: Template splicing
%% -------------------------------------------------------

test(splice_template_inserts_goals) :-
    BaseClause = (p(X) :- body(X)),
    plop_splice_template(BaseClause, [check(X)], (p(X) :- (check(X), body(X)))).

test(splice_template_empty_goals) :-
    BaseClause = (p(X) :- body(X)),
    plop_splice_template(BaseClause, [], (p(X) :- body(X))).

test(splice_fact_with_guard) :-
    plop_splice_template(p(a), [guard(a)], (p(a) :- guard(a))).

%% -------------------------------------------------------
%% Feature 2: Indexical optimisation
%% -------------------------------------------------------

test(index_head_produces_hint) :-
    Clause = (p(X, Y) :- body(X, Y)),
    plop_index_head(Clause, 1, Result),
    Result = [Hint, _Clause],
    atom(Hint),
    sub_atom(Hint, _, _, _, "PLOP index hint").

%% -------------------------------------------------------
%% Feature 9: Dependency analysis
%% -------------------------------------------------------

test(dependency_analysis_finds_callees) :-
    Clauses = [(double_all([], []) :- true),
               (double_all([X|Xs], [Y|Ys]) :- Y is X*2, double_all(Xs, Ys))],
    plop_dependency_analysis(Clauses, double_all, Deps),
    assertion(member(double_all/2, Deps)).

test(dependency_analysis_empty_for_fact) :-
    Clauses = [(p(a) :- true)],
    plop_dependency_analysis(Clauses, p, Deps),
    assertion(member(true/0, Deps)).

%% -------------------------------------------------------
%% Feature 10: Invariant extraction
%% -------------------------------------------------------

test(invariant_extraction_common_goal) :-
    Clauses = [
        (p(x) :- check(x), do_x),
        (p(y) :- check(y), do_y)
    ],
    plop_extract_invariant(Clauses, p, Invariants),
    assertion(member(check(_), Invariants)).

test(invariant_extraction_no_common) :-
    Clauses = [
        (p(x) :- do_x),
        (p(y) :- do_y)
    ],
    plop_extract_invariant(Clauses, p, Invariants),
    assertion(Invariants == []).

%% -------------------------------------------------------
%% Feature 7: Expensive predicate caching
%% -------------------------------------------------------

test(cache_expensive_has_invalidate_hook) :-
    plop_cache_expensive(slow_pred, 1, Clauses),
    member((slow_pred_invalidate_cache :- _), Clauses).

:- end_tests(stage8_plop).
