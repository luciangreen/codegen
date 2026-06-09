:- module(s2a_bridge, [
    s2a_induce/2,
    pattern_class/1
]).

example_window_size(14).

pattern_class(map).
pattern_class(filter).
pattern_class(fold).
pattern_class(grammar).
pattern_class(decision_tree).
pattern_class(recursion).
pattern_class(generator).
pattern_class(predicate_merge).
pattern_class(test_repair).
pattern_class(loop_conversion).
pattern_class(subterm_indexing).

s2a_induce(spec(Name, Dict), Profile) :-
    Relation = Dict.get(relation),
    Operation = Dict.get(operation),
    Examples = Dict.get(examples),
    Constraints = Dict.get(constraints),
    infer_example_shape(Examples, ExampleShape),
    infer_recursion_need(Relation, Constraints, ExampleShape, RequiresRecursion),
    template_priorities(Relation, RequiresRecursion, BasePriorities),
    build_stage5_profile(Relation, Operation, Examples, Constraints, Stage5),
    (   Stage5.active == true
    ->  Priorities = Stage5.template_priorities
    ;   Priorities = BasePriorities
    ),
    Profile = _{
        name: Name,
        relation: Relation,
        operation: Operation,
        example_shape: ExampleShape,
        requires_recursion: RequiresRecursion,
        template_priorities: Priorities,
        stage5: Stage5
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

build_stage5_profile(Relation, Operation, Examples, Constraints, Stage5) :-
    example_window_size(WindowSize),
    chunk_examples(Examples, WindowSize, ExampleWindows),
    detect_repeated_local_patterns(ExampleWindows, LocalPatterns),
    manual_neuronet_classify(Relation, Constraints, LocalPatterns, ManualClass),
    compress_examples(Operation, Examples, CompressedRules),
    reconstruct_algorithms(ManualClass, CompressedRules, ReconstructedCandidates),
    verify_reconstructed_candidates(ReconstructedCandidates, Examples, VerifiedCandidates),
    stage5_template_priorities(ManualClass, VerifiedCandidates, Stage5Priorities),
    needs_stage5_upgrade(Examples, Active),
    Stage5 = _{
        active: Active,
        window_size: WindowSize,
        example_windows: ExampleWindows,
        repeated_local_patterns: LocalPatterns,
        manual_class: ManualClass,
        compressed_rules: CompressedRules,
        reconstructed_candidates: VerifiedCandidates,
        verified_on_complete_examples: true,
        template_priorities: Stage5Priorities
    }.

needs_stage5_upgrade(Examples, true) :-
    has_large_example_set(Examples),
    !.
needs_stage5_upgrade(_, false).

has_large_example_set(Examples) :-
    example_window_size(Limit),
    member(io(In, Out), Examples),
    (list_longer_than(In, Limit); list_longer_than(Out, Limit)),
    !.

list_longer_than(List, Limit) :-
    is_list(List),
    length(List, Len),
    Len > Limit.

chunk_examples([], _, []).
chunk_examples([io(In, Out)|Rest], WindowSize, Windows) :-
    is_list(In),
    is_list(Out),
    !,
    chunk_io_pair(In, Out, WindowSize, PairWindows),
    chunk_examples(Rest, WindowSize, RestWindows),
    append(PairWindows, RestWindows, Windows).
chunk_examples([Example|Rest], WindowSize, [Example|Windows]) :-
    chunk_examples(Rest, WindowSize, Windows).

chunk_io_pair(In, Out, WindowSize, Windows) :-
    chunk_list(In, WindowSize, InChunks),
    chunk_list(Out, WindowSize, OutChunks),
    pair_chunks(InChunks, OutChunks, Windows).

pair_chunks([], [], []).
pair_chunks([In|Ins], [Out|Outs], [io(In, Out)|Rest]) :-
    pair_chunks(Ins, Outs, Rest).

chunk_list([], _, []).
chunk_list(List, WindowSize, [Chunk|Chunks]) :-
    take_prefix(WindowSize, List, Chunk, Rest),
    Chunk \= [],
    chunk_list(Rest, WindowSize, Chunks).

take_prefix(0, List, [], List) :- !.
take_prefix(_, [], [], []) :- !.
take_prefix(N, [X|Xs], [X|Taken], Rest) :-
    N1 is N - 1,
    take_prefix(N1, Xs, Taken, Rest).

detect_repeated_local_patterns(ExampleWindows, Patterns) :-
    findall(Pattern, local_pattern(ExampleWindows, Pattern), Raw),
    sort(Raw, Patterns).

local_pattern(ExampleWindows, chunked_windows) :-
    length(ExampleWindows, N),
    N > 1.
local_pattern(ExampleWindows, stable_io_shape) :-
    ExampleWindows \= [],
    forall(member(io(In, Out), ExampleWindows), (is_list(In), is_list(Out))).
local_pattern(ExampleWindows, length_preserved_local) :-
    ExampleWindows \= [],
    forall(member(io(In, Out), ExampleWindows), (is_list(In), is_list(Out), length(In, L), length(Out, L))).
local_pattern(ExampleWindows, repeated_operation(Op)) :-
    infer_operation_from_examples(ExampleWindows, Op).

manual_neuronet_classify(_, Constraints, _, test_repair) :-
    member(test_repair, Constraints),
    !.
manual_neuronet_classify(_, Constraints, _, predicate_merge) :-
    member(predicate_merge, Constraints),
    !.
manual_neuronet_classify(generator_search, _, _, generator) :- !.
manual_neuronet_classify(fold, _, _, fold) :- !.
manual_neuronet_classify(filter, _, _, filter) :- !.
manual_neuronet_classify(map, _, _, map) :- !.
manual_neuronet_classify(_, Constraints, _, recursion) :-
    member(recursive, Constraints),
    !.
manual_neuronet_classify(_, _, LocalPatterns, recursion) :-
    member(repeated_operation(_), LocalPatterns),
    !.
manual_neuronet_classify(_, _, _, decision_tree).

compress_examples(Operation, Examples, Rules) :-
    findall(Rule, compressed_rule(Operation, Examples, Rule), Raw),
    sort(Raw, Rules).

compressed_rule(_, Examples, map_relation) :-
    all_examples_list_to_list(Examples).
compressed_rule(_, Examples, length_preserved) :-
    all_examples_list_to_list(Examples),
    forall(member(io(In, Out), Examples), same_length(In, Out)).
compressed_rule(Operation, Examples, operation(Operation)) :-
    Operation \= unknown,
    consistent_operation(Operation, Examples).
compressed_rule(_, Examples, recursive_step(head_tail)) :-
    member(io([_|_], [_|_]), Examples).
compressed_rule(_, Examples, chunk_safe) :-
    has_large_example_set(Examples).

all_examples_list_to_list([]).
all_examples_list_to_list([io(In, Out)|Rest]) :-
    is_list(In),
    is_list(Out),
    all_examples_list_to_list(Rest).

consistent_operation(_, []).
consistent_operation(Operation, [Example|Rest]) :-
    example_matches_operation(Operation, Example),
    consistent_operation(Operation, Rest).

example_matches_operation(double, io(In, Out)) :- maplist(double_of, In, Out).
example_matches_operation(triple, io(In, Out)) :- maplist(triple_of, In, Out).
example_matches_operation(square, io(In, Out)) :- maplist(square_of, In, Out).
example_matches_operation(increment, io(In, Out)) :- maplist(increment_of, In, Out).
example_matches_operation(decrement, io(In, Out)) :- maplist(decrement_of, In, Out).

double_of(X, Y) :- number(X), Y is X * 2.
triple_of(X, Y) :- number(X), Y is X * 3.
square_of(X, Y) :- number(X), Y is X * X.
increment_of(X, Y) :- number(X), Y is X + 1.
decrement_of(X, Y) :- number(X), Y is X - 1.

infer_operation_from_examples(Examples, double) :- consistent_operation(double, Examples), !.
infer_operation_from_examples(Examples, triple) :- consistent_operation(triple, Examples), !.
infer_operation_from_examples(Examples, square) :- consistent_operation(square, Examples), !.
infer_operation_from_examples(Examples, increment) :- consistent_operation(increment, Examples), !.
infer_operation_from_examples(Examples, decrement) :- consistent_operation(decrement, Examples), !.

reconstruct_algorithms(ManualClass, Rules, Candidates) :-
    findall(Candidate, reconstructed_candidate(ManualClass, Rules, Candidate), Raw),
    sort(Raw, Candidates).

reconstructed_candidate(map, Rules, candidate(recursion, map_operation(Op))) :-
    member(operation(Op), Rules).
reconstructed_candidate(map, Rules, candidate(map_filter_fold, map_operation(Op))) :-
    member(operation(Op), Rules).
reconstructed_candidate(filter, _, candidate(map_filter_fold, filter_pattern)).
reconstructed_candidate(fold, _, candidate(map_filter_fold, fold_pattern)).
reconstructed_candidate(generator, _, candidate(generator, generator_pattern)).
reconstructed_candidate(predicate_merge, _, candidate(predicate_merge, parameterised_factor)).
reconstructed_candidate(recursion, Rules, candidate(recursion, head_tail)) :-
    member(recursive_step(head_tail), Rules).

verify_reconstructed_candidates(Candidates, Examples, Verified) :-
    include(candidate_verified(Examples), Candidates, Verified).

candidate_verified(Examples, candidate(recursion, map_operation(Op))) :-
    all_examples_list_to_list(Examples),
    consistent_operation(Op, Examples).
candidate_verified(Examples, candidate(map_filter_fold, map_operation(Op))) :-
    all_examples_list_to_list(Examples),
    consistent_operation(Op, Examples).
candidate_verified(Examples, candidate(recursion, head_tail)) :-
    all_examples_list_to_list(Examples),
    member(io([_|_], [_|_]), Examples).
candidate_verified(Examples, candidate(map_filter_fold, filter_pattern)) :-
    all_examples_list_to_list(Examples).
candidate_verified(Examples, candidate(map_filter_fold, fold_pattern)) :-
    all_examples_list_to_list(Examples).
candidate_verified(Examples, candidate(generator, generator_pattern)) :-
    all_examples_list_to_list(Examples).
candidate_verified(_, candidate(predicate_merge, parameterised_factor)).

stage5_template_priorities(ManualClass, VerifiedCandidates, Priorities) :-
    class_template_priorities(ManualClass, Base),
    verified_templates(VerifiedCandidates, VerifiedTemplates),
    append(VerifiedTemplates, Base, Combined),
    sort_preserving_order(Combined, Priorities).

class_template_priorities(map, [recursion, map_filter_fold, direct, predicate_reuse, predicate_merge, generator, loop2_deterministic, plop_optimised, starlog_expression]).
class_template_priorities(filter, [map_filter_fold, recursion, direct, generator, predicate_reuse, predicate_merge, loop2_deterministic, plop_optimised, starlog_expression]).
class_template_priorities(fold, [map_filter_fold, direct, recursion, generator, predicate_reuse, predicate_merge, loop2_deterministic, plop_optimised, starlog_expression]).
class_template_priorities(generator, [generator, recursion, direct, map_filter_fold, predicate_reuse, predicate_merge, loop2_deterministic, plop_optimised, starlog_expression]).
class_template_priorities(predicate_merge, [predicate_merge, predicate_reuse, recursion, direct, map_filter_fold, generator, loop2_deterministic, plop_optimised, starlog_expression]).
class_template_priorities(test_repair, [direct, recursion, map_filter_fold, generator, predicate_reuse, predicate_merge, loop2_deterministic, plop_optimised, starlog_expression]).
class_template_priorities(_, [direct, recursion, map_filter_fold, predicate_reuse, predicate_merge, generator, loop2_deterministic, plop_optimised, starlog_expression]).

verified_templates([], []).
verified_templates([candidate(Template, _)|Rest], [Template|Templates]) :-
    verified_templates(Rest, Templates).

sort_preserving_order(List, Ordered) :-
    sort_preserving_order(List, [], Ordered).

sort_preserving_order([], Acc, Acc).
sort_preserving_order([X|Xs], Acc, Ordered) :-
    (   member(X, Acc)
    ->  sort_preserving_order(Xs, Acc, Ordered)
    ;   append(Acc, [X], Next),
        sort_preserving_order(Xs, Next, Ordered)
    ).
