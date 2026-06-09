/* Lucian Codegen – front-end application logic
 *
 * The pipeline (parse -> dict -> tests -> code -> optimise -> merge)
 * runs server-side via SWI-Prolog.  This script wires up the UI panels
 * for a future HTTP API; until that API exists the panels show placeholder
 * output derived entirely in the browser.
 */

'use strict';

/* ---- Intent classifier (mirrors chatbot_adapter.pl) ---- */
function classifyIntent(text) {
  const t = text.toLowerCase();
  if (/test(s)?/.test(t))                       return 'generate_tests';
  if (/generate|predicate/.test(t))             return 'generate_code';
  if (/debug|fail|explain why/.test(t))         return 'debug_failure';
  if (/optim|findall/.test(t))                  return 'optimise_code';
  if (/merge/.test(t))                          return 'merge_predicates';
  if (/explain/.test(t))                        return 'explain_code';
  if (/starlog|>>|\bis\b/.test(t))              return 'convert_starlog';
  if (/deterministic|loop/.test(t))             return 'convert_loop';
  if (/invariant/.test(t))                      return 'find_invariant';
  if (/repair/.test(t))                         return 'repair_tests';
  return 'generate_code';
}

/* ---- Minimal in-browser spec parser (placeholder for Prolog backend) ---- */
function parseSpecBrowser(sentence) {
  const s = sentence.toLowerCase();
  const nameMatch = s.match(/predicate\s+([a-z_][a-z0-9_]*)\s*\(/);
  const name = nameMatch ? nameMatch[1] : 'unknown_predicate';
  const relation =
    /\bmap\b/.test(s)    ? 'map'    :
    /\bfilter\b/.test(s) ? 'filter' :
    /\bfold\b/.test(s)   ? 'fold'   : 'transform';
  const operation =
    /double|twice/.test(s)  ? 'double'    :
    /triple|thrice/.test(s) ? 'triple'    :
    /square/.test(s)        ? 'square'    :
    /increment/.test(s)     ? 'increment' :
    /decrement/.test(s)     ? 'decrement' : 'unknown';

  /* Extract examples: anything matching [...] -> [...] */
  const exampleRe = /(\[[^\]]*\])\s*->\s*(\[[^\]]*\])/g;
  const examples = [];
  let m;
  while ((m = exampleRe.exec(s)) !== null) {
    examples.push(`io(${m[1]}, ${m[2]})`);
  }

  return {
    name,
    relation,
    operation,
    examples,
    inputs:  ['list(number)'],
    outputs: ['list(number)'],
    constraints: relation === 'map' ? ['deterministic', 'order_preserved', 'same_length'] : ['deterministic'],
  };
}

function dictToString(d) {
  return `spec(${d.name}, _{\n` +
    `  name: ${d.name},\n` +
    `  inputs: [${d.inputs.join(', ')}],\n` +
    `  outputs: [${d.outputs.join(', ')}],\n` +
    `  relation: ${d.relation},\n` +
    `  operation: ${d.operation},\n` +
    `  examples: [${d.examples.join(', ')}],\n` +
    `  constraints: [${d.constraints.join(', ')}]\n` +
    `}).`;
}

function testsToString(d) {
  let out = `:- begin_tests(${d.name}).\n`;
  d.examples.forEach((ex, i) => {
    const parts = ex.match(/io\(([^,]+(?:,[^,]+)*),\s*(\[[^\]]*\])\)/);
    if (parts) {
      out += `test(example_${i + 1}) :-\n`;
      out += `    ${d.name}(${parts[1]}, R),\n`;
      out += `    assertion(R == ${parts[2]}).\n`;
    }
  });
  out += `test(empty) :-\n    ${d.name}([], R),\n    assertion(R == []).\n`;
  out += `:- end_tests(${d.name}).\n`;
  return out;
}

function codeToString(d) {
  if (d.operation === 'double') {
    return `${d.name}([], []).\n` +
           `${d.name}([X|Xs], [Y|Ys]) :-\n` +
           `    Y is X * 2,\n` +
           `    ${d.name}(Xs, Ys).\n`;
  }
  return `% Code generation pending (Stage 4)\n${d.name}(_, not_yet_implemented).\n`;
}

function starlogToString(d) {
  if (d.operation === 'double') {
    return `${d.name}(Input, Output) :-\n    Output is Input >> map(double).\n`;
  }
  return `% Starlog emission pending (Stage 6)\n`;
}

/* ---- Wire up UI ---- */
document.addEventListener('DOMContentLoaded', () => {
  const btn      = document.getElementById('btn-parse');
  const specTA   = document.getElementById('sentence-spec');
  const outDict  = document.getElementById('output-dict');
  const outTests = document.getElementById('output-tests');
  const outProlog = document.getElementById('output-prolog');
  const outStar  = document.getElementById('output-starlog');
  const outOpt   = document.getElementById('output-optimised');
  const outRes   = document.getElementById('output-results');
  const outFail  = document.getElementById('output-failure');
  const outMerge = document.getElementById('output-merge');

  const chatInput = document.getElementById('chatbot-input');
  const btnChat   = document.getElementById('btn-chat');
  const outChat   = document.getElementById('output-chat');

  btn.addEventListener('click', () => {
    const sentence = specTA.value.trim();
    if (!sentence) return;

    const spec = parseSpecBrowser(sentence);

    outDict.textContent   = dictToString(spec);
    outTests.textContent  = testsToString(spec);
    outProlog.textContent = codeToString(spec);
    outStar.textContent   = starlogToString(spec);
    outOpt.textContent    = '% Optimisation pending (Stage 8)\n' + codeToString(spec);
    outRes.textContent    = '% Run: swipl -g "run_tests" generated_tests.pl';
    outFail.textContent   = '(no failures)';
    outMerge.textContent  = '(no merge suggestions)';
  });

  btnChat.addEventListener('click', () => {
    const text = chatInput.value.trim();
    if (!text) return;
    const intent = classifyIntent(text);
    outChat.textContent = `Intent: ${intent}\n(Full chatbot routing pending – Stage 12)`;
  });
});
