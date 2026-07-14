:- module(detlog_opt, [
    detlog_analyse/2,
    detlog_classify/3,
    detlog_emit_wrapper/4,
    detlog_optimise/3,
    detlog_splice_convert/2
]).

:- use_module(library(lists)).

%% =========================================================
%% Stage 13: Detlog Optimisation Integration
%%
%% Detlog reduces hidden nondeterminism in generated Prolog while
%% preserving ordinary Prolog semantics.
%%
%% Input:  list of clause terms — (Head :- Body) or bare facts
%% Output: Detlog-annotated code string + diagnostic list
%%
%% Analysis dimensions:
%%
%%   Mode:    det      — single clause, no choice points
%%            semidet  — single clause with internal choice
%%            nondet   — multiple clauses or search
%%
%%   Cut:     no_cut       — no cut in any clause
%%            local_cut    — cut appears inside if-then or once
%%            unsafe_cut   — cut that prunes parent choice points
%%
%%   Effect:  pure         — no I/O, assert/retract, or meta-calls
%%            side_effects — any impure operation present
%%
%%   Status:  converted — det + no_cut + pure  → safe to emit directly
%%            fallback  — any other case → emit with diagnostic warning
%%
%% API:
%%   detlog_analyse(+Clauses, -Analysis)
%%   detlog_classify(+Analysis, +PI, -Status)
%%   detlog_emit_wrapper(+Head, +SourceModule, +Status, -WrapperText)
%%   detlog_optimise(+Clauses, -AnnotatedCode, -Diagnostics)
%%   detlog_splice_convert(+Goal, -SplicedGoal)
%% =========================================================

%% =========================================================
%% detlog_analyse/2
%%
%% detlog_analyse(+Clauses, -Analysis)
%%
%% Analysis = analysis(Modes, Cuts, Effects)
%%   Modes   = list of mode_info(PI, det|semidet|nondet)
%%   Cuts    = list of cut_info(PI, no_cut|local_cut|unsafe_cut)
%%   Effects = list of effect_info(PI, pure|side_effects)
%% =========================================================

detlog_analyse(Clauses, analysis(Modes, Cuts, Effects)) :-
    clause_predicates(Clauses, PIs),
    maplist(infer_det(Clauses), PIs, DetList),
    maplist(infer_cut(Clauses), PIs, CutList),
    maplist(infer_effect(Clauses), PIs, EffList),
    maplist([PI, D, mode_info(PI, D)]>>(true), PIs, DetList, Modes),
    maplist([PI, C, cut_info(PI, C)]>>(true), PIs, CutList, Cuts),
    maplist([PI, E, effect_info(PI, E)]>>(true), PIs, EffList, Effects).

%% =========================================================
%% Mode inference
%% =========================================================

infer_det(Clauses, Name/Arity, det) :-
    findall(Body,
            (member(C, Clauses), clause_head_body(C, H, Body), functor(H, Name, Arity)),
            Bodies),
    length(Bodies, Count),
    Count =< 1,
    \+ bodies_contain_choicepoint(Bodies), !.
infer_det(Clauses, Name/Arity, semidet) :-
    findall(Body,
            (member(C, Clauses), clause_head_body(C, H, Body), functor(H, Name, Arity)),
            Bodies),
    length(Bodies, 1),
    bodies_contain_choicepoint(Bodies), !.
infer_det(_, _, nondet).

bodies_contain_choicepoint(Bodies) :-
    member(Body, Bodies),
    body_has_choicepoint(Body).

%% body_has_choicepoint/1 uses functor/3 checks to avoid unifying
%% with unbound variables inside clause terms.
body_has_choicepoint(Body) :-
    contains_functor(Body, ';', 2), !.
body_has_choicepoint(Body) :-
    contains_functor(Body, findall, 3), !.
body_has_choicepoint(Body) :-
    contains_functor(Body, bagof, 3), !.
body_has_choicepoint(Body) :-
    contains_functor(Body, setof, 3), !.
body_has_choicepoint(Body) :-
    contains_functor(Body, member, 2), !.
body_has_choicepoint(Body) :-
    contains_functor(Body, between, 3).

%% contains_functor(+Term, +F, +A) — true if Term contains F/A as a subterm
contains_functor(Term, F, A) :-
    nonvar(Term),
    functor(Term, F, A), !.
contains_functor(Term, F, A) :-
    compound(Term),
    Term =.. [_|Args],
    member(Arg, Args),
    contains_functor(Arg, F, A).

%% =========================================================
%% Cut classification
%% =========================================================

infer_cut(Clauses, Name/Arity, no_cut) :-
    \+ (member(C, Clauses),
        clause_head_body(C, H, Body),
        functor(H, Name, Arity),
        contains_functor(Body, !, 0)), !.
infer_cut(Clauses, Name/Arity, local_cut) :-
    \+ (member(C, Clauses),
        clause_head_body(C, H, Body),
        functor(H, Name, Arity),
        unsafe_cut_in_body(Body)), !.
infer_cut(_, _, unsafe_cut).

%% A cut is unsafe when it appears at the top level of the body
%% (not guarded by if-then-else or once).
unsafe_cut_in_body(Body) :-
    Body == (!).
unsafe_cut_in_body((!, _Rest)).
unsafe_cut_in_body((_Before, !)).

%% =========================================================
%% Effect classification
%% =========================================================

infer_effect(Clauses, Name/Arity, pure) :-
    \+ (member(C, Clauses),
        clause_head_body(C, H, Body),
        functor(H, Name, Arity),
        body_has_side_effects(Body)), !.
infer_effect(_, _, side_effects).

body_has_side_effects(Body) :-
    contains_functor(Body, write, 1), !.
body_has_side_effects(Body) :-
    contains_functor(Body, nl, 0), !.
body_has_side_effects(Body) :-
    contains_functor(Body, writeln, 1), !.
body_has_side_effects(Body) :-
    contains_functor(Body, format, 2), !.
body_has_side_effects(Body) :-
    contains_functor(Body, format, 1), !.
body_has_side_effects(Body) :-
    contains_functor(Body, assert, 1), !.
body_has_side_effects(Body) :-
    contains_functor(Body, assertz, 1), !.
body_has_side_effects(Body) :-
    contains_functor(Body, retract, 1), !.
body_has_side_effects(Body) :-
    contains_functor(Body, retractall, 1), !.
body_has_side_effects(Body) :-
    contains_functor(Body, read, 1), !.
body_has_side_effects(Body) :-
    contains_functor(Body, get_char, 1).

%% =========================================================
%% detlog_classify/3
%%
%% detlog_classify(+Analysis, +PI, -Status)
%%
%% Status = converted  when det + no_cut + pure
%%          fallback   otherwise
%% =========================================================

detlog_classify(analysis(Modes, Cuts, Effects), PI, converted) :-
    member(mode_info(PI, det), Modes),
    member(cut_info(PI, no_cut), Cuts),
    member(effect_info(PI, pure), Effects), !.
detlog_classify(_, _, fallback).

%% =========================================================
%% detlog_emit_wrapper/4
%%
%% detlog_emit_wrapper(+Head, +SourceModule, +Status, -WrapperText)
%%
%% Emits a wrapper clause that delegates to SourceModule:Head.
%% Fallback wrappers include a diagnostic comment.
%% =========================================================

detlog_emit_wrapper(Head, SourceModule, converted, Text) :-
    format(string(Text),
        "~q :- ~q:~q.",
        [Head, SourceModule, Head]).
detlog_emit_wrapper(Head, SourceModule, fallback, Text) :-
    format(string(Text),
        "~q :- ~q:~q.  % detlog:fallback",
        [Head, SourceModule, Head]).

%% =========================================================
%% detlog_optimise/3  — main entry point
%%
%% detlog_optimise(+Clauses, -AnnotatedCode, -Diagnostics)
%%
%% Clauses:       list of (Head :- Body) or bare fact terms
%% AnnotatedCode: string with per-clause detlog:converted/fallback annotations
%% Diagnostics:   list of diagnostic(fallback, PI) for each fallback predicate
%% =========================================================

detlog_optimise(Clauses, AnnotatedCode, Diagnostics) :-
    detlog_analyse(Clauses, Analysis),
    maplist(annotate_clause(Analysis), Clauses, Parts),
    atomic_list_concat(Parts, '\n', AnnotatedCode),
    collect_diagnostics(Clauses, Analysis, Diagnostics).

annotate_clause(Analysis, Clause, Text) :-
    clause_head_body(Clause, Head, _Body),
    functor(Head, Name, Arity),
    detlog_classify(Analysis, Name/Arity, Status),
    format(string(Text), "% detlog:~w~n~q.", [Status, Clause]).

collect_diagnostics(Clauses, Analysis, Diagnostics) :-
    clause_predicates(Clauses, PIs),
    include([PI]>>(detlog_classify(Analysis, PI, fallback)), PIs, FallbackPIs),
    maplist([PI, diagnostic(fallback, PI)]>>(true), FallbackPIs, Diagnostics).

%% =========================================================
%% detlog_splice_convert/2
%%
%% detlog_splice_convert(+Goal, -SplicedGoal)
%%
%% Converts a nondeterministic member/2 goal into an equivalent
%% splice_each/2 form suitable for Detlog's spliced execution.
%%
%% member(X, List) → splice_each([cp(List)], [X])
%% (A, member(X, List)) → (A, splice_each([cp(List)], [X]))
%% =========================================================

detlog_splice_convert(member(X, List), splice_each([cp(List)], [X])) :- !.

detlog_splice_convert((A, B), (A2, B2)) :-
    !,
    detlog_splice_convert(A, A2),
    detlog_splice_convert(B, B2).

detlog_splice_convert(Goal, Goal).

%% =========================================================
%% Internal helpers
%% =========================================================

%% clause_head_body(+Clause, -Head, -Body)
clause_head_body((Head :- Body), Head, Body) :- !.
clause_head_body(Fact, Fact, true).

%% clause_predicates(+Clauses, -SortedPIs)
clause_predicates(Clauses, PIs) :-
    findall(Name/Arity,
            (member(C, Clauses),
             clause_head_body(C, H, _),
             functor(H, Name, Arity)),
            Raw),
    sort(Raw, PIs).
