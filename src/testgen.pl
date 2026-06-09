:- module(testgen, [
    generate_tests/2,
    generate_test_lines/2,
    spec_to_test_file/3
]).

:- use_module(library(lists)).

generate_tests(spec(Name, Dict), Code) :-
    generate_test_lines(spec(Name, Dict), Lines),
    atomic_list_concat(Lines, '\n', Code).

generate_test_lines(spec(Name, Dict), Lines) :-
    Examples = Dict.get(examples),
    Relation = Dict.get(relation),
    Operation = Dict.get(operation),
    begin_tests(Name, BeginLine),
    end_tests(Name, EndLine),
    findall(Line, example_test_line(Name, Examples, Line), ExampleLines),
    edge_case_lines(Name, Relation, Operation, Examples, EdgeLines),
    append([
        [BeginLine],
        ExampleLines,
        EdgeLines,
        [EndLine]
    ], Nested),
    flatten(Nested, Lines).

spec_to_test_file(Spec, ModuleName, FileCode) :-
    generate_tests(Spec, Body),
    format(string(FileCode),
        ":- module(~w, [run/0]).~nrun :- run_tests.~n~n~w",
        [ModuleName, Body]).

begin_tests(Name, Line) :-
    format(string(Line), ":- begin_tests(~w).", [Name]).

end_tests(Name, Line) :-
    format(string(Line), ":- end_tests(~w).", [Name]).

example_test_line(Name, Examples, Lines) :-
    nth1(Index, Examples, io(Input, Output)),
    format(string(TestName), "example_~d", [Index]),
    io_assertion_test(Name, TestName, Input, Output, Lines).

io_assertion_test(Name, TestName, Input, Output,
    [Head, Goal, Assert, '.']) :-
    format(string(Head), "test(~w) :-", [TestName]),
    term_to_code(Input, InputCode),
    format(string(Goal), "    ~w(~w, R),", [Name, InputCode]),
    term_to_code(Output, OutputCode),
    format(string(Assert), "    assertion(R == ~w)", [OutputCode]).

edge_case_lines(Name, Relation, Operation, Examples, Lines) :-
    findall(Part, edge_case_group(Name, Relation, Operation, Examples, Part), Groups),
    flatten(Groups, Lines).

edge_case_group(Name, Relation, _, _Examples, Lines) :-
    member(Relation, [map, filter]),
    io_assertion_test(Name, empty, [], [], Lines).

edge_case_group(Name, _Relation, _Operation, [io([InHead|_], [OutHead|_])|_], Lines) :-
    io_assertion_test(Name, single_item, [InHead], [OutHead], Lines).

edge_case_group(Name, map, _Operation, [io([InHead|_], [OutHead|_])|_], Lines) :-
    io_assertion_test(Name, duplicate_input, [InHead, InHead], [OutHead, OutHead], Lines).

edge_case_group(Name, map, _Operation, Examples,
    ["test(more_than_14_items) :-",
     Goal,
     LenAssert,
     DetAssert,
     '.']) :-
    member(io(Input, Output), Examples),
    is_list(Input),
    length(Input, N),
    N > 14,
    term_to_code(Input, InputCode),
    length(Output, OutLen),
    format(string(Goal), "    ~w(~w, R),", [Name, InputCode]),
    format(string(LenAssert), "    assertion(length(R, ~d)),", [OutLen]),
    format(string(DetAssert), "    assertion(once(~w(~w, _)))", [Name, InputCode]),
    !.

edge_case_group(Name, map, _Operation, Examples,
    ["test(nested_list_case) :-",
     Goal,
     Assert,
     '.']) :-
    member(io(Input, Output), Examples),
    is_list(Input),
    Input = [[_|_]|_],
    term_to_code(Input, InputCode),
    term_to_code(Output, OutputCode),
    format(string(Goal), "    ~w(~w, R),", [Name, InputCode]),
    format(string(Assert), "    assertion(R == ~w)", [OutputCode]),
    !.

edge_case_group(Name, map, Operation, _Examples,
    ["test(mixed_type_rejection, [fail]) :-",
     Goal,
     '.']) :-
    member(Operation, [double, triple, square, increment, decrement]),
    format(string(Goal), "    ~w([1,a], _)", [Name]).

edge_case_group(Name, _Relation, _Operation, [io(Input, _)|_],
    ["test(ground_and_nonground_cases) :-",
     GroundGoal,
     NongroundGoal,
     '.']) :-
    term_to_code(Input, InputCode),
    format(string(GroundGoal), "    once(~w(~w, _)),", [Name, InputCode]),
    format(string(NongroundGoal), "    once(~w(_, _))", [Name]).

edge_case_group(Name, _Relation, _Operation, [io(Input, _)|_],
    ["test(deterministic_single_success) :-",
     FindallGoal,
     Assert,
     '.']) :-
    term_to_code(Input, InputCode),
    format(string(FindallGoal), "    findall(R, ~w(~w, R), Rs),", [Name, InputCode]),
    Assert = "    assertion(Rs = [_])".

edge_case_group(_Name, _Relation, _Operation, _Examples,
    ["test(unsupported_nondeterministic_behaviour, [blocked('unsupported nondeterministic behaviour')]) :-",
     "    true",
     '.']).

term_to_code(Term, Code) :-
    with_output_to(string(Code), write_term(Term, [quoted(true)])).
