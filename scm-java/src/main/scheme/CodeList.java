package scheme;

import java.util.ArrayList;

import scheme.jit.JitCode;

// The instruction list of compiled code. Caches its array form, which
// every Lambda over this code shares (a closure is created per FN), and
// the JIT's state for the code (scheme.jit.Jit).
public class CodeList extends ArrayList<Instruction> {
    private Instruction[] array;

    // the compiled code, once the code got hot and could be compiled
    public JitCode jit;
    // calls in the interpreter, counted towards Jit.threshold
    public int calls;
    // jit is JitBuiltins code, used by compiled callers only
    public boolean builtin;
    // true once compilation failed or was not possible
    public boolean jitRejected;
    // Jit.escapeOnly of a call/cc receiver over this code: 0 unknown, 1 yes, 2 no
    public byte escapeOnly;
    // operand stack depth before each instruction (Jit.analyze)
    public int[] depths;
    // the frames compiled code keeps in locals (Jit.Translator.analyzeLevels):
    // levels from firstUnboxed; per instruction the variable count of each
    // level; per level the index of its first variable in Rt.frames' vars
    public int firstUnboxed = Integer.MAX_VALUE;
    public int[][] shapes;
    public int[] varBase;

    public Instruction[] array() {
        Instruction[] a = array;
        if (a == null || a.length != size()) {
            a = toArray(new Instruction[0]);
            array = a;
        }
        return a;
    }

    // Drops everything derived from the instructions (set-code!).
    public void invalidate() {
        array = null;
        jit = null;
        calls = 0;
        jitRejected = false;
        escapeOnly = 0;
        depths = null;
    }
}
