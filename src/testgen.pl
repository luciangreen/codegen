:- module(testgen, [
    spec_to_tests/2,
    generate_tests/2
]).

:- use_module(library(lists)).
:- use_module(library(apply)).

%% spec_to_tests(+Spec:spec, -Code:string) is det.
%  Generate a Prolog plunit test block as a string from a dictionary spec.
spec_to_tests(spec(Name, Dict), Code) :-
    generate_tests(spec(Name, Dict), Tests),
    with_output_to(string(Code), emit_test_block(Name, Tests)).

%% generate_tests(+Spec:spec, -Tests:list) is det.
%  Generate a list of test descriptor terms from a dictionary spec.
%  Each descriptor is one of:
%    test(Name, PredName, Input, Expected, Kind)
%    test_fail(Name, PredName, Input)
%    test_todo(Name, PredName, Input, Reason)
%    test_skip(Name, Reason)
%    test_deterministic(PredName, Input)
generate_tests(spec(Name, Dict), Tests) :-
    get_dict(examples, Dict, Examples),
    get_dict(inputs, Dict, Inputs),
    get_dict(constraints, Dict, Constraints),
    get_dict(relation, Dict, Relation),
    generate_example_tests(Name, Examples, ExampleTests),
    generate_edge_case_tests(Name, Inputs, Relation, Constraints, EdgeTests),
    append(ExampleTests, EdgeTests, Tests).

% ---- Example tests ----

generate_example_tests(Name, Examples, Tests) :-
    generate_example_tests_(Examples, Name, 1, Tests).

generate_example_tests_([], _, _, []).
generate_example_tests_([io(Input, Output)|Rest], Name, N, [test(TN, Name, Input, Output, example)|Tests]) :-
    atomic_list_concat([example_, N], TN),
    N1 is N + 1,
    generate_example_tests_(Rest, Name, N1, Tests).

% ---- Edge case tests ----

generate_edge_case_tests(Name, Inputs, Relation, Constraints, Tests) :-
    findall(T, edge_case_test(Name, Inputs, Relation, Constraints, T), Tests).

% 1. Empty list - map/filter/transform produce empty output for empty input
edge_case_test(Name, Inputs, Relation, _Constraints,
               test(empty, Name, [], EmptyOut, empty_list)) :-
    has_list_input(Inputs),
    empty_output_for_relation(Relation, EmptyOut).

% 2. Single item list - expected output not derived; mark as todo.
%    Use a type-appropriate single item based on input type.
edge_case_test(Name, Inputs, _Relation, _Constraints,
               test_todo(single_item, Name, [Item],
                         single_item_expected_output_not_derived)) :-
    has_list_input(Inputs),
    single_item_for_inputs(Inputs, Item).

% 3. More than 14 items - skip if already flagged in constraints/warnings
edge_case_test(_Name, _Inputs, _Relation, Constraints,
               test_skip(large_input, too_many_examples_or_items)) :-
    member(too_many_examples_or_items, Constraints).

% 4. Duplicate inputs - check predicate handles repeated values
edge_case_test(Name, Inputs, _Relation, _Constraints,
               test(duplicate_inputs, Name, [1, 1], _, duplicate)) :-
    has_number_list_input(Inputs).
edge_case_test(Name, Inputs, _Relation, _Constraints,
               test(duplicate_inputs, Name, [a, a], _, duplicate)) :-
    has_atom_list_input(Inputs).

% 5. Nested lists - expected output not derived; mark as todo
edge_case_test(Name, Inputs, _Relation, _Constraints,
               test_todo(nested_list, Name, [[1, 2], [3, 4]],
                         nested_list_expected_output_not_derived)) :-
    has_nested_list_input(Inputs).

% 6. Mixed type rejection - predicate should fail on heterogeneous list
edge_case_test(Name, Inputs, _Relation, _Constraints,
               test_fail(mixed_type_rejection, Name, [1, bad_atom, 3])) :-
    has_number_list_input(Inputs).

% 7. Variables in input (non-ground input) - behaviour unspecified; mark as todo
edge_case_test(Name, Inputs, _Relation, _Constraints,
               test_todo(variables_in_input, Name, [1, _Var, 3],
                         variables_in_input_behaviour_unspecified)) :-
    has_list_input(Inputs).

% 8. Ground and non-ground: ground case is covered by example tests.
%    Non-ground is covered by variables_in_input above.

% 9. Deterministic single-success expectation
edge_case_test(Name, _Inputs, _Relation, Constraints,
               test_deterministic(Name, [])) :-
    member(deterministic, Constraints).

% 10. Unsupported nondeterministic behaviour - explicitly skip
edge_case_test(_Name, _Inputs, _Relation, Constraints,
               test_skip(nondeterministic_behaviour, nondeterminism_not_supported)) :-
    member(generator_search, Constraints).

% ---- Helpers ----

has_list_input(Inputs) :-
    member(list(_), Inputs), !.

has_nested_list_input(Inputs) :-
    member(list(list(_)), Inputs), !.

has_number_list_input(Inputs) :-
    member(list(number), Inputs), !.

has_atom_list_input(Inputs) :-
    member(list(atom), Inputs), !.

% single_item_for_inputs(+Inputs, -Item) chooses a type-appropriate item.
single_item_for_inputs(Inputs, 1)    :- member(list(number), Inputs), !.
single_item_for_inputs(Inputs, a)    :- member(list(atom), Inputs), !.
single_item_for_inputs(Inputs, "x")  :- member(list(string), Inputs), !.
single_item_for_inputs(Inputs, [])   :- member(list(list(_)), Inputs), !.
single_item_for_inputs(_, item).

empty_output_for_relation(map, []) :- !.
empty_output_for_relation(filter, []) :- !.
empty_output_for_relation(transform, []) :- !.
empty_output_for_relation(_, []).

% ---- Code emission ----

emit_test_block(Name, Tests) :-
    format(":- begin_tests(~w).~n", [Name]),
    maplist(emit_test, Tests),
    format(":- end_tests(~w).~n", [Name]).

% Standard example test
emit_test(test(TestName, PredName, Input, Expected, example)) :- !,
    format("test(~w) :-~n", [TestName]),
    format("    ~w(~q, R),~n", [PredName, Input]),
    format("    assertion(R == ~q).~n", [Expected]).

% Empty list edge case test
emit_test(test(empty, PredName, Input, Expected, empty_list)) :- !,
    format("test(empty) :-~n"),
    format("    ~w(~q, R),~n", [PredName, Input]),
    format("    assertion(R == ~q).~n", [Expected]).

% Duplicate inputs edge case
emit_test(test(duplicate_inputs, PredName, Input, _, duplicate)) :- !,
    format("test(duplicate_inputs) :-~n"),
    format("    ~w(~q, _).~n", [PredName, Input]).

% Todo test (single item, nested list, non-ground)
emit_test(test_todo(TestName, PredName, Input, Reason)) :- !,
    format("test(~w, [todo(~w)]) :-~n", [TestName, Reason]),
    format("    ~w(~q, _).~n", [PredName, Input]).

% Fail test (mixed type rejection)
emit_test(test_fail(TestName, PredName, Input)) :- !,
    format("test(~w, [fail]) :-~n", [TestName]),
    format("    ~w(~q, _).~n", [PredName, Input]).

% Deterministic test
emit_test(test_deterministic(PredName, Input)) :- !,
    format("test(deterministic, [deterministic]) :-~n"),
    format("    ~w(~q, _).~n", [PredName, Input]).

% Skip test (large input, nondeterministic)
emit_test(test_skip(TestName, Reason)) :- !,
    format("test(~w, [skip(~w)]) :-~n", [TestName, Reason]),
    format("    true.~n").
