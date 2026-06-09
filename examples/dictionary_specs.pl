:- module(dictionary_specs, [expected_spec/2]).

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