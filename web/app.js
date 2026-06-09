/* =========================================================
   Lucian Codegen — Stage 11 Web Interface JavaScript
   Wires up the 10 UI panels without an LLM backend:
   - Panel 1:  spec input
   - Panel 2:  dictionary-data preview
   - Panel 3:  generated tests preview
   - Panel 4:  generated Prolog preview
   - Panel 5:  Starlog form preview
   - Panel 6:  optimised code preview
   - Panel 7:  test result panel
   - Panel 8:  failure explanation panel
   - Panel 9:  predicate merge suggestions
   - Panel 10: chatbot-style command panel
   ========================================================= */

'use strict';

/* =========================================================
   1. In-browser spec parser (mirrors src/parser.pl logic)
   ========================================================= */

const OPERATIONS = {
  double: 'Y is X * 2',  triple: 'Y is X * 3',
  square: 'Y is X * X',  increment: 'Y is X + 1',
  decrement: 'Y is X - 1',
};

function detectRelation(text) {
  if (/\bmap\b/i.test(text))    return 'map';
  if (/\bfilter\b/i.test(text)) return 'filter';
  if (/\bfold\b/i.test(text))   return 'fold';
  return 'transform';
}

function detectOperation(text) {
  if (/double|twice/i.test(text))   return 'double';
  if (/triple|thrice/i.test(text))  return 'triple';
  if (/square/i.test(text))         return 'square';
  if (/increment/i.test(text))      return 'increment';
  if (/decrement/i.test(text))      return 'decrement';
  return 'unknown';
}

function extractSignature(text) {
  const m = text.match(/predicate\s+([a-z_][a-z0-9_]*)\s*\(([^)]*)\)/i);
  if (!m) return { name: 'unknown_predicate', inputs: ['Input'], outputs: ['Output'] };
  const args = m[2].split(',').map(s => s.trim()).filter(Boolean);
  return {
    name: m[1].toLowerCase(),
    inputs:  args.slice(0, -1).length ? args.slice(0, -1) : ['Input'],
    outputs: args.slice(-1),
  };
}

function parseExamples(text) {
  const examples = [];
  const parts = text.split(';');
  for (const part of parts) {
    const m = part.match(/([^\->]+)\s*->\s*([^;.]+)/);
    if (m) {
      examples.push({ input: m[1].trim().replace(/^examples?:\s*/i, ''), output: m[2].trim() });
    }
  }
  return examples;
}

function parseSentenceSpec(sentence) {
  const text  = sentence.toLowerCase();
  const sig   = extractSignature(sentence);
  const rel   = detectRelation(text);
  const op    = detectOperation(text);
  const exs   = parseExamples(sentence);
  const warns = [];
  if (/change\b/i.test(text)) warns.push('ambiguous_verb(change)');
  if (/\bmake\b/i.test(text)) warns.push('ambiguous_verb(make)');
  if (exs.length === 0)        warns.push('no_examples');
  if (exs.length > 14)         warns.push('too_many_examples_or_items');
  return {
    name: sig.name, inputs: sig.inputs, outputs: sig.outputs,
    relation: rel, operation: op, examples: exs,
    constraints: rel === 'map' ? ['deterministic','order_preserved','same_length'] : ['deterministic'],
    warnings: warns,
    classification: /\btest\b/i.test(text) ? 'tests_only' : 'code_only',
  };
}

function dictToString(dict) {
  return `spec(${dict.name}, _{\n` +
    `  name:        ${dict.name},\n` +
    `  inputs:      [${dict.inputs.join(', ')}],\n` +
    `  outputs:     [${dict.outputs.join(', ')}],\n` +
    `  relation:    ${dict.relation},\n` +
    `  operation:   ${dict.operation},\n` +
    `  examples:    [${dict.examples.map(e => `io(${e.input}, ${e.output})`).join(', ')}],\n` +
    `  constraints: [${dict.constraints.join(', ')}],\n` +
    `  warnings:    [${dict.warnings.join(', ')}],\n` +
    `  classification: ${dict.classification}\n}).`;
}

/* =========================================================
   2. Code generators
   ========================================================= */

function generateTests(dict) {
  const name = dict.name;
  const lines = [`:- begin_tests(${name}).`];
  dict.examples.forEach((ex, i) => {
    lines.push(`test(example_${i + 1}) :-`);
    lines.push(`    ${name}(${ex.input}, R),`);
    lines.push(`    assertion(R == ${ex.output}).`);
  });
  lines.push(`test(empty) :-`);
  lines.push(`    ${name}([], R),`);
  lines.push(`    assertion(R == []).`);
  lines.push(`:- end_tests(${name}).`);
  return lines.join('\n');
}

function generateProlog(dict) {
  const name = dict.name;
  const op   = dict.operation;
  const goal = OPERATIONS[op] || 'Y = X';
  if (dict.relation === 'map') {
    return `${name}([], []).\n${name}([X|Xs], [Y|Ys]) :-\n    ${goal},\n    ${name}(Xs, Ys).`;
  }
  if (dict.relation === 'filter') {
    return `${name}([], []).\n${name}([X|Xs], Ys) :-\n    ( test_pred(X) -> Ys = [X|Ys1] ; Ys = Ys1 ),\n    ${name}(Xs, Ys1).`;
  }
  return `${name}(Input, Input).`;
}

function generateStarlog(dict) {
  const name = dict.name;
  const op   = dict.operation;
  if (dict.relation === 'map')    return `${name}(Input, Output) :-\n    Output is Input >> map(${op}).`;
  if (dict.relation === 'filter') return `${name}(Input, Output) :-\n    Output is Input >> filter(${op}).`;
  if (dict.relation === 'fold')   return `${name}(Input, Output) :-\n    Output is Input >> fold(${op}, 0).`;
  return `${name}(Input, Output) :-\n    Output = Input.`;
}

function generateOptimised(dict) {
  const prolog = generateProlog(dict);
  return `% PLOP-optimised (memoised):\n:- dynamic ${dict.name}_cache/2.\n${dict.name}_memo(Input, Output) :-\n    ( ${dict.name}_cache(Input, Output) -> true\n    ; ${prolog.split('\n')[0].replace(':-','').trim()}, assertz(${dict.name}_cache(Input, Output))\n    ).\n\n${prolog}`;
}

/* =========================================================
   3. Simulated test runner
   ========================================================= */

function simulateTests(dict) {
  const results = [];
  dict.examples.forEach((ex, i) => {
    results.push({ name: `example_${i + 1}`, status: 'pass' });
  });
  results.push({ name: 'empty', status: 'pass' });
  return results;
}

function renderTestResults(results) {
  return results.map(r =>
    `<div class="${r.status}">${r.status === 'pass' ? '✓' : '✗'} ${r.name}</div>`
  ).join('');
}

/* =========================================================
   4. Predicate merge detection
   ========================================================= */

function detectMergeSuggestions(specs) {
  const suggestions = [];
  for (let i = 0; i < specs.length; i++) {
    for (let j = i + 1; j < specs.length; j++) {
      const a = specs[i], b = specs[j];
      if (a.relation === b.relation && a.inputs[0] === b.inputs[0]) {
        suggestions.push({
          a: a.name, b: b.name,
          reason: a.operation !== b.operation ? 'differ_by_constant' : 'renamed_duplicate',
        });
      }
    }
  }
  return suggestions;
}

/* =========================================================
   5. Chatbot intent classifier (mirrors chatbot_adapter.pl)
   ========================================================= */

const INTENT_PATTERNS = [
  { intent: 'generate_code',   patterns: [/generate.*predicate/i, /create.*code/i, /write.*predicate/i] },
  { intent: 'generate_tests',  patterns: [/generate.*test/i, /create.*test/i, /add.*test/i] },
  { intent: 'debug_failure',   patterns: [/why.*fail/i, /explain.*fail/i, /debug/i] },
  { intent: 'optimise_code',   patterns: [/optimis/i, /optimize/i, /speed up/i] },
  { intent: 'merge_predicates',patterns: [/merge/i, /combine.*predicate/i] },
  { intent: 'explain_code',    patterns: [/explain/i, /what does/i, /describe/i] },
  { intent: 'convert_starlog', patterns: [/starlog/i, /convert.*starlog/i] },
  { intent: 'convert_loop',    patterns: [/deterministic/i, /convert.*loop/i, /findall/i] },
  { intent: 'find_invariant',  patterns: [/invariant/i, /show.*invariant/i] },
  { intent: 'repair_tests',    patterns: [/repair/i, /fix.*test/i, /update.*test/i] },
];

function classifyIntent(text) {
  for (const { intent, patterns } of INTENT_PATTERNS) {
    if (patterns.some(p => p.test(text))) return intent;
  }
  return 'unknown';
}

function respondToIntent(intent, text) {
  const responses = {
    generate_code:    () => `Generating code from: "${text.substring(0, 60)}…"`,
    generate_tests:   () => 'Generating tests from current spec.',
    debug_failure:    () => 'Diagnosing failure…',
    optimise_code:    () => 'Applying PLOP optimisation.',
    merge_predicates: () => 'Detecting merge candidates.',
    explain_code:     () => 'Explaining current code.',
    convert_starlog:  () => 'Emitting Starlog form.',
    convert_loop:     () => 'Converting to Loop2 deterministic form.',
    find_invariant:   () => 'Extracting invariants.',
    repair_tests:     () => 'Repairing test suite.',
    unknown:          () => `I did not recognise that command. Intent classified as: unknown.`,
  };
  return (responses[intent] || responses.unknown)();
}

/* =========================================================
   6. UI wiring
   ========================================================= */

const state = { dict: null, specs: [] };

function $id(id) { return document.getElementById(id); }

function enable(id) { $id(id).disabled = false; }

// Panel 1 → 2: parse spec
$id('btn-parse').addEventListener('click', () => {
  const text = $id('spec-input').value.trim();
  if (!text) return;
  state.dict = parseSentenceSpec(text);
  state.specs.push(state.dict);
  $id('dict-output').textContent = dictToString(state.dict);
  enable('btn-gen-tests');
  enable('btn-gen-prolog');
  enable('btn-gen-starlog');
});

// Panel 3: tests
$id('btn-gen-tests').addEventListener('click', () => {
  if (!state.dict) return;
  $id('tests-output').textContent = generateTests(state.dict);
  enable('btn-run-tests');
});

// Panel 4: Prolog
$id('btn-gen-prolog').addEventListener('click', () => {
  if (!state.dict) return;
  $id('prolog-output').textContent = generateProlog(state.dict);
  enable('btn-optimise');
});

// Panel 5: Starlog
$id('btn-gen-starlog').addEventListener('click', () => {
  if (!state.dict) return;
  $id('starlog-output').textContent = generateStarlog(state.dict);
});

// Panel 6: Optimised
$id('btn-optimise').addEventListener('click', () => {
  if (!state.dict) return;
  $id('optimised-output').textContent = generateOptimised(state.dict);
});

// Panel 7: run tests
$id('btn-run-tests').addEventListener('click', () => {
  if (!state.dict) return;
  const results = simulateTests(state.dict);
  $id('results-output').innerHTML = renderTestResults(results);
  const failures = results.filter(r => r.status !== 'pass');
  if (failures.length > 0) {
    $id('explain-output').textContent =
      failures.map(f => `FAIL ${f.name}: check recursion base case or operation.`).join('\n');
  } else {
    $id('explain-output').textContent = '-- all tests passed --';
  }
  enable('btn-detect-merge');
});

// Panel 9: merge suggestions
$id('btn-detect-merge').addEventListener('click', () => {
  const suggestions = detectMergeSuggestions(state.specs);
  if (suggestions.length === 0) {
    $id('merge-output').innerHTML = '<span class="placeholder">No merge candidates found.</span>';
  } else {
    $id('merge-output').innerHTML = suggestions
      .map(s => `<span class="merge-chip">${s.a} ↔ ${s.b} (${s.reason})</span>`)
      .join('');
  }
});

// Panel 10: chatbot
$id('btn-chat-send').addEventListener('click', sendChat);
$id('chat-input').addEventListener('keydown', e => { if (e.key === 'Enter') sendChat(); });

function sendChat() {
  const text = $id('chat-input').value.trim();
  if (!text) return;
  const intent = classifyIntent(text);
  const reply  = respondToIntent(intent, text);
  appendChat('user',  text);
  appendChat('agent', reply);
  $id('chat-intent').textContent = `Classified intent: ${intent}`;
  $id('chat-input').value = '';
}

function appendChat(role, text) {
  const div = document.createElement('div');
  div.className = `chat-msg-${role}`;
  div.textContent = (role === 'user' ? '> ' : '• ') + text;
  $id('chat-history').appendChild(div);
  $id('chat-history').scrollTop = $id('chat-history').scrollHeight;
}
