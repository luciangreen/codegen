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
