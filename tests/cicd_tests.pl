:- begin_tests(stage10_cicd).

:- use_module('../src/cicd_agent').

%% -------------------------------------------------------
%% All 16 failure categories are declared
%% -------------------------------------------------------

test(all_failure_categories_declared) :-
    findall(C, cicd_failure_category(C), Cats),
    length(Cats, N),
    assertion(N =:= 16),
    assertion(member(spec_parse_error, Cats)),
    assertion(member(missing_type, Cats)),
    assertion(member(missing_example, Cats)),
    assertion(member(contradictory_example, Cats)),
    assertion(member(code_generation_failure, Cats)),
    assertion(member(test_generation_failure, Cats)),
    assertion(member(predicate_arity_mismatch, Cats)),
    assertion(member(incorrect_recursion_base_case, Cats)),
    assertion(member(incorrect_recursive_step, Cats)),
    assertion(member(wrong_output_order, Cats)),
    assertion(member(missing_deterministic_constraint, Cats)),
    assertion(member(unsupported_nondeterminism, Cats)),
    assertion(member(optimisation_changed_semantics, Cats)),
    assertion(member(predicate_merge_unsafe, Cats)),
    assertion(member(timeout, Cats)),
    assertion(member(infinite_recursion, Cats)).

%% -------------------------------------------------------
%% cicd_step/4 — individual step smoke tests
%% -------------------------------------------------------

test(step_read_specs) :-
    Spec = spec(double_all, _{relation: map, operation: double, inputs: [list(number)],
                               outputs: [list(number)], examples: [], constraints: [],
                               warnings: [], classification: code_only}),
    cicd_step(read_specs, [Spec], _, read_ok(Specs)),
    assertion(Specs == [Spec]).

test(step_convert_specs) :-
    Spec = spec(double_all, _{relation: map, operation: double, inputs: [list(number)],
                               outputs: [list(number)], examples: [], constraints: [],
                               warnings: [], classification: code_only}),
    cicd_step(convert_specs, [Spec], _, dict_ok(Dicts)),
    assertion(Dicts == [Spec]).

test(step_generate_tests) :-
    Spec = spec(my_pred, _{relation: map, operation: double, inputs: [list(number)],
                            outputs: [list(number)], examples: [], constraints: [],
                            warnings: [], classification: code_only}),
    cicd_step(generate_tests, [Spec], _, tests_ok(Tests)),
    Tests = [test(my_pred, placeholder)].

test(step_generate_code_map) :-
    Spec = spec(double_all, _{relation: map, operation: double, inputs: [list(number)],
                               outputs: [list(number)], examples: [], constraints: [],
                               warnings: [], classification: code_only}),
    cicd_step(generate_code, [Spec], _, code_ok([code(double_all, Code)])),
    sub_string(Code, _, _, _, "double_all([], [])").

test(step_run_tests_passes) :-
    Tests = [test(p, placeholder)],
    Code  = [code(p, "p(X,X).")],
    cicd_step(run_tests, tests_and_code(Tests, Code), _, test_result(Results)),
    Results = [pass(p)].

%% -------------------------------------------------------
%% cicd_diagnose/3
%% -------------------------------------------------------

test(diagnose_missing_type) :-
    cicd_diagnose(test_failure(p, missing_type), Category, _Explanation),
    assertion(Category == missing_type).

test(diagnose_contradictory_example) :-
    cicd_diagnose(test_failure(p, contradictory_examples), Category, _),
    assertion(Category == contradictory_example).

test(diagnose_timeout) :-
    cicd_diagnose(test_failure(p, timeout), Category, _),
    assertion(Category == timeout).

test(diagnose_arity_mismatch) :-
    cicd_diagnose(test_failure(p, arity_mismatch), Category, _),
    assertion(Category == predicate_arity_mismatch).

test(diagnose_produces_explanation_string) :-
    cicd_diagnose(test_failure(p, missing_type), _, Explanation),
    string(Explanation),
    sub_string(Explanation, _, _, _, "missing_type").

%% -------------------------------------------------------
%% cicd_run/3 — full loop smoke test
%% -------------------------------------------------------

test(cicd_run_produces_report) :-
    Spec = spec(double_all, _{
        relation:    map,
        operation:   double,
        inputs:      [list(number)],
        outputs:     [list(number)],
        examples:    [io([1,2,3],[2,4,6])],
        constraints: [deterministic, order_preserved, same_length],
        warnings:    [],
        classification: code_only
    }),
    cicd_run([Spec], [], Report),
    assertion(is_dict(Report)),
    assertion(member(read_specs, Report.steps_completed)),
    assertion(member(rerun_tests, Report.steps_completed)),
    assertion(string(Report.explanation)),
    assertion(string(Report.commit_summary)).

test(cicd_run_10_steps_completed) :-
    Spec = spec(p, _{
        relation: transform, operation: unknown,
        inputs: [unknown(input_type_missing)], outputs: [unknown(output_type_missing)],
        examples: [], constraints: [deterministic], warnings: [], classification: code_only
    }),
    cicd_run([Spec], [], Report),
    length(Report.steps_completed, N),
    assertion(N =:= 10).

test(cicd_run_empty_failures_for_trivial_spec) :-
    Spec = spec(id, _{
        relation: transform, operation: unknown,
        inputs: [list(number)], outputs: [list(number)],
        examples: [], constraints: [deterministic], warnings: [], classification: code_only
    }),
    cicd_run([Spec], [], Report),
    assertion(Report.failures == []).

%% -------------------------------------------------------
%% commit_summary/2
%% -------------------------------------------------------

test(commit_summary_pass) :-
    Report = report{specs: [s1, s2], failures: [], merge_suggestions: [m1],
                    steps_completed: [], tests: [], code: [], diagnosis: [],
                    optimised_code: [], explanation: "", commit_summary: ""},
    commit_summary(Report, Summary),
    sub_string(Summary, _, _, _, "all tests pass").

test(commit_summary_failures) :-
    Report = report{specs: [s1], failures: [f1, f2], merge_suggestions: [],
                    steps_completed: [], tests: [], code: [], diagnosis: [],
                    optimised_code: [], explanation: "", commit_summary: ""},
    commit_summary(Report, Summary),
    sub_string(Summary, _, _, _, "failure").

:- end_tests(stage10_cicd).
