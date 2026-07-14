# codegen
Integrates code generation and Dev-Ops with optimisation.

## Current status
- Stage 1 complete: repository scaffold.
- Stage 2 complete: sentence specs to dictionary data (`src/parser.pl`, `src/dictionary.pl`, `tests/parser_tests.pl`).
- Stage 3 complete: dictionary data to tests (`src/testgen.pl`, `tests/testgen_tests.pl`).
- Stage 4 complete: S2A + CAW code generation candidate pipeline (`src/s2a_bridge.pl`, `src/caw_codegen.pl`, `tests/codegen_tests.pl`).
- Stage 5 complete: greater-than-14-item S2A upgrade with windowing, manual classification, rule compression, and prioritised CAW search (`src/s2a_bridge.pl`, `src/caw_codegen.pl`, `tests/codegen_tests.pl`).
- Stage 6 complete: Starlog integration — emit, expand, all 10 features + atom-concat (•), univ operators (..= / =..), starlog_eval/2, starlog_no_eval/2 (`src/starlog.pl`, `tests/starlog_tests.pl`).
- Stage 7 complete: Loop2 optimisation — findall/member conversion to deterministic recursive loops (`src/optimiser.pl`, `tests/optimisation_tests.pl`).
- Stage 8 complete: PLOP optimisation — memoisation, subterm-with-address, indexical optimisation, invariant extraction, duplicate subcall elimination, dependency analysis (`src/optimiser.pl`, `tests/optimisation_tests.pl`).
- Stage 9 complete: predicate merging — detect and generate merged/parameterised forms, unsafe merge rejection (`src/predicate_merge.pl`, `tests/merge_tests.pl`).
- Stage 10 complete: Lucian CI/CD agent loop — 10-step pipeline, 16 failure categories, repair, explain, commit summary (`src/cicd_agent.pl`, `tests/cicd_tests.pl`).
- Stage 11 complete: web interface — 10 panels covering full pipeline (`web/index.html`, `web/app.js`, `web/style.css`).
- Stage 12 complete: manual chatbot adapter — 10 intents, keyword classification, dictionary data extraction, routing (`src/chatbot_adapter.pl`, `tests/chatbot_tests.pl`).
- Stage 13 complete: Detlog optimisation integration — mode inference (det/semidet/nondet), cut classification (no_cut/local_cut/unsafe_cut), effect classification (pure/side_effects), converted vs fallback annotation, wrapper emission, splice conversion (`src/detlog_opt.pl`, `tests/detlog_tests.pl`).
- Stage 14 complete: Piglog optimisation integration — partition extraction, dependency graph, safety-first and adaptive scheduling, readiness scoring, Piglog metadata header generation (`src/piglog_opt.pl`, `tests/piglog_tests.pl`).

## Run tests
- `swipl -q -f none -g "load_files('tests/parser_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/testgen_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/codegen_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/optimisation_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/merge_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/cicd_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/starlog_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/chatbot_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/detlog_tests.pl', [if(not_loaded)]), run_tests, halt."`
- `swipl -q -f none -g "load_files('tests/piglog_tests.pl', [if(not_loaded)]), run_tests, halt."`

