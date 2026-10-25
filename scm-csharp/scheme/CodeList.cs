namespace scheme;

// The instruction list of compiled code. Caches its array form, which
// every Lambda over this code shares (a closure is created per FN), and
// the JIT's state for the code (Jit).
public class CodeList : List<Instruction>
{
    private Instruction[]? array;

    // the compiled code, once the code got hot and could be compiled
    public JitCode? jit;
    // jit is JitBuiltins code, used by compiled callers only
    public bool builtin;
    // calls in the interpreter, counted towards Jit.Threshold
    public int calls;
    // true once compilation failed or was not possible
    public bool jitRejected;
    // Jit.EscapeOnly of a call/cc receiver over this code: 0 unknown, 1 yes, 2 no
    public byte escapeOnly;
    // operand stack depth before each instruction (Jit.Analyze)
    public int[]? depths;

    public Instruction[] Array()
    {
        var a = array;
        if (a == null || a.Length != Count)
        {
            a = ToArray();
            array = a;
        }
        return a;
    }

    // Drops everything derived from the instructions (set-code!).
    public void Invalidate()
    {
        array = null;
        jit = null;
        calls = 0;
        jitRejected = false;
        escapeOnly = 0;
        depths = null;
    }
}
