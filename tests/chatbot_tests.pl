:- begin_tests(stage12_chatbot).

:- use_module('../src/chatbot_adapter').

%% -------------------------------------------------------
%% All 10 intents declared
%% -------------------------------------------------------

test(all_intents_declared) :-
    findall(I, chat_intent(I), Intents),
    length(Intents, N),
    assertion(N =:= 10),
    assertion(member(generate_code,    Intents)),
    assertion(member(generate_tests,   Intents)),
    assertion(member(debug_failure,    Intents)),
    assertion(member(optimise_code,    Intents)),
    assertion(member(merge_predicates, Intents)),
    assertion(member(explain_code,     Intents)),
    assertion(member(convert_starlog,  Intents)),
    assertion(member(convert_loop,     Intents)),
    assertion(member(find_invariant,   Intents)),
    assertion(member(repair_tests,     Intents)).

%% -------------------------------------------------------
%% parse_sentence/2
%% -------------------------------------------------------

test(parse_sentence_produces_atoms) :-
    parse_sentence("Generate a predicate from these examples.", Tokens),
    assertion(is_list(Tokens)),
    assertion(member(generate, Tokens)),
    assertion(member(predicate, Tokens)).

test(parse_sentence_lowercases) :-
    parse_sentence("Explain Why This FAILED", Tokens),
    assertion(member(explain, Tokens)),
    assertion(member(why, Tokens)),
    assertion(member(failed, Tokens)).

test(parse_sentence_strips_punctuation) :-
    parse_sentence("Merge these predicates!", Tokens),
    assertion(member(merge, Tokens)),
    assertion(member(predicates, Tokens)).

%% -------------------------------------------------------
%% classify_intent/2
%% -------------------------------------------------------

test(classify_generate_code) :-
    parse_sentence("Generate a predicate from these examples.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == generate_code).

test(classify_generate_tests) :-
    parse_sentence("Create tests for double_all.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == generate_tests).

test(classify_debug_failure) :-
    parse_sentence("Why did this test fail?", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == debug_failure).

test(classify_optimise_code) :-
    parse_sentence("Optimise this findall.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == optimise_code).

test(classify_merge_predicates) :-
    parse_sentence("Merge these predicates.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == merge_predicates).

test(classify_explain_code) :-
    parse_sentence("Explain the predicate double_all.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == explain_code).

test(classify_convert_starlog) :-
    parse_sentence("Convert this Starlog to Prolog.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == convert_starlog).

test(classify_convert_loop) :-
    parse_sentence("Make this code deterministic using loop.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == convert_loop).

test(classify_find_invariant) :-
    parse_sentence("Show the invariant.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == find_invariant).

test(classify_repair_tests) :-
    parse_sentence("Repair the recursive case tests.", Tokens),
    classify_intent(Tokens, Intent),
    assertion(Intent == repair_tests).

%% -------------------------------------------------------
%% chat_command/3 — full pipeline
%% -------------------------------------------------------

test(chat_command_returns_intent_and_data) :-
    chat_command("Generate a predicate double_all from these examples.", Intent, Data),
    assertion(Intent == generate_code),
    assertion(is_dict(Data)),
    assertion(Data.operation == double).

test(chat_command_debug_gives_debug_intent) :-
    chat_command("Why did the test fail?", Intent, _Data),
    assertion(Intent == debug_failure).

test(chat_command_data_has_tokens) :-
    chat_command("Optimise this code.", _Intent, Data),
    assertion(is_list(Data.tokens)).

%% -------------------------------------------------------
%% route_command/3
%% -------------------------------------------------------

test(route_generate_code_produces_message) :-
    Data = _{predicate: double_all, relation: map, operation: double, tokens: []},
    route_command(generate_code, Data, response(generate_code, _, Msg)),
    string(Msg),
    sub_string(Msg, _, _, _, "double_all").

test(route_debug_failure_mentions_recursion) :-
    Data = _{predicate: p, relation: transform, operation: unknown, tokens: []},
    route_command(debug_failure, Data, response(debug_failure, _, Msg)),
    sub_string(Msg, _, _, _, "recursion").

test(route_convert_starlog_message) :-
    Data = _{predicate: unknown, relation: transform, operation: unknown, tokens: []},
    route_command(convert_starlog, Data, response(convert_starlog, _, Msg)),
    sub_string(Msg, _, _, _, "Starlog").

test(route_unknown_falls_back) :-
    Data = _{predicate: unknown, relation: transform, operation: unknown, tokens: []},
    route_command(unknown_intent_xyz, Data, response(unknown, _, _)).

%% -------------------------------------------------------
%% extract_dictionary_data/2
%% -------------------------------------------------------

test(extract_operation_double) :-
    parse_sentence("double every number", Tokens),
    extract_dictionary_data(Tokens, Data),
    assertion(Data.operation == double).

test(extract_relation_map) :-
    parse_sentence("map every element", Tokens),
    extract_dictionary_data(Tokens, Data),
    assertion(Data.relation == map).

:- end_tests(stage12_chatbot).
