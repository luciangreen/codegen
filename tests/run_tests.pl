:- use_module(library(plunit)).

:- initialization(main, main).

main(_) :-
    load_files([
        'tests/parser_tests.pl',
        'tests/testgen_tests.pl',
        'tests/codegen_tests.pl',
        'tests/optimisation_tests.pl',
        'tests/merge_tests.pl',
        'tests/cicd_tests.pl',
        'tests/starlog_tests.pl',
        'tests/chatbot_tests.pl',
        'tests/detlog_tests.pl',
        'tests/piglog_tests.pl'
    ], [if(not_loaded), silent(true)]),
    run_tests.
