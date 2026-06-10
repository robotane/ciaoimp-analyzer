%
%  error.pl			Nai-Wei Lin			December, 1991
%
%  This file contains the procedures for reporting error messages.
%

%
%  Print out an error message.
%
error_message(Code,Source,Clause) :-
	write('* Caslog error: '),
	error(Code,Source),
	nl,
	write('  '),
	write(Clause),
	nl.

%
%  Unknown complexity name error.
%
error(comp1,Source) :-
	write('unknown complexity name: '),
	write(Source).


%
%  Unknown predicate error.
%
error(lit1,Source) :-
	write('unknown predicate: '),
	write(Source).

%
%  Unbound input variable error.
%
error(bound1,Source) :-
	write('unbound input variable: '),
	write(Source).

%
%  Declaration error.
%
error(dec1,Source) :-
	write('complexity declaration is missed for predicate: '),
	write(Source).
error(dec2,Source) :-
	write('illegal declaration: '),
	write(Source).
error(dec3,Source) :-
	write('mode is not declared for predicate: '),
	write(Source).
error(dec4,Source) :-
	write('measure is not declared for predicate: '),
	write(Source).
error(dec5,Source) :-
	write('size is not declared for predicate: '),
	write(Source).
error(dec6,Source) :-
	write('det is not declared for predicate: '),
	write(Source).
error(dec7,Source) :-
	write('time is not declared for predicate: '),
	write(Source).
error(dec8,_) :-
	write('illegal expressions in declaration').
error(dec9,Source) :-
	write('mutex is not declared for predicate: '),
	write(Source).
error(mode1,_) :-
	write('use list_cas for mode declaration').
error(mode2,_) :-
	write('arity inconsistency in mode declaration').
error(mode3,Source) :-
	write('illegal mode symbol: '),
	write(Source).
error(measure1,_) :-
	write('use list_cas for measure declaration').
error(measure2,_) :-
	write('arity inconsistency in measure declaration').
error(measure3,Source) :-
	write('illegal measure name: '),
	write(Source).
error(mutex1,_) :-
	write('use list_cas for mutex declaration').
error(mutex2,_) :-
	write('use list_cas of integers for mutex declaration').
error(domain1,_) :-
	write('use list_cas for domain declaration').
error(domain2,_) :-
	write('arity inconsistency in domain declaration').
error(domain3,_) :-
	write('use integer interval or list_cas for domain declaration').
error(size1,_) :-
	write('use list_cas for size declaration').
error(size2,_) :-
	write('arity inconsistency in size declaration').
error(det1,_) :-
	write('do not use list_cas for det declaration').
error(time1,_) :-
	write('do not use list_cas for time declaration').
error(second_order1,Source) :-
	write('illegal predicate argument '),
	write(Source),
	write(' in findall predicate').
