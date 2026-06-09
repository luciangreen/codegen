:- module(s2a_bridge, [
    s2a_induce/2
]).

s2a_induce(spec(Name, Dict), Profile) :-
    Relation = Dict.get(relation),
    Operation = Dict.get(operation),
    Examples = Dict.get(examples),
    Constraints = Dict.get(constraints),
    infer_example_shape(Examples, ExampleShape),
    infer_recursion_need(Relation, Constraints, ExampleShape, RequiresRecursion),
    template_priorities(Relation, RequiresRecursion, Priorities),
    Profile = _{
        name: Name,
        relation: Relation,
        operation: Operation,
        example_shape: ExampleShape,
        requires_recursion: RequiresRecursion,
        template_priorities: Priorities
    }.

infer_example_shape([io(In, Out)|_], list_to_list) :-
    is_list(In),
    is_list(Out),
    !.
infer_example_shape([io(_, _)|_], io_pair) :- !.
infer_example_shape([], unknown).

infer_recursion_need(Relation, Constraints, _, true) :-
    member(recursive, Constraints),
    Relation \= fold,
    !.
infer_recursion_need(map, _, list_to_list, true) :- !.
infer_recursion_need(_, _, _, false).

template_priorities(Relation, true, [recursion, map_filter_fold, direct, predicate_reuse, predicate_merge, generator, loop2_deterministic, plop_optimised, starlog_expression]) :-
    Relation == map,
    !.
template_priorities(_, _, [direct, recursion, map_filter_fold, predicate_reuse, predicate_merge, generator, loop2_deterministic, plop_optimised, starlog_expression]).