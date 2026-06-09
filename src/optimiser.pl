:- module(optimiser, [
    optimise/2
]).

%% optimise(+Code:term, -Optimised:term) is det.
%  Placeholder: PLOP-style optimiser.
%  Applies memoisation, indexical optimisation, subterm-with-address,
%  subterm-index looping, and Gaussian-style reconstruction.
%  Full implementation is Stage 8.
optimise(Code, Code).
