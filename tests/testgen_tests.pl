:- begin_tests(stage3_testgen).

:- use_module('../src/testgen').

%% Shared sample spec used across tests
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

sample_large_spec(spec(double_big, _{
    name: double_big,
    inputs: [list(number)],
    outputs: [list(number)],
    relation: map,
    operation: double,
    examples: [io(
        [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15],
        [2,4,6,8,10,12,14,16,18,20,22,24,26,28,30]
    )],
    constraints: [deterministic],
    warnings: [],
    classification: code_only
})).

sample_nested_spec(spec(wrap_items, _{
    name: wrap_items,
    inputs: [list(list(number))],
    outputs: [list(list(number))],
    relation: map,
    operation: identity,
    examples: [io([[1,2],[3,4]], [[1,2],[3,4]])],
    constraints: [deterministic],
    warnings: [],
    classification: code_only
})).

%% -------------------------------------------------------
%% generate_tests/2 — produces a code string
%% -------------------------------------------------------

test(generates_code_string) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    atomic(Code).

test(code_contains_begin_tests) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, ":- begin_tests(double_all).").

test(code_contains_end_tests) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, ":- end_tests(double_all).").

test(code_contains_example_1_test) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(example_1)").

test(code_contains_assertion_for_output) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "assertion(R == [2,4,6])").

%% -------------------------------------------------------
%% generate_test_lines/2 — produces a list of lines
%% -------------------------------------------------------

test(generates_lines_list) :-
    sample_spec(Spec),
    generate_test_lines(Spec, Lines),
    is_list(Lines),
    Lines \= [].

test(lines_start_with_begin_tests) :-
    sample_spec(Spec),
    generate_test_lines(Spec, [First|_]),
    sub_string(First, _, _, _, "begin_tests").

test(lines_end_with_end_tests) :-
    sample_spec(Spec),
    generate_test_lines(Spec, Lines),
    last(Lines, Last),
    sub_string(Last, _, _, _, "end_tests").

%% -------------------------------------------------------
%% Edge case 1: empty list test generated for map relation
%% -------------------------------------------------------

test(empty_list_test_generated) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(empty)"),
    sub_string(Code, _, _, _, "double_all([], R)").

%% -------------------------------------------------------
%% Edge case 2: single item test generated
%% -------------------------------------------------------

test(single_item_test_generated) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(single_item)").

%% -------------------------------------------------------
%% Edge case 3: more than 14 items test generated
%% -------------------------------------------------------

test(more_than_14_items_test_generated) :-
    sample_large_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(more_than_14_items)").

test(more_than_14_items_test_has_length_assertion) :-
    sample_large_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "assertion(length(R, 15))").

test(more_than_14_items_test_has_determinism_assertion) :-
    sample_large_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "assertion(once(").

%% -------------------------------------------------------
%% Edge case 4: duplicate input test generated for map
%% -------------------------------------------------------

test(duplicate_input_test_generated) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(duplicate_input)").

%% -------------------------------------------------------
%% Edge case 5: nested list test generated
%% -------------------------------------------------------

test(nested_list_test_generated) :-
    sample_nested_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(nested_list_case)").

%% -------------------------------------------------------
%% Edge case 6: mixed type rejection test generated
%% -------------------------------------------------------

test(mixed_type_rejection_test_generated) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(mixed_type_rejection, [fail])").

test(mixed_type_rejection_uses_mixed_list) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "double_all([1,a], _)").

%% -------------------------------------------------------
%% Edge case 8: ground and non-ground cases test
%% -------------------------------------------------------

test(ground_and_nonground_test_generated) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(ground_and_nonground_cases)").

%% -------------------------------------------------------
%% Edge case 9: deterministic single-success test
%% -------------------------------------------------------

test(deterministic_single_success_test_generated) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(deterministic_single_success)").

test(deterministic_single_success_uses_findall) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "findall(R,").

test(deterministic_single_success_asserts_singleton) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "assertion(Rs = [_])").

%% -------------------------------------------------------
%% Edge case 10: unsupported nondeterministic behaviour
%% -------------------------------------------------------

test(unsupported_nondeterministic_test_blocked) :-
    sample_spec(Spec),
    generate_tests(Spec, Code),
    sub_string(Code, _, _, _, "test(unsupported_nondeterministic_behaviour, [blocked(").

%% -------------------------------------------------------
%% spec_to_test_file/3
%% -------------------------------------------------------

test(spec_to_test_file_produces_module_header) :-
    sample_spec(Spec),
    spec_to_test_file(Spec, double_all_tests, FileCode),
    sub_string(FileCode, _, _, _, ":- module(double_all_tests, [run/0]).").

test(spec_to_test_file_contains_run_predicate) :-
    sample_spec(Spec),
    spec_to_test_file(Spec, double_all_tests, FileCode),
    sub_string(FileCode, _, _, _, "run :- run_tests.").

test(spec_to_test_file_contains_test_body) :-
    sample_spec(Spec),
    spec_to_test_file(Spec, double_all_tests, FileCode),
    sub_string(FileCode, _, _, _, "begin_tests(double_all)").

:- end_tests(stage3_testgen).
