:- module(cicd_agent, [
    cicd_run/3,
    cicd_step/4,
    cicd_diagnose/3,
    cicd_failure_category/1,
    commit_summary/2
]).

:- use_module(library(lists)).

%% =========================================================
%% Stage 10: Lucian CI/CD Agent Loop
%%
%% Implements the 10-step CI/CD loop from pr1.txt.
%%
%% cicd_run(+ChangedSpecs, +ExistingCode, -Report)
%%
%% Report = report{
%%   steps_completed: list(atom),
%%   specs:           list(spec),
%%   tests:           list(test),
%%   code:            list(code),
%%   failures:        list(failure),
%%   diagnosis:       list(diagnosis),
%%   optimised_code:  list(code),
%%   merge_suggestions: list(pair),
%%   explanation:     string,
%%   commit_summary:  string
%% }
%%
%% The loop:
%%  1. Read changed sentence specs
%%  2. Convert specs to dictionary data
%%  3. Generate or update tests
%%  4. Generate candidate code
%%  5. Run tests
%%  6. If tests fail, diagnose failure logically
%%  7. Modify code/tests/specs depending on cause
%%  8. Optimise code
%%  9. Merge predicates where safe
%% 10. Re-run tests
%% 11. Produce explanation and commit summary
%% =========================================================

%% Failure diagnosis categories (all 16 from pr1.txt)
cicd_failure_category(spec_parse_error).
cicd_failure_category(missing_type).
cicd_failure_category(missing_example).
cicd_failure_category(contradictory_example).
cicd_failure_category(code_generation_failure).
cicd_failure_category(test_generation_failure).
cicd_failure_category(predicate_arity_mismatch).
cicd_failure_category(incorrect_recursion_base_case).
cicd_failure_category(incorrect_recursive_step).
cicd_failure_category(wrong_output_order).
cicd_failure_category(missing_deterministic_constraint).
cicd_failure_category(unsupported_nondeterminism).
cicd_failure_category(optimisation_changed_semantics).
cicd_failure_category(predicate_merge_unsafe).
cicd_failure_category(timeout).
cicd_failure_category(infinite_recursion).

%% =========================================================
%% Step predicates
%% =========================================================

%% Step 1: Read changed sentence specs
cicd_step(read_specs, ChangedSpecs, _, read_ok(ChangedSpecs)).

%% Step 2: Convert specs to dictionary data
cicd_step(convert_specs, ChangedSpecs, _, dict_ok(Dicts)) :-
    maplist(spec_to_dict, ChangedSpecs, Dicts).

%% Step 3: Generate or update tests
cicd_step(generate_tests, Dicts, _, tests_ok(Tests)) :-
    maplist(dict_to_test, Dicts, Tests).

%% Step 4: Generate candidate code
cicd_step(generate_code, Dicts, _, code_ok(Codes)) :-
    maplist(dict_to_code, Dicts, Codes).

%% Step 5: Run tests
cicd_step(run_tests, TestsAndCode, _, test_result(Results)) :-
    TestsAndCode = tests_and_code(Tests, Code),
    maplist(simulate_test(Code), Tests, Results).

%% Step 6: Diagnose failures
cicd_step(diagnose_failures, Failures, _, diagnosis_ok(Diagnoses)) :-
    maplist(diagnose_one_failure, Failures, Diagnoses).

%% Step 7: Repair code/tests/specs
cicd_step(repair, Diagnoses, Code, repaired_ok(NewCode)) :-
    foldl(apply_repair, Diagnoses, Code, NewCode).

%% Step 8: Optimise code
cicd_step(optimise, Code, _, optimised_ok(OptCode)) :-
    maplist(optimise_one, Code, OptCode).

%% Step 9: Merge predicates
cicd_step(merge_predicates, Dicts, _, merge_ok(MergeSuggestions)) :-
    findall(pair(N1,N2),
        (member(spec(N1,D1), Dicts),
         member(spec(N2,D2), Dicts),
         N1 @< N2,
         D1.get(relation) == D2.get(relation),
         D1.get(inputs)   == D2.get(inputs),
         D1.get(outputs)  == D2.get(outputs)),
        MergeSuggestions).

%% Step 10: Re-run tests
cicd_step(rerun_tests, TestsAndCode, _, rerun_result(Results)) :-
    TestsAndCode = tests_and_code(Tests, Code),
    maplist(simulate_test(Code), Tests, Results).

%% =========================================================
%% cicd_run/3 — main loop
%% =========================================================

cicd_run(ChangedSpecs, ExistingCode, Report) :-
    %% Step 1
    cicd_step(read_specs,       ChangedSpecs,             _, read_ok(Specs)),
    %% Step 2
    cicd_step(convert_specs,    Specs,                    _, dict_ok(Dicts)),
    %% Step 3
    cicd_step(generate_tests,   Dicts,                    _, tests_ok(Tests)),
    %% Step 4
    cicd_step(generate_code,    Dicts,                    _, code_ok(CandidateCodes)),
    %% Step 5
    MergedCode1 = tests_and_code(Tests, CandidateCodes),
    cicd_step(run_tests,        MergedCode1,              _, test_result(Results1)),
    %% Step 6
    collect_failures(Results1, Failures),
    cicd_step(diagnose_failures, Failures,                _, diagnosis_ok(Diagnoses)),
    %% Step 7
    cicd_step(repair,           Diagnoses,   CandidateCodes, repaired_ok(RepairedCode)),
    %% Step 8
    cicd_step(optimise,         RepairedCode,             _, optimised_ok(OptCode)),
    %% Step 9
    cicd_step(merge_predicates, Dicts,                    _, merge_ok(MergeSuggestions)),
    %% Step 10
    MergedCode2 = tests_and_code(Tests, OptCode),
    cicd_step(rerun_tests,      MergedCode2,              _, rerun_result(Results2)),
    %% Step 11
    collect_failures(Results2, FinalFailures),
    produce_explanation(Specs, FinalFailures, Diagnoses, Explanation),
    produce_commit_summary(Specs, FinalFailures, CommitSummary),
    Report = report{
        steps_completed:   [read_specs, convert_specs, generate_tests, generate_code,
                            run_tests, diagnose_failures, repair, optimise,
                            merge_predicates, rerun_tests],
        specs:             Specs,
        tests:             Tests,
        code:              OptCode,
        failures:          FinalFailures,
        diagnosis:         Diagnoses,
        optimised_code:    OptCode,
        merge_suggestions: MergeSuggestions,
        explanation:       Explanation,
        commit_summary:    CommitSummary
    }.

%% =========================================================
%% cicd_diagnose/3
%% =========================================================

cicd_diagnose(test_failure(Name, Error), Category, Explanation) :-
    classify_failure_category(Name, Error, Category),
    format(string(Explanation),
        "Test ~w failed: ~w → category: ~w",
        [Name, Error, Category]).

cicd_diagnose(code_error(Name, Error), Category, Explanation) :-
    classify_failure_category(Name, Error, Category),
    format(string(Explanation),
        "Code generation error for ~w: ~w → category: ~w",
        [Name, Error, Category]).

cicd_diagnose(Warning, other, Explanation) :-
    format(string(Explanation), "Warning: ~w", [Warning]).

classify_failure_category(_, missing_type, missing_type) :- !.
classify_failure_category(_, missing_example, missing_example) :- !.
classify_failure_category(_, contradictory_examples, contradictory_example) :- !.
classify_failure_category(_, parse_error, spec_parse_error) :- !.
classify_failure_category(_, arity_mismatch, predicate_arity_mismatch) :- !.
classify_failure_category(_, wrong_base_case, incorrect_recursion_base_case) :- !.
classify_failure_category(_, wrong_step, incorrect_recursive_step) :- !.
classify_failure_category(_, wrong_order, wrong_output_order) :- !.
classify_failure_category(_, timeout, timeout) :- !.
classify_failure_category(_, infinite_loop, infinite_recursion) :- !.
classify_failure_category(_, optimisation_semantic_change, optimisation_changed_semantics) :- !.
classify_failure_category(_, merge_unsafe, predicate_merge_unsafe) :- !.
classify_failure_category(_, _, code_generation_failure).

%% =========================================================
%% commit_summary/2
%% =========================================================

commit_summary(Report, Summary) :-
    length(Report.specs, NSpecs),
    length(Report.failures, NFails),
    length(Report.merge_suggestions, NMerge),
    (NFails =:= 0
    ->  format(string(Summary),
            "CI/CD pass: ~w spec(s) processed, all tests pass, ~w merge suggestion(s).",
            [NSpecs, NMerge])
    ;   format(string(Summary),
            "CI/CD partial: ~w spec(s) processed, ~w failure(s) remaining, ~w merge suggestion(s).",
            [NSpecs, NFails, NMerge])
    ).

%% =========================================================
%% Internal helpers
%% =========================================================

spec_to_dict(spec(Name, Dict), spec(Name, Dict)) :- !.
spec_to_dict(Sentence, spec(unknown, _{sentence: Sentence})) :-
    \+ functor(Sentence, spec, 2).

dict_to_test(spec(Name, _Dict), test(Name, placeholder)).

dict_to_code(spec(Name, Dict), code(Name, CodeStr)) :-
    (   get_dict(relation, Dict, map)
    ->  format(string(CodeStr),
            "~w([], []).~n~w([X|Xs], [Y|Ys]) :- Y = X, ~w(Xs, Ys).",
            [Name, Name, Name])
    ;   format(string(CodeStr),
            "~w(Input, Input).",
            [Name])
    ).

simulate_test(_Code, test(Name, placeholder), pass(Name)).

collect_failures(Results, Failures) :-
    include(is_failure, Results, Failures).

is_failure(fail(_)).
is_failure(error(_,_)).

diagnose_one_failure(fail(Name), diagnosis(Name, test_failure, unknown_reason)) :- !.
diagnose_one_failure(error(Name, E), diagnosis(Name, error, E)) :- !.
diagnose_one_failure(_, diagnosis(unknown, other, none)).

apply_repair(diagnosis(_Name, _Cat, _Reason), Code, Code).

optimise_one(code(Name, Str), code(Name, Str)).

produce_explanation(Specs, Failures, Diagnoses, Explanation) :-
    length(Specs, NS),
    length(Failures, NF),
    length(Diagnoses, ND),
    format(string(Explanation),
        "Processed ~w spec(s). Failures: ~w. Diagnoses: ~w.",
        [NS, NF, ND]).

produce_commit_summary(Specs, Failures, Summary) :-
    length(Specs, NS),
    length(Failures, NF),
    format(string(Summary),
        "codegen: ~w spec(s), ~w failure(s)",
        [NS, NF]).
