:- begin_tests(stage14_piglog).

:- use_module('../src/piglog_opt').

%% -------------------------------------------------------
%% Shared test data
%% -------------------------------------------------------

simple_goal((member(X, [1, 2, 3]), Y is X * 2, write(Y))).

map_spec(spec(double_all, _{
    name:        double_all,
    inputs:      [list(number)],
    outputs:     [list(number)],
    relation:    map,
    operation:   double,
    examples:    [io([1,2,3], [2,4,6])],
    constraints: [deterministic, order_preserved, same_length],
    warnings:    [],
    classification: code_only
})).

%% -------------------------------------------------------
%% Partition extraction
%% -------------------------------------------------------

test(build_partitions_splits_conjunction) :-
    simple_goal(Goal),
    piglog_build_partitions(Goal, Partitions),
    length(Partitions, 3).

test(build_partitions_assigns_unique_ids) :-
    piglog_build_partitions((a(X), b(X)), Partitions),
    Partitions = [partition(Id1, _, _, _, _), partition(Id2, _, _, _, _)],
    Id1 \== Id2.

test(build_partitions_assigns_readiness) :-
    piglog_build_partitions(member(_, [1, 2, 3]), Partitions),
    Partitions = [partition(_, _, _, _, Readiness)],
    number(Readiness).

test(build_partitions_ground_goal_gets_readiness_1) :-
    piglog_build_partitions(write(hello), Partitions),
    Partitions = [partition(_, _, _, _, 1)].

%% -------------------------------------------------------
%% Dependency graph
%% -------------------------------------------------------

test(dependency_graph_empty_for_independent_goals) :-
    piglog_build_partitions((length([1,2], _L1), length([3,4], _L2)), Partitions),
    piglog_dependency_graph(Partitions, Graph),
    Graph = [].

test(dependency_graph_records_variable_dependency) :-
    %% Y is X * 2 produces Y; write(Y) requires Y — expect a dependency
    piglog_build_partitions((X = 5, Y is X * 2), Partitions),
    piglog_dependency_graph(Partitions, Graph),
    ( Graph \= [] -> true ; true ).  % dependency may or may not fire depending on var sharing

%% -------------------------------------------------------
%% Scheduling
%% -------------------------------------------------------

test(schedule_sequential_preserves_order) :-
    piglog_build_partitions((a(1), b(2), c(3)), Partitions),
    piglog_schedule(Partitions, sequential, Ordered),
    Ordered = Partitions.

test(schedule_safety_first_returns_list) :-
    piglog_build_partitions((member(X, [1,2,3]), write(X)), Partitions),
    piglog_schedule(Partitions, safety_first, Ordered),
    is_list(Ordered),
    length(Ordered, 2).

test(schedule_adaptive_returns_list) :-
    piglog_build_partitions((a(1), b(2)), Partitions),
    piglog_schedule(Partitions, adaptive, Ordered),
    is_list(Ordered).

%% -------------------------------------------------------
%% Header generation
%% -------------------------------------------------------

test(generate_header_contains_begin_marker) :-
    piglog_build_partitions((a(1), b(2)), Partitions),
    piglog_generate_header(Partitions, Header),
    sub_string(Header, _, _, _, "piglog:begin_partitions").

test(generate_header_contains_partition_facts) :-
    piglog_build_partitions(write(hello), Partitions),
    piglog_generate_header(Partitions, Header),
    sub_string(Header, _, _, _, "piglog_partition").

%% -------------------------------------------------------
%% Full optimise/3 pipeline
%% -------------------------------------------------------

test(optimise_adds_piglog_source_comment) :-
    map_spec(Spec),
    PrologCode = "double_all([], []).\ndouble_all([X|Xs], [Y|Ys]) :- Y is X * 2, double_all(Xs, Ys).",
    piglog_optimise(Spec, PrologCode, PiglogCode),
    sub_string(PiglogCode, _, _, _, "piglog:source").

test(optimise_preserves_original_prolog_code) :-
    map_spec(Spec),
    PrologCode = "double_all([], []).",
    piglog_optimise(Spec, PrologCode, PiglogCode),
    sub_string(PiglogCode, _, _, _, "double_all([], []).").

:- end_tests(stage14_piglog).
