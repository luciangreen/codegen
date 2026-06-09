# codegen
Integrates code generation and Dev-Ops with optimisation.

## Current status

| Stage | Description | Completion |
|-------|-------------|------------|
| 1 | Repository Setup | **100%** |
| 2 | Sentence Specs to Dictionary Data | **100%** |
| 3 | Dictionary Data to Tests | **100%** |
| 4–12 | (planned) | 0% |

### Stage 1 – Repository Setup (100%)
All required files and directories are present:
- `src/` – `parser.pl`, `dictionary.pl`, `testgen.pl`, and stubs for `s2a_bridge.pl`, `caw_codegen.pl`, `optimiser.pl`, `predicate_merge.pl`, `cicd_agent.pl`, `chatbot_adapter.pl`
- `web/` – `index.html`, `app.js`, `style.css` (full 10-panel UI scaffold + JS intent classifier)
- `examples/` – `sentence_specs.pl` (14 edge-case sentences), `dictionary_specs.pl`, `generated_tests.pl`, `generated_code.pl`
- `tests/` – `parser_tests.pl`, `codegen_tests.pl`, stubs for `optimisation_tests.pl`, `merge_tests.pl`, `cicd_tests.pl`

### Stage 2 – Sentence Specs to Dictionary Data (100%)
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

### Stage 3 – Dictionary Data to Tests (100%)
`src/testgen.pl` generates plunit test blocks from specs, covering all 10 edge cases.
See `examples/generated_tests.pl` for example output.

## Run tests

```sh
# Stage 2 (parser + dictionary) – 13 tests
swipl -g "load_test_files([]), run_tests(stage2_parser), halt" tests/parser_tests.pl

# Stage 3 (test generator) – 21 tests
swipl -g "load_test_files([]), run_tests(stage3_testgen), halt" tests/codegen_tests.pl
```

