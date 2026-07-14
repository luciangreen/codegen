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

## Showcase
- Parse a sentence spec into structured dictionary data:
  - `swipl -q -f none -g "use_module('src/parser.pl'), sentence_to_spec('Generate a predicate double_all(Input, Output) that maps every number in Input to twice its value. Examples: [1,2,3] -> [2,4,6].', Spec), portray_clause(Spec), halt."`
- Generate Prolog tests from a spec:
  - `swipl -q -f none -g "use_module('src/testgen.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), generate_tests(Spec, Code), writeln(Code), halt."`
- Generate candidate code from a spec:
  - `swipl -q -f none -g "use_module('src/caw_codegen.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), generate_best_code(Spec, Code), writeln(Code), halt."`
- Emit Starlog and expanded Prolog from the same spec:
  - `swipl -q -f none -g "use_module('src/starlog.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), starlog_full(Spec, StarlogCode, PrologCode), writeln(StarlogCode), nl, writeln(PrologCode), halt."`
- Convert nondeterministic list processing into deterministic recursive loops:
  - `swipl -q -f none -g "use_module('src/optimiser.pl'), reset_loop_counter, loop2_convert((double_all(Input, Output) :- findall(Y, (member(X, Input), Y is X*2), Output)), Clauses), maplist(portray_clause, Clauses), halt."`
- Detect safe predicate merges:
  - `swipl -q -f none -g "use_module('src/predicate_merge.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, spec(double_all, D1)), S2 = spec(triple_all, D1.put(_{name: triple_all, operation: triple, examples: [io([1,2,3], [3,6,9])] })), merge_predicates(spec(double_all, D1), S2, Code), writeln(Code), halt."`
- Run the CI/CD agent loop over changed specs:
  - `swipl -q -f none -g "use_module('src/cicd_agent.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), cicd_run([Spec], [], Report), portray_clause(Report), halt."`
- Route a natural-language command through the manual chatbot adapter:
  - `swipl -q -f none -g "use_module('src/chatbot_adapter.pl'), chat_command('Generate a predicate double_all from these examples.', Intent, Data), portray_clause(Intent), portray_clause(Data), halt."`
- Apply Detlog and Piglog optimisation passes to generated logic:
  - `swipl -q -f none -g "use_module('src/detlog_opt.pl'), detlog_optimise([(double_all([],[])), (double_all([X|Xs],[Y|Ys]) :- Y is X*2, double_all(Xs,Ys))], Code, Diagnostics), writeln(Code), portray_clause(Diagnostics), halt."`
  - `swipl -q -f none -g "use_module('src/piglog_opt.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), PrologCode = \"double_all([], []).\\ndouble_all([X|Xs], [Y|Ys]) :- Y is X * 2, double_all(Xs, Ys).\", piglog_optimise(Spec, PrologCode, Code), writeln(Code), halt."`
- Open the static web interface:
  - `python3 -m http.server 8000 --directory web`
  - Then visit `http://localhost:8000`.

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
