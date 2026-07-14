:- begin_tests(stage13_detlog).

:- use_module('../src/detlog_opt').

%% -------------------------------------------------------
%% Shared test data
%% -------------------------------------------------------

%% Deterministic, no-cut, pure predicate
det_clauses([
    (double(X, Y) :- Y is X * 2)
]).

%% Nondeterministic predicate (multiple clauses)
nondet_clauses([
    (colour(red) :- true),
    (colour(blue) :- true),
    (colour(green) :- true)
]).

%% Predicate with a cut
cut_clauses([
    (first_nonzero([H|_], H) :- H \= 0, !),
    (first_nonzero([_|T], X) :- first_nonzero(T, X))
]).

%% Predicate with side effects
impure_clauses([
    (log_and_double(X, Y) :- format("doubling ~w~n", [X]), Y is X * 2)
]).

%% Pure map loop
loop_clauses([
    (scale([], []) :- true),
    (scale([X|Xs], [Y|Ys]) :- Y is X * 3, scale(Xs, Ys))
]).

%% -------------------------------------------------------
%% Mode inference
%% -------------------------------------------------------

test(mode_det_single_clause) :-
    det_clauses(Clauses),
    detlog_analyse(Clauses, analysis(Modes, _, _)),
    member(mode_info(double/2, det), Modes).

test(mode_nondet_multiple_clauses) :-
    nondet_clauses(Clauses),
    detlog_analyse(Clauses, analysis(Modes, _, _)),
    member(mode_info(colour/1, nondet), Modes).

%% -------------------------------------------------------
%% Cut classification
%% -------------------------------------------------------

test(cut_no_cut_for_pure_predicate) :-
    det_clauses(Clauses),
    detlog_analyse(Clauses, analysis(_, Cuts, _)),
    member(cut_info(double/2, no_cut), Cuts).

test(cut_local_cut_detected) :-
    cut_clauses(Clauses),
    detlog_analyse(Clauses, analysis(_, Cuts, _)),
    member(cut_info(first_nonzero/2, CutClass), Cuts),
    CutClass \== no_cut.

%% -------------------------------------------------------
%% Effect classification
%% -------------------------------------------------------

test(effect_pure_for_arithmetic_predicate) :-
    det_clauses(Clauses),
    detlog_analyse(Clauses, analysis(_, _, Effects)),
    member(effect_info(double/2, pure), Effects).

test(effect_side_effects_for_format_call) :-
    impure_clauses(Clauses),
    detlog_analyse(Clauses, analysis(_, _, Effects)),
    member(effect_info(log_and_double/2, side_effects), Effects).

%% -------------------------------------------------------
%% Classification: converted vs fallback
%% -------------------------------------------------------

test(classify_converted_for_det_pure_no_cut) :-
    det_clauses(Clauses),
    detlog_analyse(Clauses, Analysis),
    detlog_classify(Analysis, double/2, converted).

test(classify_fallback_for_nondet) :-
    nondet_clauses(Clauses),
    detlog_analyse(Clauses, Analysis),
    detlog_classify(Analysis, colour/1, fallback).

%% -------------------------------------------------------
%% Wrapper emission
%% -------------------------------------------------------

test(emit_wrapper_converted_has_no_comment) :-
    functor(Head, double, 2),
    detlog_emit_wrapper(Head, my_source, converted, Text),
    \+ sub_string(Text, _, _, _, "fallback").

test(emit_wrapper_fallback_has_comment) :-
    functor(Head, colour, 1),
    detlog_emit_wrapper(Head, my_source, fallback, Text),
    sub_string(Text, _, _, _, "fallback").

%% -------------------------------------------------------
%% Full optimise/3 pipeline
%% -------------------------------------------------------

test(optimise_annotates_clauses_with_status) :-
    det_clauses(Clauses),
    detlog_optimise(Clauses, Code, _Diagnostics),
    sub_string(Code, _, _, _, "detlog:converted").

test(optimise_returns_diagnostics_for_fallback) :-
    nondet_clauses(Clauses),
    detlog_optimise(Clauses, _Code, Diagnostics),
    member(diagnostic(fallback, colour/1), Diagnostics).

%% -------------------------------------------------------
%% Splice conversion
%% -------------------------------------------------------

test(splice_convert_member_to_splice_each) :-
    Goal = member(X, [a, b, c]),
    detlog_splice_convert(Goal, Spliced),
    Spliced = splice_each([cp([a, b, c])], [X]).

test(splice_convert_conjunction_with_member) :-
    Goal = (ground(X), member(X, [1, 2, 3])),
    detlog_splice_convert(Goal, Spliced),
    Spliced = (ground(X), splice_each([cp([1, 2, 3])], [X])).

:- end_tests(stage13_detlog).
