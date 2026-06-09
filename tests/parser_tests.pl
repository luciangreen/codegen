:- begin_tests(stage2_parser).

:- use_module('../src/parser').
:- use_module('../src/dictionary').

test(parses_double_all_spec) :-
    Sentence = 'Generate a predicate double_all(Input, Output) that maps every number in Input to twice its value. Examples: [1,2,3] -> [2,4,6].',
    sentence_to_spec(Sentence, spec(double_all, Dict)),
    assertion(Dict.inputs == [list(number)]),
    assertion(Dict.outputs == [list(number)]),
    assertion(Dict.relation == map),
    assertion(Dict.operation == double),
    assertion(Dict.examples == [io([1,2,3], [2,4,6])]),
    assertion(Dict.warnings == []).

test(missing_input_type_warning) :-
    Sentence = 'Generate a predicate normalize(Input, Output) that maps Input to Output.',
    sentence_to_spec(Sentence, spec(normalize, Dict)),
    assertion(member(missing_input_type, Dict.warnings)).

test(multiple_outputs_warning) :-
    Sentence = 'Generate a predicate split(Input, Left, Right) that maps every number in Input to twice its value.',
    sentence_to_spec(Sentence, spec(split, Dict)),
    assertion(member(multiple_outputs, Dict.warnings)).

test(ambiguous_verb_warning) :-
    Sentence = 'Generate a predicate tweak(Input, Output) that can change every number in Input.',
    sentence_to_spec(Sentence, spec(tweak, Dict)),
    assertion(member(ambiguous_verb(change), Dict.warnings)).

test(tests_only_classification) :-
    Sentence = 'Create a test that checks [1,2] -> [2,4].',
    sentence_to_spec(Sentence, spec(unknown_predicate, Dict)),
    assertion(Dict.classification == tests_only),
    assertion(member(tests_without_code, Dict.warnings)).

test(contradictory_examples_warning) :-
    Sentence = 'Generate a predicate f(Input, Output) that maps every number in Input to twice its value. Examples: [1] -> [2]; [1] -> [3].',
    sentence_to_spec(Sentence, spec(f, Dict)),
    assertion(member(contradictory_examples, Dict.warnings)).

test(large_examples_warning) :-
    Sentence = 'Generate a predicate long_map(Input, Output) that maps every number in Input to twice its value. Examples: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15] -> [2,4,6,8,10,12,14,16,18,20,22,24,26,28,30].',
    sentence_to_spec(Sentence, spec(long_map, Dict)),
    assertion(member(too_many_examples_or_items, Dict.warnings)).

test(extra_constraints) :-
    Sentence = 'Generate a predicate rebuild(Input, Output) that maps every number in Input to twice its value and requires recursion, generator support, merge candidates, and change previous tests.',
    sentence_to_spec(Sentence, spec(rebuild, Dict)),
    assertion(member(recursive, Dict.constraints)),
    assertion(member(generator_search, Dict.constraints)),
    assertion(member(predicate_merge, Dict.constraints)),
    assertion(member(test_repair, Dict.constraints)).

test(nested_structure_type) :-
    Sentence = 'Generate a predicate flatten_rows(Input, Output) that maps list of lists of numbers in Input.',
    sentence_to_spec(Sentence, spec(flatten_rows, Dict)),
    assertion(Dict.inputs == [list(list(number))]),
    assertion(member(nested_structures, Dict.constraints)).

test(dictionary_bridge_single) :-
    Sentence = 'Generate a predicate double_all(Input, Output) that maps every number in Input to twice its value.',
    sentence_spec_dict(Sentence, spec(double_all, _)).

test(dictionary_bridge_many) :-
    Sentences = [
        'Generate a predicate a(Input, Output) that maps every number in Input to twice its value.',
        'Generate a predicate b(Input, Output) that maps every number in Input to twice its value.'
    ],
    sentences_to_dictionary(Sentences, Specs),
    assertion(length(Specs, 2)).

% Edge case 2: missing output type generates a warning
test(missing_output_type_warning) :-
    Sentence = 'Generate a predicate foo(Input, Output) that converts a number.',
    sentence_to_spec(Sentence, spec(foo, Dict)),
    assertion(member(missing_output_type, Dict.warnings)).

% Edge case 8: code-only spec (no mention of tests) classified as code_only
test(code_only_classification) :-
    Sentence = 'Generate a predicate reverse_list(Input, Output) that maps every number in Input to twice its value.',
    sentence_to_spec(Sentence, spec(reverse_list, Dict)),
    assertion(Dict.classification == code_only).

:- end_tests(stage2_parser).