:- mode(add_polynomials/3,[+,+,-]).
:- measure(add_polynomials/3,[length,length,length]).
add_polynomials([],Poly,Poly) :- !.
add_polynomials(Poly,[],Poly) :- !.
add_polynomials([(Ai,Ni)|Poly1],[(Aj,Nj)|Poly2],[(Ai,Ni)|Poly]) :-
    Ni > Nj, !,
    add_polynomials(Poly1,[(Aj,Nj)|Poly2],Poly).
add_polynomials([(Ai,Ni)|Poly1],[(Aj,Nj)|Poly2],[(A,Ni)|Poly]) :-
    Ni =:= Nj, !,
    A is Ai + Aj,
    add_polynomials(Poly1,Poly2,Poly).
add_polynomials([(Ai,Ni)|Poly1],[(Aj,Nj)|Poly2],[(Aj,Nj)|Poly]) :-
    Ni < Nj, !,
    add_polynomials([(Ai,Ni)|Poly1],Poly2,Poly).
