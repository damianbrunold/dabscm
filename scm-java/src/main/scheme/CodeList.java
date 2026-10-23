package scheme;

import java.util.ArrayList;

// The instruction list of compiled code. Caches its array form, which
// every Lambda over this code shares (a closure is created per FN).
public class CodeList extends ArrayList<Instruction> {
    private Instruction[] array;

    public Instruction[] array() {
        Instruction[] a = array;
        if (a == null || a.length != size()) {
            a = toArray(new Instruction[0]);
            array = a;
        }
        return a;
    }
}
