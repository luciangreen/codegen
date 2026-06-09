# codegen
Integrates code generation and Dev-Ops with optimisation.

## Current status

- Stage 1 complete: repository scaffold.
- Stage 2 complete: sentence specs to dictionary data (`src/parser.pl`, `src/dictionary.pl`, `tests/parser_tests.pl`).
- Stage 3 complete: dictionary data to tests (`src/testgen.pl`, `tests/codegen_tests.pl`).
- Stage 4 complete: S2A + CAW code generation candidate pipeline (`src/s2a_bridge.pl`, `src/caw_codegen.pl`, `tests/codegen_tests.pl`).
- Stage 5 complete: greater-than-14-item S2A upgrade with windowing, manual classification, rule compression, and prioritised CAW search (`src/s2a_bridge.pl`, `src/caw_codegen.pl`, `tests/codegen_tests.pl`).
- Stage 6 complete: Starlog expression generation (`src/starlog.pl`, `src/caw_codegen.pl`, `tests/codegen_tests.pl`).
- Stage 7 complete: Loop2 optimisation (`src/optimiser.pl`, `tests/codegen_tests.pl`).
- Stage 9 complete: Predicate merging (`src/predicate_merge.pl`, `tests/codegen_tests.pl`).
- Stage 11 complete: Web interface (`web/index.html`, `web/app.js`, `web/style.css`).
- Stage 12 complete: Manual chatbot adapter (`src/chatbot_adapter.pl`, `tests/codegen_tests.pl`).

## Stage 2 – Edge cases handled

`src/parser.pl` and `src/dictionary.pl` handle all 14 specified edge cases:
1. Missing input type → `missing_input_type` warning
2. Missing output type → `missing_output_type` warning
3. Multiple outputs → `multiple_outputs` warning
4. Nested structures → `list(list(T))` input type + `nested_structures` constraint
5. Strings, atoms, chars, lists, numbers, dicts → full type inference
6. Ambiguous verbs (change/make/find) → `ambiguous_verb(V)` warning
7. Tests-only specs → `tests_only` classification + `tests_without_code` warning
8. Code-only specs → `code_only` classification
9. Contradictory examples → `contradictory_examples` warning
10. More than 14 examples/items → `too_many_examples_or_items` warning
11. Recursion required → `recursive` constraint
12. Generator search → `generator_search` constraint
13. Predicate merging → `predicate_merge` constraint
14. Change previous tests → `test_repair` constraint

## Run tests

```sh
swipl -q -f none -g "load_files('tests/parser_tests.pl', [if(not_loaded)]), run_tests, halt."
swipl -q -f none -g "load_files('tests/codegen_tests.pl', [if(not_loaded)]), run_tests, halt."
```
