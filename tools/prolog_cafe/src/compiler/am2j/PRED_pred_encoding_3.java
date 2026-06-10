package com.googlecode.prolog_cafe.compiler.am2j;

import com.googlecode.prolog_cafe.exceptions.PInstantiationException;
import com.googlecode.prolog_cafe.exceptions.PrologException;
import com.googlecode.prolog_cafe.lang.IntegerTerm;
import com.googlecode.prolog_cafe.lang.ListTerm;
import com.googlecode.prolog_cafe.lang.Operation;
import com.googlecode.prolog_cafe.lang.Predicate;
import com.googlecode.prolog_cafe.lang.Prolog;
import com.googlecode.prolog_cafe.lang.Term;
import com.googlecode.prolog_cafe.lang.VariableTerm;

/** {@code pred_encoding(+Codes, ?Encoded, ?Tail)} */
public class PRED_pred_encoding_3 extends Predicate.P3 {
  public PRED_pred_encoding_3(Term a1, Term a2, Term a3, Operation next) {
    arg1 = a1;
    arg2 = a2;
    arg3 = a3;
    cont = next;
  }

  @Override
  public Operation exec(Prolog engine) throws PrologException {
    engine.setB0();

    Term input = arg1.dereference();
    if (input instanceof VariableTerm) throw new PInstantiationException(this, 1);

    Term encoded = encode(input, arg3.dereference(), engine);
    if (encoded == null) return engine.fail();

    if (arg2.dereference().unify(encoded, engine.trail))
      return cont;
    else
      return engine.fail();
  }

  private Term encode(Term input, Term tail, Prolog engine) throws PrologException {
    input = input.dereference();
    if (Prolog.Nil.equals(input)) return tail;
    if (!(input instanceof ListTerm)) return null;

    Term head = ((ListTerm) input).car().dereference();
    Term rest = ((ListTerm) input).cdr().dereference();
    if (!(head instanceof IntegerTerm)) return null;

    int value = ((IntegerTerm) head).value();
    Term encodedRest = encode(rest, tail, engine);
    if (encodedRest == null) return null;

    return appendEncodedChar(value, encodedRest);
  }

  private Term appendEncodedChar(int value, Term tail) {
    if ((97 <= value && value <= 122) || (65 <= value && value <= 90)
        || (48 <= value && value <= 57) || value == 95 || value == 36) {
      return new ListTerm(new IntegerTerm(value), tail);
    }

    if (0 <= value && value <= 65535) {
      String hex = Integer.toHexString(value).toUpperCase();
      while (hex.length() < 4) hex = "0" + hex;

      Term result = tail;
      for (int i = hex.length() - 1; i >= 0; i--)
        result = new ListTerm(new IntegerTerm(hex.charAt(i)), result);

      return new ListTerm(new IntegerTerm(36), result);
    }

    return null;
  }
}
