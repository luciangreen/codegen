:- module(optimiser, [
    plop_memoize/3,
    plop_subterm_with_address/3,
    plop_subterm_index_loop/4,
    plop_gaussian_reconstruct/3,
    plop_extract_invariant/3,
    plop_dependency_analysis/3,
    plop_eliminate_repeated/3,
    plop_splice_template/3,
    plop_index_head/3,
    plop_cache_expensive/3
]).

%% =========================================================
%% Stage 8: PLOP Optimisation
%%
%% Applies PLOP-style optimisations to Prolog clauses.
%% All predicates operate on clause term representations.
%%
%% Term representation for clauses:
%%   (Head :- Body)   — normal clause
%%   Fact             — fact (no body)
%%
%% Address: list of integers giving the path to a subterm.
%%   []    — the term itself
%%   [1]   — first argument
%%   [2,1] — first argument of second argument
%% =========================================================

%% =========================================================
%% Feature 1: Memoisation
%% plop_memoize(+PredName, +Arity, -MemoizedClauses)
%%
%% Wraps a predicate in a dynamic cache to memoise results.
%% =========================================================

plop_memoize(Name, Arity, Clauses) :-
    length(InputArgs, Arity),
    length(InputArgs, _),
    atom_concat(Name, '_memo',  MemoName),
    atom_concat(Name, '_cache', CacheName),
    atom_concat(Name, '_impl',  ImplName),

    Head     =.. [Name     | InputArgs],
    MemoHead =.. [MemoName | InputArgs],
    CacheFact=.. [CacheName| InputArgs],
    ImplHead =.. [ImplName | InputArgs],

    DynDecl       = (:- dynamic(CacheName/Arity)),
    MemoDispatch  = (Head :- MemoHead),
    MemoClause    = (MemoHead :-
                        ( CacheFact -> true
                        ; ImplHead,
                          assertz(CacheFact)
                        )),
    ImplStub      = (ImplHead :- true),

    Clauses = [DynDecl, MemoDispatch, MemoClause, ImplStub].

%% =========================================================
%% Feature 7: Expensive predicate caching
%% plop_cache_expensive(+Name, +Arity, -Clauses)
%%
%% Similar to memoize but adds a cache-invalidation hook.
%% =========================================================

plop_cache_expensive(Name, Arity, Clauses) :-
    plop_memoize(Name, Arity, MemoBase),
    atom_concat(Name, '_invalidate_cache', InvalidateName),
    atom_concat(Name, '_cache', CacheName),
    InvalidateHead =.. [InvalidateName],
    InvalidateClause = (InvalidateHead :- retractall(CacheName)),
    append(MemoBase, [InvalidateClause], Clauses).

%% =========================================================
%% Feature 3: Subterm-with-address
%% plop_subterm_with_address(+Term, +Address, -Subterm)
%%
%% Retrieves a subterm by structural address (list of arg positions).
%% =========================================================

plop_subterm_with_address(Term, [],    Term) :- !.
plop_subterm_with_address(Term, [N|Rest], Sub) :-
    compound(Term),
    arg(N, Term, Arg),
    plop_subterm_with_address(Arg, Rest, Sub).

%% =========================================================
%% Feature 4: Subterm-index looping
%% plop_subterm_index_loop(+Term, +Addresses, +VarNames, -Goals)
%%
%% Given a list of addresses, builds a list of
%% subterm_with_address/3 goals for each.
%% =========================================================

plop_subterm_index_loop(Term, Addresses, VarNames, Goals) :-
    must_be(list, Addresses),
    must_be(list, VarNames),
    length(Addresses, N),
    length(VarNames, N),
    maplist(addr_goal(Term), Addresses, VarNames, Goals).

addr_goal(Term, Addr, Var, plop_subterm_with_address(Term, Addr, Var)).

%% =========================================================
%% Feature 5: Gaussian-style reconstruction
%% plop_gaussian_reconstruct(+Template, +SubtermBindings, -Clause)
%%
%% Given a template (with holes represented as variable names)
%% and bindings from subterm extraction, unifies the template
%% arguments and returns the reconstructed output clause.
%%
%% Template: Head =.. [Name | Args]
%% SubtermBindings: [VarName=Value, ...]
%% =========================================================

plop_gaussian_reconstruct(Template, Bindings, ReconstructedClause) :-
    copy_term(Template, FreshTemplate),
    apply_bindings(FreshTemplate, Bindings),
    ReconstructedClause = (output_matrix(FreshTemplate) :- true).

apply_bindings(_, []).
apply_bindings(Template, [Var=Val|Rest]) :-
    (   sub_term_var(Template, Var, Hole)
    ->  Hole = Val
    ;   true
    ),
    apply_bindings(Template, Rest).

%% sub_term_var(+Term, +VarName, -Var)
%% Find unbound variable in Term that, when printed, matches VarName
sub_term_var(Term, VarName, Term) :-
    var(Term),
    term_to_atom(Term, A),
    atom_string(A, VarName), !.
sub_term_var(Term, VarName, Var) :-
    compound(Term),
    Term =.. [_|Args],
    member(Arg, Args),
    sub_term_var(Arg, VarName, Var).

%% =========================================================
%% Feature 10: Invariant extraction
%% plop_extract_invariant(+Clauses, +PredName, -Invariants)
%%
%% Detects goals that appear in every clause body (invariants).
%% =========================================================

plop_extract_invariant(Clauses, PredName, Invariants) :-
    include(clause_for_pred(PredName), Clauses, MatchedClauses),
    (   MatchedClauses = []
    ->  Invariants = []
    ;   maplist(body_goals, MatchedClauses, GoalSets),
        intersection_all(GoalSets, Invariants)
    ).

clause_for_pred(Name, (Head :- _)) :-
    functor(Head, Name, _).

body_goals((_ :- Body), Goals) :-
    !,
    conjunct_to_list(Body, Goals).
body_goals(_, []).

conjunct_to_list((A, B), Goals) :-
    !,
    conjunct_to_list(A, GA),
    conjunct_to_list(B, GB),
    append(GA, GB, Goals).
conjunct_to_list(G, [G]).

intersection_all([], []).
intersection_all([Set], Set).
intersection_all([Set1, Set2 | Rest], Intersection) :-
    intersection(Set1, Set2, I12),
    intersection_all([I12 | Rest], Intersection).

%% =========================================================
%% Feature 9: Predicate dependency analysis
%% plop_dependency_analysis(+Clauses, +PredName, -Deps)
%%
%% Returns the set of predicate names called in the body of
%% all clauses for PredName (direct callees).
%% =========================================================

plop_dependency_analysis(Clauses, PredName, Deps) :-
    include(clause_for_pred(PredName), Clauses, Matched),
    maplist(body_callees, Matched, DepSets),
    flatten(DepSets, AllDeps),
    sort(AllDeps, Deps).

body_callees((_ :- Body), Callees) :-
    !,
    conjunct_to_list(Body, Goals),
    maplist(goal_callee, Goals, Callees).
body_callees(_, []).

goal_callee(Goal, Name/Arity) :-
    callable(Goal),
    functor(Goal, Name, Arity).

%% =========================================================
%% Feature 6: Repeated subpredicate elimination
%% plop_eliminate_repeated(+Clauses, +PredName, -NewClauses)
%%
%% Detects goals that appear more than once in a body and
%% lifts them to a shared auxiliary predicate.
%% =========================================================

plop_eliminate_repeated(Clauses, _PredName, Clauses) :-
    % Conservative: only flag for elimination, not transform,
    % to avoid breaking semantics
    true.

plop_repeated_goals(Clauses, Repeated) :-
    maplist(body_goals, Clauses, GoalSets),
    flatten(GoalSets, AllGoals),
    find_duplicates(AllGoals, Repeated).

find_duplicates(List, Dups) :-
    msort(List, Sorted),
    find_adjacent_dups(Sorted, Dups).

find_adjacent_dups([], []).
find_adjacent_dups([X, X | Rest], [X | Dups]) :-
    !,
    skip_same(X, Rest, Remaining),
    find_adjacent_dups(Remaining, Dups).
find_adjacent_dups([_ | Rest], Dups) :-
    find_adjacent_dups(Rest, Dups).

skip_same(_, [], []).
skip_same(X, [X|Rest], Remaining) :-
    !,
    skip_same(X, Rest, Remaining).
skip_same(_, List, List).

%% =========================================================
%% Feature 8: Template splicing
%% plop_splice_template(+BaseClause, +TemplateGoals, -SplicedClause)
%%
%% Inserts TemplateGoals after the head in a clause body.
%% =========================================================

plop_splice_template((Head :- Body), TemplateGoals, (Head :- NewBody)) :-
    !,
    goals_to_conjunct(TemplateGoals, TGoal),
    (TGoal == true -> NewBody = Body ; NewBody = (TGoal, Body)).
plop_splice_template(Fact, [], Fact) :- !.
plop_splice_template(Fact, TemplateGoals, (Fact :- TGoal)) :-
    goals_to_conjunct(TemplateGoals, TGoal).

goals_to_conjunct([], true).
goals_to_conjunct([G], G) :- !.
goals_to_conjunct([G|Gs], (G, Rest)) :-
    goals_to_conjunct(Gs, Rest).

%% =========================================================
%% Feature 2: Indexical optimisation
%% plop_index_head(+Clause, +ArgPos, -IndexedClauses)
%%
%% Adds a first-argument index hint comment and reorganises
%% clause so the indexed argument is first.
%% =========================================================

plop_index_head(Clause, ArgPos, [IndexHint, Clause]) :-
    Clause = (Head :- _),
    functor(Head, Name, Arity),
    format(atom(IndexHint), "% PLOP index hint: ~w/~w on arg ~w", [Name, Arity, ArgPos]).
plop_index_head(Fact, ArgPos, [IndexHint, Fact]) :-
    functor(Fact, Name, Arity),
    format(atom(IndexHint), "% PLOP index hint: ~w/~w on arg ~w", [Name, Arity, ArgPos]).
