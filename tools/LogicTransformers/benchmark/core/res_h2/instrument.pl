% Instrumentation de P_n pour compter les resolutions SLD (CF-1).
%
% Usage : swipl instrument.pl -- <entree.pl> <sortie.pl>
%
% Chaque clause utilisateur recoit l'appel res_inc en tete de corps :
%     H :- B.   ->   H :- res_inc, B.
%     H.        ->   H :- res_inc.
% res_inc n'est execute qu'apres une unification de tete reussie : le
% compteur vaut donc le nombre d'etapes de resolution SLD, y compris dans
% les branches qui echouent ensuite. Les builtins (is/2, >/2, !, ...) ne
% sont pas comptes, comme dans la table des builtins de CasLog (temps 0).

:- initialization(main, main).

main :-
    current_prolog_flag(argv, [In, Out]),
    setup_call_cleanup(open(In, read, S), read_all(S, Cs), close(S)),
    setup_call_cleanup(open(Out, write, O),
                       forall(member(C, Cs), (inst(C, C2), portray_clause(O, C2))),
                       close(O)).

read_all(S, Cs) :-
    read_term(S, T, []),
    (   T == end_of_file
    ->  Cs = []
    ;   Cs = [T|R],
        read_all(S, R)
    ).

inst((:- D), (:- D)) :- !.
inst((H :- B), (H :- (res_inc, B))) :- !.
inst(H, (H :- res_inc)).
