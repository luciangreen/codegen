# codegen
Integrates code generation and Dev-Ops with optimisation.

## Current status
- Stage 1 complete: repository scaffold.
- Stage 2 complete: sentence specs to dictionary data (`src/parser.pl`, `src/dictionary.pl`, `tests/parser_tests.pl`).
- Stage 3 pending: dictionary data to tests (`src/testgen.pl`, Stage 3 test-generation tests to be added).
- Stage 4 complete: S2A + CAW code generation candidate pipeline (`src/s2a_bridge.pl`, `src/caw_codegen.pl`, `tests/codegen_tests.pl`).

## Run tests
- `swipl -q -f none -g "load_files('tests/parser_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/codegen_tests.pl', [if(not_loaded)]), run_tests, halt."`
