:- module(predicate_merge, [
    merge_candidates/2,
    merge_predicates/3,
    merge_safe/2,
    merge_unsafe_reason/2,
    merge_detect/3
]).

%% =========================================================
%% Stage 9: Predicate Merging
%%
%% Detects when predicates should be merged and generates
%% merged forms that parameterise the common structure.
%%
%% Merge candidate relations:
%%   1. Same input/output examples
%%   2. Same recursive shape
%%   3. Same invariant
%%   4. Same generator source
%%   5. Same output template
%%   6. One is a special case of another
%%   7. One is a renamed duplicate
%%   8. One differs only by constants
%%   9. One can be parameterised
%%  10. Two share expensive subcalls
%%
%% A merge is UNSAFE if it changes observable semantics.
%% =========================================================

%% =========================================================
%% merge_candidates(+Specs, -Pairs)
%%
%% Given a list of spec(Name, Dict) terms, returns pairs of
%% specs that are candidates for merging.
%% =========================================================

merge_candidates(Specs, Pairs) :-
    findall(pair(S1, S2, Reason),
        (member(S1, Specs),
         member(S2, Specs),
         S1 @< S2,
         merge_detect(S1, S2, Reason)),
        Pairs).

%% =========================================================
%% merge_detect(+Spec1, +Spec2, -Reason)
%%
%% Succeeds when two specs have a detectable merge relation.
%% =========================================================

%% 1. Same input/output examples
merge_detect(spec(_, D1), spec(_, D2), same_examples) :-
    D1.get(examples) == D2.get(examples), !.

%% 2. Same recursive shape (same relation)
merge_detect(spec(_, D1), spec(_, D2), same_recursive_shape) :-
    D1.get(relation) == D2.get(relation),
    D1.get(relation) \== transform,
    !.

%% 3. Same invariant / constraints
merge_detect(spec(_, D1), spec(_, D2), same_invariant) :-
    D1.get(constraints) == D2.get(constraints),
    D1.get(constraints) \== [],
    !.

%% 4. Same generator source (same input types)
merge_detect(spec(_, D1), spec(_, D2), same_generator_source) :-
    D1.get(inputs) == D2.get(inputs),
    D1.get(outputs) == D2.get(outputs),
    !.

%% 5. Same output template (same output types)
merge_detect(spec(_, D1), spec(_, D2), same_output_template) :-
    D1.get(outputs) == D2.get(outputs),
    !.

%% 6. One is a special case: one has extra constraints
merge_detect(spec(_, D1), spec(_, D2), special_case) :-
    D1.get(relation) == D2.get(relation),
    D1.get(operation) \== D2.get(operation),
    D1.get(inputs) == D2.get(inputs),
    !.

%% 8. Same structure but differ by operation constant
merge_detect(spec(_, D1), spec(_, D2), differ_by_constant) :-
    D1.get(relation) == D2.get(relation),
    D1.get(inputs)   == D2.get(inputs),
    D1.get(outputs)  == D2.get(outputs),
    D1.get(operation) \== D2.get(operation),
    !.

%% 7. Renamed duplicate (same everything, different name)
merge_detect(spec(N1, D1), spec(N2, D2), renamed_duplicate) :-
    N1 \== N2,
    D1.get(relation)    == D2.get(relation),
    D1.get(operation)   == D2.get(operation),
    D1.get(inputs)      == D2.get(inputs),
    D1.get(outputs)     == D2.get(outputs),
    D1.get(constraints) == D2.get(constraints),
    !.

%% 9. Can be parameterised (differ by numeric operation)
merge_detect(spec(_, D1), spec(_, D2), can_parameterise) :-
    D1.get(relation) == map,
    D2.get(relation) == map,
    numeric_multiply_op(D1.get(operation)),
    numeric_multiply_op(D2.get(operation)),
    D1.get(operation) \== D2.get(operation),
    !.

%% 10. Share expensive subcalls (same relation, any inputs)
merge_detect(spec(_, D1), spec(_, D2), shared_expensive_subcall) :-
    D1.get(relation) == D2.get(relation),
    D1.get(inputs) \== D2.get(inputs),
    !.

numeric_multiply_op(double).
numeric_multiply_op(triple).
numeric_multiply_op(square).

%% =========================================================
%% merge_safe(+Pair, -MergedSpec)
%%
%% Attempts a safe merge: returns a merged spec when safe.
%% =========================================================

merge_safe(pair(spec(N1, D1), spec(N2, D2), differ_by_constant),
           merged(N1, N2, MergedCode)) :-
    D1.get(relation) == map,
    !,
    op_multiplier(D1.get(operation), M1),
    op_multiplier(D2.get(operation), M2),
    generate_merged_multiply(N1, N2, M1, M2, MergedCode).

merge_safe(pair(spec(N1, D1), spec(N2, D2), can_parameterise),
           merged(N1, N2, MergedCode)) :-
    !,
    op_multiplier(D1.get(operation), M1),
    op_multiplier(D2.get(operation), M2),
    generate_merged_multiply(N1, N2, M1, M2, MergedCode).

merge_safe(pair(spec(N1, _), spec(N2, _), renamed_duplicate),
           merged(N1, N2, Code)) :-
    !,
    format(string(Code),
        "% ~w and ~w are renamed duplicates; retain ~w, alias ~w.",
        [N1, N2, N1, N2]).

%% =========================================================
%% merge_unsafe_reason(+Pair, -Reason)
%%
%% Reports why a merge pair is UNSAFE.
%% =========================================================

merge_unsafe_reason(pair(spec(_, D1), spec(_, D2), _), different_argument_counts) :-
    D1.get(inputs) \== D2.get(inputs),
    length(D1.get(inputs), L1),
    length(D2.get(inputs), L2),
    L1 \== L2,
    !.

merge_unsafe_reason(pair(_, _, same_examples), contradictory_if_merged) :-
    !.

merge_unsafe_reason(pair(spec(_, D1), spec(_, D2), _), incompatible_constraints) :-
    D1.get(constraints) \== D2.get(constraints),
    D1.get(constraints) \== [],
    D2.get(constraints) \== [],
    !.

%% =========================================================
%% merge_predicates(+Spec1, +Spec2, -MergedCode)
%%
%% High-level entry point: merges two specs if safe.
%% =========================================================

merge_predicates(Spec1, Spec2, MergedCode) :-
    merge_detect(Spec1, Spec2, Reason),
    Pair = pair(Spec1, Spec2, Reason),
    \+ merge_unsafe_reason(Pair, _),
    !,
    merge_safe(Pair, merged(_, _, MergedCode)).

%% =========================================================
%% Helpers
%% =========================================================

op_multiplier(double, 2) :- !.
op_multiplier(triple, 3) :- !.
op_multiplier(square, 0) :- !.  % X*X, treated as non-N form
op_multiplier(increment, 0) :- !.
op_multiplier(_, 1).

generate_merged_multiply(N1, N2, M1, M2, Code) :-
    format(string(Code),
        "multiply_all(_, [], []).~n\
multiply_all(N, [X|Xs], [Y|Ys]) :-~n\
    Y is X * N,~n\
    multiply_all(N, Xs, Ys).~n\
~w(Xs, Ys) :- multiply_all(~w, Xs, Ys).~n\
~w(Xs, Ys) :- multiply_all(~w, Xs, Ys).",
        [N1, M1, N2, M2]).
