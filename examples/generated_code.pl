:- module(generated_code, [
    stage4_best_code/2
]).

:- use_module('../src/caw_codegen').

stage4_best_code(Spec, Code) :-
    caw_codegen:generate_best_code(Spec, Code).