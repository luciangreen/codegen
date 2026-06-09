:- module(sentence_specs, [sentence_spec/2]).

% Edge case 1 & 2: canonical map spec with both input and output types inferred
sentence_spec(double_all,
    'Generate a predicate double_all(Input, Output) that maps every number in Input to twice its value. Examples: [1,2,3] -> [2,4,6].').

% Edge case 3: multiple outputs
sentence_spec(split_list,
    'Generate a predicate split_list(Input, Left, Right) that maps every number in Input to twice its value.').

% Edge case 4: nested structures
sentence_spec(flatten_rows,
    'Generate a predicate flatten_rows(Input, Output) that maps list of lists of numbers in Input.').

% Edge case 5: strings
sentence_spec(upcase_all,
    'Generate a predicate upcase_all(Input, Output) that maps a list of strings to their uppercased versions.').

% Edge case 6: ambiguous verb
sentence_spec(tweak,
    'Generate a predicate tweak(Input, Output) that can change every number in Input.').

% Edge case 7: tests only
sentence_spec(check_mapping,
    'Create a test that checks [1,2] -> [2,4].').

% Edge case 9: contradictory examples
sentence_spec(bad_map,
    'Generate a predicate bad_map(Input, Output) that maps every number in Input to twice its value. Examples: [1] -> [2]; [1] -> [3].').

% Edge case 10: more than 14 items
sentence_spec(long_map,
    'Generate a predicate long_map(Input, Output) that maps every number in Input to twice its value. Examples: [1,2,3,4,5,6,7,8,9,10,11,12,13,14,15] -> [2,4,6,8,10,12,14,16,18,20,22,24,26,28,30].').

% Edge case 11: recursion
sentence_spec(rebuild,
    'Generate a predicate rebuild(Input, Output) that maps every number in Input to twice its value and requires recursion.').

% Edge case 12: generator search
sentence_spec(find_primes,
    'Generate a predicate find_primes(Input, Output) that uses generator search to find primes.').

% Edge case 13: predicate merging
sentence_spec(normalize_and_count,
    'Generate a predicate normalize_and_count(Input, Output) that maps every number in Input using merge candidates.').

% Edge case 14: change previous tests
sentence_spec(updated_transform,
    'Generate a predicate updated_transform(Input, Output) that maps every number in Input to twice its value and must change previous tests.').
