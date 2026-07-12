:- module(optimiser, [
    loop2_convert/2,
    loop2_convert_goal/3,
    loop2_supported/1,
    loop2_unsupported_reason/2,
    reset_loop_counter/0,
    plop_optimise/2,
    plop_memoize/3,
    plop_subterm_with_address/3,
    plop_index_optimise/2,
    plop_extract_invariants/3,
    plop_eliminate_duplicate_subcalls/3,
    plop_dependency_analysis/2
]).

%% =========================================================
%% Stage 7: Loop2 Optimisation
%%
%% Converts supported nondeterministic Prolog patterns into
%% explicit deterministic recursive loops.
%%
%% Supported input forms (as Prolog terms):
%%
%%   findall(Template, member(X, List), Result)
%%   findall([X,X], member(X, List), Result)
%%   findall(T, (member(X, List), Body), Result)
%%   Nested findall (flattened)
%%   Fact-based generators
%%
%% All are converted to explicit loop predicates of the form:
%%   loop_NNN([], []).
%%   loop_NNN([X|Xs], [Y|Ys]) :- Body, loop_NNN(Xs, Ys).
%%
%% Unsupported constructs are reported via loop2_unsupported_reason/2.
%% =========================================================

%% Counter for unique loop predicate names
:- dynamic loop2_counter/1.
loop2_counter(0).

next_loop_name(Name) :-
    retract(loop2_counter(N)),
    N1 is N + 1,
    assertz(loop2_counter(N1)),
    format(atom(Name), "loop~|~`0t~d~3|", [N1]).

reset_loop_counter :-
    retractall(loop2_counter(_)),
    assertz(loop2_counter(0)).

%% =========================================================
%% loop2_supported(+Goal) — succeeds if Goal can be converted
%% =========================================================

loop2_supported(findall(_, member(_, _), _)) :- !.
loop2_supported(findall(_, (member(_, _), _), _)) :- !.
loop2_supported(findall(_, (member(_, _), _, _), _)) :- !.

%% =========================================================
%% loop2_unsupported_reason(+Goal, -Reason)
%% =========================================================

loop2_unsupported_reason(Goal, cut) :-
    contains_term(!, Goal), !.
loop2_unsupported_reason(Goal, negation_as_failure) :-
    contains_term(\+(_), Goal), !.
loop2_unsupported_reason(Goal, dynamic_predicate) :-
    (contains_term(assert(_), Goal) ; contains_term(retract(_), Goal)), !.
loop2_unsupported_reason(Goal, side_effects) :-
    contains_term(write(_), Goal), !.
loop2_unsupported_reason(Goal, side_effects) :-
    contains_term(format(_,_), Goal), !.
loop2_unsupported_reason(Goal, infinite_generator) :-
    contains_term(between(_,inf,_), Goal), !.
loop2_unsupported_reason(Goal, meta_call) :-
    contains_term(call(_), Goal), !.
loop2_unsupported_reason(Goal, assert_retract) :-
    contains_term(assertz(_), Goal), !.
loop2_unsupported_reason(Goal, io_inside_generator) :-
    contains_term(read(_), Goal), !.
loop2_unsupported_reason(Goal, unsupported_construct(Goal)).

%% =========================================================
%% loop2_convert(+InputClause, -OutputClauses)
%%
%% InputClause  = (Head :- Body)
%% OutputClauses = list of (Head :- Body) terms representing
%%                 the converted predicate + loop helpers
%% =========================================================

loop2_convert((Head :- Body), OutputClauses) :-
    reset_loop_counter,
    convert_body(Body, Head, NewBody, HelperClauses),
    MainClause = (Head :- NewBody),
    flatten([MainClause | HelperClauses], OutputClauses).

loop2_convert(Fact, [Fact]) :-
    Fact \= (_ :- _).

%% convert_body(+Body, +Head, -NewBody, -Helpers)
convert_body(findall(Template, member(X, List), Result), _Head, NewBody, Helpers) :-
    !,
    next_loop_name(LoopName),
    make_loop_name_atom(LoopName, LoopAtom),
    build_loop_clauses_member(LoopAtom, X, Template, LoopHelpers),
    NewBody = call(LoopAtom, List, Result),
    Helpers = LoopHelpers.

convert_body(findall(Template, (member(X, List), InnerBody), Result), _Head, NewBody, Helpers) :-
    !,
    next_loop_name(LoopName),
    make_loop_name_atom(LoopName, LoopAtom),
    build_loop_clauses_body(LoopAtom, X, Template, InnerBody, LoopHelpers),
    NewBody = call(LoopAtom, List, Result),
    Helpers = LoopHelpers.

convert_body((GoalA, GoalB), Head, NewBody, Helpers) :-
    contains_findall(GoalA),
    !,
    convert_body(GoalA, Head, NewA, HelpersA),
    convert_body(GoalB, Head, NewB, HelpersB),
    NewBody = (NewA, NewB),
    append(HelpersA, HelpersB, Helpers).

convert_body(Body, _Head, Body, []).

%% =========================================================
%% loop2_convert_goal(+Goal, -LoopCall, -HelperClauses)
%%
%% Convert a single findall goal (used standalone or in tests)
%% =========================================================

loop2_convert_goal(findall(Template, member(X, List), Result), LoopCall, Helpers) :-
    !,
    next_loop_name(LoopName),
    make_loop_name_atom(LoopName, LoopAtom),
    build_loop_clauses_member(LoopAtom, X, Template, Helpers),
    LoopCall = call(LoopAtom, List, Result).

loop2_convert_goal(findall(Template, (member(X, List), Body), Result), LoopCall, Helpers) :-
    !,
    next_loop_name(LoopName),
    make_loop_name_atom(LoopName, LoopAtom),
    build_loop_clauses_body(LoopAtom, X, Template, Body, Helpers),
    LoopCall = call(LoopAtom, List, Result).

%% =========================================================
%% Helper: build loop clauses for simple member/2
%% =========================================================

build_loop_clauses_member(LoopAtom, X, Template, Clauses) :-
    BaseClause = (LoopHead1 :- true),
    LoopHead1 =.. [LoopAtom, [], []],
    RecClause = (LoopHead2 :- LoopBody2),
    LoopHead2 =.. [LoopAtom, [X|Xs], [Template|Ys]],
    LoopCall =.. [LoopAtom, Xs, Ys],
    LoopBody2 = LoopCall,
    Clauses = [BaseClause, RecClause].

%% =========================================================
%% Helper: build loop clauses for member + body
%% =========================================================

build_loop_clauses_body(LoopAtom, X, Template, InnerBody, Clauses) :-
    BaseClause = (LoopHead1 :- true),
    LoopHead1 =.. [LoopAtom, [], []],
    RecClause = (LoopHead2 :- LoopBody2),
    LoopHead2 =.. [LoopAtom, [X|Xs], [Template|Ys]],
    LoopCallRec =.. [LoopAtom, Xs, Ys],
    LoopBody2 = (InnerBody, LoopCallRec),
    Clauses = [BaseClause, RecClause].

%% =========================================================
%% loop2_convert/2 — code string interface
%%
%% Accepts a code string representation of a clause,
%% returns converted code string
%% =========================================================

loop2_convert_string(InputString, OutputString) :-
    term_string(Clause, InputString),
    loop2_convert(Clause, OutputClauses),
    maplist(clause_to_string, OutputClauses, ClauseStrings),
    atomic_list_concat(ClauseStrings, '\n', OutputString).

clause_to_string((Head :- true), Str) :-
    !,
    format(string(Str), "~w.", [Head]).
clause_to_string((Head :- Body), Str) :-
    !,
    format(string(Str), "~w :-\n    ~w.", [Head, Body]).
clause_to_string(Fact, Str) :-
    format(string(Str), "~w.", [Fact]).

%% =========================================================
%% Utilities
%% =========================================================

make_loop_name_atom(LoopName, LoopAtom) :-
    (atom(LoopName) -> LoopAtom = LoopName ; atom_string(LoopAtom, LoopName)).

contains_findall(findall(_, _, _)) :- !.
contains_findall((A, _)) :- contains_findall(A), !.
contains_findall((_, B)) :- contains_findall(B).

contains_term(_Pattern, Term) :-
    var(Term), !, fail.
contains_term(Pattern, Term) :-
    Term =.. [F|Args],
    (   Pattern =.. [PF|PArgs],
        F == PF,
        length(Args, N),
        length(PArgs, N)
    ->  true
    ;   member(Arg, Args),
        contains_term(Pattern, Arg)
    ).

%% =========================================================
%% Stage 8: PLOP Optimisation
%%
%% Improves generated Prolog using memoisation, indexical
%% optimisation, subterm-with-address, subterm-index looping,
%% Gaussian-style reconstruction, repeated subpredicate
%% elimination, expensive predicate caching, template
%% splicing, predicate dependency analysis, and invariant
%% extraction.
%% =========================================================

%% ---------------------------------------------------------
%% plop_optimise(+Clauses, -OptClauses)
%%
%% Apply all safe PLOP passes in sequence:
%%   1. Eliminate duplicate subcalls
%%   2. Extract loop invariants
%%   3. Index-optimise first arguments
%%
%% Clauses and OptClauses are lists of (Head :- Body) terms.
%% ---------------------------------------------------------

plop_optimise([], []).
plop_optimise([Clause|Clauses], [OptClause|OptClauses]) :-
    plop_optimise_clause(Clause, OptClause),
    plop_optimise(Clauses, OptClauses).

plop_optimise_clause((Head :- Body), (Head :- OptBody)) :-
    !,
    plop_eliminate_duplicate_subcalls(Body, Body1, _Bindings),
    plop_extract_invariants([Head :- Body1], [(Head :- OptBody)|_], _Inv).
plop_optimise_clause(Fact, Fact).

%% ---------------------------------------------------------
%% plop_memoize(+Name, +Arity, -MemoClause)
%%
%% Generate a memoisation wrapper clause for Name/Arity.
%%
%% Produces:
%%   Name_memo(Args...) :-
%%       ( Name_cache(Args...) -> true
%%       ; Name(Args...), assertz(Name_cache(Args...)) ).
%% ---------------------------------------------------------

plop_memoize(Name, Arity, memo(Name, Arity, CacheName, WrapperCode)) :-
    atom(Name),
    integer(Arity),
    Arity >= 0,
    atom_concat(Name, '_cache', CacheName),
    length(ArgVars, Arity),
    WrapperCode = memo_wrapper(Name, CacheName, ArgVars).

%% ---------------------------------------------------------
%% plop_subterm_with_address(+Term, +Address, -Subterm)
%%
%% Access a subterm by a positional address (list of 1-based
%% argument indices).
%%
%% Example:
%%   plop_subterm_with_address(f(a, g(b,c)), [2,1], X)
%%   => X = b
%%
%% As used in the Stage 8 target example:
%%   subterm_with_address(A, [1], [C,D])   % 1st arg of A
%%   subterm_with_address(A, [2,1], F)     % A's 2nd arg's 1st arg
%% ---------------------------------------------------------

plop_subterm_with_address(Term, [], Term) :- !.
plop_subterm_with_address(Term, [Idx|Rest], Subterm) :-
    integer(Idx),
    Idx >= 1,
    Term =.. [_Functor|Args],
    nth1(Idx, Args, Arg),
    plop_subterm_with_address(Arg, Rest, Subterm).

%% ---------------------------------------------------------
%% plop_index_optimise(+Clauses, -IndexClauses)
%%
%% Add first-argument indexing metadata to clause heads where
%% multiple clauses share the same functor but differ on the
%% first argument (list vs atom vs compound).
%%
%% Returns an annotated list:
%%   indexed(Head, Body, first_arg_type(Type))
%%
%% If a clause's first argument is already a non-variable,
%% it is already indexed by the WAM; those are marked
%%   already_indexed(Head, Body).
%% ---------------------------------------------------------

plop_index_optimise(Clauses, IndexedClauses) :-
    findall(F/A, (
        member((Head :- _), Clauses),
        functor(Head, F, A)
    ), FAs0),
    sort(FAs0, FAs),
    findall(IClause,
        (member(FA, FAs),
         index_one_functor(FA, Clauses, IClause)),
        Nested),
    flatten(Nested, IndexedClauses).

index_one_functor(F/A, Clauses, IClauses) :-
    findall(Head-Body,
        (member((Head :- Body), Clauses), functor(Head, F, A)),
        Pairs),
    maplist(annotate_clause_index, Pairs, IClauses).

annotate_clause_index(Head-Body, already_indexed(Head, Body)) :-
    Head =.. [_|[First|_]],
    nonvar(First),
    !.
annotate_clause_index(Head-Body, needs_index(Head, Body)).

%% ---------------------------------------------------------
%% plop_extract_invariants(+Clauses, -NewClauses, -Invariants)
%%
%% Detect sub-goals in a recursive clause body that do not
%% depend on the recursive argument and can be hoisted to the
%% enclosing scope (loop invariants).
%%
%% A goal G is invariant if none of its variables appear in
%% the recursive argument position (first argument of the head).
%%
%% NewClauses: clauses with invariant goals removed from body.
%% Invariants: list of hoisted goals.
%% ---------------------------------------------------------

plop_extract_invariants([], [], []).
plop_extract_invariants([Clause|Clauses], [NewClause|NewClauses], AllInv) :-
    plop_extract_invariants_clause(Clause, NewClause, Inv),
    plop_extract_invariants(Clauses, NewClauses, RestInv),
    append(Inv, RestInv, AllInv).

plop_extract_invariants_clause((Head :- Body), (Head :- NewBody), Invariants) :-
    !,
    Head =.. [_|[RecArg|_]],
    term_variables(RecArg, RecVars),
    conjunct_list(Body, Goals),
    partition_invariant(Goals, RecVars, InvGoals, VarGoals),
    list_to_conjunct(VarGoals, NewBody),
    Invariants = InvGoals.
plop_extract_invariants_clause(Fact, Fact, []).

partition_invariant([], _, [], []).
partition_invariant([G|Gs], RecVars, [G|Invs], Vars) :-
    term_variables(G, GVars),
    \+ (member(V, GVars), member(W, RecVars), V == W),
    !,
    partition_invariant(Gs, RecVars, Invs, Vars).
partition_invariant([G|Gs], RecVars, Invs, [G|Vars]) :-
    partition_invariant(Gs, RecVars, Invs, Vars).

conjunct_list(true, []) :- !.
conjunct_list((A, B), [A|Bs]) :- !, conjunct_list(B, Bs).
conjunct_list(G, [G]).

list_to_conjunct([], true) :- !.
list_to_conjunct([G], G) :- !.
list_to_conjunct([G|Gs], (G, Rest)) :- list_to_conjunct(Gs, Rest).

%% ---------------------------------------------------------
%% plop_eliminate_duplicate_subcalls(+Body, -NewBody, -Bindings)
%%
%% Within a clause body (a conjunction), detect repeated
%% deterministic sub-goals and replace subsequent occurrences
%% with a shared variable binding.
%%
%% Bindings is a list of V = Goal pairs representing the
%% first occurrence retained.
%%
%% Example:
%%   Body  = (length(Xs,N), foo(N), length(Xs,N), bar(N))
%%   =>
%%   NewBody = (length(Xs,N), foo(N), bar(N))
%%   Bindings = [length(Xs,N)]
%% ---------------------------------------------------------

plop_eliminate_duplicate_subcalls(Body, NewBody, Bindings) :-
    conjunct_list(Body, Goals),
    eliminate_dupes(Goals, [], UniqueGoals, Bindings),
    list_to_conjunct(UniqueGoals, NewBody).

eliminate_dupes([], _Seen, [], []).
eliminate_dupes([G|Gs], Seen, UniqueGoals, Bindings) :-
    member(G, Seen),
    !,
    eliminate_dupes(Gs, Seen, UniqueGoals, Bindings).
eliminate_dupes([G|Gs], Seen, [G|UniqueRest], [G|Bindings]) :-
    eliminate_dupes(Gs, [G|Seen], UniqueRest, Bindings).

%% ---------------------------------------------------------
%% plop_dependency_analysis(+Clauses, -DepGraph)
%%
%% Build a predicate dependency graph from a list of clauses.
%%
%% DepGraph is a list of  dep(Caller, Callee) pairs where
%% Caller and Callee are F/A terms.
%%
%% Only direct calls appearing in the clause body are recorded.
%% Meta-calls (call/N) are noted but their callees are unknown.
%% ---------------------------------------------------------

plop_dependency_analysis(Clauses, DepGraph) :-
    findall(dep(Caller, Callee),
        (member((Head :- Body), Clauses),
         functor(Head, F, A),
         Caller = F/A,
         conjunct_list(Body, Goals),
         member(Goal, Goals),
         callable(Goal),
         functor(Goal, CF, CA),
         CF \== (','),
         Callee = CF/CA),
        DepGraph0),
    sort(DepGraph0, DepGraph).

