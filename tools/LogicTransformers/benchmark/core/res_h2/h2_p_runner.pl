% Runner portable (Prolog Cafe, SWI-Prolog) pour P_n (CF-4 / H2).
%
% A concatener apres P_n et les faits :
%     h2_pscen(N, Appel).   % appel P_n construit depuis le scenario xsyntax
%
% Sortie :
%     H2P|N|NbSolutions|[Arg1, ..., ArgK]   (1re solution, ou [] si echec)

h2p_main :-
    h2_pscen(N, Call),
    h2p_one(N, Call),
    fail.
h2p_main.

h2p_one(N, Call) :-
    copy_term(Call, C2),
    findall(C2, call(C2), Sols),
    length(Sols, NS),
    write(user_output, 'H2P|'), write(user_output, N), write(user_output, '|'), write(user_output, NS), write(user_output, '|'),
    (   Sols = [S1|_]
    ->  S1 =.. [_|Args],
        h2_pt(Args)
    ;   write(user_output, '[]')
    ),
    nl(user_output).
