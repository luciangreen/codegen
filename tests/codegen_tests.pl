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
    assertion(member(test_todo(single_item, double_all, _, _), Tests)).

test(generates_duplicate_inputs_test) :-
    double_all_spec(Spec),
    generate_tests(Spec, Tests),
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
