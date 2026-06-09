:- module(generated_tests, [
    stage3_generated_tests/2
]).

:- use_module('../src/testgen').

stage3_generated_tests(Spec, TestsCode) :-
    testgen:generate_tests(Spec, TestsCode).
