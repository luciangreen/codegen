:- module(chatbot_adapter, [
    chat_command/3,
    classify_intent/2
]).

%% chat_command(+Text:atom, -Intent:atom, -Data:term) is semidet.
%  Routes a natural-language command to the appropriate intent and
%  extracts relevant dictionary data.
%  Full manual-neuronet implementation is Stage 12.
chat_command(Text, Intent, Data) :-
    atom_string(Text, Str),
    string_lower(Str, Lower),
    classify_intent(Lower, Intent),
    Data = Lower.

%% classify_intent(+Text:string, -Intent:atom) is det.
%  Classifies a lowercased command text into one of the known intents.
classify_intent(Text, generate_tests) :-
    (sub_string(Text, _, _, _, "test"); sub_string(Text, _, _, _, "tests")), !.
classify_intent(Text, generate_code) :-
    (sub_string(Text, _, _, _, "generate"); sub_string(Text, _, _, _, "predicate")), !.
classify_intent(Text, debug_failure) :-
    (sub_string(Text, _, _, _, "debug"); sub_string(Text, _, _, _, "fail"); sub_string(Text, _, _, _, "explain why")), !.
classify_intent(Text, optimise_code) :-
    (sub_string(Text, _, _, _, "optim"); sub_string(Text, _, _, _, "findall")), !.
classify_intent(Text, merge_predicates) :-
    sub_string(Text, _, _, _, "merge"), !.
classify_intent(Text, explain_code) :-
    sub_string(Text, _, _, _, "explain"), !.
classify_intent(Text, convert_starlog) :-
    (sub_string(Text, _, _, _, "starlog"); sub_string(Text, _, _, _, ">>"); sub_string(Text, _, _, _, "is ")), !.
classify_intent(Text, convert_loop) :-
    (sub_string(Text, _, _, _, "deterministic"); sub_string(Text, _, _, _, "loop")), !.
classify_intent(Text, find_invariant) :-
    sub_string(Text, _, _, _, "invariant"), !.
classify_intent(Text, repair_tests) :-
    sub_string(Text, _, _, _, "repair"), !.
classify_intent(_, generate_code).
