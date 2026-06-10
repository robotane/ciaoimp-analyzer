%
%  color.pl			Nai-Wei Lin			April 1992
%
%  This program performs map coloring.
%

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(color_map/5,[-,-,-,-,-]).
:- measure(color_map/5,[size,size,size,size,size]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
color_map(A,B,C,D,E) :-
	color(A), color(B), color(C), color(D), color(E).

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(legal_coloring/5,[+,+,+,+,+]).
:- measure(legal_coloring/5,[size,size,size,size,size]).
:- domain(legal_coloring/5,[[blue,green,orange,red,yellow],[blue,green,orange,red,yellow],[blue,green,orange,red,yellow],[blue,green,orange,red,yellow],[blue,green,orange,red,yellow]]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
legal_coloring(A,B,C,D,E) :-
	A =\= B,
	A =\= C,
	A =\= D,
	A =\= E,
	c(B,C,D),
	C =\= E.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(c/3,[+,+,+]).
:- measure(c/3,[size,size,size]).
:- domain(c/3,[[blue,green,orange,red,yellow],[blue,green,orange,red,yellow],[blue,green,orange,red,yellow]]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
c(X,Y,Z) :-
	X =\= Y,
	X =\= Z.

%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
:- mode(color/1,[-]).
:- measure(color/1,[size]).
%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%%
color(blue).
color(green).
color(orange).
color(red).
color(yellow).
