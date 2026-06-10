:- mode(substitute/3,[+,+,-]).
:- measure(substitute/3,[size,length,size]).
substitute(exp(A,B),Subs,exp(NewA,B)) :-
    integer(B),
    !,
    substitute(A,Subs,NewA).
