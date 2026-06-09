:- module(caw_codegen, [
    generate_candidates/2,
    best_candidate/2,
    generate_best_code/2
]).

:- use_module(s2a_bridge).

generate_candidates(Spec, Candidates) :-
    s2a_bridge:s2a_induce(Spec, Profile),
    build_candidates(Spec, Profile, Candidates).

best_candidate(Spec, Best) :-
    generate_candidates(Spec, Candidates),
    sort_candidates(Candidates, [Best|_]).

generate_best_code(Spec, Code) :-
    best_candidate(Spec, candidate(_, _, Code)).

build_candidates(spec(Name, Dict), Profile, Candidates) :-
    Operation = Dict.get(operation),
    BasePredicate = Name,
    op_goal(Operation, OpGoal),
    findall(
        candidate(Template, Score, Code),
        candidate_template(Template, BasePredicate, OpGoal, Profile, Score, Code),
        Candidates
    ).

candidate_template(direct, Name, OpGoal, Profile, Score, Code) :-
    code_direct(Name, OpGoal, Code),
    template_score(direct, Profile, Score).
candidate_template(recursion, Name, OpGoal, Profile, Score, Code) :-
    code_recursion(Name, OpGoal, Code),
    template_score(recursion, Profile, Score).
candidate_template(map_filter_fold, Name, OpGoal, Profile, Score, Code) :-
    code_map_filter_fold(Name, OpGoal, Code),
    template_score(map_filter_fold, Profile, Score).
candidate_template(generator, Name, OpGoal, Profile, Score, Code) :-
    code_generator(Name, OpGoal, Code),
    template_score(generator, Profile, Score).
candidate_template(starlog_expression, Name, _, Profile, Score, Code) :-
    code_starlog(Name, Code),
    template_score(starlog_expression, Profile, Score).
candidate_template(loop2_deterministic, Name, OpGoal, Profile, Score, Code) :-
    code_loop2(Name, OpGoal, Code),
    template_score(loop2_deterministic, Profile, Score).
candidate_template(plop_optimised, Name, OpGoal, Profile, Score, Code) :-
    code_plop(Name, OpGoal, Code),
    template_score(plop_optimised, Profile, Score).
candidate_template(predicate_reuse, Name, OpGoal, Profile, Score, Code) :-
    code_predicate_reuse(Name, OpGoal, Code),
    template_score(predicate_reuse, Profile, Score).
candidate_template(predicate_merge, Name, OpGoal, Profile, Score, Code) :-
    code_predicate_merge(Name, OpGoal, Code),
    template_score(predicate_merge, Profile, Score).

template_score(recursion, Profile, 0.96) :-
    Profile.relation == map,
    Profile.requires_recursion == true,
    !.
template_score(map_filter_fold, Profile, 0.91) :-
    Profile.relation == map,
    !.
template_score(direct, _, 0.80).
template_score(predicate_reuse, _, 0.73).
template_score(predicate_merge, _, 0.70).
template_score(generator, _, 0.66).
template_score(loop2_deterministic, _, 0.64).
template_score(plop_optimised, _, 0.60).
template_score(starlog_expression, _, 0.55).

sort_candidates(Candidates, Sorted) :-
    predsort(compare_candidate, Candidates, Sorted).

compare_candidate(Order, candidate(_, ScoreA, _), candidate(_, ScoreB, _)) :-
    compare(Order0, ScoreB, ScoreA),
    (Order0 == (=) -> Order = (=) ; Order = Order0).

op_goal(double, "Y is X * 2").
op_goal(triple, "Y is X * 3").
op_goal(square, "Y is X * X").
op_goal(increment, "Y is X + 1").
op_goal(decrement, "Y is X - 1").
op_goal(_, "Y = X").

code_direct(Name, OpGoal, Code) :-
    format(string(Code),
        "~w(Input, Output) :-~n    maplist(~w_elem, Input, Output).~n~w_elem(X, Y) :-~n    ~w.",
        [Name, Name, Name, OpGoal]).

code_recursion(Name, OpGoal, Code) :-
    format(string(Code),
        "~w([], []).~n~w([X|Xs], [Y|Ys]) :-~n    ~w,~n    ~w(Xs, Ys).",
        [Name, Name, OpGoal, Name]).

code_map_filter_fold(Name, OpGoal, Code) :-
    format(string(Code),
        "~w(Input, Output) :-~n    foldl(~w_step, Input, [], Rev),~n    reverse(Rev, Output).~n~w_step(X, Acc, [Y|Acc]) :-~n    ~w.",
        [Name, Name, Name, OpGoal]).

code_generator(Name, OpGoal, Code) :-
    format(string(Code),
        "~w(Input, Output) :-~n    findall(Y, (member(X, Input), ~w), Output).",
        [Name, OpGoal]).

code_starlog(Name, Code) :-
    format(string(Code),
        "~w(Input, Output) :-~n    Output is Input >> map(double).",
        [Name]).

code_loop2(Name, OpGoal, Code) :-
    format(string(Code),
        "~w(Input, Output) :-~n    loop001(Input, Output).~nloop001([], []).~nloop001([X|Xs], [Y|Ys]) :-~n    ~w,~n    loop001(Xs, Ys).",
        [Name, OpGoal]).

code_plop(Name, OpGoal, Code) :-
    atom_concat(Name, '_helper', HelperName),
    format(string(Code),
        "~w(Input, Output) :-~n    ~w_memo(Input, Output).~n:- dynamic ~w_cache/2.~n~w_memo(Input, Output) :-~n    ( ~w_cache(Input, Output) -> true~n    ; ~w(Input, Output), assertz(~w_cache(Input, Output))~n    ).~n~w(Input, Output) :-~n    ~w(Input, Output).~n~w([], []).~n~w([X|Xs], [Y|Ys]) :-~n    ~w,~n    ~w(Xs, Ys).",
        [Name, Name, Name, Name, Name, HelperName, Name, HelperName, HelperName, HelperName, HelperName, OpGoal, HelperName]).

code_predicate_reuse(Name, OpGoal, Code) :-
    op_to_multiplier(OpGoal, Multiplier),
    format(string(Code),
        "multiply_all(N, [], []).~nmultiply_all(N, [X|Xs], [Y|Ys]) :-~n    Y is X * N,~n    multiply_all(N, Xs, Ys).~n~w(Xs, Ys) :-~n    multiply_all(~w, Xs, Ys).",
        [Name, Multiplier]).

code_predicate_merge(Name, OpGoal, Code) :-
    op_to_multiplier(OpGoal, Multiplier),
    merged_variant(Name, VariantName, VariantFactor),
    format(string(Code),
        "multiply_all(N, [], []).~nmultiply_all(N, [X|Xs], [Y|Ys]) :-~n    Y is X * N,~n    multiply_all(N, Xs, Ys).~n~w(Xs, Ys) :-~n    multiply_all(~w, Xs, Ys).~n~w(Xs, Ys) :-~n    multiply_all(~w, Xs, Ys).",
        [Name, Multiplier, VariantName, VariantFactor]).

op_to_multiplier("Y is X * 2", 2) :- !.
op_to_multiplier("Y is X * 3", 3) :- !.
op_to_multiplier(_, 2).

merged_variant(Name, VariantName, VariantFactor) :-
    atom_concat(Name, '_variant', VariantName),
    VariantFactor = 3.