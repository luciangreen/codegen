:- module(chatbot_adapter, [
    chat_command/3,
    classify_intent/2,
    parse_sentence/2,
    extract_dictionary_data/2,
    route_command/3,
    chat_intent/1
]).

:- use_module(library(lists)).

%% =========================================================
%% Stage 12: Manual Chatbot Adapter
%%
%% Manual-neuronet chatbot layer that routes natural-language
%% commands to codegen operations WITHOUT calling an LLM.
%%
%% Architecture:
%%
%%   chat_command(Text, Intent, Data)
%%     ├── parse_sentence(Text, Tokens)
%%     ├── classify_intent(Tokens, Intent)
%%     └── extract_dictionary_data(Tokens, Data)
%%
%% All classification is done via manual pattern rules.
%% =========================================================

%% =========================================================
%% Supported intents
%% =========================================================

chat_intent(generate_code).
chat_intent(generate_tests).
chat_intent(debug_failure).
chat_intent(optimise_code).
chat_intent(merge_predicates).
chat_intent(explain_code).
chat_intent(convert_starlog).
chat_intent(convert_loop).
chat_intent(find_invariant).
chat_intent(repair_tests).

%% =========================================================
%% chat_command/3 — main entry point
%%
%% chat_command(+Text, -Intent, -Data)
%% =========================================================

chat_command(Text, Intent, Data) :-
    parse_sentence(Text, Tokens),
    classify_intent(Tokens, Intent),
    extract_dictionary_data(Tokens, Data).

%% =========================================================
%% parse_sentence/2 — text → token list
%%
%% parse_sentence(+Text, -Tokens)
%%
%% Tokens is a list of lowercased atoms representing words.
%% =========================================================

parse_sentence(Text, Tokens) :-
    (atom(Text) -> atom_string(Text, Str) ; Str = Text),
    string_lower(Str, Lower),
    split_string(Lower, " \t\n.,;?!", " \t\n", RawTokens),
    exclude(empty_token, RawTokens, StringTokens),
    maplist(atom_string, Tokens, StringTokens).

empty_token("").

%% =========================================================
%% classify_intent/2 — tokens → intent atom
%%
%% classify_intent(+Tokens, -Intent)
%%
%% Uses manual keyword rules (neuronet-style) to classify.
%% =========================================================

%% generate_code: mentions generate/create + predicate/code
classify_intent(Tokens, generate_code) :-
    (member(generate, Tokens) ; member(create, Tokens) ; member(write, Tokens)),
    (member(predicate, Tokens) ; member(code, Tokens) ; member(examples, Tokens)),
    !.

%% generate_tests: mentions generate/create + test/tests
classify_intent(Tokens, generate_tests) :-
    (member(generate, Tokens) ; member(create, Tokens) ; member(add, Tokens)),
    (member(test, Tokens) ; member(tests, Tokens)),
    !.

%% debug_failure: mentions fail/error/why + fail/failure
classify_intent(Tokens, debug_failure) :-
    (member(why, Tokens) ; member(debug, Tokens) ; member(diagnose, Tokens)),
    (member(failed, Tokens) ; member(fail, Tokens) ; member(error, Tokens) ; member(failure, Tokens)),
    !.

%% debug_failure: "explain why this test failed"
classify_intent(Tokens, debug_failure) :-
    member(explain, Tokens),
    (member(failed, Tokens) ; member(fail, Tokens)),
    !.

%% optimise_code: mentions optimise/optimize/speed
classify_intent(Tokens, optimise_code) :-
    (member(optimise, Tokens) ; member(optimize, Tokens)
    ; member(optimisation, Tokens) ; member(optimization, Tokens)
    ; (member(speed, Tokens), member(up, Tokens))
    ; member(cache, Tokens) ; member(memoize, Tokens) ; member(memoise, Tokens)),
    !.

%% merge_predicates: mentions merge/combine + predicate/predicates
classify_intent(Tokens, merge_predicates) :-
    (member(merge, Tokens) ; member(combine, Tokens)),
    (member(predicate, Tokens) ; member(predicates, Tokens)),
    !.

%% explain_code: explain without fail — code explanation
classify_intent(Tokens, explain_code) :-
    member(explain, Tokens),
    \+ (member(failed, Tokens) ; member(fail, Tokens)),
    !.

%% explain_code: show/describe + predicate/code
classify_intent(Tokens, explain_code) :-
    (member(show, Tokens) ; member(describe, Tokens)),
    (member(predicate, Tokens) ; member(code, Tokens)),
    !.

%% convert_starlog: mentions starlog or "convert to starlog"
classify_intent(Tokens, convert_starlog) :-
    (member(starlog, Tokens) ; member(emit, Tokens)),
    !.

%% convert_loop: mentions deterministic/loop/findall
classify_intent(Tokens, convert_loop) :-
    (member(deterministic, Tokens) ; member(loop, Tokens)
    ; member(findall, Tokens) ; member(loop2, Tokens)),
    !.

%% find_invariant: mentions invariant
classify_intent(Tokens, find_invariant) :-
    (member(invariant, Tokens) ; member(invariants, Tokens)),
    !.

%% repair_tests: mentions repair/fix + test/tests
classify_intent(Tokens, repair_tests) :-
    (member(repair, Tokens) ; member(fix, Tokens) ; member(update, Tokens)),
    (member(test, Tokens) ; member(tests, Tokens)),
    !.

%% Fallback
classify_intent(_, generate_code).

%% =========================================================
%% extract_dictionary_data/2 — tokens → data dict
%%
%% extract_dictionary_data(+Tokens, -Data)
%%
%% Extracts key terms from the token stream to populate
%% a lightweight data structure used by the router.
%% =========================================================

extract_dictionary_data(Tokens, Data) :-
    extract_predicate_name(Tokens, PredName),
    extract_operation(Tokens, Operation),
    extract_relation(Tokens, Relation),
    Data = _{
        predicate: PredName,
        operation: Operation,
        relation:  Relation,
        tokens:    Tokens
    }.

extract_predicate_name(Tokens, Name) :-
    (   next_token_after(predicate, Tokens, Name)
    ->  true
    ;   next_token_after(for, Tokens, Name)
    ->  true
    ;   Name = unknown
    ).

extract_operation(Tokens, double)    :- member(double, Tokens), !.
extract_operation(Tokens, triple)    :- member(triple, Tokens), !.
extract_operation(Tokens, double)    :- member(twice, Tokens), !.
extract_operation(Tokens, filter)    :- member(filter, Tokens), !.
extract_operation(Tokens, increment) :- member(increment, Tokens), !.
extract_operation(Tokens, decrement) :- member(decrement, Tokens), !.
extract_operation(Tokens, merge)     :- member(merge, Tokens), !.
extract_operation(Tokens, double)    :-
    member(T, Tokens), atom_concat(double, _, T), !.
extract_operation(Tokens, triple)    :-
    member(T, Tokens), atom_concat(triple, _, T), !.
extract_operation(_,       unknown).

extract_relation(Tokens, map)    :- member(map, Tokens), !.
extract_relation(Tokens, filter) :- member(filter, Tokens), !.
extract_relation(Tokens, fold)   :- member(fold, Tokens), !.
extract_relation(_, transform).

next_token_after(_, [], unknown).
next_token_after(Target, [Target, Next | _], Next) :- !.
next_token_after(Target, [_ | Rest], Name) :-
    next_token_after(Target, Rest, Name).

%% =========================================================
%% route_command/3 — intent + data → response
%%
%% route_command(+Intent, +Data, -Response)
%%
%% Returns a structured response for the chatbot to display.
%% =========================================================

route_command(generate_code, Data, response(generate_code, Data, Msg)) :-
    format(string(Msg),
        "Generating predicate '~w' with relation '~w' and operation '~w'.",
        [Data.predicate, Data.relation, Data.operation]).

route_command(generate_tests, Data, response(generate_tests, Data, Msg)) :-
    format(string(Msg),
        "Generating tests for predicate '~w'.",
        [Data.predicate]).

route_command(debug_failure, Data, response(debug_failure, Data, Msg)) :-
    format(string(Msg),
        "Diagnosing failure for predicate '~w'. Check recursion base case and operation.",
        [Data.predicate]).

route_command(optimise_code, Data, response(optimise_code, Data, Msg)) :-
    format(string(Msg),
        "Applying PLOP optimisation (memoisation, indexing) to '~w'.",
        [Data.predicate]).

route_command(merge_predicates, Data, response(merge_predicates, Data, Msg)) :-
    format(string(Msg),
        "Detecting merge candidates. Tokens: ~w.",
        [Data.tokens]).

route_command(explain_code, Data, response(explain_code, Data, Msg)) :-
    format(string(Msg),
        "Explaining predicate '~w': relation=~w, operation=~w.",
        [Data.predicate, Data.relation, Data.operation]).

route_command(convert_starlog, Data, response(convert_starlog, Data,
    "Emitting Starlog-readable form for current spec.")).

route_command(convert_loop, Data, response(convert_loop, Data,
    "Converting findall/3 patterns to deterministic Loop2 form.")).

route_command(find_invariant, Data, response(find_invariant, Data,
    "Extracting shared invariants from clause bodies.")).

route_command(repair_tests, Data, response(repair_tests, Data,
    "Repairing test suite to match updated spec.")).

route_command(_, Data, response(unknown, Data, "Command not recognised.")).
