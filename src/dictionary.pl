:- module(dictionary, [
    sentence_spec_dict/2,
    sentences_to_dictionary/2
]).

:- use_module(parser).

sentence_spec_dict(Sentence, Spec) :-
    parser:sentence_to_spec(Sentence, Spec).

sentences_to_dictionary(Sentences, Specs) :-
    must_be(list, Sentences),
    maplist(sentence_spec_dict, Sentences, Specs).