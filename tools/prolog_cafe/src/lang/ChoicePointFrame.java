package com.googlecode.prolog_cafe.lang;

/**
 * Choice point frame.
 *
 * @author Mutsunori Banbara (banbara@kobe-u.ac.jp)
 * @author Naoyuki Tamura (tamura@kobe-u.ac.jp)
 * @version 1.0
 */
class ChoicePointFrame {
    ChoicePointFrame prior;

    long timeStamp;
    Operation cont;  // continuation goal
    Operation bp;    // next clause
    int tr;          // trail pointer
    int b0;          // cut point
    private final Term[] savedRegisters;

    ChoicePointFrame() {
      this(null);
    }

    private ChoicePointFrame(Term[] savedRegisters) {
      this.savedRegisters = savedRegisters;
    }

    static ChoicePointFrame withSavedRegisters(Prolog engine, int registerCount) {
      return new ChoicePointFrame(engine.copyRegisters(registerCount));
    }

    void restore(Prolog engine) {
      engine.cont = this.cont;
      engine.restoreRegisters(this.savedRegisters);
    }

    @Override
    public String toString() {
      String t = " time:" + timeStamp + "\n" ;
      t = t + " cont:" + cont + "\n";
      t = t + " bp:" + bp + "\n";
      t = t + " tr:" + tr + "\n";
      t = t + " b0:" + b0 + "\n";
      t = t + " savedRegisters:" + (savedRegisters == null ? 0 : savedRegisters.length) + "\n";
      return t;
    }
}
