:- module(drv, [clean_print/1], []).
:- use_module(library(compiler/p_unit), [pr_key_get/2]).
:- use_module(library(compiler/p_unit/p_unit_db), [curr_file/2, source_clause/3]).
:- use_module(library(compiler/p_unit/p_printer), [with_mod_syntax/1]).
:- use_module(library(compiler/p_unit/unexpand), [transform_clause_list/3]).
:- use_module(library(pretty_print), [pretty_print/4]).

:- meta_predicate with_mod_syntax(goal).
clean_print(S) :- with_mod_syntax(clean_print_(S)).
clean_print_(S) :-
    ( curr_file(_,M),
      pr_key_get(M, K),
      source_clause(_, clause(K,B), Dic),
      rm(B, B1),
      transform_clause_list([clause(K,B1)], M, Cls),
      pretty_print(S, Cls, [], [Dic]),
      fail
    ; true ).
rm(B,B) :- var(B), !.
rm((A,Bs),(A1,B1)) :- !, rm(A,A1), rm(Bs,B1).
rm((A;Bs),(A1;B1)) :- !, rm(A,A1), rm(Bs,B1).
rm((A->Bs),(A1->B1)) :- !, rm(A,A1), rm(Bs,B1).
rm(L:_, L) :- !.
rm(L,L).
