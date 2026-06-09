# codegen
Integrates code generation and Dev-Ops with optimisation.

## Current status
- Stage 1 complete: repository scaffold.
- Stage 2 complete: sentence specs to dictionary data (`src/parser.pl`, `src/dictionary.pl`, `tests/parser_tests.pl`).

## Run tests
- `swipl -q -f none -g "load_files('tests/parser_tests.pl', [if(not_loaded)]), run_tests, halt."`
