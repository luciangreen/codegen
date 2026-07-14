:- module(piglog_opt, [
    piglog_build_partitions/2,
    piglog_dependency_graph/2,
    piglog_schedule/3,
    piglog_generate_header/2,
    piglog_optimise/3
]).

:- use_module(library(lists)).

%% =========================================================
%% Stage 14: Piglog Optimisation Integration
%%
%% Piglog is a source converter and runtime scheduler that creates
%% readable partition metadata and executes with deterministic
%% safety-first scheduling modes.
%%
%% This module adds Piglog-aware code generation to codegen:
%%   - Partition extraction: split a goal conjunction into partitions
%%     each with requires/produces variable sets and readiness scores
%%   - Dependency graph: track which partitions depend on which
%%   - Cost estimation: low / medium / high per partition
%%   - Header generation: emit Piglog metadata annotations
%%   - Scheduling: order partitions by readiness (safety-first)
%%
%% Partition structure:
%%   partition(Id, Goal, Requires, Produces, Readiness)
%%
%%   Id        — unique atom (piglet_1, piglet_2, ...)
%%   Goal      — the Prolog goal for this partition
%%   Requires  — list of variables the partition needs as input
%%   Produces  — list of variables the partition binds as output
%%   Readiness — integer cost score (lower = run first)
%%
%% Execution modes mirrored from Piglog:
%%   sequential  — run partitions left to right
%%   safety_first — run cheapest / most constrained partitions first
%%   adaptive    — estimate overhead vs work and choose mode
%%
%% API:
%%   piglog_build_partitions(+Goal, -Partitions)
%%   piglog_dependency_graph(+Partitions, -Graph)
%%   piglog_schedule(+Partitions, +Mode, -Ordered)
%%   piglog_generate_header(+Partitions, -HeaderCode)
%%   piglog_optimise(+Spec, +PrologCode, -PiglogCode)
%% =========================================================

%% =========================================================
%% piglog_build_partitions/2
%%
%% piglog_build_partitions(+Goal, -Partitions)
%%
%% Splits a Prolog goal (conjunction) into a list of partition/5 terms.
%% Each call in the conjunction becomes its own partition.
%% =========================================================

piglog_build_partitions(Goal, Partitions) :-
    conjunction_to_calls(Goal, Calls),
    nb_setval(piglog_partition_counter, 0),
    maplist(build_single_partition, Calls, Partitions).

build_single_partition(Call, partition(Id, Call, Requires, Produces, Readiness)) :-
    next_partition_id(Id),
    term_variables(Call, Vars),
    partition_requires(Call, Vars, Requires),
    partition_produces(Call, Vars, Produces),
    readiness_score(Call, Readiness).

next_partition_id(Id) :-
    nb_getval(piglog_partition_counter, N),
    N1 is N + 1,
    nb_setval(piglog_partition_counter, N1),
    format(atom(Id), "piglet_~w", [N1]).

%% Variables that appear in a call and are already bound (inputs)
partition_requires(Call, Vars, Requires) :-
    term_variables(Call, AllVars),
    include([V]>>(member(V, Vars), \+ var(V)), AllVars, Requires).

%% Variables that the call will produce (outputs) — all vars in the call
partition_produces(_Call, Vars, Vars).

%% Readiness score: lower = run sooner (more constrained = more ready)
readiness_score(Call, 1) :-
    ground(Call), !.
readiness_score(Call, 2) :-
    \+ ground(Call),
    functor(Call, _, Arity),
    Arity > 0,
    Call =.. [_|Args],
    include([A]>>(ground(A)), Args, GroundArgs),
    length(GroundArgs, G),
    G > 0, !.
readiness_score(_, 5).

%% conjunction_to_calls(+Goal, -Calls)
conjunction_to_calls((A, B), Calls) :-
    !,
    conjunction_to_calls(A, LeftCalls),
    conjunction_to_calls(B, RightCalls),
    append(LeftCalls, RightCalls, Calls).
conjunction_to_calls(true, []) :- !.
conjunction_to_calls(Call, [Call]).

%% =========================================================
%% piglog_dependency_graph/2
%%
%% piglog_dependency_graph(+Partitions, -Graph)
%%
%% Graph = list of dep(FromId, ToId) — FromId must run before ToId
%% because FromId produces variables that ToId requires.
%% =========================================================

piglog_dependency_graph(Partitions, Graph) :-
    findall(dep(From, To),
            (member(partition(From, _, _, Produces, _), Partitions),
             member(partition(To,   _, Requires, _, _), Partitions),
             From \== To,
             shared_variables(Produces, Requires)),
            Raw),
    sort(Raw, Graph).

shared_variables(Produces, Requires) :-
    member(V, Produces),
    member(V2, Requires),
    V == V2.

%% =========================================================
%% piglog_schedule/3
%%
%% piglog_schedule(+Partitions, +Mode, -Ordered)
%%
%% Mode = sequential | safety_first | adaptive
%%
%% sequential:   preserve original order
%% safety_first: sort by ascending readiness (lowest = most ready)
%% adaptive:     compare total work vs overhead; use safety_first
%%               when work > overhead, sequential otherwise
%% =========================================================

piglog_schedule(Partitions, sequential, Partitions) :- !.

piglog_schedule(Partitions, safety_first, Ordered) :-
    !,
    msort(Partitions,
          Ordered0),
    predsort([Order, P1, P2]>>(
        P1 = partition(_, _, _, _, R1),
        P2 = partition(_, _, _, _, R2),
        compare(Order, R1, R2)
    ), Partitions, Ordered0),
    !,
    Ordered = Ordered0.

piglog_schedule(Partitions, adaptive, Ordered) :-
    !,
    length(Partitions, Count),
    Overhead is Count * 2.5,
    maplist([P, C]>>(
        P = partition(_, Goal, _, _, _),
        estimate_call_cost(Goal, C)
    ), Partitions, Costs),
    sum_list(Costs, Work),
    (   Work > Overhead
    ->  piglog_schedule(Partitions, safety_first, Ordered)
    ;   Ordered = Partitions
    ).

estimate_call_cost(Call, 1.0) :- ground(Call), !.
estimate_call_cost(Call, 9.0) :-
    functor(Call, F, _),
    member(F, [findall, bagof, setof, member, between]), !.
estimate_call_cost(_, 3.0).

%% =========================================================
%% piglog_generate_header/2
%%
%% piglog_generate_header(+Partitions, -HeaderCode)
%%
%% Emits Piglog metadata annotation as a Prolog comment block
%% plus piglog_partition/5 facts that record the execution plan.
%% =========================================================

piglog_generate_header(Partitions, HeaderCode) :-
    maplist(partition_annotation, Partitions, Lines),
    atomic_list_concat(Lines, '\n', Body),
    format(string(HeaderCode),
        "%% piglog:begin_partitions~n~w~n%% piglog:end_partitions",
        [Body]).

partition_annotation(partition(Id, Goal, _Req, _Prod, Readiness), Line) :-
    format(string(GoalStr), "~q", [Goal]),
    format(string(Line),
        ":- piglog_partition(~w, ~w, readiness(~w)).",
        [Id, GoalStr, Readiness]).

%% =========================================================
%% piglog_optimise/3 — main entry point
%%
%% piglog_optimise(+Spec, +PrologCode, -PiglogCode)
%%
%% Takes a codegen spec and the already-generated Prolog code string.
%% Returns an augmented code string with Piglog partition metadata
%% header, dependency annotations, and scheduling comment.
%%
%% Spec is a spec/2 dict from the codegen pipeline.
%% PrologCode is the expanded Prolog string from starlog_expand_code/2.
%% =========================================================

piglog_optimise(Spec, PrologCode, PiglogCode) :-
    extract_spec_goal(Spec, Goal),
    piglog_build_partitions(Goal, Partitions),
    piglog_dependency_graph(Partitions, Graph),
    piglog_schedule(Partitions, adaptive, Ordered),
    piglog_generate_header(Partitions, Header),
    build_dep_comment(Graph, DepComment),
    build_schedule_comment(Ordered, SchedComment),
    format(string(PiglogCode),
        "%% piglog:source ~w~n~w~n~w~n~w~n~n~w",
        [Spec, Header, DepComment, SchedComment, PrologCode]).

extract_spec_goal(spec(Name, Dict), Goal) :-
    Relation = Dict.get(relation),
    ( Relation == map    -> Goal = (input >> map(_Op) = output)
    ; Relation == filter -> Goal = (input >> filter(_Op) = output)
    ; Relation == fold   -> Goal = (input >> fold(_Op, 0) = output)
    ; Goal = Name
    ).

build_dep_comment([], "%% piglog:dependencies none") :- !.
build_dep_comment(Graph, Comment) :-
    maplist([dep(F,T), Line]>>(format(string(Line), "%%   ~w -> ~w", [F, T])), Graph, Lines),
    atomic_list_concat(Lines, '\n', Body),
    format(string(Comment), "%% piglog:dependencies~n~w", [Body]).

build_schedule_comment(Ordered, Comment) :-
    maplist([partition(Id,_,_,_,R), S]>>(
        format(string(S), "%%   ~w (readiness ~w)", [Id, R])
    ), Ordered, Lines),
    atomic_list_concat(Lines, '\n', Body),
    format(string(Comment), "%% piglog:schedule(adaptive)~n~w", [Body]).
