:- module(dictionary_specs, [expected_spec/2]).

% Canonical double_all spec (from the Stage 2 requirements example)
expected_spec(double_all,
    spec(double_all, _{
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

% Edge case 3: multiple outputs
expected_spec(split_list,
    spec(split_list, _{
        name: split_list,
        inputs: [list(number)],
        outputs: [list(number), list(number)],
        relation: map,
        operation: double,
        examples: [],
        constraints: [deterministic, order_preserved, same_length],
        warnings: [multiple_outputs, no_examples],
        classification: code_only
    })).

% Edge case 4: nested structures
expected_spec(flatten_rows,
    spec(flatten_rows, _{
        name: flatten_rows,
        inputs: [list(list(number))],
        outputs: [list(list(number))],
        relation: map,
        operation: unknown,
        examples: [],
        constraints: [deterministic, nested_structures, order_preserved, same_length],
        warnings: [no_examples],
        classification: code_only
    })).

% Edge case 7: tests-only classification
expected_spec(check_mapping,
    spec(unknown_predicate, _{
        name: unknown_predicate,
        inputs: [list(number)],
        outputs: [list(number)],
        relation: map,
        operation: unknown,
        examples: [io([1,2], [2,4])],
        constraints: [deterministic, order_preserved, same_length],
        warnings: [tests_without_code],
        classification: tests_only
    })).

% Edge case 11-14: extra constraints
expected_spec(rebuild,
    spec(rebuild, _{
        name: rebuild,
        inputs: [list(number)],
        outputs: [list(number)],
        relation: map,
        operation: double,
        examples: [],
        constraints: [deterministic, generator_search, nested_structures, order_preserved,
                      predicate_merge, recursive, same_length, test_repair],
        warnings: [no_examples],
        classification: code_only
    })).
