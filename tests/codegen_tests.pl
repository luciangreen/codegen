:- begin_tests(codegen).

:- use_module('../src/s2a_bridge').
:- use_module('../src/caw_codegen').

sample_spec(spec(double_all, _{
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

sample_large_spec(spec(double_all_long, _{
    name: double_all_long,
    inputs: [list(number)],
    outputs: [list(number)],
    relation: map,
    operation: double,
    examples: [io(
        [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],
        [2,4,6,8,10,12,14,16,18,20,22,24,26,28,30]
    )],
    constraints: [deterministic, order_preserved, same_length],
    warnings: [too_many_examples_or_items],
    classification: code_only
})).

test(s2a_induction_profile) :-
    sample_spec(Spec),
    s2a_induce(Spec, Profile),
    assertion(Profile.name == double_all),
    assertion(Profile.relation == map),
    assertion(Profile.operation == double),
    assertion(Profile.requires_recursion == true),
    assertion(Profile.template_priorities == [recursion, map_filter_fold, direct, predicate_reuse, predicate_merge, generator, loop2_deterministic, plop_optimised, starlog_expression]).

test(caw_generates_stage4_template_set) :-
    sample_spec(Spec),
    generate_candidates(Spec, Candidates),
    findall(T, member(candidate(T, _, _), Candidates), Templates),
    sort(Templates, TemplateSet),
    assertion(TemplateSet == [
        direct,
        generator,
        loop2_deterministic,
        map_filter_fold,
        plop_optimised,
        predicate_merge,
        predicate_reuse,
        recursion,
        starlog_expression
    ]).

test(recursion_candidate_has_expected_shape) :-
    sample_spec(Spec),
    generate_candidates(Spec, Candidates),
    member(candidate(recursion, _, Code), Candidates),
    sub_string(Code, _, _, _, "double_all([], [])."),
    sub_string(Code, _, _, _, "double_all([X|Xs], [Y|Ys])"),
    sub_string(Code, _, _, _, "Y is X * 2").

test(best_candidate_prefers_recursive_map_solution) :-
    sample_spec(Spec),
    best_candidate(Spec, candidate(recursion, Score, Code)),
    assertion(Score > 0.9),
    sub_string(Code, _, _, _, "double_all(Xs, Ys)").

test(stage5_profile_activates_for_large_examples) :-
    sample_large_spec(Spec),
    s2a_induce(Spec, Profile),
    Stage5 = Profile.stage5,
    assertion(Stage5.active == true),
    assertion(Stage5.window_size == 14),
    assertion(Stage5.manual_class == map),
    assertion(member(chunked_windows, Stage5.repeated_local_patterns)),
    assertion(member(operation(double), Stage5.compressed_rules)),
    assertion(member(candidate(recursion, map_operation(double)), Stage5.reconstructed_candidates)),
    assertion(Stage5.verified_on_complete_examples == true).

test(stage5_prioritised_templates_reduce_search_space) :-
    sample_large_spec(Spec),
    generate_candidates(Spec, Candidates),
    findall(T, member(candidate(T, _, _), Candidates), Templates),
    assertion(Templates = [recursion|_]),
    assertion(member(map_filter_fold, Templates)),
    assertion(member(direct, Templates)),
    length(Templates, N),
    assertion(N =< 4).

:- end_tests(codegen).