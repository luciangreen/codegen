# Requirements and implementation status

The full staged feature specification is retained in [`pr1.txt`](pr1.txt).
This file tracks what the current implementation does and what remains; it
supersedes the stale Stage 5-only implementation target in the original draft.

## Implemented modules

- Sentence parsing and dictionary-spec construction: `src/parser.pl`,
  `src/dictionary.pl`.
- Test-code generation: `src/testgen.pl`.
- Example-induction bridge and ranked candidate templates, including the
  greater-than-14-item path: `src/s2a_bridge.pl`, `src/caw_codegen.pl`.
- Starlog emission/expansion and supported operator/evaluation features:
  `src/starlog.pl`.
- Loop2 and PLOP-style transformations/analysis:
  `src/optimiser.pl`.
- Predicate merge detection and safety checks: `src/predicate_merge.pl`.
- Rule-based chatbot command classification and extraction:
  `src/chatbot_adapter.pl`.
- Detlog mode/cut/effect analysis and conversion:
  `src/detlog_opt.pl`.
- Piglog partition/dependency analysis and scheduling metadata:
  `src/piglog_opt.pl`.

Each module has a corresponding PlUnit suite under `tests/`. Run the complete
suite from the repository root with:

```sh
swipl -q -f none -s tests/run_tests.pl
```

## Partial demonstrations

- `src/cicd_agent.pl` exposes the ten-step report flow and maps known failure
  categories, but test execution is simulated, repair is a no-op, and the
  optimiser step currently preserves input code unchanged.
- `web/` contains ten static panels. Parsing/code generation are implemented
  with browser-side heuristics, and test results are simulated; no backend
  connects the UI to SWI-Prolog.
- `src/chatbot_adapter.pl` routes intents and extracts data but does not execute
  the requested pipeline operation.

## Remaining work

1. Replace CI/CD placeholder tests with executable generated tests, capture
   failures from a controlled Prolog test run, perform real repairs/optimisation,
   and re-run tests before reporting success.
2. Connect the web UI to a backend (or clearly restrict it to a frontend-only
   demonstration) and remove simulated test results.
3. Route chatbot intents to the actual parser, generator, optimiser, and
   diagnostics, with explicit responses for unsupported actions.
4. Expand and validate the natural-language parser and candidate generator
   against ambiguous, contradictory, nested, non-ground, and unsupported specs.
5. Continue semantic and safety testing of optimizer conversions, especially
   the unsupported Loop2 cases listed in `pr1.txt`.

The features above are prototypes, not a production CI service or a general
English-to-Prolog compiler. Run generated code and optimisations only in an
environment appropriate for executing Prolog.
