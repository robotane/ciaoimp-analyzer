:- mode(permSort/2,[+,-]).
:- mode(sorted/1,[+]).
:- measure(permSort/2,[length,length]).
:- measure(sorted/1,[length]).
:- mode(perm/2,[+,-]).
:- measure(perm/2,[length,length]).
:- mode(select/3,[-,+,-]).
:- measure(select/3,[size,length,length]).

perm([],[]).
perm([X|Xs],[R|Rs]) :- select(R,[X|Xs],Y), perm(Y,Rs).


select(X,[X|Xs],Xs).
select(X,[Y|Ys],[Y|Zs]) :- select(X,Ys,Zs).

permSort(Xs,Ys):-perm(Xs,Ys),sorted(Ys).
sorted([ ]).
sorted([X]).
sorted([X,Y|Zs]) :- X =< Y,sorted([Y|Zs]).
