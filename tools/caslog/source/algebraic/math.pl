/*
foreign_file('math.o',[pow,log2]).
foreign(pow,pow(+float,+float,[-float])).
foreign(log2,log2(+float,[-float])).
:- load_foreign_files(['math.o'],['-lm']).
*/

pow(X,Y,Z):-Z is X**Y.
log2(X,Y):-Y is log(X).

