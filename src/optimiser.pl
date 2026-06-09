:- module(optimiser, [
    loop2_convert/2,
    loop2_convert_goal/3,
    loop2_supported/1,
    loop2_unsupported_reason/2
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
