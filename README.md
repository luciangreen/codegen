# codegen

Lucian Codegen is a Prolog code-generation and optimisation prototype. It turns
sentence specifications into dictionary data, tests, and candidate Prolog, and
provides Starlog, Loop2/PLOP-style optimisation, merge analysis, and companion
web/chatbot prototypes.

## Feature status

| Area | Implemented functionality | Status / limits |
|---|---|---|
| Parsing and dictionary (`src/parser.pl`, `src/dictionary.pl`) | Heuristic sentence parsing, operation/relation classification, dictionary specs and examples | Prototype parser; not a general natural-language parser |
| Test generation (`src/testgen.pl`) | PlUnit tests for examples and supported edge cases | Generated tests are code output; they are not executed by the CI/CD agent |
| Code generation (`src/s2a_bridge.pl`, `src/caw_codegen.pl`) | Example analysis, candidate templates, ranking, large-input windowing and prioritised search | Template-based induction; verify generated code against your own specs |
| Starlog (`src/starlog.pl`) | Emit/expand helpers, supported operators, eval/no-eval entry points | Use the module tests for the supported syntax and evaluation boundaries |
| Optimisation (`src/optimiser.pl`) | Loop2 conversions and PLOP-style transformations/analysis | Only supported patterns are converted; this is not a general Prolog optimiser |
| Predicate merge (`src/predicate_merge.pl`) | Merge candidates, parameterised forms, unsafe-merge checks | Suggestions are conservative prototype results, not automatic repository edits |
| CI/CD agent (`src/cicd_agent.pl`) | Ten-step report shape, failure-category mapping, candidate summaries | Test execution, repairs, and optimisation are currently simulated or identity operations |
| Web UI (`web/`) | Ten-panel static demonstration of the pipeline | Browser-side parser, generation, and test results are illustrative, not connected to SWI-Prolog |
| Chatbot (`src/chatbot_adapter.pl`) | Rule-based intent classification, data extraction, routing | Manual adapter only; intents do not invoke the full pipeline |
| Detlog (`src/detlog_opt.pl`) | Mode/cut/effect analysis and conversion annotations | Supported-clause prototype; review fallback diagnostics |
| Piglog (`src/piglog_opt.pl`) | Partition/dependency analysis, scheduling metadata and headers | Produces metadata; it is not a parallel runtime |

Stages 1–9 and 12–14 have module implementations and tests, subject to the
limits above. Stages 10–11 are demonstrations rather than end-to-end execution.
See [Requirements.md](Requirements.md) for the remaining implementation work;
`pr1.txt` retains the full original staged requirements.

## Requirements

- SWI-Prolog (the `swipl` executable) to run the Prolog modules and tests.
- Python 3 only if you want to serve the static web UI locally.

## Run the test suite

From the repository root, run all ten PlUnit test files:

```sh
swipl -q -f none -s tests/run_tests.pl
```

Individual suites can also be run with:

```sh
swipl -q -f none -g "load_files('tests/parser_tests.pl'), run_tests, halt."
```

Replace `parser_tests.pl` with any of `testgen_tests.pl`,
`codegen_tests.pl`, `optimisation_tests.pl`, `merge_tests.pl`, `cicd_tests.pl`,
`starlog_tests.pl`, `chatbot_tests.pl`, `detlog_tests.pl`, or
`piglog_tests.pl`.

## Try the pipeline modules

Parse a sentence spec into structured dictionary data:

```sh
swipl -q -f none -g "use_module('src/parser.pl'), sentence_to_spec('Generate a predicate double_all(Input, Output) that maps every number in Input to twice its value. Examples: [1,2,3] -> [2,4,6].', Spec), portray_clause(Spec), halt."
```

Generate tests or candidate code from an example dictionary spec:

```sh
swipl -q -f none -g "use_module('src/testgen.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), generate_tests(Spec, Code), writeln(Code), halt."
swipl -q -f none -g "use_module('src/caw_codegen.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), generate_best_code(Spec, Code), writeln(Code), halt."
```

Emit Starlog and expanded Prolog, or convert a supported `findall/3` pattern
to a deterministic recursive loop:

```sh
swipl -q -f none -g "use_module('src/starlog.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), starlog_full(Spec, StarlogCode, PrologCode), writeln(StarlogCode), nl, writeln(PrologCode), halt."
swipl -q -f none -g "use_module('src/optimiser.pl'), reset_loop_counter, loop2_convert((double_all(Input, Output) :- findall(Y, (member(X, Input), Y is X*2), Output)), Clauses), maplist(portray_clause, Clauses), halt."
```

Run the CI/CD report prototype or rule-based chatbot adapter:

```sh
swipl -q -f none -g "use_module('src/cicd_agent.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), cicd_run([Spec], [], Report), portray_clause(Report), halt."
swipl -q -f none -g "use_module('src/chatbot_adapter.pl'), chat_command('Generate a predicate double_all from these examples.', Intent, Data), portray_clause(Intent), portray_clause(Data), halt."
```

Apply Detlog or Piglog analysis:

```sh
swipl -q -f none -g "use_module('src/detlog_opt.pl'), detlog_optimise([(double_all([],[])), (double_all([X|Xs],[Y|Ys]) :- Y is X*2, double_all(Xs,Ys))], Code, Diagnostics), writeln(Code), portray_clause(Diagnostics), halt."
swipl -q -f none -g "use_module('src/piglog_opt.pl'), use_module('examples/dictionary_specs.pl'), expected_spec(double_all, Spec), PrologCode = \"double_all([], []).\\ndouble_all([X|Xs], [Y|Ys]) :- Y is X * 2, double_all(Xs, Ys).\", piglog_optimise(Spec, PrologCode, Code), writeln(Code), halt."
```

Open the static browser demonstration:

```sh
python3 -m http.server 8000 --directory web
```

Then visit `http://localhost:8000`. The UI currently uses its own in-browser
heuristics and simulated test results; it does not call the Prolog modules.
