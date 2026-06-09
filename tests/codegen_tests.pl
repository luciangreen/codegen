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
    assertion(length(Templates, N)),
    assertion(N =< 4).

:- end_tests(codegen).
:- begin_tests(stage3_testgen).

:- use_module('../src/testgen').
:- use_module('../src/parser').

% ---- Helpers ----

double_all_spec(spec(double_all, _{
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

map_atoms_spec(spec(upper_all, _{
    name: upper_all,
    inputs: [list(atom)],
    outputs: [list(atom)],
    relation: map,
    operation: unknown,
    examples: [io([a,b,c], [aa,bb,cc])],
    constraints: [deterministic, order_preserved, same_length],
    warnings: [],
    classification: code_only
})).

generator_spec(spec(find_evens, _{
    name: find_evens,
    inputs: [list(number)],
    outputs: [list(number)],
    relation: generator_search,
    operation: find,
    examples: [],
    constraints: [deterministic, generator_search],
    warnings: [],
    classification: code_only
})).

% ---- generate_tests/2 ----

test(generates_non_empty_tests) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
    assertion(Tests \== []).

test(generates_example_test) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
    assertion(member(test(example_1, double_all, [1,2,3], [2,4,6], example), Tests)).

test(generates_empty_list_test) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
    assertion(member(test(empty, double_all, [], [], empty_list), Tests)).

test(generates_single_item_todo) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
    % Single item uses type-appropriate placeholder (1 for list(number))
    assertion(member(test_todo(single_item, double_all, [1], _), Tests)).

test(generates_duplicate_inputs_test) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
    % Expected output is left as _ since it depends on the generated predicate's behaviour
    assertion(member(test(duplicate_inputs, double_all, [1,1], _, duplicate), Tests)).

test(generates_mixed_type_rejection) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
    assertion(member(test_fail(mixed_type_rejection, double_all, _), Tests)).

test(generates_variables_in_input_todo) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
    assertion(member(test_todo(variables_in_input, double_all, _, _), Tests)).

test(generates_deterministic_test) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
    assertion(member(test_deterministic(double_all, _), Tests)).

test(multiple_examples_numbered) :-
    Spec = spec(multi, _{
        name: multi,
        inputs: [list(number)],
        outputs: [list(number)],
        relation: map,
        operation: double,
        examples: [io([1], [2]), io([3], [6])],
        constraints: [deterministic],
        warnings: [],
        classification: code_only
    }),
    generate_tests(Spec, Tests),
    assertion(member(test(example_1, multi, [1], [2], example), Tests)),
    assertion(member(test(example_2, multi, [3], [6], example), Tests)).

test(no_example_tests_for_empty_examples) :-
    Spec = spec(mystery, _{
        name: mystery,
        inputs: [list(number)],
        outputs: [list(number)],
        relation: map,
        operation: unknown,
        examples: [],
        constraints: [deterministic],
        warnings: [no_examples],
        classification: code_only
    }),
    generate_tests(Spec, Tests),
    \+ member(test(example_1, _, _, _, _), Tests).

test(skips_nondeterministic_if_generator) :-
    generator_spec(Spec),
    generate_tests(Spec, Tests),
    assertion(member(test_skip(nondeterministic_behaviour, nondeterminism_not_supported), Tests)).

test(nested_list_todo_for_nested_input) :-
    Spec = spec(flatten, _{
        name: flatten,
        inputs: [list(list(number))],
        outputs: [list(number)],
        relation: transform,
        operation: unknown,
        examples: [io([[1,2],[3,4]], [1,2,3,4])],
        constraints: [deterministic],
        warnings: [],
        classification: code_only
    }),
    generate_tests(Spec, Tests),
    assertion(member(test_todo(nested_list, flatten, [[1,2],[3,4]], _), Tests)).

test(atom_list_duplicate_uses_atoms) :-
    map_atoms_spec(Spec),
    generate_tests(Spec, Tests),
    assertion(member(test(duplicate_inputs, upper_all, [a,a], _, duplicate), Tests)).

% ---- spec_to_tests/2 ----

test(emits_begin_end_tests) :-
    double_all_spec(Spec),
    spec_to_tests(Spec, Code),
    assertion(sub_string(Code, _, _, _, ":- begin_tests(double_all).")),
    assertion(sub_string(Code, _, _, _, ":- end_tests(double_all).")).

test(emits_example_test_call) :-
    double_all_spec(Spec),
    spec_to_tests(Spec, Code),
    assertion(sub_string(Code, _, _, _, "test(example_1)")),
    assertion(sub_string(Code, _, _, _, "double_all([1,2,3], R)")),
    assertion(sub_string(Code, _, _, _, "assertion(R == [2,4,6])")).

test(emits_empty_test) :-
    double_all_spec(Spec),
    spec_to_tests(Spec, Code),
    assertion(sub_string(Code, _, _, _, "test(empty)")),
    assertion(sub_string(Code, _, _, _, "double_all([], R)")).

test(emits_deterministic_option) :-
    double_all_spec(Spec),
    spec_to_tests(Spec, Code),
    assertion(sub_string(Code, _, _, _, "test(deterministic, [deterministic])")).

test(emits_skip_for_nondeterministic) :-
    generator_spec(Spec),
    spec_to_tests(Spec, Code),
    assertion(sub_string(Code, _, _, _, "test(nondeterministic_behaviour, [skip(nondeterminism_not_supported)])")).

test(emits_fail_for_mixed_types) :-
    double_all_spec(Spec),
    spec_to_tests(Spec, Code),
    assertion(sub_string(Code, _, _, _, "test(mixed_type_rejection, [fail])")).

test(code_is_string) :-
    double_all_spec(Spec),
    spec_to_tests(Spec, Code),
    assertion(string(Code)).

test(integrates_with_parser, [nondet]) :-
    Sentence = 'Generate a predicate double_all(Input, Output) that maps every number in Input to twice its value. Examples: [1,2,3] -> [2,4,6].',
    sentence_to_spec(Sentence, Spec),
    generate_tests(Spec, Tests),
    assertion(Tests \== []).

:- end_tests(stage3_testgen).
