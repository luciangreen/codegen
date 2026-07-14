:- begin_tests(stage9_merge).

:- use_module('../src/predicate_merge').

%% -------------------------------------------------------
%% Shared test specs
%% -------------------------------------------------------

double_spec(spec(double_all, _{
    name: double_all,
    inputs: [list(number)],
    outputs: [list(number)],
    relation: map,
    operation: double,
    examples: [io([1,2,3], [2,4,6])],
    constraints: [deterministic, order_preserved, same_length],
    warnings: [],
    classification: code_only
})).

triple_spec(spec(triple_all, _{
    name: triple_all,
    inputs: [list(number)],
    outputs: [list(number)],
    relation: map,
    operation: triple,
    examples: [io([1,2,3], [3,6,9])],
    constraints: [deterministic, order_preserved, same_length],
    warnings: [],
    classification: code_only
})).

%% Filter spec — different relation
keep_positive_spec(spec(keep_positive, _{
    name: keep_positive,
    inputs: [list(number)],
    outputs: [list(number)],
    relation: filter,
    operation: positive,
    examples: [io([1,-2,3], [1,3])],
    constraints: [deterministic, order_preserved],
    warnings: [],
    classification: code_only
})).

%% Renamed duplicate of double_all
dbl_spec(spec(dbl, _{
    name: dbl,
    inputs: [list(number)],
    outputs: [list(number)],
    relation: map,
    operation: double,
    examples: [io([1,2,3], [2,4,6])],
    constraints: [deterministic, order_preserved, same_length],
    warnings: [],
    classification: code_only
})).

%% -------------------------------------------------------
%% Merge detection
%% -------------------------------------------------------

test(detect_differ_by_constant) :-
    double_spec(S1),
    triple_spec(S2),
    merge_detect(S1, S2, Reason),
    assertion(Reason == differ_by_constant).

test(detect_can_parameterise) :-
    double_spec(S1),
    triple_spec(S2),
    merge_detect(S1, S2, can_parameterise).

test(detect_renamed_duplicate) :-
    double_spec(S1),
    dbl_spec(S2),
    merge_detect(S1, S2, renamed_duplicate).

test(detect_same_output_template) :-
    double_spec(S1),
    triple_spec(S2),
    merge_detect(S1, S2, same_output_template).

test(detect_same_recursive_shape) :-
    double_spec(S1),
    keep_positive_spec(S2),
    \+ merge_detect(S1, S2, renamed_duplicate).  % different operations

%% -------------------------------------------------------
%% merge_candidates/2
%% -------------------------------------------------------

test(candidates_finds_double_triple_pair) :-
    double_spec(S1),
    triple_spec(S2),
    merge_candidates([S1, S2], Pairs),
    Pairs \= [].

test(candidates_list_three_specs) :-
    double_spec(S1),
    triple_spec(S2),
    keep_positive_spec(S3),
    merge_candidates([S1, S2, S3], Pairs),
    length(Pairs, N),
    assertion(N >= 2).

%% -------------------------------------------------------
%% Merge 8: differ by constant → parameterise
%% -------------------------------------------------------

test(merge_differ_by_constant_generates_multiply_all) :-
    double_spec(S1),
    triple_spec(S2),
    merge_predicates(S1, S2, Code),
    sub_string(Code, _, _, _, "multiply_all"),
    sub_string(Code, _, _, _, "double_all"),
    sub_string(Code, _, _, _, "triple_all").

test(merged_code_has_multiplier_params) :-
    double_spec(S1),
    triple_spec(S2),
    merge_predicates(S1, S2, Code),
    sub_string(Code, _, _, _, "2"),
    sub_string(Code, _, _, _, "3").

%% -------------------------------------------------------
%% Merge 7: renamed duplicate
%% -------------------------------------------------------

test(merge_renamed_duplicate_aliases) :-
    double_spec(S1),
    dbl_spec(S2),
    merge_predicates(S1, S2, Code),
    sub_string(Code, _, _, _, "renamed duplicate").

%% -------------------------------------------------------
%% merge_safe/2
%% -------------------------------------------------------

test(merge_safe_produces_merged) :-
    double_spec(S1),
    triple_spec(S2),
    merge_detect(S1, S2, Reason),
    merge_safe(pair(S1, S2, Reason), merged(_, _, Code)),
    sub_string(Code, _, _, _, "multiply_all").

%% -------------------------------------------------------
%% Unsafe merges reported
%% -------------------------------------------------------

%% Different arg counts would be unsafe
test(unsafe_reason_different_arg_counts) :-
    S1 = spec(p, _{inputs: [list(number)], outputs: [list(number)],
                   relation: map, operation: double,
                   examples: [], constraints: [deterministic], warnings: [], classification: code_only}),
    S2 = spec(q, _{inputs: [list(number), number], outputs: [list(number)],
                   relation: map, operation: triple,
                   examples: [], constraints: [deterministic], warnings: [], classification: code_only}),
    merge_unsafe_reason(pair(S1, S2, differ_by_constant), Reason),
    assertion(Reason == different_argument_counts).

%% -------------------------------------------------------
%% Acceptance: full example from pr1.txt
%% -------------------------------------------------------

test(double_triple_merge_matches_spec) :-
    double_spec(S1),
    triple_spec(S2),
    merge_predicates(S1, S2, Code),
    sub_string(Code, _, _, _, "multiply_all(N, [X|Xs], [Y|Ys])"),
    sub_string(Code, _, _, _, "Y is X * N").

test(merge_accepts_dict_put_update_term) :-
    double_spec(spec(double_all, D1)),
    S2 = spec(triple_all, D1.put(_{
        name: triple_all,
        operation: triple,
        examples: [io([1,2,3], [3,6,9])]
    })),
    merge_predicates(spec(double_all, D1), S2, Code),
    sub_string(Code, _, _, _, "double_all"),
    sub_string(Code, _, _, _, "triple_all").

:- end_tests(stage9_merge).
