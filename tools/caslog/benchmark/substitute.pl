:- mode(substitute/3,[+,+,-]).
:- measure(substitute/3,[size,length,size]).
substitute(A+B,Subs,NewA+NewB) :-
    !,
    substitute(A,Subs,NewA),
    substitute(B,Subs,NewB).
substitute(A*B,Subs,NewA*NewB) :-
    !,
    substitute(A,Subs,NewA),
    substitute(B,Subs,NewB).
substitute(A-B,Subs,NewA-NewB) :-
    !,
    substitute(A,Subs,NewA),
    substitute(B,Subs,NewB).
substitute(A=B,Subs,NewA=NewB) :-
    !,
    substitute(A,Subs,NewA),
    substitute(B,Subs,NewB).
substitute(exp(A,B),Subs,exp(NewA,B)) :-
    integer(B),
    !,
    substitute(A,Subs,NewA).
substitute(A,Subs,B) :-
    member2(A=B,Subs),
    !.
substitute(A,_,A).

:- mode(member2/2,[-,+]).
:- measure(member2/2,[void,length]).
member2(X,[X|_]).
member2(X,[_|Ys]) :- member2(X,Ys).
