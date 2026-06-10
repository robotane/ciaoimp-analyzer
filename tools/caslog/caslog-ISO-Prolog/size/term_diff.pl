%
%  term_diff.pl			Nai-Wei Lin			November, 1991
%
%  This file contains the procedures for performing the diff functions.
%

%
%  Compute the size difference between a term and its predecessors.
%
general_term_diff(_,_,_,_,[],_,bot).
general_term_diff(BT,ST,Measure,Clause,[Pos|PList],Term,Size) :-
	clause_term_measure(BT,ST,Clause,Pos,PosTerm,PosMeasure),
 % write('\nPosmeasure='),write(PosMeasure),write('\nPos='),write(Pos),
 % write('\nPosTerm='),write(PosTerm),write('\nTerm='),write(Term),
	term_diff(PosMeasure,Measure,Pos,PosTerm,Term,Size1),
	general_term_diff(BT,ST,Measure,Clause,PList,Term,Size2),
	minimum(Size1,Size2,Size).

%
%  Compute the size difference between two terms.
%
term_diff(M1,M2,_,_,_,bot) :-
	M1 \== (?),
	M2 \== (?),
	M1 \== M2.
term_diff((?),(?),_,_,_,bot).
term_diff((?),M2,Pos,Term1,Term2,Size) :-
	M2 \== (?),
	term_diff(M2,Pos,Term1,Term2,Size).
term_diff(M1,(?),Pos,Term1,Term2,Size) :-
	M1 \== (?),
	term_diff(M1,Pos,Term1,Term2,Size).
term_diff(M1,M2,Pos,Term1,Term2,Size) :-
	M1 == M2,
	M1 \== (?),
	term_diff(M1,Pos,Term1,Term2,Size).

term_diff(int,Pos,Term1,Term2,Size) :-
	term_diff_int(Term1,Term2,Size1),
	addition(Pos,Size1,Size).
term_diff(length,Pos,Term1,Term2,Size) :-
	term_diff_length(Term1,Term2,Size1),
	addition(Pos,Size1,Size).
term_diff(depth(ChildList),Pos,Term1,Term2,Size) :-
	term_diff_depth(ChildList,Term1,Term2,Size1),
	addition(Pos,Size1,Size).
term_diff(size,Pos,Term1,Term2,Size) :-
	term_diff_size(Pos,Term1,Term2,Size).

%
%  Compute the size difference between two terms under the measure int.
%

term_diff_int(Term1,Term2,0) :-
	Term1 == Term2.
term_diff_int(Term1,Term2,bot) :-
	Term1 \== Term2.

/*
term_diff_int(Term1,Term2,S) :-
  (Term1 == Term2 -> S=0;
   (Term1 \== Term2 -> S=bot)).
*/

%
%  Compute the size difference between two terms under the measure length.
%

term_diff_length(Term1,Term2,0) :-
	Term1 == Term2.
term_diff_length(Term1,Term2,bot) :-
	Term1 \== Term2,
	noncompound_cas(Term1).
term_diff_length(Term1,Term2,Size) :-
	Term1 \== Term2,
	Term1 = [_|TList],
	term_diff_length(TList,Term2,Size1),
	sub(Size1,1,Size).
/*

term_diff_length(Term1,Term2,Size) :-
	(Term1 == Term2 -> Size=0;
	 (Term1 \== Term2 ->
	  (noncompound_cas(Term1) -> Size=bot;
	   (Term1 = [_|TList],
	    term_diff_length(TList,Term2,Size1),
	    sub(Size1,1,Size)
	   )
	  )
	 )
	).
*/
%
%  Compute the size difference between two terms under the measure depth.
%

term_diff_depth(_,Term1,Term2,0) :-
	Term1 == Term2.
term_diff_depth(_,Term1,Term2,bot) :-
	Term1 \== Term2,
	noncompound_cas(Term1).
term_diff_depth(ChildList,Term1,Term2,Size) :-
	Term1 \== Term2,
	compound_cas(Term1),
	functor(Term1,_,N),
	term_diff_depth(N,ChildList,Term1,Term2,Size1),
	sub(Size1,1,Size).


/*
term_diff_depth(ChildList,Term1,Term2,Size) :-
	(Term1 == Term2 -> Size=0;
	    (Term1 \== Term2 ->
		(noncompound_cas(Term1) -> Size=bot;
		    (compound_cas(Term1) -> 
			(
			    functor(Term1,_,N),
			    term_diff_depth(N,ChildList,Term1,Term2,Size1),
			    sub(Size1,1,Size)
			)
		    )
		)
	    )
	).
	*/	

term_diff_depth(0,_,_,_,bot).
term_diff_depth(N,ChildList,Term1,Term2,Size) :-
	N > 0,
	N1 is N-1,
	(member_cas(ChildList,N) ->
		(arg(N,Term1,Arg),
		 term_diff_depth(ChildList,Arg,Term2,SizeN),
		 term_diff_depth(N1,ChildList,Term1,Term2,SizeN1),
		 minimum(SizeN,SizeN1,Size));
		 term_diff_depth(N1,ChildList,Term1,Term2,Size)).

%
%  Compute the size difference between two terms under the measure size.
%

term_diff_size(Pos,Term1,Term2,Pos) :-
	Term1 == Term2.
term_diff_size(Pos,[Head|_],Term,head(Pos)) :-
	Head == Term.
term_diff_size(Pos,[_|Tail],Term,tail(Pos)) :-
	Tail == Term.
term_diff_size(_,Term1,Term2,bot) :-
	Term1 \== Term2,
	noncompound_cas(Term1).
term_diff_size(Pos,Term1,Term2,Size) :-
	Term1 \== Term2,
	compound_cas(Term1),
	functor(Term1,_,N),
	term_diff_size(N,Pos,Term1,Term2,Size).
/*
term_diff_size(Pos,Term1,Term2,Size) :-
(Term1 == Term2 -> Size=bot;
 (Term1 \== Term2 ->
  (Term1=[Head|Tail],
   (Head == Term2 -> Size=head(Pos);
    (Tail == Term2 -> Size=tail(Pos))
   )
  ),
  (noncompound_cas(Term1) -> Size=bot;
   (compound_cas(Term1) -> 
    (functor(Term1,_,N),
     term_diff_size(N,Pos,Term1,Term2,Size))
    )
   )
  )
).


*/


term_diff_size(0,_,_,_,bot).
term_diff_size(N,Pos,Term1,Term2,Size) :-
	N > 0,
	N1 is N-1,
	arg(N,Term1,Arg),
	(Arg == Term2 ->
		Size = arg(Pos,N);
		term_diff_size(N1,Pos,Term1,Term2,Size)).
