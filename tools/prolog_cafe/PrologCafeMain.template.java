import com.googlecode.prolog_cafe.lang.BufferingPrologControl;
import com.googlecode.prolog_cafe.lang.Term;
import com.googlecode.prolog_cafe.lang.VariableTerm;

public class PrologCafeMain {
    private static Term[] makeArguments() {
        return new Term[] { new VariableTerm() };
    }

    public static void main(String[] args) {
        BufferingPrologControl control = new BufferingPrologControl();
        
        // Limite de réduction augmentée par précaution pour les contrats complexes
        control.setReductionLimit(10000000L);
        control.initialize("user");
        
        // Exécution du but principal (on suppose goal/1)
        Term result = control.once("user", "goal", makeArguments()[0]);
        
        if (result != null) {
            System.out.println("Result: " + result);
        } else {
            System.out.println("Result: null (no solution)");
        }
    }
}
