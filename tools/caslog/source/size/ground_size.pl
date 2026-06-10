%
%  ground_size.pl		Nai-Wei Lin			December, 1991
%
%  This file contains the procedures for determining the size of a ground
%  term.
%

%
%  Determine the size of a ground term.
%
ground_term_size(void,_,0).
ground_term_size(int,Term,Size) :-
	ground_int(Term,Size).
ground_term_size(length,Term,Size) :-
	ground_length(Term,Size).
ground_term_size(size,Term,Size) :-
	ground_size(Term,Size).
ground_term_size(depth(ChildList),Term,Size) :-
	ground_depth(ChildList,Term,Size).

%
%  Determine the size of a ground term under measure int.
%
ground_int(Int,bot) :-
	noninteger(Int).
ground_int(Int,Int) :-
	integer(Int).

%
%  Determine the size of a ground term under measure length.
%
/*
ground_length(Term,bot) :-
	nonlist_cas(Term).
ground_length([],0).
ground_length([_|T],Size) :-
	ground_term_size(length,T,Size1),
	add(Size1,1,Size).
*/

ground_length(Term,Size) :-
  (nonlist_cas(Term) -> Size=bot;
   (Term == [] -> Size =0;
    (Term = [_|T],
     ground_term_size(length,T,Size1),
     add(Size1,1,Size)
    )
   )
  ).
%
%  Determine the size of a ground term under measure size.
%
ground_size(Term,bot) :-
	var(Term).
ground_size(Term,1) :-
	atomic(Term).
ground_size(Term,Size) :-
	compound_cas(Term),
	functor(Term,_,N),
	ground_size(N,Term,Size1),
	add(Size1,1,Size).

ground_size(0,_,0).
ground_size(N,Term,Size) :-
	N > 0,
	arg(N,Term,Arg),
	ground_size(Arg,Size1),
	N1 is N-1,
	ground_size(N1,Term,Size2),
	add(Size1,Size2,Size).

%
%  Determine the size of a ground term under measure depth.
%
ground_depth(_,Term,bot) :-
	var(Term).
ground_depth(_,Term,0) :-
	atomic(Term).
ground_depth(ChildList,Term,Size) :-
	compound_cas(Term),
	functor(Term,_,N),
	ground_depth(ChildList,N,Term,Size1),
	add(Size1,1,Size).

ground_depth(_,0,_,bot).
ground_depth(ChildList,N,Term,Size) :-
	N > 0,
	(member_cas(ChildList,N) ->
		(arg(N,Term,Arg),
		 ground_depth(ChildList,Arg,Size1));
		Size1 = bot),
	N1 is N-1,
	ground_depth(ChildList,N1,Term,Size2),
	maximum(Size1,Size2,Size).

