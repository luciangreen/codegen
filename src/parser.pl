:- module(parser, [
    sentence_to_spec/2,
    sentence_to_spec/3,
    parse_examples/2,
    validate_spec/1
]).

:- use_module(library(lists)).
:- use_module(library(pcre)).
:- use_module(library(apply)).

example_limit(14).

sentence_to_spec(Sentence, Spec) :-
    sentence_to_spec(Sentence, [], Spec).

sentence_to_spec(Sentence, _Options, spec(Name, Dict)) :-
    normalize_sentence_text(Sentence, Lower),
    extract_signature(Lower, Name, InputVars, OutputVars),
    detect_relation(Lower, Relation),
    detect_operation(Lower, Operation),
    infer_types(Lower, Relation, Operation, InputVars, OutputVars, Inputs, Outputs),
    parse_examples(Lower, Examples),
    detect_constraints(Lower, Relation, Constraints0),
    classify_sentence(Lower, Classification),
    collect_warnings(Classification, Lower, Inputs, Outputs, OutputVars, Examples, Warnings0),
    add_contradiction_warning(Examples, Warnings0, Warnings1),
    add_large_example_warning(Examples, Warnings1, Warnings),
    Dict = _{
        name: Name,
        inputs: Inputs,
        outputs: Outputs,
        relation: Relation,
        operation: Operation,
        examples: Examples,
        constraints: Constraints0,
        warnings: Warnings,
        classification: Classification
    },
    validate_spec(spec(Name, Dict)).

validate_spec(spec(Name, Dict)) :-
    atom(Name),
    is_dict(Dict),
    get_dict(inputs, Dict, Inputs),
    get_dict(outputs, Dict, Outputs),
    is_list(Inputs),
    is_list(Outputs).

normalize_sentence_text(Sentence, Lower) :-
    (   atom(Sentence)
    ->  atom_string(Sentence, Text)
    ;   string(Sentence)
    ->  Text = Sentence
    ;   throw(error(type_error(text, Sentence), _))
    ),
    string_lower(Text, Lower).

extract_signature(Text, Name, InputVars, OutputVars) :-
    (   re_matchsub("predicate\\s+([a-z_][a-z0-9_]*)\\s*\\(([^)]*)\\)", Text, Dict, [caseless(true)])
    ->  atom_string(Name, Dict.1),
        split_args(Dict.2, Args),
        split_io_vars(Args, InputVars, OutputVars)
    ;   Name = unknown_predicate,
        InputVars = [],
        OutputVars = []
    ).

split_args(ArgsText, Args) :-
    split_string(ArgsText, ",", " \t\n", Raw),
    exclude(is_empty_string, Raw, Filtered),
    maplist(atom_string, Args, Filtered).

is_empty_string("").

split_io_vars([], [], []).
split_io_vars([Only], [Only], []).
split_io_vars([In, Out], [In], [Out]).
split_io_vars([In|Rest], [In], Rest) :-
    Rest \= [].

detect_relation(Text, map) :-
    sub_string(Text, _, _, _, "map"), !.
detect_relation(Text, filter) :-
    sub_string(Text, _, _, _, "filter"), !.
detect_relation(Text, fold) :-
    sub_string(Text, _, _, _, "fold"), !.
detect_relation(Text, generator_search) :-
    sub_string(Text, _, _, _, "generator"), !.
detect_relation(_, transform).

detect_operation(Text, double) :-
    (sub_string(Text, _, _, _, "double"); sub_string(Text, _, _, _, "twice")), !.
detect_operation(Text, triple) :-
    (sub_string(Text, _, _, _, "triple"); sub_string(Text, _, _, _, "thrice")), !.
detect_operation(Text, square) :-
    sub_string(Text, _, _, _, "square"), !.
detect_operation(Text, increment) :-
    sub_string(Text, _, _, _, "increment"), !.
detect_operation(Text, decrement) :-
    sub_string(Text, _, _, _, "decrement"), !.
detect_operation(Text, change) :-
    sub_string(Text, _, _, _, "change"), !.
detect_operation(Text, make) :-
    sub_string(Text, _, _, _, "make"), !.
detect_operation(Text, find) :-
    sub_string(Text, _, _, _, "find"), !.
detect_operation(_, unknown).

infer_types(Text, Relation, Operation, InputVars, OutputVars, Inputs, Outputs) :-
    infer_input_type(Text, Relation, InputType),
    infer_output_type(Text, Relation, Operation, InputType, OutputType),
    typed_vars(InputVars, InputType, Inputs),
    typed_vars(OutputVars, OutputType, Outputs).

typed_vars([], _, []).
typed_vars([_|Vars], Type, [Type|Rest]) :-
    typed_vars(Vars, Type, Rest).

infer_input_type(Text, _, list(list(number))) :-
    sub_string(Text, _, _, _, "list of lists of numbers"), !.
infer_input_type(Text, _, list(number)) :-
    (sub_string(Text, _, _, _, "every number in")
    ;sub_string(Text, _, _, _, "list of numbers")
    ;sub_string(Text, _, _, _, "input list of numbers")), !.
infer_input_type(Text, _, list(string)) :-
    sub_string(Text, _, _, _, "list of strings"), !.
infer_input_type(Text, _, list(atom)) :-
    sub_string(Text, _, _, _, "list of atoms"), !.
infer_input_type(Text, _, list(char)) :-
    sub_string(Text, _, _, _, "list of chars"), !.
infer_input_type(Text, _, list(dict)) :-
    sub_string(Text, _, _, _, "list of dicts"), !.
infer_input_type(Text, _, number) :-
    sub_string(Text, _, _, _, "number"), !.
infer_input_type(Text, _, string) :-
    sub_string(Text, _, _, _, "string"), !.
infer_input_type(Text, _, atom) :-
    sub_string(Text, _, _, _, "atom"), !.
infer_input_type(Text, _, char) :-
    sub_string(Text, _, _, _, "char"), !.
infer_input_type(Text, _, dict) :-
    sub_string(Text, _, _, _, "dict"), !.
infer_input_type(_, _, unknown(input_type_missing)).

infer_output_type(_, map, double, list(number), list(number)) :- !.
infer_output_type(_, map, triple, list(number), list(number)) :- !.
infer_output_type(_, map, square, list(number), list(number)) :- !.
infer_output_type(_, map, _, list(T), list(T)) :- !.
infer_output_type(_, _, _, unknown(input_type_missing), unknown(output_type_missing)) :- !.
infer_output_type(Text, _, _, _, list(number)) :-
    sub_string(Text, _, _, _, "list of numbers"), !.
infer_output_type(Text, _, _, _, list(string)) :-
    sub_string(Text, _, _, _, "list of strings"), !.
infer_output_type(Text, _, _, _, list(atom)) :-
    sub_string(Text, _, _, _, "list of atoms"), !.
infer_output_type(Text, _, _, _, list(char)) :-
    sub_string(Text, _, _, _, "list of chars"), !.
infer_output_type(Text, _, _, _, list(dict)) :-
    sub_string(Text, _, _, _, "list of dicts"), !.
infer_output_type(_, _, _, _, unknown(output_type_missing)).

detect_constraints(Text, Relation, Constraints) :-
    relation_constraints(Relation, Base),
    findall(C, extra_constraint(Text, C), Extras),
    append(Base, Extras, Constraints0),
    sort(Constraints0, Constraints).

relation_constraints(map, [same_length, order_preserved, deterministic]).
relation_constraints(filter, [order_preserved, deterministic]).
relation_constraints(fold, [deterministic]).
relation_constraints(generator_search, [generator_search]).
relation_constraints(transform, [deterministic]).

extra_constraint(Text, recursive) :-
    sub_string(Text, _, _, _, "recursion").
extra_constraint(Text, generator_search) :-
    sub_string(Text, _, _, _, "generator").
extra_constraint(Text, predicate_merge) :-
    sub_string(Text, _, _, _, "merge").
extra_constraint(Text, test_repair) :-
    sub_string(Text, _, _, _, "change previous tests").
extra_constraint(Text, nested_structures) :-
    sub_string(Text, _, _, _, "list of lists").

collect_warnings(Classification, Text, Inputs, Outputs, OutputVars, Examples, Warnings) :-
    findall(W, base_warning(Classification, Text, Inputs, Outputs, OutputVars, Examples, W), Warnings0),
    sort(Warnings0, Warnings).

base_warning(_, _, Inputs, _, _, _, missing_input_type) :-
    member(unknown(input_type_missing), Inputs).
base_warning(_, _, _, Outputs, _, _, missing_output_type) :-
    member(unknown(output_type_missing), Outputs).
base_warning(_, _, _, _, OutputVars, _, multiple_outputs) :-
    length(OutputVars, N),
    N > 1.
base_warning(_, Text, _, _, _, _, ambiguous_verb(change)) :-
    sub_string(Text, _, _, _, "change").
base_warning(_, Text, _, _, _, _, ambiguous_verb(make)) :-
    sub_string(Text, _, _, _, "make").
base_warning(_, Text, _, _, _, _, ambiguous_verb(find)) :-
    sub_string(Text, _, _, _, "find").
base_warning(tests_only, _, _, _, _, _, tests_without_code).
base_warning(_, _, _, _, _, Examples, no_examples) :-
    Examples == [].

classify_sentence(Text, tests_only) :-
    sub_string(Text, _, _, _, "test"),
    \+ sub_string(Text, _, _, _, "predicate"), !.
classify_sentence(Text, code_and_tests) :-
    sub_string(Text, _, _, _, "test"),
    sub_string(Text, _, _, _, "predicate"), !.
classify_sentence(_, code_only).

parse_examples(Text, Examples) :-
    split_string(Text, ";", "", Parts),
    findall(Example, (member(Part, Parts), parse_arrow_example(Part, Example)), Examples).

parse_arrow_example(Part, io(Input, Output)) :-
    sub_string(Part, _, _, _, "->"),
    split_string(Part, ">", " \t\n", [LeftRaw, RightRaw|_]),
    normalize_arrow_left(LeftRaw, Left),
    normalize_arrow_right(RightRaw, Right),
    safe_term(Left, Input),
    safe_term(Right, Output), !.
normalize_arrow_left(Text, Clean) :-
    split_string(Text, "-", " \t\n", [A|_]),
    strip_prefix("examples:", A, Clean0),
    strip_prefix("example:", Clean0, Clean).

normalize_arrow_right(Text, Clean) :-
    split_string(Text, ".", " \t\n", [A|_]),
    trim_string(A, Clean).

strip_prefix(Prefix, Text, Out) :-
    (   string_concat(Prefix, Rest, Text)
    ->  trim_string(Rest, Out)
    ;   Out = Text
    ).

trim_string(In, Out) :-
    normalize_space(string(Out), In).

safe_term(Text, Term) :-
    catch(term_string(Term, Text), _, fail).

add_contradiction_warning(Examples, Warnings0, Warnings) :-
    (has_contradiction(Examples) -> sort([contradictory_examples|Warnings0], Warnings) ; Warnings = Warnings0).

has_contradiction(Examples) :-
    member(io(Input, Out1), Examples),
    member(io(Input, Out2), Examples),
    Out1 \== Out2,
    !.

add_large_example_warning(Examples, Warnings0, Warnings) :-
    (has_large_example_set(Examples) -> sort([too_many_examples_or_items|Warnings0], Warnings) ; Warnings = Warnings0).

has_large_example_set(Examples) :-
    example_limit(Limit),
    length(Examples, N),
    N > Limit, !.
has_large_example_set(Examples) :-
    member(io(In, Out), Examples),
    (is_long_list(In); is_long_list(Out)),
    !.

is_long_list(List) :-
    example_limit(Limit),
    is_list(List),
    length(List, N),
    N > Limit.